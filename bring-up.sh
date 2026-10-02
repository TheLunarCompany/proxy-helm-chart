#!/usr/bin/env bash
# AIGW-38: one-command local bring-up of MCPX + Lunar AI Gateway on minikube.
#
# What this does, in order (every step is readiness-gated, no fixed sleeps):
#   1. Start minikube sized for the full control plane + embedded Postgres/Redis/ClickHouse.
#   2. Build all 11 images from lunar-private on the host docker daemon, load them into minikube.
#   3. Deploy a disposable in-cluster Keycloak and import a realm/client/user/groups-scope
#      via a single `kcadm.sh create realms -f realm.json` call (scriptable, not UI clicking).
#   4. helm install/upgrade the chart with minikube-values.yaml.
#   5. Wait for every pod to be Ready.
#   6. Wire up host->ingress access (minikube tunnel + ingress Service patch + /etc/hosts).
#   7. Print the URLs to open and the test user's credentials.
#
# Prerequisites this script assumes are already installed: minikube, helm, kubectl, mkcert,
# docker (images are built on the host daemon, then `minikube image load`-ed in).
#
# ---------------------------------------------------------------------------------------------
# KNOWN MANUAL STEP (documented, not silently swallowed): `minikube tunnel` needs an interactive
# sudo password and must keep running in its own terminal for the lifetime of the cluster. This
# script cannot pass that prompt non-interactively, so it will print instructions and wait for
# you to start it in a separate terminal, then poll until the ingress Service gets an external IP.
# ---------------------------------------------------------------------------------------------
#
# Local-network workaround included below (NOT part of the chart, this is laptop-only glue):
# this host's corporate DNS search domain breaks pod-side resolution of the public *.example.com
# hostnames, so this script patches CoreDNS with a `hosts {}` block mapping them to the minikube
# node IP. If your network doesn't have this problem, this step is harmless (adds unused entries).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUNAR_PRIVATE="${LUNAR_PRIVATE:-$HOME/lunar-private}"
NAMESPACE="mcpx-hive"
RELEASE="mcpx"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
VALUES_FILE="$SCRIPT_DIR/minikube-values.yaml"
CHART_DIR="$SCRIPT_DIR/charts/lunar-mcpx-webapp"

HOSTS=(mcpx-app.example.com mcpx-admin.example.com mcpx-auth.example.com mcpx-ui.example.com mcpx.example.com keycloak.example.com)

