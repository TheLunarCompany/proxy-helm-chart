# mcpx-hive

![Version: 0.1.10](https://img.shields.io/badge/Version-0.1.10-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A comprehensive Helm chart for the MCPx Hive system including hive-controller and ingress

**Homepage:** <https://github.com/TheLunarCompany/hive-poc>

## Maintainers

| Name       | Email               | Url |
| ---------- | ------------------- | --- |
| Lunar Team | <support@lunar.dev> |     |

## Source Code

* <https://github.com/TheLunarCompany/hive-poc>

## Values

| Key                                                      | Type   | Default                                                                             | Description                                             |
| -------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------- | ------------------------------------------------------- |
| controller_domain                                        | string | `""`                                                                                | The domain for the hive controller.                     |
| ui_domain                                                | string | `""`                                                                                | The domain for the MCPx UI.                             |
| router_domain                                            | string | `""`                                                                                | The domain for the MCPx router/gateway.                 |
| ingress_class                                            | string | `"gce"`                                                                             | The ingress class to use.                               |
| crds.enabled                                             | bool   | `true`                                                                              | Whether to install the MCPx CRD.                        |
| domain                                                   | string | `""`                                                                                | The base domain for the deployment.                     |
| global.cloudProvider                                     | string | `"gcp"`                                                                             | The cloud provider (gcp, aws, azure).                   |
| global.clusterDomain                                     | string | `"cluster.local"`                                                                   | The cluster's internal domain.                          |
| global.staticIPName                                      | string | `""`                                                                                | The name of the static IP to use for the ingress.       |
| ingress.enabled                                          | bool   | `true`                                                                              | Whether to create ingress resources.                    |
| ingress.type                                             | string | `"gce"`                                                                             | The type of ingress controller.                         |
| ingress.className                                        | string | `"gce"`                                                                             | The class name for the ingress.                         |
| ingress.domains.controller.host                          | string | `""`                                                                                | Hostname for the controller ingress.                    |
| ingress.domains.router.host                              | string | `""`                                                                                | Hostname for the router ingress.                        |
| ingress.domains.ui.host                                  | string | `""`                                                                                | Hostname for the UI ingress.                            |
| hiveController.affinity                                  | object | `{}`                                                                                | Affinity settings for the controller.                   |
| hiveController.autoscaling.enabled                       | bool   | `false`                                                                             | Whether to enable horizontal pod autoscaling.           |
| hiveController.controllerTokenSecret.key                 | string | `"token"`                                                                           | The key within the secret for the controller token.     |
| hiveController.controllerTokenSecret.name                | string | `""`                                                                                | The name of the secret containing the controller token. |
| hiveController.env.LOG_LEVEL                             | string | `"info"`                                                                            | Log level for the controller.                           |
| hiveController.env.MCPX_API_VERSION                      | string | `"hive.lunar.dev/v1alpha1"`                                                         | The API version of the MCPx resource.                   |
| hiveController.env.MCPX_KIND                             | string | `"MCPx"`                                                                            | The kind of the MCPx resource.                          |
| hiveController.env.PORT                                  | int    | `8080`                                                                              | The port for the controller to listen on.               |
| hiveController.env.ROUTER_DOMAIN                         | string | `""`                                                                                | The domain of the router.                               |
| hiveController.image.pullPolicy                          | string | `"IfNotPresent"`                                                                    | Image pull policy.                                      |
| hiveController.image.repository                          | string | `"us-central1-docker.pkg.dev/prj-common-442813/lunar-private/mcpx-hive-controller"` | Image repository for the controller.                    |
| hiveController.image.tag                                 | string | `"b223d43"`                                                                         | Image tag for the controller.                           |
| hiveController.imagePullSecrets                          | list   | `[]`                                                                                | Secrets for pulling private images.                     |
| hiveController.nodeSelector                              | object | `{}`                                                                                | Node selector for the controller.                       |
| hiveController.podSecurityContext.fsGroup                | int    | `2000`                                                                              | The GID for the pod's filesystem.                       |
| hiveController.podSecurityContext.runAsNonRoot           | bool   | `true`                                                                              | Whether to run as a non-root user.                      |
| hiveController.podSecurityContext.runAsUser              | int    | `1000`                                                                              | The UID to run the container as.                        |
| hiveController.probes.livenessProbe.httpGet.path         | string | `"/health/live"`                                                                    | Path for the liveness probe.                            |
| hiveController.probes.livenessProbe.httpGet.port         | int    | `8080`                                                                              | Port for the liveness probe.                            |
| hiveController.probes.livenessProbe.initialDelaySeconds  | int    | `30`                                                                                | Initial delay for the liveness probe.                   |
| hiveController.probes.livenessProbe.periodSeconds        | int    | `10`                                                                                | Period for the liveness probe.                          |
| hiveController.probes.readinessProbe.httpGet.path        | string | `"/health/ready"`                                                                   | Path for the readiness probe.                           |
| hiveController.probes.readinessProbe.httpGet.port        | int    | `8080`                                                                              | Port for the readiness probe.                           |
| hiveController.probes.readinessProbe.initialDelaySeconds | int    | `5`                                                                                 | Initial delay for the readiness probe.                  |
| hiveController.probes.readinessProbe.periodSeconds       | int    | `5`                                                                                 | Period for the readiness probe.                         |
| hiveController.rbac.create                               | bool   | `true`                                                                              | Whether to create RBAC resources.                       |
| hiveController.replicaCount                              | int    | `1`                                                                                 | Number of replicas for the controller.                  |
| hiveController.resources.limits.cpu                      | string | `"500m"`                                                                            | CPU limit for the controller.                           |
| hiveController.resources.limits.memory                   | string | `"512Mi"`                                                                           | Memory limit for the controller.                        |
| hiveController.resources.requests.cpu                    | string | `"100m"`                                                                            | CPU request for the controller.                         |
| hiveController.resources.requests.memory                 | string | `"128Mi"`                                                                           | Memory request for the controller.                      |
| hiveController.securityContext.runAsNonRoot              | bool   | `true`                                                                              | Whether the container runs as non-root.                 |
| hiveController.securityContext.runAsUser                 | int    | `1000`                                                                              | The user ID for the container.                          |
| hiveController.service.port                              | int    | `80`                                                                                | The service port for the controller.                    |
| hiveController.service.targetPort                        | int    | `8080`                                                                              | The target port for the controller.                     |
| hiveController.service.type                              | string | `"ClusterIP"`                                                                       | The service type for the controller.                    |
| hiveController.serviceAccount.annotations                | object | `{}`                                                                                | Annotations for the service account.                    |
| hiveController.serviceAccount.create                     | bool   | `true`                                                                              | Whether to create a service account.                    |
| hiveController.serviceAccount.name                       | string | `""`                                                                                | The name of the service account.                        |
| hiveController.tolerations                               | list   | `[]`                                                                                | Tolerations for the controller.                         |
| router.enabled                                           | bool   | `true`                                                                              | Whether to enable the router.                           |
| router.image.pullPolicy                                  | string | `"IfNotPresent"`                                                                    | Image pull policy for the router.                       |
| router.image.repository                                  | string | `"openresty/openresty"`                                                             | Image repository for the router.                        |
| router.image.tag                                         | string | `"1.27.1.2-4-alpine-fat"`                                                           | Image tag for the router.                               |
| router.oidc.clientId                                     | string | `""`                                                                                | OIDC client ID.                                         |
| router.oidc.clientSecret                                 | string | `""`                                                                                | OIDC client secret.                                     |
| router.oidc.issuerUrl                                    | string | `""`                                                                                | OIDC issuer URL.                                        |
| router.oidc.sessionSecret                                | string | `""`                                                                                | OIDC session secret.                                    |
| router.replicaCount                                      | int    | `1`                                                                                 | Number of replicas for the router.                      |
| router.resources.limits.cpu                              | string | `"200m"`                                                                            | CPU limit for the router.                               |
| router.resources.limits.memory                           | string | `"256Mi"`                                                                           | Memory limit for the router.                            |
| router.resources.requests.cpu                            | string | `"100m"`                                                                            | CPU request for the router.                             |
| router.resources.requests.memory                         | string | `"128Mi"`                                                                           | Memory request for the router.                          |
| router.service.name                                      | string | `"mcpx-hive-router"`                                                                | The name of the router service.                         |
| router.service.ports[0].name                             | string | `"ui"`                                                                              | The name of the UI port.                                |
| router.service.ports[0].port                             | int    | `5173`                                                                              | The port for the UI.                                    |
| router.service.ports[0].targetPort                       | int    | `5173`                                                                              | The target port for the UI.                             |
| router.service.ports[1].name                             | string | `"mcpx-server"`                                                                     | The name of the MCPx server port.                       |
| router.service.ports[1].port                             | int    | `9000`                                                                              | The port for the MCPx server.                           |
| router.service.ports[1].targetPort                       | int    | `9000`                                                                              | The target port for the MCPx server.                    |
| router.service.ports[2].name                             | string | `"metrics"`                                                                         | The name of the metrics port.                           |
| router.service.ports[2].port                             | int    | `3000`                                                                              | The port for metrics.                                   |
| router.service.ports[2].targetPort                       | int    | `3000`                                                                              | The target port for metrics.                            |
| router.service.type                                      | string | `"ClusterIP"`                                                                       | The service type for the router.                        |

