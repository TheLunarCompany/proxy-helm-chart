# Lunar MCPX Webapps Helm Chart

## Intro
This Helm chart will install Lunar MCPX Webapps on your Kubernetes cluster.

### Prerequisites
#### Image pull secrets
To be able to pull images from Lunar Private Registry please make sure that pull secrets has been configured.
Contact Lunar sales representative in order to receive credentials. Credentials can be installed with following command:
```
kubectl create ns {{ mcpx_namespace }}
kubectl apply -f lunar-private-mcpx-registry.yaml -n {{ mcpx_namespace }}
```

#### Required external services
Lunar MCPX Webapps requires external Postresql and Redis servers in order to work. It is possible to deploy this chart with
embedded services by setting up following variables:

```
postgres.enabled=true
redis.enabled=true 
```

> [!WARNING]  
> Embedded services included in this is chart are for demo/POC purposes only. Please do NOT use them in production.


Required service versions:

|  Service   | Version  |
|:----------:|:--------:|
| Postgresql | \>= 17.0 |
|   Redis    | \>= 8.0  |



#### Required global environment variables with sensitive data

|       Variable        |                                           Value                                           |
|:---------------------:|:-----------------------------------------------------------------------------------------:|
|    SESSION_SECRET     |    random string, can be generated on Unix system by running 'openssl rand -base64 32'    |
| SESSION_COOKIE_DOMAIN |                                        example.com                                        |
|     DATABASE_URL      | postgres://{{ USER }}:{{ PASS }}@{{ HOST }}:{{ PORT }}/{{ DATABASE }}?schema={{ SCHEMA }} |
|       REDIS_URL       |                               redis://{{ HOST }}:{{ PORT }}                               |
|   REDIS_IS_CLUSTER    |                                   boolean (true\|false)                                   |

#### Required encryption configuration

|    Variable    |                                       Value                                        |
|:--------------:|:----------------------------------------------------------------------------------:|
| ENCRYPTION_KEY | base64-encoded 32-byte AES-256-GCM key, generate with `openssl rand -base64 32` |

Used by hub, webserver, and any service that reads or clones setups. Set via `global.encryptionKey` — the value is injected into all services through the shared embedded secret.

#### Required OIDC environment variables with sensitive data

|           Variable            | Value |
|:-----------------------------:|:-----:|
|        OIDC_CLIENT_ID         |       |
|      OIDC_CLIENT_SECRET       |       |
|          OIDC_ISSUER          |       |
|       OIDC_REDIRECT_URI       |       |
|         OIDC_JWKS_URI         |       |
|         OIDC_AUDIENCE         |       |
|       OIDC_ISSUER_URL         |       |

Note: Router `OIDC_JWKS_URI` defaults to in-cluster auth service (`http://<release>-auth/.well-known/jwks.json`) and can be overridden with `router.oidcJwksUri`.

#### Optional environmental variables


|     Variable     |                                           Value                                           |
|:----------------:|:-----------------------------------------------------------------------------------------:|
|    LOG_LEVEL     |                                           info|debug                                            |


It is possible to supply this variables using several different techniques:
- Using pre-created secret and extraEnvFromSecrets (recommended):
  - Create secret with global variables:
      ```bash
      kubectl create secret generic mcpx-webapp-global -n {{ mcpx_namespace }} \
        --from-literal=SESSION_SECRET="$(openssl rand -base64 32)" \
        --from-literal=DATABASE_URL="postgres://{{ USER }}:{{ PASS }}@{{ HOST }}:{{ PORT }}/{{ DATABASE }}?schema={{ SCHEMA }}" \
        --from-literal=REDIS_URL="redis://{{ HOST }}:{{ PORT }}" \
        --from-literal=REDIS_IS_CLUSTER="{{ boolean (true or false) }}"
      ```
  - Create secret with OIDC variables:
    ```bash
    kubectl create secret generic mcpx-webapp-oidc -n {{ mcpx_namespace }} \
        --from-literal=OIDC_CLIENT_ID="" \
        --from-literal=OIDC_CLIENT_SECRET="" \
        --from-literal=OIDC_ISSUER="" \
        --from-literal=OIDC_REDIRECT_URI="" \
        --from-literal=OIDC_JWKS_URI="" \
        --from-literal=OIDC_AUDIENCE="" \
        --from-file=credentials.json="/path/to/service-account.json"
    ```
  - Specify pre-created secrets using `extraEnvFromSecrets` parameter:
    ```yaml
    ---
    global:
      extraEnvFromSecrets:
        - mcpx-webapp-global

    hub:
      extraEnvFromSecrets:
        - mcpx-webapp-oidc

    auth:
      extraEnvFromSecrets:
        - mcpx-webapp-oidc
      googleApplicationCredentials:
        secretName: mcpx-webapp-oidc
    ```

  - `auth.googleApplicationCredentials` is optional.
    - Set `secretName` to mount a service account key as a file for `auth-bff`.
    - The chart then sets `GOOGLE_APPLICATION_CREDENTIALS=/var/secrets/google/credentials.json`.
    - Override `secretKey` if your secret stores the JSON under a different key name.
    - Leave it unset to rely on ambient ADC / Workload Identity instead.