log() { printf '\n[bring-up] %s\n' "$*"; }
die() { printf '\n[bring-up] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }
for c in minikube helm kubectl mkcert docker openssl; do require_cmd "$c"; done

# ------------------------------------------------------------------------------------------------
log "Step 1/8: minikube start"
# ------------------------------------------------------------------------------------------------
if minikube status -p "$MINIKUBE_PROFILE" >/dev/null 2>&1; then
  log "minikube profile '$MINIKUBE_PROFILE' already running, reusing it."
else
  minikube start -p "$MINIKUBE_PROFILE" --driver=docker --cpus=6 --memory=10000
fi

# Idempotent no-op if already enabled. Needed on a genuinely clean cluster: Step 6 below only
# patches an existing ingress-nginx-controller Service, it never installs the controller itself.
minikube addons enable ingress -p "$MINIKUBE_PROFILE"

# ------------------------------------------------------------------------------------------------
log "Step 2/8: build images on the host docker daemon, then load into minikube"
# ------------------------------------------------------------------------------------------------
IMAGE_NAMES=(mcpx-webserver mcpx-hub mcpx-auth-bff mcpx-router mcpx-hive-controller mcpx-jobs \
             mcpx-admin-ui mcpx-ui mcpx-server llm-gateway llm-gateway-hub)

# Created unconditionally (even under SKIP_IMAGE_BUILD): Step 3's mkcert output needs TLS_DIR too.
TMP_DOCKERFILES="$(mktemp -d)"
TLS_DIR="$(mktemp -d)"
CA_CTX_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DOCKERFILES" "$TLS_DIR" "$CA_CTX_DIR"; }
trap cleanup EXIT

# Opt-in debug escape hatch for iterating on Step 3+ without rebuilding. Not the default: the
# ticket requires images built from current source, and defaulting to skip would silently serve
# stale code after a lunar-private edit.
if [ "${SKIP_IMAGE_BUILD:-false}" = true ]; then
  log "SKIP_IMAGE_BUILD=true: verifying all 11 :local images already exist in both daemons instead of rebuilding"
  for n in "${IMAGE_NAMES[@]}"; do
    docker image inspect "$n:local" >/dev/null 2>&1 \
      || die "SKIP_IMAGE_BUILD=true but $n:local is missing from the host docker daemon. Run without SKIP_IMAGE_BUILD first."
    minikube -p "$MINIKUBE_PROFILE" image ls 2>/dev/null | grep -q "/$n:local$" \
      || die "SKIP_IMAGE_BUILD=true but $n:local is missing from minikube. Run without SKIP_IMAGE_BUILD first."
  done
  log "all 11 images present in both daemons, skipping Step 2 build/load"
else

[ -d "$LUNAR_PRIVATE" ] || die "lunar-private not found at $LUNAR_PRIVATE (set LUNAR_PRIVATE env var)"

# Catch a full docker VM disk now, not deep into some build with a cryptic ENOSPC.
DOCKER_DISK_PCT="$(docker run --rm alpine:3.20 df -P / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
if [ -n "$DOCKER_DISK_PCT" ] && [ "$DOCKER_DISK_PCT" -ge 90 ] 2>/dev/null; then
  die "Docker's VM disk is ${DOCKER_DISK_PCT}% full. Free space first, e.g.: docker builder prune -af && docker image prune -af"
fi

# Deliberately NOT `eval $(minikube docker-env)`: minikube's internal daemon's embedded DNS
# resolver can SERVFAIL on registry-1.docker.io on this Rancher Desktop setup. Build on the host
# daemon and `minikube image load` the result instead.

# Bundle a local corporate CA (Zscaler-style TLS interception) into builds if present, so
# npm/go module fetches succeed; a no-op if absent. Passed as a build context
# (`--build-context cabundle=...`), not an absolute host path — COPY sources must resolve inside
# a build context.
: > "$CA_CTX_DIR/aigw38-local-ca.crt"
for f in "$HOME/.zscaler_combined_bundle.pem" "$HOME/.certs/zscaler_root.pem" "$(mkcert -CAROOT 2>/dev/null)/rootCA.pem"; do
  [ -f "$f" ] && cat "$f" >> "$CA_CTX_DIR/aigw38-local-ca.crt"
done
CA_BUNDLE_NONEMPTY=false
[ -s "$CA_CTX_DIR/aigw38-local-ca.crt" ] && CA_BUNDLE_NONEMPTY=true

make_ca_aware_dockerfile() {
  # $1 = source Dockerfile, $2 = output path. Inserts the CA cert + trust-store wiring after
  # each node/golang FROM line; no-op copy if no local CA was found.
  local src="$1" out="$2"
  if [ "$CA_BUNDLE_NONEMPTY" != true ]; then
    cp "$src" "$out"
    return
  fi
  awk '
    /^FROM .*node:/ {
      print
      print "COPY --from=cabundle aigw38-local-ca.crt /usr/local/share/ca-certificates/aigw38-local-ca.crt"
      print "ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/aigw38-local-ca.crt"
      next
    }
    /^FROM golang:/ {
      print
      print "COPY --from=cabundle aigw38-local-ca.crt /usr/local/share/ca-certificates/aigw38-local-ca.crt"
      print "RUN cat /usr/local/share/ca-certificates/aigw38-local-ca.crt >> /etc/ssl/certs/ca-certificates.crt || true"
      next
    }
    { print }
  ' "$src" > "$out"
}

make_ca_aware_dockerfile "$LUNAR_PRIVATE/mcpx-webapp/Dockerfile-express"   "$TMP_DOCKERFILES/Dockerfile-express"
make_ca_aware_dockerfile "$LUNAR_PRIVATE/mcpx-webapp/Dockerfile-jobs"     "$TMP_DOCKERFILES/Dockerfile-jobs"
make_ca_aware_dockerfile "$LUNAR_PRIVATE/mcpx-webapp/Dockerfile-admin-ui" "$TMP_DOCKERFILES/Dockerfile-admin-ui"
make_ca_aware_dockerfile "$LUNAR_PRIVATE/mcpx/Dockerfile"                 "$TMP_DOCKERFILES/Dockerfile-mcpx.tmp"
make_ca_aware_dockerfile "$LUNAR_PRIVATE/llm-gateway/Dockerfile"          "$TMP_DOCKERFILES/Dockerfile-llm-gateway"
make_ca_aware_dockerfile "$LUNAR_PRIVATE/llm-gateway/Dockerfile.hub"      "$TMP_DOCKERFILES/Dockerfile-llm-gateway-hub"

# mcpx/Dockerfile needs two more fixes beyond CA trust: npm/cli#4828 (the @tailwindcss/oxide
# native binding fails to install in this Alpine/musl image) and stale exact-version Alpine
# package pins that age out of the repo.
awk '
  /^RUN npm run install:ui && npm run build:ui$/ {
    print "# Fix ARM64/x64 tailwindcss oxide native-binding optional dependency issue for Alpine/musl (npm/cli#4828)"
    print "RUN ARCH=$(uname -m) && \\"
    print "    if [ \"$ARCH\" = \"aarch64\" ] || [ \"$ARCH\" = \"arm64\" ]; then \\"
    print "        npm install @tailwindcss/oxide-linux-arm64-musl --save-dev --no-audit --no-fund 2>/dev/null || true; \\"
    print "    else \\"
    print "        npm install @tailwindcss/oxide-linux-x64-musl --save-dev --no-audit --no-fund 2>/dev/null || true; \\"
    print "    fi"
    print ""
  }
  { print }
' "$TMP_DOCKERFILES/Dockerfile-mcpx.tmp" | sed -E \
  -e 's/python3=[0-9.]+-r[0-9]+/python3/' \
  -e 's/py3-pip=[0-9.]+-r[0-9]+/py3-pip/' \
  -e 's/uv=[0-9.]+-r[0-9]+/uv/' \
  -e 's/ca-certificates=[0-9]+-r[0-9]+/ca-certificates/' \
  -e 's/libexpat=[0-9.]+-r[0-9]+/libexpat/' \
  -e 's/su-exec=[0-9.]+-r[0-9]+/su-exec/' \
  > "$TMP_DOCKERFILES/Dockerfile-mcpx"
rm -f "$TMP_DOCKERFILES/Dockerfile-mcpx.tmp"

build() {
  local name="$1"; shift
  log "building $name:local"
  docker build -t "$name:local" --build-context "cabundle=$CA_CTX_DIR" "$@"
  log "loading $name:local into minikube"
  minikube -p "$MINIKUBE_PROFILE" image load "$name:local"
}

(
  cd "$LUNAR_PRIVATE"
  build mcpx-webserver        -f "$TMP_DOCKERFILES/Dockerfile-express" --build-arg APP_NAME=webserver .
  build mcpx-hub              -f "$TMP_DOCKERFILES/Dockerfile-express" --build-arg APP_NAME=hub .
  build mcpx-auth-bff         -f "$TMP_DOCKERFILES/Dockerfile-express" --build-arg APP_NAME=auth-bff .
  build mcpx-router           -f "$TMP_DOCKERFILES/Dockerfile-express" --build-arg APP_NAME=router .
  build mcpx-hive-controller  -f "$TMP_DOCKERFILES/Dockerfile-express" --build-arg APP_NAME=hive-controller .
  build mcpx-jobs             -f "$TMP_DOCKERFILES/Dockerfile-jobs" .
  build mcpx-admin-ui         -f "$TMP_DOCKERFILES/Dockerfile-admin-ui" .
  build mcpx-ui               -f "$TMP_DOCKERFILES/Dockerfile-mcpx" --target mcpx-ui ./mcpx
  build mcpx-server           -f "$TMP_DOCKERFILES/Dockerfile-mcpx" --target mcpx-server ./mcpx
  build llm-gateway           -f "$TMP_DOCKERFILES/Dockerfile-llm-gateway" llm-gateway/
  build llm-gateway-hub       -f "$TMP_DOCKERFILES/Dockerfile-llm-gateway-hub" .
)

fi # SKIP_IMAGE_BUILD

# ------------------------------------------------------------------------------------------------
log "Step 3/8: namespace, CoreDNS local-network workaround, mkcert TLS secret"
# ------------------------------------------------------------------------------------------------
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

MINIKUBE_IP="$(minikube -p "$MINIKUBE_PROFILE" ip)"

# Corporate search-domain workaround: harmless if your network doesn't need it.
COREDNS_CM="$(mktemp)"
{
  echo 'apiVersion: v1'
  echo 'kind: ConfigMap'
  echo 'metadata:'
  echo '  name: coredns'
  echo '  namespace: kube-system'
  echo 'data:'
  echo '  Corefile: |'
  echo '    .:53 {'
  echo '        errors'
  echo '        health {'
  echo '           lameduck 5s'
  echo '        }'
  echo '        ready'
  echo '        hosts {'
  for h in "${HOSTS[@]}"; do
    echo "           $MINIKUBE_IP $h"
  done
  # Also add the search-domain-suffixed form pods inherit from /etc/resolv.conf's search line.
  for suffix in $(awk '/^search/{for(i=2;i<=NF;i++) print $i}' /etc/resolv.conf 2>/dev/null); do
    for h in "${HOSTS[@]}"; do
      echo "           $MINIKUBE_IP $h.$suffix"
    done
  done
  echo '           fallthrough'
  echo '        }'
  echo '        kubernetes cluster.local in-addr.arpa ip6.arpa {'
  echo '           pods insecure'
  echo '           fallthrough in-addr.arpa ip6.arpa'
  echo '           ttl 30'
  echo '        }'
  echo '        prometheus :9153'
  echo '        forward . /etc/resolv.conf {'
  echo '           max_concurrent 1000'
  echo '        }'
  echo '        cache 30 {'
  echo '           disable success cluster.local'
  echo '           disable denial cluster.local'
  echo '        }'
  echo '        loop'
  echo '        reload'
  echo '        loadbalance'
  echo '    }'
} > "$COREDNS_CM"
kubectl apply -f "$COREDNS_CM"
rm -f "$COREDNS_CM"
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=120s

# mkcert-trusted TLS cert covering all public hostnames, used by the ingress.
mkcert -install >/dev/null 2>&1 || true
(cd "$TLS_DIR" && mkcert -cert-file tls.crt -key-file tls.key "${HOSTS[@]}")
kubectl create secret tls mcpx-local-tls -n "$NAMESPACE" \
  --cert="$TLS_DIR/tls.crt" --key="$TLS_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

# Same mkcert root CA, exposed as a Secret so auth-bff/webserver/router/controller trust it when
# calling the public hostnames over HTTPS from inside the cluster (global.caCerts.secretName).
kubectl create secret generic mcpx-keycloak-ca -n "$NAMESPACE" \
  --from-file=ca.crt="$(mkcert -CAROOT)/rootCA.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

# Secrets referenced by minikube-values.yaml's extraEnvFromSecrets / credentialsSecret. The
# chart does not create these itself (they're meant to come from whatever secret store a real
# deployment uses) so bring-up.sh owns them for local use.
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-mcpx-local-secret}"
SESSION_SECRET="${SESSION_SECRET:-$(openssl rand -base64 32)}"
HUB_TOKEN="${HUB_TOKEN:-$(openssl rand -base64 24)}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9')}"

