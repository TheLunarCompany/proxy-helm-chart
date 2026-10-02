#!/usr/bin/env bash
# AIGW-38: tear down the local MCPX + Lunar AI Gateway stack brought up by bring-up.sh.
#
# Default behavior (documented here so a second run's outcome is never a surprise):
#   - `helm uninstall` the release.
#   - Delete the disposable Keycloak Pod/Service/Ingress.
#   - KEEP the three PVCs (Postgres/Redis/ClickHouse data) and KEEP the minikube VM itself
#     (`minikube stop`, not `minikube delete`). This makes the next `bring-up.sh` fast and
#     preserves any data you created (MCPX instances, usage history, etc).
#   - Leave `minikube tunnel` running if it's running (it's harmless when idle, and killing
#     another terminal's process from here would be surprising).
#
# For a true clean-slate retest (what the plan calls "repeatability" testing), pass --full:
#   - Also deletes the PVCs (`kubectl delete pvc -n mcpx-hive --all`).
#   - Also runs `minikube delete` instead of `minikube stop`.
#
# Usage:
#   ./teardown.sh          # fast teardown, keep data + minikube VM
#   ./teardown.sh --full    # full wipe, next bring-up.sh starts from nothing

set -euo pipefail

NAMESPACE="mcpx-hive"
RELEASE="mcpx"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
FULL=false

for arg in "$@"; do
  case "$arg" in
    --full) FULL=true ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

log() { printf '\n[teardown] %s\n' "$*"; }

log "uninstalling helm release '$RELEASE' (namespace $NAMESPACE)"
helm uninstall "$RELEASE" -n "$NAMESPACE" 2>/dev/null || log "release not found, skipping"

log "deleting disposable Keycloak resources"
kubectl delete ingress keycloak -n "$NAMESPACE" --ignore-not-found
kubectl delete service keycloak -n "$NAMESPACE" --ignore-not-found
kubectl delete pod keycloak -n "$NAMESPACE" --ignore-not-found

if [ "$FULL" = true ]; then
  log "--full: deleting PVCs in $NAMESPACE"
  kubectl delete pvc -n "$NAMESPACE" --all --ignore-not-found

  log "--full: deleting local-only secrets (next bring-up.sh regenerates them)"
  kubectl delete secret mcpx-local-secrets llm-gateway-token mcpx-clickhouse mcpx-local-tls mcpx-keycloak-ca \
    -n "$NAMESPACE" --ignore-not-found

  log "--full: deleting namespace $NAMESPACE"
  kubectl delete namespace "$NAMESPACE" --ignore-not-found

  log "--full: minikube delete -p $MINIKUBE_PROFILE"
  minikube delete -p "$MINIKUBE_PROFILE"
else
  log "keeping PVCs, local secrets, and namespace $NAMESPACE (pass --full to wipe them)"
  log "minikube stop -p $MINIKUBE_PROFILE"
  minikube stop -p "$MINIKUBE_PROFILE"
fi

if pgrep -f "minikube.*tunnel" >/dev/null 2>&1; then
  log "NOTE: a 'minikube tunnel' process is still running in some terminal. Not killing it from" \
      "here — stop it yourself (Ctrl-C in that terminal) if you're done with this cluster for now."
fi

log "done."