- Using values-override.yaml file with plain-text value:
```yaml
---
global:
  extraEnvVars:
    - name: DATABASE_URL
      value: "postgres://{{ USER }}:{{ PASS }}@{{ HOST }}:{{ PORT }}/{{ DATABASE }}?schema={{ SCHEMA }}"
    - name: REDIS_URL
      value: "redis://{{ HOST }}:{{ PORT }}"
    - name: REDIS_IS_CLUSTER
      value: "true|false"
```

- Using values-override.yaml file with extraEnvVars and extraEnvVars:
```yaml
---
global:
  extraEnvVars:
    - name: DATABASE_URL
      valueFrom:
      `secretKeyRef`:
        name: SECRET_NAME
        key: KEY1
    - name: REDIS_URL
      valueFrom:
      secretKeyRef:
        name: SECRET_NAME
        key: KEY2
    - name: REDIS_IS_CLUSTER
      valueFrom:
      secretKeyRef:
        name: SECRET_NAME
        key: KEY3
```

### Ingress configuration
Ingress configuration is heavily depends on the Kubernetes cluster configuration, cloud platform, network configuration, etc.
Please reffer to [examples/values-override](examples/values-override) directory to find example applicable for your environment


### Private Certificate Authorities
For the cases when there is a requirement of using certificates issued by private CA, it is required to make this CA
'trusted' to application by adding it as a Kubernetes secrets and configuring in `global.caCerts` section.

To add CA cert as a secret one can use following command:
```bash
kubectl create secret generic {{ name_of_cert }} -n {{ mcpx_namespace }} --from-file=ca.crt={{ path/to/file }}
```
Note: In case when multiple CA certificates should be added, concat all of them in the same file and import as a single
kubernetes secret

#### GCP

- [Minimal non-production configuration with GCE ingress controller](examples/values-override/gcp-nonprod-demo.yaml)
- [Production-like configuration with external secrets and external databases](examples/values-override/gcp-prod.yaml)

### Admin DB Migration Jobs

This chart includes four **suspended CronJobs** for DB migration management. They never run automatically — admins create one-off jobs from them using `kubectl create job`.

> **Warning:** These jobs interact directly with the database. Use with caution and only when instructed!

| CronJob | Purpose |
|:--------|:--------|
| `<release>-migrate-status` | Shows the current state of all migrations |
| `<release>-migrate-rollback-dry` | Dry-run rollback (no changes are made) |
| `<release>-migrate-rollback-execute` | **Executes** a rollback — this will modify the database |
| `<release>-migrate-resolve-failed` | Marks a failed migration as resolved so Prisma can move past it |

In the examples below, `<release>` is the full CronJob name prefix — composed of your Helm release name and the chart name (e.g. `mcpx-webapp`). Run `kubectl get cronjobs -n <namespace> | grep migrate` to find the exact names.

**Check migration status:**
```bash
kubectl create job migrate-status-$(date +%s) \
  --from=cronjob/<release>-migrate-status -n <namespace>
```

**Dry-run a rollback (safe, no DB changes):**
```bash
kubectl create job rollback-dry-$(date +%s) \
  --from=cronjob/<release>-migrate-rollback-dry -n <namespace>
```

**Execute a rollback:**
```bash
kubectl create job rollback-$(date +%s) \
  --from=cronjob/<release>-migrate-rollback-execute -n <namespace>
```

**Resolve a failed migration (allows Prisma to proceed on next deploy):**
```bash
kubectl create job resolve-failed-$(date +%s) \
  --from=cronjob/<release>-migrate-resolve-failed -n <namespace>
```

> **Rollback vs. Resolve-failed:**
> - **Rollback** is for when a migration ran successfully but is causing issues — the app is misbehaving, or you need to revert to a previous version for any reason. Rollback undoes the migration's changes to the database.
> - **Resolve-failed** is for when a migration ran and failed. A failed migration blocks all future migrations from running. Since we use a forward-rolling strategy (we never delete migrations, even bad ones), resolving marks the failed migration as acknowledged so the next release — which should contain the fix — can run its migrations normally.

