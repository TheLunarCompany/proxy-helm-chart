### Overview

This Terraform configuration installs and configures mcpx-webapp helm chart

### Prerequisites

- Kubernetes cluster up and running. One can be deployed using terraform in [infra](../../infra) folder
- DNS records configured. List of DNS records can be found in `.ingress.domains` section of
  [values-override](config-examples/values-override) examples:
```
  domains:
    webserver:
      - mcpx-app.example.com
    admin:
      - mcpx-admin.example.com
    auth:
      - mcpx-auth.example.com
    ui:
      - mcpx-ui.example.com
    router:
      - mcpx.example.com
```
- Configuration files:
    - `lunar-private-mcpx-registry.yaml` - provided by Lunar, grants access to container registry
    - `oidc_data.yaml` - file with OIDC related configuration. See example in [oidc_data.yaml](config-examples/oidc_data.yaml)
    - `values-override.yaml` - file containing values for configuring helm chart. See examples in terraform's
      [values-override](config-examples/values-override) or chart's
      [values-override](../../../../charts/lunar-mcpx-webapp/examples/values-override)

### Installation  
1. Create file `terraform.tfvars` with following content:
```
pull_secrets_path    = "< path to lunar-private-mcpx-registry.yaml >"
oidc_secrets_path    = "< path to config with OIDC creds >"
override_values_path = "< path to file with override values >"
```  
   
   Example: [terraform.tfvars.example](terraform.tfvars.example)

2. Run Terraform
```
terraform init
terraform apply
```

### Terraform

#### Providers

| Name | Version |
|------|---------|
| helm | 3.1.1 |
| kubernetes | 3.0.1 |
| random | 3.7.2 |

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| oidc_secrets_path | Path to file containing OIDC secrets. See example in config-examples/oidc_data.yaml | `string` | n/a | yes |
| override_values_path | Path to file containing override values for helm chart. See example for different platforms in config-examples/values-override | `string` | n/a | yes |
| pull_secrets_path | Path to lunar-private-mcpx-registry.yaml. File provided by Lunar | `string` | n/a | yes |
| kube_config_path | Path to Kube config file. Default value points to the file created by Terraform configuration in 'infra' directory | `string` | `"../../kube_config"` | no |
| name | Name that would be assigned for all resources and namespace | `string` | `"mcpx-webapp"` | no |

#### Outputs

No output.

