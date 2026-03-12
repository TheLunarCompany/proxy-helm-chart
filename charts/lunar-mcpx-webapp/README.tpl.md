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

### Hibernation Cron Schedule

Use `hibernation.cronSchedule` to control when the `hibernate-instances` CronJob runs.

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

### Installation

Minimal deployment with embedded Postgresql and Redis
```bash
helm install mcpx lunar/lunar-mcpx-webapp --version $CHART_VERSION --set postgres.enabled=true --set redis.enabled=true
```

Alternatively, you may work with a separate values file to handle values override just like any other Helm chart:

```bash
helm install mcpx lunar/lunar-mcpx-webapp --version $CHART_VERSION  -f ./values-override.yaml
```