By default, rollback targets the latest applied migration and resolve-failed targets the latest failed migration. To target a specific migration, set `jobs.admin.rollbackMigrationName` or `jobs.admin.resolveMigrationName` via Helm values override, apply it, and then create the job.

### Catalog Item Store Jobs

This chart includes three **suspended CronJobs** for managing catalog items from the built-in store. Like the migration jobs above, they never run automatically — admins create one-off jobs from them using `kubectl create job`.

| CronJob | Purpose |
|:--------|:--------|
| `<release>-catalog-list` | Lists all store items and their status relative to the DB (already present, customized, missing, etc.) |
| `<release>-catalog-populate` | Inserts new catalog items from the store into the DB |
| `<release>-catalog-fix` | Updates existing DB catalog items with the latest store definitions |

**List all store catalog items and their status:**
```bash
kubectl create job catalog-list-$(date +%s) \
  --from=cronjob/<release>-catalog-list -n <namespace>
```

**Populate new catalog items from the store:**

First, set `jobs.admin.catalogItemStore.catalogItemNames` to the desired items, apply the Helm values, then create the job:
```yaml
jobs:
  admin:
    catalogItemStore:
      catalogItemNames:
        - slack
        - github
        - linear
```
```bash
kubectl create job catalog-populate-$(date +%s) \
  --from=cronjob/<release>-catalog-populate -n <namespace>
```

**Fix (update) existing catalog items from the store:**

Set `catalogItemNames` the same way. Optionally set `forceOverride` to `true` to replace DB config entirely instead of merging:
```yaml
jobs:
  admin:
    catalogItemStore:
      catalogItemNames:
        - slack
        - github
      forceOverride: true
```
```bash
kubectl create job catalog-fix-$(date +%s) \
  --from=cronjob/<release>-catalog-fix -n <namespace>
```

> **Merge vs. Force Override:**
> - **Default (merge):** metadata fields (`displayName`, `description`, `repoUrl`, `docsUrl`) are overwritten from the store. For stdio config, `command` and `args` are overridden from the store; for env, only new keys are added — existing admin customizations are preserved. For remote config, `url` is overridden; for headers, only new keys are added.
> - **Force override (`forceOverride: true`):** the entire config is replaced with the store template, discarding all admin customizations.

### Catalog Derived Host Backfill Job

This chart includes a **suspended CronJob** for a one-time backfill that populates the `derivedHost` column on existing catalog items with remote config. Like the other admin jobs above, it never runs automatically — admins create a one-off job from it using `kubectl create job`.

| CronJob | Purpose |
|:--------|:--------|
| `<release>-host-backfill` | Backfills `derivedHost` on catalog items where it is currently null (remote config items only) |

**Run the backfill:**
```bash
kubectl create job host-backfill-$(date +%s) \
  --from=cronjob/<release>host-backfill -n <namespace>
```

> **Note:** This job is idempotent — it only updates items where `derivedHost` is null. Stdio catalog items are skipped.

### ClickHouse System-Log Pruning

When `clickhouse.enabled` is set, `clickhouse.systemLogConfig` disables ClickHouse's internal system-log tables (`text_log`, `trace_log`, `metric_log`, `asynchronous_metric_log`) going forward — they grow with server uptime and can fill the data volume. Historical rows written before that may still be sitting on the volume; they have no use, so the chart includes two **suspended CronJobs** to drop them. Running these is optional (not mandatory) and, like the other admin jobs, they never run automatically.

| CronJob | Purpose |
|:--------|:--------|
| `<release>-prune-ch-logs-dry` | Reports which tables would be dropped and how many bytes would be freed (no changes) |
| `<release>-prune-ch-logs-execute` | **Drops** the noisy system-log tables |

**Run a dry run, then execute:**
```bash
kubectl create job prune-ch-logs-dry-$(date +%s) \
  --from=cronjob/<release>-prune-ch-logs-dry -n <namespace>

kubectl create job prune-ch-logs-execute-$(date +%s) \
  --from=cronjob/<release>-prune-ch-logs-execute -n <namespace>
```

### Drain Space-Editing Swaps

Restores each user's real ACTIVE setup before moving to the new space-editing mechanism. If a user was left mid-edit under the old mechanism, their ACTIVE slot holds a temporary editing copy while their real setup sits in a stash. Two **suspended CronJobs**, they never run automatically.

| CronJob | Purpose |
|:--------|:--------|
| `<release>-drain-swaps-dry` | Lists every affected user (email + space name), makes no changes |
| `<release>-drain-swaps-execute` | **Restores** each affected user's real ACTIVE setup |

