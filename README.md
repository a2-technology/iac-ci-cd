# Terraform CI-CD Playground

## Prerequisites

1. An AWS Organization structure is in place where:

   - There is an organizational unit for workloads with children workload accounts.
   - There is an organizational unit for deployments with a child ci-cd account whose singular function is cross-account deployments

![organization](docs/organization.png)

WIP

## Future enhancements/work

1. Automate the state of the bootstrap module into the default workspace
2. Push artifact to ECR without the .terraform directory to save on storage. Include the plan, scan, and terraform.lock.hcl // not sure if this will work
