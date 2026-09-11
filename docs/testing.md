# Testing

The whole suite runs against a **mocked OCI provider** - no credentials, no real
resources, no cost, safe to run anytime. This is deliberate: OCI vault and key
deletion is always scheduled 7 to 30 days out (never immediate), so real
apply/destroy tests cannot clean up after themselves. The module is exercised
with `mock_provider "oci" {}` instead.

```bash
terraform init
terraform test
```

## What is covered

| File                          | Against            | Checks                                                                 |
| ----------------------------- | ------------------ | --------------------------------------------------------------------- |
| `tests/unit_mappings.tftest.hcl` | the module root    | vault-create vs bring-your-own, `key_shape` passthrough, display-name defaulting, tag merging, the auto-rotation block, `time_of_deletion` passthrough, replication gating, `create = false`, and a reject case for every `validation` rule |
| `tests/simple.tftest.hcl`        | `examples/simple`  | the minimal example plans and exposes its outputs                     |
| `tests/complete.tftest.hcl`      | `examples/complete` | three keys with the expected shapes and an auto-rotation schedule    |
| `tests/existing-vault.tftest.hcl` | `examples/existing-vault` | `vault_id` passthrough: no vault created, keys created against it |
| `tests/replicated.tftest.hcl`    | `examples/replicated` | `VIRTUAL_PRIVATE` vault with `replica_region` wired to the replication resource |

## Running a real apply by hand

If you do want to try the module against a live tenancy, apply an example
directly (not through `terraform test`):

```bash
cd examples/simple
export TF_VAR_compartment_id="ocid1.compartment.oc1..aaaa"
export TF_VAR_deletion_time=$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)
terraform init && terraform apply
# ... inspect ...
terraform destroy
```

`terraform destroy` schedules the vault and key for deletion at `deletion_time`
(or 30 days out if unset); they remain in `PENDING_DELETION` until then. A
`DEFAULT` vault is not billed for. Use `oci kms management vault
cancel-deletion` / `schedule-deletion` to adjust or a `VIRTUAL_PRIVATE` vault
will keep costing money for the whole window.

## Notes

- Key `length` is in **bytes**: AES 16/24/32, RSA 256/384/512, ECDSA 32/48/66. A
  wrong value is rejected by a `validation` block before any provider call.
- `oci_kms_key` needs the vault's `management_endpoint`. When the module creates
  the vault this is wired automatically; with `vault_id` it is read from the
  `oci_kms_vault` data source, so `vault_id` must point at a live vault.
- If `vault_id` is the output of a vault resource in the same configuration, its
  OCID is unknown at plan and the module's `count`-based resources cannot be
  planned in one pass - apply the vault first or keep it in a separate state.