**Run a dry run, then execute:**
```bash
kubectl create job drain-swaps-dry-$(date +%s) \
  --from=cronjob/<release>-drain-swaps-dry -n <namespace>

kubectl create job drain-swaps-execute-$(date +%s) \
  --from=cronjob/<release>-drain-swaps-execute -n <namespace>
```

> **Note:** Once you upgrade the MCPX pods in the system, any affected setup will be the correct one.

### Migrate Tool Groups to Skills

Turns each active setup's tool groups into skills before enabling the skills feature. Every tool group becomes one skill carrying the same capability group; tools on custom (non-catalog) servers are dropped, and a group left with nothing is skipped. The original tool groups are **not** deleted. The migrated skills are **not** enabled for any consumer/client, so after the migration users will need to re-enable them per subject. A single **suspended CronJob**, it never runs automatically. It is **idempotent**: rerunning skips groups already migrated, so no duplicates.

| CronJob | Purpose |
|:--------|:--------|
| `<release>-migrate-tool-groups-to-skills` | Creates a skill per tool group; logs a report of what was created, skipped, and dropped |

**Run it:**
```bash
kubectl create job migrate-tgs-$(date +%s) \
  --from=cronjob/<release>-migrate-tool-groups-to-skills -n <namespace>
```

> **Note:** Run this job first and check its log, then enable the skills feature flag on the MCPX instances. Order matters: migrate, then turn on.

### Hibernation

Two independent ways to hibernate idle MCPX instances. Either one (or both) turns
`HIBERNATION_ENABLED` on for the webserver, and they can run together.

**Scheduled (CronJob).** `hibernation.cronSchedule` controls when the `hibernate-instances`
CronJob runs.

