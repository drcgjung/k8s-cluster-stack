# Cluster registration in central argocd

## On the destination cluster create:

  - serviceaccount: register/serviceaccount.yaml (creates a secret automatically)
  - clusterrole: register/clusterrole.yaml
  - clusterrolebinding: register/clusterrolebinding.yaml

## Secrets needed from destination cluster:

  - serviceaccount created in previous step
    (contains ca.crt and token)
  - tunnelfront-tls
    (contains client.key client.pem )

## Create a secret on the argo cluster

  - register/registration.temp (register/config.temp will be used in the registration.yaml config)