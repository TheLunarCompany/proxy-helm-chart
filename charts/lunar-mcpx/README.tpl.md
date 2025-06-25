# Lunar MCPX Helm Chart

## Installation
This Helm chart will install Lunar MCPX on your Kubernetes cluster.

```bash
helm install my-mcpx lunar/lunar-mcpx --version $CHART_VERSION
```

## Versioning
This Helm chart follows [SemVer](https://semver.org/) principles. Its version correlates directly with MCPX's container image versions.

## Configuration & Working With Values
Lunar's MCPX Helm Chart accepts configuration input via Helm's values. Inspect `values.yaml` and `values.schema.json` for full description of what is available.

Supplying filesystem-driven configuration is done via the `config` value. it maps the nested `mcpJson` and `appYaml` keys into the respective configuration files, and the chart ensures that they will be available to MCPX on runtime. See more info about these files in the official docs ([1](https://docs.lunar.dev/mcpx/target_mcp_servers), [2](https://docs.lunar.dev/mcpx/access_control_list), [3](https://docs.lunar.dev/mcpx/api_key_auth)).

As with any other Helm chart, you may create a separate values file to easily override chart's defaults. Consider a file named `override-values.yaml` looking like this:
```yaml
config:
  appYaml: |
    auth:
      enabled: false
    permissions:
      base: "block"
```

We can then install the chart with
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
MCPX will inject these environment variables from the referenced secret automatically and they will be available in its runtime.

## Healthcheck
Lunar MCPX responds to `GET /healthcheck` endpoint. This chart configures a Kubernetes `livenessProbe` and `readinessProbe` to use this endpoint, ensuring that the MCPX pod is healthy and ready to serve requests. Note that the healthcheck endpoint is not protected by authentication, so it can be accessed without any credentials. Also, it is not logged as part of the MCPX access logs to avoid spamming the logs.

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
