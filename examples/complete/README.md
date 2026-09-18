# Complete vault

Configuration in this directory creates a `DEFAULT` vault with three keys that
show the range of options: an HSM-protected `AES` key with yearly auto-rotation,
a software-protected `RSA` signing key, and an `ECDSA` key created disabled.
Per-vault and per-key tags are set.

## Usage

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Set `TF_VAR_compartment_id`. Your `oci` provider must be configured for the
region the vault should live in.

> **Teardown is not immediate.** `terraform destroy` *schedules* the vault and
> keys for deletion (7-day minimum); they sit in `PENDING_DELETION` until then.
> A `DEFAULT` vault is not billed for.

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
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment to create the vault and keys in | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_ids"></a> [key\_ids](#output\_key\_ids) | Map of key name => OCID |
| <a name="output_keys"></a> [keys](#output\_keys) | Curated attributes of each created key |
| <a name="output_vault"></a> [vault](#output\_vault) | Curated attributes of the created vault |
| <a name="output_vault_id"></a> [vault\_id](#output\_vault\_id) | OCID of the created vault |
<!-- END_TF_DOCS -->
