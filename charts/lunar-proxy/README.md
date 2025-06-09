# Lunar Gateway Helm Chart

## Installation
This Helm chart will install Lunar Gateway on your Kubernetes cluster.

In order to install it, only a minimal configuration is required:
```bash
helm install lunar-proxy lunar/lunar-proxy --version 1.2.0 --set tenantName=<organization-name> --set lunarAPIKey=<api-key>
```
The API key can be obtained by opening an account on [app.lunar.dev](app.lunar.dev).

Alternatively, you may work with a separate `values` file to handle values override just like any other Helm chart:
```bash
helm install lunar-proxy lunar/lunar-proxy --version 1.2.0 -f ./values-override.yaml
```

## Versioning
Like Lunar Gateway, this Helm chart follows [SemVer](https://semver.org/) principles.
Each chart version correspond directly to a Lunar Gateway version.
For example, chart version 0.10.19 will install Lunar Gateway version 0.10.19.
When there is a need to fix only the Helm chart, a postfix will be added.
For example, chart version 0.10.20-fix2 would still correspond to 0.10.20.

## Working With Values
This chart allows for plenty of customization options in order to cater for various needs. Please see the **Values Schema** in our [ArtifactHub](https://artifacthub.io/packages/helm/lunar/lunar-proxy) page to explore these options and learn about them. See also [Gateway Environment Variables](https://docs.lunar.dev/lunar-dev-in-production/core-settings/environment-variables/gateway-environment-variables) from our documentation in order to learn more about matching environment variables.

## Usage in ArgoCD
Consider the following example as a recipe for using this Helm chart via ArgoCD:
```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lunar-proxy
  namespace: cd
spec:
  destination:
    namespace: lunar-proxy
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: https://thelunarcompany.github.io/proxy-helm-chart/
    targetRevision: '1.2.0'
    chart: lunar-proxy
    helm:
      values: |
        logLevel: "INFO"

        lunarAPIKey: # fill this in
        tenantName: # fill this in
        lunarStreamsEnabled: true

        configMapNames:
          root: root-config
          flows: flows-config
          quotas: quotas-config

        resources:
          requests:
            cpu: 2
            memory: 2Gi
          limits:
            cpu: 2
            memory: 2Gi
  syncPolicy:
    automated: {}
    syncOptions:
    - CreateNamespace=true
```

Here, the `spec.source.helm.values` field effectively serves as a value overriding mechanism - similar to the ones we've used above.

## Supplying Gateway Configuration
In order to maximize your utilization of Lunar Gateway, you may want to pass configuration to it. The file structure described in the [docs](https://docs.lunar.dev/flows-configurations/#folder-structure) is supported via Kubernetes' ConfigMaps and Secrets.

In order to do so, we will:
1. Prepare the desired configuration on a matching local folder
2. Load the different ConfigMaps and Secret, naming them as we wish
3. Declare these names in the values passed to the chart

After you have completed step 1 and are satisfied with the content of your configuration, let's move on to load it to your Kubernetes cluster. In a terminal that is present at the root of the configuration filesystem mentioned in the docs, you may run:
```bash
kubectl create configmap my-root-config --from-file=./
kubectl create configmap my-flows-config --from-file=./flows/
kubectl create configmap my-quotas-config --from-file=./quotas/
kubectl create configmap my-path-params-config --from-file=./path_params/
```
Certs may be loaded as secrets:
```bash
 kubectl create secret generic my-tls-certs-config --from-file=./certs/tls
 kubectl create secret generic my-mtls-certs-config --from-file=./certs/mtls
```

Note that the `--from-file` attribute points to a full directory - each file under each said directory will be reflected in the ConfigMap/Secret as a key with its content as value.

Then, supply these names as values to the chart in order for mounting to take place so Lunar Gateway can make use of those configurations:

```yaml
lunarStreamsEnabled: true
configMapNames:
  root: my-root-config
  flows: my-flows-config
  quotas: my-quotas-config
  pathParams: my-path-params-config
secretNames:
  tlsCerts: my-tls-certs-config
  mtlsCerts: my-mtls-certs-config
```
