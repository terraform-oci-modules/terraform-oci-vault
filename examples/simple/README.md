# Simple vault

Configuration in this directory creates the smallest useful setup: one `DEFAULT`
vault and one 256-bit `AES` key in it.

## Usage

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Set `TF_VAR_compartment_id`. Your `oci` provider must be configured for the
region the vault should live in.

> **Teardown is not immediate.** `terraform destroy` *schedules* the vault and
> key for deletion; they sit in `PENDING_DELETION` until then and can be cancelled
> in that window. A `DEFAULT` vault is not billed for, so the residue is harmless.
> Pass `deletion_time` to pin the window to the 7-day minimum instead of the
> 30-day default:
>
> ```bash
> export TF_VAR_deletion_time=$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)
> ```

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
| <a name="input_deletion_time"></a> [deletion\_time](#input\_deletion\_time) | Optional RFC 3339 timestamp. When set, `terraform destroy` schedules the<br/>vault and key for deletion at this time (7-30 days out) instead of the OCI<br/>default of 30 days. Handy for keeping test residue to the 7-day minimum:<br/>  TF\_VAR\_deletion\_time=$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ) | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | OCID of the created key |
| <a name="output_vault_id"></a> [vault\_id](#output\_vault\_id) | OCID of the created vault |
| <a name="output_vault_management_endpoint"></a> [vault\_management\_endpoint](#output\_vault\_management\_endpoint) | Management endpoint of the created vault |
<!-- END_TF_DOCS -->
