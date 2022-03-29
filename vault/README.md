# vault
Hashicorp Vault for secret management

Before running this workflow, you need to have deployed a three-node AKS cluster an Azure keyvault and a sevice principal

Secrets needed are:

  - AZURE_CREDENTIALS
  - TENANTID
  - CLIENTID
  - CLIENTSECRET
  - SUBSCRIPTIONID
  - AZUREVAULTNAME
  - AZUREVAULTKEYNAME

First job creates the following kubernetes resources on the vault cluster:

  - Clusterissuer letsencrypt-prod
  - Ingress definition for vault

Second job will create the following argocd applications in the central argocd for the remote vault cluster:

  - Cert-manager
  - Ingress-nginx
  - Sealed-secrets
  - Vault