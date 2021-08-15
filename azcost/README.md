A Bash script that uses Azure CLI to obtain cost of resources across multiple Azure tenants and subscriptions

Requirement:
---
- Bash shell
- An Azure service principal with privileges associated with the "Billing Reader" role or higher, across all subscriptions within the given tenant.
- The jq JSON parser on the host where this script is executed.

Usage:
---
- Configure tenant and subscription details in `conf\tenant.cfg`
- Configure service principal credentials in `conf\<tenant_name>.creds`
**NOTE**: For multiple tenants, each tenant should have its own `<tenant_name>.creds` in the `conf` directory.
- Exceute the following command:

`bash scripts/azcost.sh`

**NOTE:** Do **not** store credentials in source code management.

Output:
---
Check output in `data\raw` and `data\processed` directories.
