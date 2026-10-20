# Operations and live validation

## Read-only control-plane inspection

Authenticate to the intended subscription and run:

```bash
export AZURE_RESOURCE_GROUP=rg-hubspoke-dev
export NETWORK_PREFIX=dotunnet-dev
bash scripts/inspect-network.sh
```

Confirm Firewall provisioning succeeded, all four hub/spoke peerings are Connected, forwarded traffic is enabled, workload route tables point to the Firewall private IP, and private endpoints are approved and provisioned. This inspection does not by itself prove packet delivery.

## Private DNS

With optional VMs enabled, connect through Bastion or run an approved VM command. From a spoke VM:

```bash
getent hosts <vault-name>.vault.azure.net
getent hosts <storage-name>.blob.core.windows.net
```

Both should resolve to the private endpoint addresses. Check the VM DNS server points to the Firewall IP, DNS proxy is enabled, and the private zones have links to the hub. New DHCP/DNS settings on existing clients may require a lease refresh; this project creates new VNets and does not perform fleet changes.

A public DNS result usually indicates a zone/link/proxy issue. A private IP with HTTP 403 usually indicates missing data authorization or the wrong identity rather than a DNS failure. Validate both independently.

## Routes and packet tests

Use Azure's NIC effective route table and NSG effective security rules after the optional VMs exist. Check source and destination direction, not only the route table object. App and data workload subnets need a route to the remote spoke through Firewall for symmetric response routing.

For a positive app-to-data TCP 443 test, a listener must be running on the data endpoint. Neither Terraform nor the optional VM image starts a listener. Test other ports to confirm expected denial; a timeout alone does not prove Firewall denied the packet, so correlate the test timestamp with Firewall logs and destination state.

A private endpoint can follow a more specific route than 0.0.0.0/0. Do not use this platform to claim full Private Link inspection without implementing and validating the required routing/network-policy changes.

## Firewall queries

When the dedicated tables are available after ingestion:

```kusto
AZFWNetworkRule
| where TimeGenerated > ago(1h)
| project TimeGenerated, SourceIp, DestinationIp, DestinationPort, Action
| order by TimeGenerated desc
```

```kusto
AZFWApplicationRule
| where TimeGenerated > ago(1h)
| summarize Requests=count() by Fqdn, Action
| order by Requests desc
```

```kusto
AZFWDnsQuery
| where TimeGenerated > ago(1h)
| take 50
```

Confirm actual table availability and columns in your workspace. Diagnostics delivery is asynchronous, and the app/domain allowlist affects what clients can reach. Firewall logs do not cover every path that bypasses the Firewall.

## Change control and recovery

Review any topology, route, NSG or Firewall-policy change through Terraform plan. A route change can disconnect workloads even if Terraform marks it in place. Keep a working administration path and validate expected traffic after every networking change.

To recover a bad configuration, restore the last known-good source version and review a fresh Terraform plan against the same backend before applying. State versioning can help recover damaged state, but it does not automatically roll back actual Azure resources. Never restore state blindly to hide an infrastructure change.

## Cost and cleanup

Firewall Standard and optional Bastion have standing charges. VM stopping/deallocation does not remove Firewall, Bastion, storage, public IP or log costs. Use a current pricing estimate and resource inventory before leaving a lab running.

Destroy is manual and excluded from CI. Confirm the subscription, RG, backend key and dependencies; inspect `terraform plan -destroy` before explicitly removing a disposable lab. Bootstrap identities, RGs and state account remain. Key Vault purge protection enforces retention and can block immediate reuse of the same vault name.
