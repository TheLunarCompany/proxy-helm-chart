# Lunar MCPX Helm Chart

## Installation
This Helm chart will install Lunar MCPX on your Kubernetes cluster.

```bash
helm install my-mcpx lunar/lunar-mcpx --version $CHART_VERSION
```

## Versioning
This Helm chart follows [SemVer](https://semver.org/) principles. It's version correlates directly with MCPX's container image versions.

## Working With Values
Lunar's MCPX accepts configuration input via environment variables and configuration files. See [here](https://github.com/TheLunarCompany/lunar/tree/main/mcpx#configuration) for further information.
As with any other Helm chart, you may create a separate values file to override chart's defaults. Consider a file named `override-values.yaml` looking like this:
```yaml
config:
  appYaml: |
    auth:
      enabled: false
    permissions:
      base: "block"
```

We can install the chart with
```bash
helm install my-mcpx lunar/lunar-mcpx --version $CHART_VERSION -f ./charts/lunar-mcpx/override-values.yaml
```

## Supplying Secrets
You may pass the optional value `secretRef` in order to refer to an existing K8s secret:
```yaml
secretRef:
  name: my-mcpx-secret
  keys:
    - API_KEY                 # Used when `auth.enabled` is set to true
    - SOME_3RD_PARTY_API_KEY  # Any secret required by a target MCP server as env var
```
MCPX will inject this environment variables from the referenced secret automatically.


## Usage in ArgoCD
Consider the following example as a recipe for using this Helm chart via ArgoCD:
```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lunar-mcpx
  namespace: cd
spec:
  destination:
    namespace: lunar-mcpx
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://thelunarcompany.github.io/proxy-helm-chart/
    targetRevision: '$CHART_VERSION'
    chart: lunar-mcpx
    helm:
      values: |
        config:
          appYaml: |
            auth:
              enabled: false
            permissions:
              base: "block"
  syncPolicy:
    automated: {}
    syncOptions:
    - CreateNamespace=true
```

Here, the `spec.source.helm.values` field effectively serves as a value overriding mechanism - similar to the ones we've used above.
