# Validation evidence

Created 20 October 2026 UTC.

| Check | Result |
| --- | --- |
| Recursive Terraform formatting | Passed locally |
| Workflow syntax | Passed locally with actionlint 1.7.7 |
| Address containment, overlap, explicit egress and environment tests | 6 passed locally |
| Shell parsing | Passed for all scripts |
| Full provider schema validation | Passed on GitHub Actions |

Terraform provider schema validation runs on a GitHub-hosted runner using the locked provider version. The topology tests evaluate the configured address spaces and traffic inputs. Refer to the Validate Network Platform workflow for its result.

Successful validation run: https://github.com/dotman01k/azure-hub-spoke-platform/actions/runs/39376127255
