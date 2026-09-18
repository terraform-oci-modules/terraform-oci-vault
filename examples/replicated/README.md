# Replicated vault

Configuration in this directory creates a `VIRTUAL_PRIVATE` vault and replicates
it into a second region with `replica_region`. OCI mirrors the vault and its
keys (same OCIDs) into the target region and keeps them in sync.

Two things make this example `plan`-only rather than part of the live apply
suite:

- OCI only replicates **virtual private** vaults, and a virtual private vault
  allocates a dedicated HSM partition that is billed for as long as it (or its
  pending-deletion window) exists.
- `replica_region` must be a **subscribed** region of the tenancy.

## Usage

```bash
$ terraform init
$ terraform plan
```

Set `TF_VAR_compartment_id`, and `TF_VAR_replica_region` to a subscribed region
other than your provider's region.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | >= 6.9.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vault"></a> [vault](#module\_vault) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment to create the vault and key in | `string` | n/a | yes |
| <a name="input_replica_region"></a> [replica\_region](#input\_replica\_region) | A subscribed region of the tenancy to replicate the vault into (e.g. us-phoenix-1) | `string` | `"us-phoenix-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | OCID of the key (shared between the primary and replica vaults) |
| <a name="output_replica_region"></a> [replica\_region](#output\_replica\_region) | Region the vault is replicated into |
| <a name="output_vault_id"></a> [vault\_id](#output\_vault\_id) | OCID of the primary vault |
<!-- END_TF_DOCS -->
