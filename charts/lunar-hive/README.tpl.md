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

| Key                                                      | Type   | Default                                                                             | Description |
| -------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------- | ----------- |
| controller_domain                                        | string | `""`                                                                                |             |
| crds.enabled                                             | bool   | `true`                                                                              |             |
| domain                                                   | string | `""`                                                                                |             |
| global.cloudProvider                                     | string | `"generic"`                                                                         |             |
| global.clusterDomain                                     | string | `"cluster.local"`                                                                   |             |
| global.frontendConfigName                                | string | `""`                                                                                |             |
| global.managedCertificateName                            | string | `""`                                                                                |             |
| global.staticIPName                                      | string | `""`                                                                                |             |
| hiveController.affinity                                  | object | `{}`                                                                                |             |
| hiveController.autoscaling.enabled                       | bool   | `false`                                                                             |             |
| hiveController.controllerTokenSecret.key                 | string | `"token"`                                                                           |             |
| hiveController.controllerTokenSecret.name                | string | `""`                                                                                |             |
| hiveController.env.LOG_LEVEL                             | string | `"info"`                                                                            |             |
| hiveController.env.MCPX_API_VERSION                      | string | `"hive.lunar.dev/v1alpha1"`                                                         |             |
| hiveController.env.MCPX_KIND                             | string | `"MCPx"`                                                                            |             |
| hiveController.env.PORT                                  | int    | `8080`                                                                              |             |
| hiveController.env.ROUTER_DOMAIN                         | string | `""`                                                                                |             |
| hiveController.image.pullPolicy                          | string | `"Always"`                                                                          |             |
| hiveController.image.repository                          | string | `"us-central1-docker.pkg.dev/prj-common-442813/lunar-private/mcpx-hive-controller"` |             |
| hiveController.image.tag                                 | string | `"v0.0.25"`                                                                         |             |
| hiveController.imagePullSecrets                          | list   | `[]`                                                                                |             |
| hiveController.nodeSelector                              | object | `{}`                                                                                |             |
| hiveController.podSecurityContext.fsGroup                | int    | `2000`                                                                              |             |
| hiveController.podSecurityContext.runAsNonRoot           | bool   | `true`                                                                              |             |
| hiveController.podSecurityContext.runAsUser              | int    | `1000`                                                                              |             |
| hiveController.probes.livenessProbe.httpGet.path         | string | `"/health/live"`                                                                    |             |
| hiveController.probes.livenessProbe.httpGet.port         | int    | `8080`                                                                              |             |
| hiveController.probes.livenessProbe.initialDelaySeconds  | int    | `30`                                                                                |             |
| hiveController.probes.livenessProbe.periodSeconds        | int    | `10`                                                                                |             |
| hiveController.probes.readinessProbe.httpGet.path        | string | `"/health/ready"`                                                                   |             |
| hiveController.probes.readinessProbe.httpGet.port        | int    | `8080`                                                                              |             |
| hiveController.probes.readinessProbe.initialDelaySeconds | int    | `5`                                                                                 |             |
| hiveController.probes.readinessProbe.periodSeconds       | int    | `5`                                                                                 |             |
| hiveController.rbac.create                               | bool   | `true`                                                                              |             |
| hiveController.replicaCount                              | int    | `1`                                                                                 |             |
| hiveController.resources.limits.cpu                      | string | `"500m"`                                                                            |             |
| hiveController.resources.limits.memory                   | string | `"512Mi"`                                                                           |             |
| hiveController.resources.requests.cpu                    | string | `"100m"`                                                                            |             |
| hiveController.resources.requests.memory                 | string | `"128Mi"`                                                                           |             |
| hiveController.securityContext.fsGroup                   | int    | `2000`                                                                              |             |
| hiveController.securityContext.runAsNonRoot              | bool   | `true`                                                                              |             |
| hiveController.securityContext.runAsUser                 | int    | `1000`                                                                              |             |
| hiveController.service.port                              | int    | `80`                                                                                |             |
| hiveController.service.targetPort                        | int    | `8080`                                                                              |             |
| hiveController.service.type                              | string | `"ClusterIP"`                                                                       |             |
| hiveController.serviceAccount.annotations                | object | `{}`                                                                                |             |
| hiveController.serviceAccount.create                     | bool   | `true`                                                                              |             |
| hiveController.serviceAccount.name                       | string | `""`                                                                                |             |
| hiveController.tolerations                               | list   | `[]`                                                                                |             |
| ingresses.controller.annotations                         | object | `{}`                                                                                |             |
| ingresses.controller.backend.serviceName                 | string | `"mcpx-hive-hive-controller"`                                                       |             |
| ingresses.controller.backend.servicePort                 | int    | `80`                                                                                |             |
| ingresses.controller.className                           | string | `"nginx"`                                                                           |             |
| ingresses.controller.enabled                             | bool   | `true`                                                                              |             |
| ingresses.controller.hosts[0].host                       | string | `"hive-controller.local"`                                                           |             |
| ingresses.controller.hosts[0].paths[0].path              | string | `"/"`                                                                               |             |
| ingresses.controller.hosts[0].paths[0].pathType          | string | `"Prefix"`                                                                          |             |
| ingresses.controller.tls                                 | list   | `[]`                                                                                |             |
| ingresses.server.annotations                             | object | `{}`                                                                                |             |
| ingresses.server.backend.serviceName                     | string | `"mcpx-hive-ingress-router"`                                                        |             |
| ingresses.server.backend.servicePort                     | int    | `9000`                                                                              |             |
| ingresses.server.className                               | string | `"nginx"`                                                                           |             |
| ingresses.server.enabled                                 | bool   | `true`                                                                              |             |
| ingresses.server.hosts[0].host                           | string | `"mcpx-server.local"`                                                               |             |
| ingresses.server.hosts[0].paths[0].path                  | string | `"/"`                                                                               |             |
| ingresses.server.hosts[0].paths[0].pathType              | string | `"Prefix"`                                                                          |             |
| ingresses.server.tls                                     | list   | `[]`                                                                                |             |
| ingresses.ui.annotations                                 | object | `{}`                                                                                |             |
| ingresses.ui.backend.serviceName                         | string | `"mcpx-hive-ingress-router"`                                                        |             |
| ingresses.ui.backend.servicePort                         | int    | `5173`                                                                              |             |
| ingresses.ui.className                                   | string | `"nginx"`                                                                           |             |
| ingresses.ui.enabled                                     | bool   | `true`                                                                              |             |
| ingresses.ui.hosts[0].host                               | string | `"mcpx-ui.local"`                                                                   |             |
| ingresses.ui.hosts[0].paths[0].path                      | string | `"/"`                                                                               |             |
| ingresses.ui.hosts[0].paths[0].pathType                  | string | `"Prefix"`                                                                          |             |
| ingresses.ui.tls                                         | list   | `[]`                                                                                |             |
| ingressesCombined.className                              | string | `""`                                                                                |             |
| ingressesCombined.enabled                                | bool   | `false`                                                                             |             |
| router.enabled                                           | bool   | `true`                                                                              |             |
| router.image.pullPolicy                                  | string | `"IfNotPresent"`                                                                    |             |
| router.image.repository                                  | string | `"openresty/openresty"`                                                             |             |
| router.image.tag                                         | string | `"1.27.1.2-4-alpine-fat"`                                                           |             |
| router.oidc.clientId                                     | string | `""`                                                                                |             |
| router.oidc.clientSecret                                 | string | `""`                                                                                |             |
| router.oidc.issuerUrl                                    | string | `""`                                                                                |             |
| router.oidc.sessionSecret                                | string | `""`                                                                                |             |
| router.replicaCount                                      | int    | `1`                                                                                 |             |
| router.resources.limits.cpu                              | string | `"200m"`                                                                            |             |
| router.resources.limits.memory                           | string | `"256Mi"`                                                                           |             |
| router.resources.requests.cpu                            | string | `"100m"`                                                                            |             |
| router.resources.requests.memory                         | string | `"128Mi"`                                                                           |             |
| router.service.name                                      | string | `"mcpx-hive-ingress-router"`                                                        |             |
| router.service.ports[0].name                             | string | `"ui"`                                                                              |             |
| router.service.ports[0].port                             | int    | `5173`                                                                              |             |
| router.service.ports[0].targetPort                       | int    | `5173`                                                                              |             |
| router.service.ports[1].name                             | string | `"mcpx-server"`                                                                     |             |
| router.service.ports[1].port                             | int    | `9000`                                                                              |             |
| router.service.ports[1].targetPort                       | int    | `9000`                                                                              |             |
| router.service.ports[2].name                             | string | `"metrics"`                                                                         |             |
| router.service.ports[2].port                             | int    | `3000`                                                                              |             |
| router.service.ports[2].targetPort                       | int    | `3000`                                                                              |             |
| router.service.type                                      | string | `"ClusterIP"`                                                                       |             |
| router_domain                                            | string | `""`                                                                                |             |
| ui_domain                                                | string | `""`                                                                                |             |

