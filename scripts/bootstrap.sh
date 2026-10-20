#!/usr/bin/env bash
set -euo pipefail
: "${SUBSCRIPTION_ID:?}"
: "${DEPLOY_ENV:?dev or prod}"
: "${STATE_ACCOUNT:?Globally unique storage name}"
: "${GITHUB_REPOSITORY:?owner/repository}"
[[ "$DEPLOY_ENV" == dev || "$DEPLOY_ENV" == prod ]]
LOCATION=${LOCATION:-eastus}
az account set --subscription "$SUBSCRIPTION_ID"
for provider in Microsoft.Network Microsoft.Compute Microsoft.ManagedIdentity Microsoft.KeyVault Microsoft.Storage Microsoft.OperationalInsights Microsoft.Insights; do
  az provider register --namespace "$provider" --wait
done
platform_rg="rg-hubspoke-$DEPLOY_ENV"
state_rg=rg-hubspoke-state
az group create -n "$platform_rg" -l "$LOCATION" -o none
az group create -n "$state_rg" -l "$LOCATION" -o none
az storage account create -g "$state_rg" -n "$STATE_ACCOUNT" -l "$LOCATION" --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false --allow-shared-key-access false -o none
state_id=$(az storage account show -g "$state_rg" -n "$STATE_ACCOUNT" --query id -o tsv)
operator_id=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$operator_id" --assignee-principal-type User --role 'Storage Blob Data Contributor' --scope "$state_id" -o none
az storage container create --account-name "$STATE_ACCOUNT" --name tfstate --auth-mode login -o none
az storage account blob-service-properties update --account-name "$STATE_ACCOUNT" -g "$state_rg" --enable-versioning true --enable-delete-retention true --delete-retention-days 7 -o none
identity="hubspoke-$DEPLOY_ENV-ci"
az identity create -g "$platform_rg" -n "$identity" -o none
principal_id=$(az identity show -g "$platform_rg" -n "$identity" --query principalId -o tsv)
client_id=$(az identity show -g "$platform_rg" -n "$identity" --query clientId -o tsv)
for role in Contributor 'User Access Administrator'; do
  az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal --role "$role" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$platform_rg" -o none
done
az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Contributor' --scope "$state_id" -o none
for environment in "$DEPLOY_ENV-plan" "$DEPLOY_ENV"; do
  az identity federated-credential create -g "$platform_rg" --identity-name "$identity" --name "github-$environment" --issuer https://token.actions.githubusercontent.com --subject "repo:$GITHUB_REPOSITORY:environment:$environment" --audiences api://AzureADTokenExchange -o none
done
printf 'CI client ID: %s\nCI principal ID: %s\nState account: %s\nPlatform RG: %s\n' "$client_id" "$principal_id" "$STATE_ACCOUNT" "$platform_rg"
