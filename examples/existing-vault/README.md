# Keys in an existing vault

Configuration in this directory manages keys against a vault that already exists,
passed by OCID through `vault_id`. No vault is created. The module reads the
vault's management endpoint from a data source.

This is the pattern `terraform-oci-secret` will use: take a `vault_id` and manage
resources inside that vault.

> If `vault_id` is the output of a vault resource created in the same
> configuration, its OCID is unknown until that resource is applied, and
> Terraform cannot plan this module's `count`-based resources in one pass. Apply
> the vault first (`terraform apply -target=module.vault`) or keep the vault in a
> separate state / stack.

## Usage

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Set `TF_VAR_compartment_id` and `TF_VAR_vault_id`. Your `oci` provider must be
configured for the vault's region.

> **Teardown is not immediate.** `terraform destroy` *schedules* the keys for
> deletion (7-day minimum); the vault itself is untouched (the module does not
> own it).

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
| <a name="module_keys"></a> [keys](#module\_keys) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment to create the keys in | `string` | n/a | yes |
| <a name="input_vault_id"></a> [vault\_id](#input\_vault\_id) | OCID of an existing vault to create the keys in | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_ids"></a> [key\_ids](#output\_key\_ids) | Map of key name => OCID for the keys created in the existing vault |
| <a name="output_vault_id"></a> [vault\_id](#output\_vault\_id) | OCID of the vault the keys were created in (echoes var.vault\_id) |
<!-- END_TF_DOCS -->