kubectl create secret generic mcpx-local-secrets -n "$NAMESPACE" \
  --from-literal=OIDC_CLIENT_ID=mcpx-local \
  --from-literal=OIDC_CLIENT_SECRET="$OIDC_CLIENT_SECRET" \
  --from-literal=OIDC_ISSUER=https://keycloak.example.com/realms/mcpx \
  --from-literal=OIDC_REDIRECT_URI=https://mcpx-auth.example.com/callback \
  --from-literal=JWT_ISSUER=https://mcpx-auth.example.com \
  --from-literal=OIDC_ROLES_CLAIM=groups \
  --from-literal=OIDC_MAPPED_ADMIN_ROLES=mcpx-admin \
  --from-literal=OIDC_MAPPED_MEMBER_ROLES=mcpx-member \
  --from-literal=SESSION_SECRET="$SESSION_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic llm-gateway-token -n "$NAMESPACE" \
  --from-literal=HUB_TOKEN="$HUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic mcpx-clickhouse -n "$NAMESPACE" \
  --from-literal=CLICKHOUSE_USER=default \
  --from-literal=CLICKHOUSE_PASSWORD="$CLICKHOUSE_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# ------------------------------------------------------------------------------------------------
log "Step 4/8: deploy disposable Keycloak"
# ------------------------------------------------------------------------------------------------
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: keycloak
  namespace: $NAMESPACE
  labels: {run: keycloak}
