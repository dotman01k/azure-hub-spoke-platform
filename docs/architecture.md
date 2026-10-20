# Architecture decisions

## Hub and spoke transit

Each spoke has bidirectional peering with the hub and forwarded traffic enabled. There is no direct spoke-to-spoke peering. Workload routes send internet and the remote spoke address prefix to the Firewall private IP, giving a symmetric interspoke route configuration. The Firewall permits only the app workload subnet to initiate TCP 443 to the data workload subnet, with an additional matching destination NSG rule. Return packets for an established connection are statefully permitted.

The hub has no forced route through its own Firewall. Hub peering system routes can therefore carry spoke-to-hub traffic directly. Workload UDRs are not associated with private endpoint subnets. Private endpoint /32 routes and policy settings require a separate design if all private service traffic must be inspected. This repository does not claim that default routes capture every Azure traffic path.

## DNS

Spoke VNets use the Firewall private IP as DNS server. Firewall Policy enables DNS proxy and uses Azure DNS `168.63.129.16` upstream. The vault and blob private zones are linked to the hub because the proxy resolves from the hub context; links also exist for both spokes. Private endpoint zone groups manage service records.

The hub VNet retains Azure-provided DNS, avoiding a circular dependency on its own proxy. No on-premises forwarding or conditional resolver rules are configured. DNS Private Resolver would be a separate extension for hybrid DNS.

## Private services and identity

Vault uses Azure RBAC, public networking disabled, purge protection and a private endpoint in the hub. Blob storage has shared-key and anonymous public access disabled, public networking disabled and a private endpoint in the data spoke. No vault secrets, blob containers or data objects are created by Terraform.

Optional VM identities receive read access to vault secrets and Blob data. Network access and authorization remain independent. These role assignments deliberately scope to the relevant service resources; a production workload could narrow Blob access further to a specific container once it exists.

Terraform providers can compute sensitive storage attributes into state even with shared-key use disabled. State must remain protected. Infrastructure CI has RG-level role delegation rights to create the workload roles and configure vault permission mode.

## Security boundaries

Workload NSGs allow SSH only from the Bastion subnet and the data service exception only from the application workload subnet. A higher-priority explicit deny blocks other new inbound flows instead of relying on broad default VirtualNetwork access. NSGs retain Azure's standard outbound defaults; workload egress restriction is enforced by UDR and Firewall policy.

Firewall Standard supplies application FQDN rules, network rules and DNS proxy. HTTP is allowed only for named package repositories because some package sources use HTTP; HTTPS is also allowed. No wildcard destination allow rule, public application DNAT or unrestricted internet rule is provided. Threat intelligence is in Alert mode, not Deny, and TLS inspection/IDPS is outside Standard's configured scope.

## Availability and monitoring

The prod example uses zones for Firewall and its public IP and ZRS for storage. It does not make Basic Bastion, test VMs or the entire application zone redundant. There is one logical Firewall resource. Log Analytics receives Firewall diagnostic categories and metrics; a health alert sends email below 100 percent average health over 15 minutes.

Log ingestion caps are controls, not spending guarantees. No automatic remediation, backup or disaster recovery failover is configured. Review Azure Firewall scale, logging cost, DNS dependencies and operational procedures before production adoption.
