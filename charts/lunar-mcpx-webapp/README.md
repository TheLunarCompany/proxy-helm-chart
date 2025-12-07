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
| OIDC_POST_LOGOUT_REDIRECT_URI |       |
|       OIDC_ISSUER_URL         |       |

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
    kubectl create secret generic mcpx-webapp-oidc -n mcpx-webapp-staging \
        --from-literal=OIDC_CLIENT_ID="" \
        --from-literal=OIDC_CLIENT_SECRET="" \
        --from-literal=OIDC_ISSUER="" \
        --from-literal=OIDC_REDIRECT_URI="" \
        --from-literal=OIDC_JWKS_URI="" \
        --from-literal=OIDC_AUDIENCE="" \
        --from-literal=OIDC_POST_LOGOUT_REDIRECT_URI=""
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
    ```

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

#### GCP

- [Minimal non-production configuration with GCE ingress controller](examples/values-override/gcp-nonprod-demo.yaml)
- [Production-like configuration with external secrets and external databases](examples/values-override/gcp-prod.yaml)

### Installation

Minimal deployment with embedded Postgresql and Redis
```bash
helm install mcpx lunar/lunar-mcpx-webapp --version 0.7.9 --set postgres.enabled=true --set redis.enabled=true
```

Alternatively, you may work with a separate values file to handle values override just like any other Helm chart:

```bash
helm install mcpx lunar/lunar-mcpx-webapp --version 0.7.9  -f ./values-override.yaml
```