spec:
  restartPolicy: Never
  containers:
    - name: keycloak
      image: quay.io/keycloak/keycloak:26.3
      args: ["start-dev", "--http-port=8080", "--hostname=https://keycloak.example.com", "--hostname-strict=false", "--http-enabled=true"]
      env:
        - {name: KEYCLOAK_ADMIN, value: admin}
        - {name: KEYCLOAK_ADMIN_PASSWORD, value: admin}
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: $NAMESPACE
  labels: {run: keycloak}
spec:
  selector: {run: keycloak}
  ports: [{port: 8080, targetPort: 8080}]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: $NAMESPACE
spec:
  ingressClassName: nginx
  tls:
    - hosts: [keycloak.example.com]
      secretName: mcpx-local-tls
  rules:
    - host: keycloak.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: {name: keycloak, port: {number: 8080}}
EOF

log "waiting for keycloak pod readiness"
kubectl wait --for=condition=ready pod/keycloak -n "$NAMESPACE" --timeout=180s

KC_TEST_USER="${KC_TEST_USER:-local-admin}"

log "waiting for Keycloak's http listener to actually accept admin logins (pod-ready != JVM-booted)"
KC_LOGIN_OK=false
for _ in $(seq 1 30); do
  if kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh config credentials \
      --server http://localhost:8080 --realm master --user admin --password admin 2>/dev/null; then
    KC_LOGIN_OK=true
    break
  fi
  sleep 5
