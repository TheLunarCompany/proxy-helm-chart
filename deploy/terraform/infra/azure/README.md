### Disclaimer
Following terraform configuration is implemented for POC/Demo purposes only. It does not enforces multiple best 
practices in terms of security, reliability, and scalability. Sensitive data, like terraform state and kubernetes
config, will be created locally - make sure not to push them into git.


### Prerequisites
- Terraform >=1.3
- AZ Cli
  - Install: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
  - Configure: https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively?view=azure-cli-latest
- Set `ARM_SUBSCRIPTION_ID` environmental variable
    ```export ARM_SUBSCRIPTION_ID="azure-subscription-id"```

### Install

#### Kubernetes cluster
1. Change dir to [k8s](k8s)
2. Adjust variables: default values are sufficient for POC/Demo purposes. 
If needed, change variables in [variables.tf](k8s/variables.tf) or create your own 'terraform.tfvars' files.
3. Run Terraform
   ```
   terraform init
   terraform apply
   ```
4. Once AKS cluster is created, use IP `aks_agic_public_ip` from output to create DNS records.
Note: Please make sure to create DNS records before proceeding with installing helm chart

#### Kubernetes addons
1. Change dir to [addons](addons)
2. No adjustments needed
3. Run Terraform
   ```
   terraform init
   terraform apply
   ```

#### Kubernetes clusterissuer
1. Change dir to [clusterissuer](clusterissuer)
2. No adjustments needed
3. Run Terraform
   ```
   terraform init
   terraform apply
   ```

### Connecting to kubernetes
Configuration file to access kubernetes will be created in [terraform](../..) directory
1. Change dir to [terraform](../..)
2. Run following command to use the config:
    ```
    export KUBECONFIG=$(pwd)/kube_config
    ```
3. Verify connection to kubernetes:
    ```
    kubectl get deployments -A
    ```


