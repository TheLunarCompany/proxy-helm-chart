# mcpx-hive

Helm chart for deploying the MCPx Hive services (controller, UI, router) into a Kubernetes cluster.

- UI: The MCPx management interface
- Router: The MCPx agent access
- Controller: The MCPx-Hive management that allows to allocate MCPx deployments
  
## Prerequisites

- Helm 3 installed locally and available in your `PATH`.
- `kubectl` configured for the target provider/cluster (`kubectl config current-context` should point to the desired cluster).
- Permissions to create namespaces, secrets, ingresses, and any cloud-specific load balancer resources in the target cluster.
- Network access from the cluster to backing services such as Redis and the MCPx Hub.

## Preparation

All chart configuration lives in `values.yaml` (view the latest copy [in the repository](https://github.com/TheLunarCompany/proxy-helm-chart/blob/gh-pages/charts/lunar-hive/values.yaml)). Before installing:

1. Copy `charts/lunar-hive/values.yaml` to an environment-specific file (for example, `values-override.yaml`).
2. Populate all required settings (domains, hub URL, controller token, OIDC configuration, Redis connection, etc.) with environment-specific values.
3. Store any sensitive values (controller token, OIDC secrets, etc.) securely and reference Kubernetes secrets when appropriate.

### Required configuration fields

- **Domains**: `controller_domain`, `ui_domain`, and `router_domain` must be set to routable hostnames (for example, `mcpx-controller-<env>.<domain>`), aligning with the ingress entries you plan to expose.
- **Hub service**: `global.hubUrl` must point to the Hub WebSocket URL exposed by the MCPx Hub service installed via the [`lunar-mcpx-webapp` chart](https://artifacthub.io/packages/helm/lunar/lunar-mcpx-webapp). Use the service endpoint returned during that installation in the form `ws://<hubServiceEndpoint>`.
- **Controller shared secret**: `global.controllerToken` should be a long, random secret; it is required to authenticate to the controller admin portal (`https://mcpx-controller-<env>.<domain>/admin`) when allocating MCPx instances.
- **Image pull secrets**: Configure `global.imagePullSecrets` with Kubernetes secrets that hold Lunar's private registry credentials so the pods can pull their images.
- **OIDC**: Populate `global.oidc.*` fields with the issuer URL, client credentials, and session secret provided by your identity provider.
- **Redis**: If you are using an external Redis cluster set `global.redis.deploy: false`, `global.redis.isCluster: true`, and provide `global.redis.url` in the form `redis://<redisEndpoint>:<redisPort>`. Alternatively, enable the bundled Redis by setting `deploy: true` and adjust the other fields as needed.
- **Ingress**: Confirm `ingress.enabled` and update `ingress.annotations` and provider-specific settings (AWS/GCP/Azure blocks) so certificates, load balancers, and IP addresses are managed correctly.

## Installation

Run Helm:

```bash
helm upgrade --install mcpx-hive charts/lunar-hive \
  --namespace mcpx-hive \
  --create-namespace \
  -f values-override.yaml
```

## Configuration reference

| Key                                 | Type   | Default                                                                       | Description                                                                              |
| ----------------------------------- | ------ | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `domain`                            | string | `""`                                                                          | Optional base domain propagated to the router service.                                   |
| `controller_domain`                 | string | `(required)`                                                                  | Public domain for the hive controller.                                                   |
| `ui_domain`                         | string | `(required)`                                                                  | Public domain for the MCPx UI.                                                           |
| `router_domain`                     | string | `(required)`                                                                  | Public domain for the router/gateway.                                                    |
| `global.hubUrl`                     | string | `(required)`                                                                  | WebSocket URL for the hub service.                                                       |
| `global.controllerToken`            | string | `(required)`                                                                  | Shared secret required for controller admin portal access.                               |
| `global.logLevel`                   | string | `"warn"`                                                                      | Default log level applied to controller and router pods.                                 |
| `global.imagePullSecrets`           | list   | `[]`                                                                          | Image pull secrets that grant access to Lunar's private registries.                      |
| `global.oidc.issuerUrl`             | string | `(required)`                                                                  | OIDC issuer URL.                                                                         |
| `global.oidc.clientId`              | string | `(required)`                                                                  | OIDC client ID.                                                                          |
| `global.oidc.clientSecret`          | string | `(required)`                                                                  | OIDC client secret.                                                                      |
| `global.oidc.sessionSecret`         | string | `(required)`                                                                  | Secret used to sign OIDC sessions.                                                       |
| `global.redis.deploy`               | bool   | `false`                                                                       | Deploy the bundled Redis instance.                                                       |
| `global.redis.isCluster`            | bool   | `true`                                                                        | Indicates whether the Redis target is a cluster.                                         |
| `global.redis.prefix`               | string | `"mcpx-hive"`                                                                 | Prefix for keys created in Redis.                                                        |
| `global.redis.url`                  | string | `""`                                                                          | External Redis URL when `deploy` is `false` (e.g., `redis://redis-endpoint:redis-port`). |
| `ingress.enabled`                   | bool   | `true`                                                                        | Enable ingress resources.                                                                |
| `ingress.annotations`               | object | `{}`                                                                          | Extra annotations added to ingress resources.                                            |
| `ingress.domains.controller[].host` | string | `(derived from controller_domain)`                                            | Hostname routed to the controller service.                                               |
| `ingress.domains.router[].host`     | string | `(derived from router_domain)`                                                | Hostname routed to the router service.                                                   |
| `ingress.domains.ui[].host`         | string | `(derived from ui_domain)`                                                    | Hostname routed to the UI service.                                                       |
| `router.replicaCount`               | int    | `1`                                                                           | Number of router pods to run.                                                            |
| `router.image.repository`           | string | `us-central1-docker.pkg.dev/prj-common-442813/lunar-private/mcpx-hive-router` | Router image repository; override to test custom builds.                                 |
| `router.image.tag`                  | string | `"" (Chart AppVersion)`                                                       | Router image tag.                                                                        |
| `mcpxUi.replicaCount`               | int    | `1`                                                                           | Number of UI pods.                                                                       |
| `mcpxUi.image.repository`           | string | `REPLACE_ME/mcpx-ui`                                                          | UI image repository.                                                                     |
| `mcpxUi.image.tag`                  | string | `"" (Chart AppVersion)`                                                       | UI image tag.                                                                            |
| `mcpxUi.service.ports[].port`       | int    | `80`                                                                          | UI Service port (front-end).                                                             |
| `mcpxUi.service.ports[].targetPort` | int    | `5173`                                                                        | UI container port (back-end).                                                            |
| `mcpxUi.env.VITE_ENABLE_ENTERPRISE` | string | `"true"`                                                                      | Enables enterprise UI surfaces by default; override to disable.                          |
| `mcpxUi.env.VITE_MCPX_SERVER_URL`   | string | `(derived)`                                                                   | Defaults to `https://<router_domain>` when not explicitly provided.                      |
