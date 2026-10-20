# Validation evidence

Created 20 October 2026 UTC.

| Check | Result |
| --- | --- |
| Recursive Terraform formatting | Passed locally |
| Workflow syntax | Passed locally with actionlint 1.7.7 |
| Address containment, overlap, explicit egress and environment tests | 6 passed locally |
| Shell parsing | Passed for all scripts |
| Full provider schema validation | Enforced by the GitHub Actions validation workflow; check its result |
| Azure apply and live DNS/routing tests | Not performed; require Azure configuration and authorized execution |

Local provider IPC sockets are restricted in the authoring environment, so full provider validation runs on a GitHub-hosted runner. No claim of live Azure connectivity or application deployment is made. Refer to the repository's Validate Network Platform workflow for its authoritative result.
