# Lunar MCPX Webapps Helm Chart

## Installation
This Helm chart will install Lunar MCPX Webapps on your Kubernetes cluster.

### Prerequisites
#### Image pull secrets
To be able to pull images from Lunar Private Registry please make sure that pull secrets has been configured.
Contact Lunar sales representative in order to receive credentials. Credentials can be installed with following command:
```
kubectl create ns {{ mcpx_namespace }}
kubectl apply -f lunar-private-mcpx-registry.yaml -n {{ mcpx_namespace }}
```

#### Required services
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



#### Required environment variables

|     Variable      |                                           Value                                           |
|:-----------------:|:-----------------------------------------------------------------------------------------:|
|   DATABASE_URL    | postgres://{{ USER }}:{{ PASS }}@{{ HOST }}:{{ PORT }}/{{ DATABASE }}?schema={{ SCHEMA }} |
|     REDIS_URL     |                               redis://{{ HOST }}:{{ PORT }}                               |
| REDIS_USE_CLUSTER |                                   boolean (true\|false)                                   |



It is possible to supply this variables using several different techniques:
- Using values-override.yaml file with plain-text value:
```yaml
---
global:
  extraEnvVars:
    - name: DATABASE_URL
      value: "postgres://{{ USER }}:{{ PASS }}@{{ HOST }}:{{ PORT }}/{{ DATABASE }}?schema={{ SCHEMA }}"
    - name: REDIS_URL
      value: "redis://{{ HOST }}:{{ PORT }}"
    - name: REDIS_USE_CLUSTER
      value: "true|false"
```

- Using values-override.yaml file with plain-text value:
```yaml
---
global:
  extraEnvVars:
    - name: DATABASE_URL
      valueFrom:
      secretKeyRef:
        name: SECRET_NAME
        key: KEY1
    - name: REDIS_URL
      valueFrom:
      secretKeyRef:
        name: SECRET_NAME
        key: KEY2
    - name: REDIS_USE_CLUSTER
      valueFrom:
      secretKeyRef:
        name: SECRET_NAME
        key: KEY3
```


#### Installation

Minimal deployment with embedded Postgresql and Redis
```bash
helm install mcpx lunar/lunar-mcpx-webapp --version $CHART_VERSION --set postgres.enabled=true --set redis.enabled=true
```

Alternatively, you may work with a separate values file to handle values override just like any other Helm chart:

```bash
helm install mcpx lunar/lunar-mcpx-webapp --version $CHART_VERSION  -f ./values-override.yaml
```
