# mcpx-hive

![Version: 0.1.10](https://img.shields.io/badge/Version-0.1.10-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A comprehensive Helm chart for the MCPx Hive system including hive-controller and ingress.

**Homepage:** <https://github.com/TheLunarCompany/hive-poc>

## Maintainers

| Name       | Email               | Url |
| ---------- | ------------------- | --- |
| Lunar Team | <support@lunar.dev> |     |

## Source Code

* <https://github.com/TheLunarCompany/hive-poc>

## Values

Operational defaults for the router, controller, Redis, and CRDs are kept in `internal-values.yaml` so that `values.yaml` stays focused on user-provided configuration. Ingress host mappings automatically reuse the top-level domain settings unless you override `ingress.domains`. Environment specific examples are available in `values-sandbox.gcp.yaml` and `values-stg.gcp.yaml`.

| Key                                       | Type   | Default                                | Description |
| ----------------------------------------- | ------ | -------------------------------------- | ----------- |
| `domain`                                  | string | `"TODO:1: add domain"`                 | Base domain for the deployment. |
| `controller_domain`                       | string | `"TODO:2: add controller domain"`      | Public domain for the hive controller. |
| `ui_domain`                               | string | `"TODO:3: add ui domain"`              | Public domain for the MCPx UI. |
| `router_domain`                           | string | `"TODO:4: add router domain"`          | Public domain for the router/gateway. |
| `global.hubUrl`                           | string | `"TODO:5: add hub url"`                | WebSocket URL for the hub service. |
| `global.controllerToken`                  | string | `"some_random_token"`                  | Shared secret used by the controller. |
| `global.logLevel`                         | string | `"info"`                               | Default log level applied to controller and router pods. |
| `global.imagePullSecrets`                 | list   | `[{"name": "TODO:6: add image pull secret"}]` | Image pull secrets for private registries. |
| `global.oidc.issuerUrl`                   | string | `"TODO:7: add oidc issuer url"`        | OIDC issuer URL. |
| `global.oidc.clientId`                    | string | `"TODO:8: add oidc client id"`         | OIDC client ID. |
| `global.oidc.clientSecret`                | string | `"TODO:9: add oidc client secret"`     | OIDC client secret. |
| `global.oidc.sessionSecret`               | string | `"TODO:10: add oidc session secret"`   | Secret used to sign OIDC sessions. |
| `global.redis.deploy`                     | bool   | `false`                                | Deploy the bundled Redis instance. |
| `global.redis.isCluster`                  | bool   | `true`                                 | Indicates whether the Redis target is a cluster. |
| `global.redis.prefix`                     | string | `"TODO:11: add redis prefix"`          | Prefix for keys created in Redis. |
| `global.redis.url`                        | string | `"TODO:12: add redis url"`             | External Redis URL when `deploy` is `false`. |
| `ingress.enabled`                         | bool   | `true`                                 | Enable ingress resources. |
| `ingress.annotations`                     | object | `{}`                                   | Extra annotations added to ingress resources. |
| `ingress.domains.controller[].host`       | string | `(derived from controller_domain)`     | Hostname routed to the controller service. |
| `ingress.domains.router[].host`           | string | `(derived from router_domain)`         | Hostname routed to the router service. |
| `ingress.domains.ui[].host`               | string | `(derived from ui_domain)`             | Hostname routed to the UI service. |