done
[ "$KC_LOGIN_OK" = true ] || die "Keycloak admin login never succeeded after 150s; check 'kubectl logs -n $NAMESPACE keycloak'"

REALM_PREEXISTED=false
if kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh get realms -r master \
    --fields realm 2>/dev/null | grep -q '"realm" : "mcpx"'; then
  REALM_PREEXISTED=true
  KC_TEST_PASSWORD="(unknown — realm pre-existed, no new password was set; delete the keycloak pod and re-run for a clean import)"
  log "realm 'mcpx' already exists in Keycloak, skipping import (delete the keycloak pod for a clean re-import)"
else
  # Only generated on the actual import path, so Step 8's banner never prints a password that
  # was silently discarded instead of applied.
  KC_TEST_PASSWORD="${KC_TEST_PASSWORD:-$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9')}"

  # No top-level "clientScopes"/"defaultClientScopes" here on purpose: declaring either makes
  # Keycloak skip creating its built-in scopes (profile/email/roles/...), breaking login with
  # "invalid_scope". The "groups" scope is created and attached separately below instead.
  REALM_JSON="$(mktemp)"
  cat > "$REALM_JSON" <<EOF
{
  "realm": "mcpx",
  "enabled": true,
  "clients": [{
    "clientId": "mcpx-local",
    "secret": "$OIDC_CLIENT_SECRET",
    "redirectUris": ["https://mcpx-auth.example.com/callback"],
    "webOrigins": ["https://mcpx-admin.example.com", "https://mcpx.example.com", "https://mcpx-ui.example.com"],
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": true,
    "publicClient": false
  }],
  "groups": [{"name": "mcpx-admin"}, {"name": "mcpx-member"}],
  "users": [{
    "username": "$KC_TEST_USER",
    "enabled": true,
    "email": "$KC_TEST_USER@example.com",
    "emailVerified": true,
    "firstName": "Local",
    "lastName": "Admin",
    "credentials": [{"type": "password", "value": "$KC_TEST_PASSWORD", "temporary": false}],
    "groups": ["/mcpx-admin"]
  }]
}
EOF

  GROUPS_SCOPE_JSON="$(mktemp)"
  cat > "$GROUPS_SCOPE_JSON" <<'EOF'
{
  "name": "groups",
  "protocol": "openid-connect",
  "attributes": {"include.in.token.scope": "true", "display.on.consent.screen": "false"},
  "protocolMappers": [{
    "name": "groups",
    "protocol": "openid-connect",
    "protocolMapper": "oidc-group-membership-mapper",
    "config": {
      "full.path": "false", "id.token.claim": "true", "access.token.claim": "true",
      "userinfo.token.claim": "true", "claim.name": "groups", "multivalued": "true"
    }
  }]
}
EOF

  kubectl exec -i -n "$NAMESPACE" keycloak -- sh -c 'cat > /tmp/realm-import.json' < "$REALM_JSON"
  kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh create realms -f /tmp/realm-import.json
  kubectl exec -n "$NAMESPACE" keycloak -- rm -f /tmp/realm-import.json

  log "adding the 'groups' client-scope and attaching it to mcpx-local as a default scope"
  kubectl exec -i -n "$NAMESPACE" keycloak -- sh -c 'cat > /tmp/groups-scope.json' < "$GROUPS_SCOPE_JSON"
  kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh create client-scopes -r mcpx -f /tmp/groups-scope.json
  kubectl exec -n "$NAMESPACE" keycloak -- rm -f /tmp/groups-scope.json

  MCPX_CLIENT_ID="$(kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh get clients -r mcpx \
    -q clientId=mcpx-local --fields id --format csv --noquotes 2>/dev/null | tail -1)"
  # client-scopes' `-q name=...` filter is silently ignored by this kcadm.sh (unlike clients'
  # `-q clientId=...` above), so filter client-side instead of trusting the server to.
  GROUPS_SCOPE_ID="$(kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh get client-scopes -r mcpx \
    --fields name,id --format csv --noquotes 2>/dev/null | awk -F, '$1=="groups"{print $2}')"
  [ -n "$MCPX_CLIENT_ID" ] || die "could not resolve mcpx-local client id after realm import"
  [ -n "$GROUPS_SCOPE_ID" ] || die "could not resolve groups client-scope id after creating it"
  kubectl exec -n "$NAMESPACE" keycloak -- /opt/keycloak/bin/kcadm.sh update \
    "clients/$MCPX_CLIENT_ID/default-client-scopes/$GROUPS_SCOPE_ID" -r mcpx
