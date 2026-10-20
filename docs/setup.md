# Setup

## Azure prerequisites

Use an Azure commercial subscription and an interactive operator for the one-time bootstrap. The operator needs provider registration, RG/storage/identity creation and role-assignment rights. Terraform itself receives RG-level permissions plus state data access, not subscription-wide Contributor.

Confirm eastus supports the selected zones, Firewall Standard, optional Bastion and optional B2s VMs. Keep this project RG and state key distinct from other infrastructure. Default addresses must not overlap connected networks.

Required provider registrations are handled by `scripts/bootstrap.sh`. The AzureRM provider has automatic registration disabled because an RG-scoped CI identity should not be registering providers at subscription scope.

## State bootstrap

Run the README bootstrap commands from the repository root after inspecting the script. Use `DEPLOY_ENV=dev` first. The state account must have a globally unique lowercase name. Repeat for prod with a separate platform RG and identity; the same state account can be reused with a different key.

The script uses `az ad signed-in-user show` and assumes an interactive user, not an application login. RBAC propagation can delay container creation. Retry only after confirming the intended identity and role scope. State account blob versioning and seven-day soft delete are enabled. Shared keys and anonymous blob access are disabled.

## GitHub configuration

Create environment pairs `dev-plan`/`dev` and `prod-plan`/`prod`. In each pair configure:

| Variable | Example |
| --- | --- |
| `AZURE_SUBSCRIPTION_ID` | Your subscription GUID |
| `AZURE_TENANT_ID` | Your tenant GUID |
| `INFRA_CLIENT_ID` | Bootstrap CI identity client GUID |
| `STATE_RESOURCE_GROUP` | `rg-hubspoke-state` |
| `STATE_STORAGE_ACCOUNT` | Globally unique bootstrap account name |
| `TFVARS_JSON` | Entire JSON object from the matching example file with real values |

Copy `infra/environments/dev.tfvars.json.example` to a local ignored file if testing locally. Keep it JSON, replace subscription and email placeholders, and ensure `environment` matches the selected workflow environment. `resource_group_name` must match the RG created by bootstrap. Public SSH keys are allowed in configuration; private keys are not.

The scripts validate the workflow environment and subscription against `TFVARS_JSON`. There are no application passwords to add. The pipeline trusts the exact repository/environment subject. Moving the repository requires new federated identity subjects.

## Workflow behavior

Validation runs without Azure credentials. Infrastructure deployment is manual and permitted only from `main`. The plan job runs in the `*-plan` environment; the apply job runs in the matching apply environment and downloads that run's saved plan.

Configure required reviewers on apply environments before relying on an approval pause. GitHub plan/visibility determines whether required-reviewer protection is available. The code does not create environment protection policies for you. Protect `main` and review third-party action versions according to your own process.

Plan artifacts are kept for one day and outputs for seven days. Plan and state files may contain sensitive provider data. Do not publish them. Backend networking is public with Entra authentication; restricting it requires privately connected runners and workflow changes.

## Optional VMs and access

`test_vms_enabled=true` creates one private Linux VM in each spoke. Set `ssh_public_key` to your OpenSSH public key. `bastion_enabled=true` creates Basic Bastion and its public endpoint for authenticated administration; this does not expose SSH on VM NIC public IPs.

No application listener is installed on test VMs. An app-to-data TCP 443 allowance is a network contract, not a complete web service. Provision a temporary listener only during a controlled validation drill and remove it afterward. The VM image version is `latest` within the configured Ubuntu 22.04 generation; image updates can change a future VM creation result. Pin an image version before requiring reproducible rebuilds.

## Current deployment status

No Azure apply was performed during project creation. Complete a dev deployment and the runbook's live checks before using the design for a production environment.
