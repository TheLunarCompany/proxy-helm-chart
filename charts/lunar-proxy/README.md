# Lunar Proxy Helm Chart

In order to use Lunar Flows, it is required to define configmaps for flows and quotas.
You may create them with any name you desire:

```bash
kubectl create configmap my-flows-config --from-file=./flows/
kubectl create configmap my-quotas-config --from-file=./quotas/
```
Note that the `--from-file` attribute points to a full directory, under which your flows/quota YAMLs are expected to be found.

Then, prepare a `values-override.yaml` (or similar) to allow installing/upgrading the chart properly:

```yaml
lunarStreamsEnabled: true
configMapNames:
  flows: flows-config-test
  quotas: quotas-config-test
```

And finally, install/upgrade the chart:
```bash
helm install my-proxy lunar/lunar-proxy -f ./override-values.yaml
```

You may also override values inline within the `helm install` command, if preferred.
