# OCI Vault Terraform Module

Terraform module which creates **Vault (KMS)** resources on Oracle Cloud
Infrastructure (OCI): a vault and the master encryption keys inside it, optionally
replicated to a second region.

Designed to be familiar to users of the [terraform-aws-modules/kms/aws](https://github.com/terraform-aws-modules/terraform-aws-kms)
module, mapped to the primitives OCI actually has. AWS KMS and OCI KMS are
structurally different: OCI keys live inside a managed **Vault**, key access is
IAM policy (there is no key policy, no grants, no aliases), and deletion is always
*scheduled* rather than immediate. See
[docs/feature_parity.md](docs/feature_parity.md) for the full mapping and design
rationale.

Secrets (`oci_vault_secret`) are handled by the separate `terraform-oci-secret`
module, which takes a `vault_id` from this one.

## Usage

```hcl
module "vault" {
  source  = "terraform-oci-modules/vault/oci"
  version = "~> 0.1"

  compartment_id = var.compartment_id

  vault = {
    display_name = "platform"
  }

  keys = {
    # Symmetric key for envelope encryption, auto-rotated yearly.
    data = {
      key_shape                 = { algorithm = "AES", length = 32 }
      is_auto_rotation_enabled  = true
      rotation_interval_in_days = 365
    }

    # RSA signing key, software-protected.
    signing = {
      key_shape       = { algorithm = "RSA", length = 512 }
      protection_mode = "SOFTWARE"
    }
  }

  tags = {
    Terraform = "true"
  }
}
```

To add keys to a vault that already exists (or one created by another module
call), pass its OCID:

```hcl
module "tenant_keys" {
  source  = "terraform-oci-modules/vault/oci"
  version = "~> 0.1"

  compartment_id = var.compartment_id
  vault_id       = module.vault.vault_id

  keys = {
    tenant-a = { key_shape = { algorithm = "AES", length = 32 } }
  }
}
```

## Vault types

`vault.vault_type` is `DEFAULT` or `VIRTUAL_PRIVATE` and cannot be changed after
creation:

| Type              | Isolation                        | Cost                                  |
| ----------------- | -------------------------------- | ------------------------------------- |
| `DEFAULT`         | Shared, multi-tenant HSM partitions | No charge for the vault itself      |
| `VIRTUAL_PRIVATE` | A dedicated HSM partition        | Billed hourly for as long as it exists |

The module defaults to `DEFAULT`. Only `VIRTUAL_PRIVATE` vaults can be replicated.

## Keys

Each entry in `keys` is a master encryption key. `key_shape` sets the algorithm
and size:

| `algorithm` | `length` (bytes)   | `curve_id`                                  |
| ----------- | ------------------ | ------------------------------------------- |
| `AES`       | 16, 24, or 32      | -                                           |
| `RSA`       | 256, 384, or 512   | -                                           |
| `ECDSA`     | 32, 48, or 66      | `NIST_P256` / `NIST_P384` / `NIST_P521` (required) |

`protection_mode` is `HSM` (default, key never leaves the HSM) or `SOFTWARE`
(cheaper, higher throughput, key stored encrypted outside the HSM). It is fixed at
creation.

Auto-rotation is off unless you set `rotation_interval_in_days` (60-365), which
implicitly enables it. Set `is_auto_rotation_enabled` explicitly only to be
explicit.

Keys are always created enabled. OCI rejects creating a key in the `DISABLED`
state, so disabling a key is not a create-time option here - see
[docs/feature_parity.md](docs/feature_parity.md).

**The map key is the key's identity.** Renaming an entry in `keys` (or `vault`
being replaced) destroys the old key and creates a new one, and the old key then
sits in `PENDING_DELETION` for 7 to 30 days. Rename deliberately.

## Scheduled deletion

OCI has no immediate delete for a vault or a key. `terraform destroy` calls
`ScheduleVaultDeletion` / `ScheduleKeyDeletion`; the resource moves to
`PENDING_DELETION` with a deletion time **7 to 30 days** out (OCI defaults to 30)
and is only actually removed then. In that window the deletion can be cancelled.
A `VIRTUAL_PRIVATE` vault keeps billing for the whole pending-deletion window.

`vault.time_of_deletion` and `keys[*].time_of_deletion` take an RFC 3339
timestamp that the provider passes to the schedule-deletion call, so you can pin
the window to the 7-day minimum instead of 30:

```hcl
vault = {
  display_name     = "scratch"
  time_of_deletion = timeadd(timestamp(), "168h") # 7 days
}
```

It only affects `terraform destroy` (ignored on create and update), and OCI still
rejects anything outside the 7-to-30-day range at destroy time.

Practically:

- destroying and re-creating a vault or key with the same name is fine (the
  pending one does not block a new one),
- but a real apply/destroy test still leaves resources behind for at least a week
  - see [docs/testing.md](docs/testing.md).

## Access control is IAM

