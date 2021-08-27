# Infrastructure as Code with Bicep

This repository is built for the purpose of understanding how to deploy a private kubernetes cluster and communicate to private PaaS Services using Bicep.

__Manual Deployment__

```bash
export PREFIX="<unique_prefix>"
export AZURE_LOCATION="<azure_location>"
export ADMIN_PASSWORD="<your_password>"

cd scripts && ./manual-deploy.sh
```


---

# References

https://github.com/paolosalvatori/private-cluster-with-public-dns-zone
https://github.com/Azure/bicep/tree/main/docs/examples