- Build/verify cron expressions with [crontab.guru](https://crontab.guru/).
- Keep it empty to disable the CronJob:
  ```yaml
  hibernation:
    cronSchedule: ""
  ```
- Example: run daily at 22:00
  ```yaml
  hibernation:
    cronSchedule: "0 22 * * *"
  ```
- Example: every 5 minutes (testing)
  ```yaml
  hibernation:
    cronSchedule: "*/5 * * * *"
  ```

**Idle (signal-based).** `hibernation.idleMinutes` hibernates any instance with no real usage
for that many minutes. The webserver runs an in-process reconciler; no CronJob involved.

- `0` disables it (default). Apart from `0`, the effective minimum is `3`: values of `1` or
  `2` are clamped up to `3`.
- Idle-only (no schedule):
  ```yaml
  hibernation:
    idleMinutes: 30
  ```
- Both together (scheduled sweep plus idle reconciler):
  ```yaml
  hibernation:
    cronSchedule: "0 22 * * *"
    idleMinutes: 30
  ```

### ClickHouse (Event Store Analytics)

The chart can deploy an embedded single-node ClickHouse instance for event store analytics. ClickHouse is cluster-internal only and is **not** exposed outside the cluster.

#### Prerequisites

1. Create a Kubernetes secret containing ClickHouse credentials:
   ```bash
   kubectl create secret generic ch-creds -n <namespace> \
     --from-literal=CLICKHOUSE_USER=default \
     --from-literal=CLICKHOUSE_PASSWORD='<strong-password>'
   ```

2. Enable ClickHouse and reference the secret in your values override:
   ```yaml
   clickhouse:
     enabled: true
     credentialsSecret: ch-creds
   ```

When enabled, the chart will:
- Deploy a ClickHouse StatefulSet with a persistent volume (default 10Gi)
- Create a ClusterIP service on port 8123
- Add a ClickHouse migration init container to both hub and webserver (runs after the Prisma migration)
- Inject `CLICKHOUSE_URL` into hub and webserver main containers

If `clickhouse.enabled` is `true` but the credentials secret is missing or empty, `helm install` will fail with a schema validation error.

#### REPL access (debugging)

```bash
kubectl exec -it <release>-clickhouse-0 -n <namespace> -- clickhouse-client \
  --user <user> --password <password>
```

### Installation

Minimal deployment with embedded Postgresql and Redis
```bash
helm install mcpx lunar/lunar-mcpx-webapp --version $CHART_VERSION --set postgres.enabled=true --set redis.enabled=true
```

Alternatively, you may work with a separate values file to handle values override just like any other Helm chart:

```bash
helm install mcpx lunar/lunar-mcpx-webapp --version $CHART_VERSION  -f ./values-override.yaml
```

### MCPX runtime auth

If your MCPX instances need private registry or index credentials at runtime, pre-create the
relevant secrets in the MCPX namespace and reference them through `controller.mcpxRuntimeAuth`.

This is separate from the chart image pull secret above. The chart image pull secret is used by
Kubernetes to pull Lunar images for this deployment, while `controller.mcpxRuntimeAuth` is used at
runtime inside each MCPX instance pod.

Each runtime auth setting accepts one secret per config type. That single secret can still contain
multiple registries or indexes inside the native config format, which matches how Docker, npm, and
uv expect these files to be managed.

For Docker-based MCP servers, create a `docker-registry` secret:

```bash
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry-host> \
  --docker-username=<username> \
  --docker-password=<token> \
  -n {{ mcpx_namespace }}
```

For npm or npx, create a generic secret with a `.npmrc` key:

```bash
kubectl create secret generic <npm-secret-name> \
  --from-file=.npmrc=<path/to/.npmrc> \
  -n {{ mcpx_namespace }}
```

For uv or uvx, create generic secrets with `uv.toml` and `.netrc` keys as needed:

```bash
kubectl create secret generic <uv-config-secret-name> \
  --from-file=uv.toml=<path/to/uv.toml> \
  -n {{ mcpx_namespace }}

kubectl create secret generic <netrc-secret-name> \
  --from-file=.netrc=<path/to/.netrc> \
  -n {{ mcpx_namespace }}
```

```yaml
controller:
  mcpxRuntimeAuth:
    dockerConfigSecret: <secret-name>
    npmrcSecret: <npm-secret-name>
    uvConfigSecret: <uv-config-secret-name>
    netrcSecret: <netrc-secret-name>
```

`dockerConfigSecret` must reference a `kubernetes.io/dockerconfigjson` secret and is exposed
through `DOCKER_CONFIG`. A single Docker config can include credentials for multiple registries.

`fsGroup` controls which group can read the mounted runtime auth secrets. The default `1002`
matches the current Lunar MCPX image group and can be overridden if a custom MCPX image uses a
different runtime group.

`npmrcSecret` must contain a `.npmrc` key and is exposed through `NPM_CONFIG_USERCONFIG` for npm
and npx. A single `.npmrc` can define multiple registries, scopes, and auth entries.

`uvConfigSecret` must contain a `uv.toml` key and is exposed through `UV_CONFIG_FILE` for uv and
uvx. A single `uv.toml` can define multiple indexes.

`netrcSecret` must contain a `.netrc` key and is exposed through `NETRC` for uv, uvx, and other
tools that honor `.netrc`. A single `.netrc` can contain credentials for multiple hosts.

`decodeBase64`, when set to `true`, treats the referenced runtime-auth secret values as base64-encoded and decodes them at pod startup via an init container. Use this for secret backends (e.g. AWS Secrets Manager) that cannot supply multi-line values cleanly.

Make sure the referenced secrets already exist in the MCPX namespace before MCPX instances are
created or restarted.

### Static OAuth configuration

Use `hub.staticOauth` to configure OAuth credentials that the Hub distributes to all connected
MCPX instances. This is useful for MCP servers that require OAuth authentication (e.g. GitHub, Asana).

Two auth methods are supported - depending on what the provider offers and supports:

- **`device_flow`** — user authorizes via browser, only a client ID is needed.
- **`client_credentials`** — traditional OAuth with client ID and secret.

The `mapping` section maps domains to provider keys, and `providers` defines the credentials and
endpoints for each provider. This allows you to match several related domains (e.g. `github.com`, `api.github.com`) to the same provider config.

**Example: GitHub device flow**

```yaml
hub:
  staticOauth:
    mapping:
      github.com: github
      api.github.com: github
      api.githubcopilot.com: github
    providers:
      github:
        authMethod: device_flow
        credentials:
          clientId: "<from your app>"
        scopes:
          - repo
        endpoints:
          deviceAuthorizationUrl: https://github.com/login/device/code
          tokenUrl: https://github.com/login/oauth/access_token
          userVerificationUrl: https://github.com/login/device
```

**Example: Client credentials flow**

```yaml
hub:
  staticOauth:
    mapping:
      api.example.com: my-provider
    providers:
      my-provider:
        authMethod: client_credentials
        credentials:
          clientId: "..."
          clientSecret: "..."
        scopes:
          - scope1
          - scope2
        tokenAuthMethod: client_secret_basic
```

Supported `tokenAuthMethod` values: `client_secret_basic`, `client_secret_post`,
`client_secret_jwt`, `private_key_jwt`, `tls_client_auth`, `self_signed_tls_client_auth`.