An OCI key has no attached policy. To let a group or dynamic group use a key,
write an IAM policy statement (with [`terraform-oci-iam`](https://github.com/terraform-oci-modules/terraform-oci-iam)
or by hand) in the key's compartment:

```
Allow group data-eng to use keys in compartment platform where target.key.id = '<key-ocid>'
Allow dynamic-group platform-instances to use keys in compartment platform
```

Common verbs: `use` (encrypt/decrypt/sign/verify with an existing key),
`manage` (also create, rotate, schedule deletion), `inspect`/`read` (metadata).
This module's job is to create the key and export its OCID; granting access to it
is a statement elsewhere.

## Replication

Set `replica_region` to a subscribed region to have OCI maintain a replica of the
vault (and its keys, sharing the same OCIDs) there. Two constraints: the vault
must be `VIRTUAL_PRIVATE`, and the target must be a subscribed region of the
tenancy. Only valid when the module creates the vault, not with `vault_id`.

## Tags

OCI supports two tag types, both mapped:

| Variable       | OCI tag type    |
| -------------- | --------------- |
| `tags`         | `freeform_tags` |
| `defined_tags` | `defined_tags`  |

`vault` and every `keys` entry accept their own `tags` / `defined_tags` that merge
over the module-wide values. Following the sibling OCI modules, tags are applied at
create time and later changes are ignored
(`lifecycle { ignore_changes = [defined_tags, freeform_tags] }`) to avoid drift
from OCI's auto-injected `Oracle-Tags` defaults.

## Adopting existing resources

Use `import` blocks (Terraform 1.5+). The `to` address uses the map key you give
the key in `keys`:

```hcl
import {
  to = module.vault.oci_kms_vault.this[0]
  id = "ocid1.vault.oc1.iad.aaaa"
}

import {
  to = module.vault.oci_kms_key.this["data"]
  id = "<management-endpoint>/<key-ocid>" # oci_kms_key import ID format
}
```

Run `terraform plan` and reconcile diffs (often just tags) before applying.

## What this module does not do

Out of scope: secrets (`terraform-oci-secret`), crypto operations as resources
(`oci_kms_sign`, `oci_kms_encrypted_data`, ...), external key management endpoints,
and vault restore-from-backup. Not applicable: key policies, grants, aliases -
key access is IAM policy on OCI. See [docs/feature_parity.md](docs/feature_parity.md).

## Examples

- [simple](examples/simple) - One `DEFAULT` vault and one 256-bit `AES` key
- [complete](examples/complete) - `DEFAULT` vault with an auto-rotated HSM `AES` key, a software `RSA` signing key, and an `ECDSA` P-384 key, with per-vault and per-key tags
- [existing-vault](examples/existing-vault) - `vault_id` passed in, module manages only keys against an existing vault (the shape `terraform-oci-secret` uses)
- [replicated](examples/replicated) - `VIRTUAL_PRIVATE` vault replicated to a second region (`plan`-only: needs a dedicated partition and a second subscribed region)

## Wrappers

- [wrappers](wrappers) - Terragrunt-style `for_each` wrapper for the root module

## Testing

The whole suite runs against a mocked OCI provider (`terraform test`) - no
credentials, no real resources, no cost. This is deliberate: OCI vault/key
deletion is always scheduled days out, so real apply/destroy tests cannot clean
up after themselves. See [docs/testing.md](docs/testing.md), which also covers
running a real apply by hand.

## AWS to OCI feature parity

See [docs/feature_parity.md](docs/feature_parity.md) for the full comparison
against `terraform-aws-modules/kms/aws`: feature, variable and output mapping,
what is not applicable to OCI, what is out of scope, and what is not yet
implemented.

## Related Projects

### Official Oracle module

Oracle maintains official KMS building blocks under
[oracle-terraform-modules](https://github.com/oracle-terraform-modules).

**When to use this module:**
- You are migrating from AWS and want the same module layout and interface as `terraform-aws-modules/kms/aws`
- You want a consistent interface across AWS and OCI infrastructure

### Disclaimer

This is an independent community module and is **not affiliated with, endorsed by, or supported by Oracle Corporation**. Oracle Cloud Infrastructure (OCI) is a trademark of Oracle Corporation. This module uses the publicly available [OCI Terraform provider](https://registry.terraform.io/providers/oracle/oci/latest) under its Mozilla Public License 2.0.

## License

[Apache 2.0](LICENSE)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | >= 6.9.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_oci"></a> [oci](#provider\_oci) | >= 6.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [oci_kms_key.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_key) | resource |
| [oci_kms_vault.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_vault) | resource |
| [oci_kms_vault_replication.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_vault_replication) | resource |
| [oci_kms_vault.existing](https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/kms_vault) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment that holds the vault and the keys | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Controls if resources should be created (master switch - affects all resources) | `bool` | `true` | no |
| <a name="input_defined_tags"></a> [defined\_tags](#input\_defined\_tags) | A map of defined tags (namespace.key = value) to add to the vault and every key. Applied at create time only (changes are ignored, matching the sibling OCI modules) | `map(string)` | `{}` | no |
| <a name="input_keys"></a> [keys](#input\_keys) | Map of master encryption keys to create in the vault, keyed by name.<br/>  display\_name              : defaults to the map key.<br/>  key\_shape.algorithm       : AES, RSA, or ECDSA.<br/>  key\_shape.length          : key size in BYTES - AES 16/24/32, RSA 256/384/512, ECDSA 32/48/66.<br/>  key\_shape.curve\_id        : NIST\_P256 / NIST\_P384 / NIST\_P521 - required for ECDSA.<br/>  protection\_mode           : HSM (default) or SOFTWARE. Cannot be changed after create.<br/>  is\_auto\_rotation\_enabled  : enable automatic key rotation. Defaults to true<br/>                              when rotation\_interval\_in\_days is set.<br/>  rotation\_interval\_in\_days : 60-365; required when is\_auto\_rotation\_enabled is true.<br/>  time\_of\_deletion          : RFC 3339 timestamp used only on `terraform<br/>                              destroy` - the key is scheduled for deletion at<br/>                              this time instead of the OCI default of 30 days<br/>                              out. OCI requires 7 to 30 days from when destroy<br/>                              runs.<br/>  timeouts                  : create / update / delete timeout overrides.<br/>  tags / defined\_tags       : per-key tags, merged over var.tags / var.defined\_tags. | <pre>map(object({<br/>    display_name = optional(string)<br/>    key_shape = object({<br/>      algorithm = string<br/>      length    = number<br/>      curve_id  = optional(string)<br/>    })<br/>    protection_mode           = optional(string, "HSM")<br/>    is_auto_rotation_enabled  = optional(bool)<br/>    rotation_interval_in_days = optional(number)<br/>    time_of_deletion          = optional(string)<br/>    timeouts = optional(object({<br/>      create = optional(string)<br/>      update = optional(string)<br/>      delete = optional(string)<br/>    }))<br/>    tags         = optional(map(string), {})<br/>    defined_tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_replica_region"></a> [replica\_region](#input\_replica\_region) | Identifier of a subscribed region (e.g. us-phoenix-1) to replicate the vault<br/>into. Only used when the module creates the vault. OCI only replicates<br/>VIRTUAL\_PRIVATE vaults, so this requires vault.vault\_type = "VIRTUAL\_PRIVATE". | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of freeform tags to add to the vault and every key. Applied at create time only (changes are ignored, matching the sibling OCI modules) | `map(string)` | `{}` | no |
| <a name="input_vault"></a> [vault](#input\_vault) | Configuration for the vault to create. Ignored when `vault_id` is set.<br/>  display\_name     : user-friendly name for the vault.<br/>  vault\_type       : DEFAULT (shared HSM partitions) or VIRTUAL\_PRIVATE<br/>                     (dedicated partition, separately billed). Cannot be<br/>                     changed after create.<br/>  time\_of\_deletion : RFC 3339 timestamp used only on `terraform destroy` -<br/>                     the vault is scheduled for deletion at this time instead<br/>                     of the OCI default of 30 days out. OCI requires it to be<br/>                     7 to 30 days from when destroy runs.<br/>  timeouts         : create / update / delete timeout overrides.<br/>  tags             : freeform tags for the vault, merged over var.tags.<br/>  defined\_tags     : defined tags for the vault, merged over var.defined\_tags. | <pre>object({<br/>    display_name     = optional(string, "vault")<br/>    vault_type       = optional(string, "DEFAULT")<br/>    time_of_deletion = optional(string)<br/>    timeouts = optional(object({<br/>      create = optional(string)<br/>      update = optional(string)<br/>      delete = optional(string)<br/>    }))<br/>    tags         = optional(map(string), {})<br/>    defined_tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_vault_id"></a> [vault\_id](#input\_vault\_id) | OCID of an existing vault to create the keys in. When set, the module does<br/>not create a vault (the `vault` variable and `replica_region` are ignored)<br/>and manages only the keys, reading the vault's management endpoint from a<br/>data source. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_ids"></a> [key\_ids](#output\_key\_ids) | Map of key name => key OCID |
| <a name="output_keys"></a> [keys](#output\_keys) | Map of key name => curated key attributes (id, display\_name, current\_key\_version, algorithm, protection\_mode, state, vault\_id). Not the raw provider objects |
| <a name="output_replica_region"></a> [replica\_region](#output\_replica\_region) | Region the vault is replicated into, or null when replication is not configured |
| <a name="output_vault"></a> [vault](#output\_vault) | Curated attributes of the created vault (null when vault\_id was passed in). Not the raw provider object |
| <a name="output_vault_crypto_endpoint"></a> [vault\_crypto\_endpoint](#output\_vault\_crypto\_endpoint) | The vault cryptographic endpoint (Encrypt/Decrypt/GenerateDataEncryptionKey). Callers performing crypto operations via an SDK need this |
| <a name="output_vault_id"></a> [vault\_id](#output\_vault\_id) | OCID of the vault - the one this module created, or the vault\_id that was passed in |
| <a name="output_vault_management_endpoint"></a> [vault\_management\_endpoint](#output\_vault\_management\_endpoint) | The vault management endpoint (Create/Update/List/Get/Delete of keys). Callers performing key management via an SDK need this |
<!-- END_TF_DOCS -->
