#!/usr/bin/env bash
# Read-only management-plane inspection after an authorized Azure deployment.
set -euo pipefail
: "${AZURE_RESOURCE_GROUP:?}"
: "${NETWORK_PREFIX:?Example dotunnet-dev}"
az network firewall show -g "$AZURE_RESOURCE_GROUP" -n "$NETWORK_PREFIX-firewall" --query '{state:provisioningState,privateIP:ipConfigurations[0].privateIPAddress,policy:firewallPolicy.id}' -o json
for network in hub app data; do
  az network vnet peering list -g "$AZURE_RESOURCE_GROUP" --vnet-name "$NETWORK_PREFIX-$network" --query '[].{name:name,state:peeringState,forwarded:allowForwardedTraffic}' -o table
done
for spoke in app data; do
  az network route-table route list -g "$AZURE_RESOURCE_GROUP" --route-table-name "$NETWORK_PREFIX-$spoke-routes" -o table
done
az network private-endpoint list -g "$AZURE_RESOURCE_GROUP" --query '[].{name:name,subnet:subnet.id,state:provisioningState}' -o table