fi
rm -f "${REALM_JSON:-}" "${GROUPS_SCOPE_JSON:-}"

# ------------------------------------------------------------------------------------------------
log "Step 5/8: helm install/upgrade"
# ------------------------------------------------------------------------------------------------
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  -n "$NAMESPACE" --create-namespace \
  -f "$VALUES_FILE" \
  --timeout 10m

log "waiting for all pods in $NAMESPACE to become Ready"
# Excludes Succeeded/Failed: completed CronJob pods stick around and would otherwise make
# `--all` time out even though every real app pod is healthy.
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" \
  --field-selector='status.phase!=Succeeded,status.phase!=Failed' --timeout=300s

# ------------------------------------------------------------------------------------------------
log "Step 6/8: wire up host -> ingress access (minikube tunnel)"
# ------------------------------------------------------------------------------------------------
CURRENT_SVC_TYPE="$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.type}' 2>/dev/null || true)"
if [ "$CURRENT_SVC_TYPE" != "LoadBalancer" ]; then
  kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'
fi

if ! pgrep -f "minikube.*tunnel" >/dev/null 2>&1; then
  log "minikube tunnel is not running. Open a SEPARATE terminal and run:"
  echo
  echo "    sudo minikube tunnel -p $MINIKUBE_PROFILE"
  echo
  log "Leave that terminal open for as long as you want host->cluster access. Waiting for it to start..."
  until kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q .; do
    sleep 2
  done
fi

EXTERNAL_IP="$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
log "ingress external IP: $EXTERNAL_IP"

MISSING_HOSTS=()
for h in "${HOSTS[@]}"; do
  grep -qE "^[0-9.]+[[:space:]]+$h\$" /etc/hosts 2>/dev/null || MISSING_HOSTS+=("$h")
done
if [ "${#MISSING_HOSTS[@]}" -gt 0 ]; then
  log "The following hostnames are missing from /etc/hosts. Add them (sudo required), pointing at $EXTERNAL_IP:"
  for h in "${MISSING_HOSTS[@]}"; do echo "    $EXTERNAL_IP $h"; done
  echo
  log "Example one-liner:"
  echo "    sudo sh -c 'printf \"%s\\n\" $(for h in "${MISSING_HOSTS[@]}"; do printf '"%s %s" ' "$EXTERNAL_IP" "$h"; done) >> /etc/hosts'"
else
  log "/etc/hosts already has all required hostnames."
fi

# ------------------------------------------------------------------------------------------------
log "Step 7/8: verify ingress is actually reachable"
# ------------------------------------------------------------------------------------------------
CA_ROOT="$(mkcert -CAROOT)/rootCA.pem"
if curl -s -o /dev/null -w '%{http_code}' --max-time 5 --cacert "$CA_ROOT" "https://mcpx-admin.example.com/" 2>/dev/null | grep -qE '^(200|30[0-9])$'; then
  log "HTTPS ingress reachable."
else
  log "WARNING: could not reach https://mcpx-admin.example.com/ yet. If /etc/hosts was just updated, DNS/caches may need a moment, or minikube tunnel may not be fully up."
fi

# ------------------------------------------------------------------------------------------------
log "Step 8/8: done"
# ------------------------------------------------------------------------------------------------
cat <<EOF

======================================================================
AIGW-38 stack is up.

  Admin UI:    https://mcpx-admin.example.com/
  Webserver:   https://mcpx-app.example.com/
  Router:      https://mcpx.example.com/
  MCPX UI:     https://mcpx-ui.example.com/
  Keycloak:    https://keycloak.example.com/admin/master/console/  (admin/admin)

  Test user for logging into the MCPX stack:
    username: $KC_TEST_USER
    password: $KC_TEST_PASSWORD

  kubectl get pods -n $NAMESPACE   # confirm everything is Running/Ready
======================================================================
EOF
