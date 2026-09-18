# KMS (AWS) to Vault / KMS (OCI) feature parity

Comparison against [`terraform-aws-modules/kms`](https://github.com/terraform-aws-modules/terraform-aws-kms)
v4.2.1. That module manages **one** customer master key (in one of four flavours:
standard, external, replica, replica-external), its aliases, its grants, and a
generated key policy document. This module manages an OCI **Vault** and the
**keys** inside it, as a map.

It is not a 1:1 mapping. AWS KMS and OCI KMS are structurally different:

- AWS keys live directly in an account and region. OCI keys live inside a
  **Vault**, a container that is itself a managed resource (with its own
  crypto/management endpoints, its own slow scheduled-deletion lifecycle, and, in
  the `VIRTUAL_PRIVATE` case, a dedicated and separately-billed HSM partition).
  The vault has no AWS counterpart.
- AWS controls key access with a **key policy** (a resource policy attached to the
  key) plus **grants** (a delegation primitive). OCI controls key access entirely
  through **IAM policy statements** in the enclosing compartment
  (`Allow group data-eng to use keys in compartment app`). There is no
  key-attached policy and no grant resource. The whole AWS key-policy builder
  (`key_owners`, `key_administrators`, `key_users`, `key_statements`, ...) and the
  `grants` map therefore have no home here: they belong in
  [`terraform-oci-iam`](https://github.com/terraform-oci-modules/terraform-oci-iam).
- AWS keys have **aliases** (`alias/my-key`), a separate resource. OCI keys have a
  `display_name` and an OCID, no alias resource.
- **Secrets** (`oci_vault_secret`) live in a vault too, but managing them is the
  job of the planned `terraform-oci-secret` module, which takes a vault OCID as
  input. This module stops at the vault and its keys.

Gaps are split three ways:

- [Not applicable](#not-applicable-to-oci): no OCI equivalent exists, or the
  concept is expressed through a different service.
- [Out of scope](#out-of-scope): OCI supports it, this module deliberately does not.
- [Not yet implemented](#not-yet-implemented): the backlog.

Status values in the tables: `mapped` where the concept carries over, `n/a` where
no OCI equivalent exists at the key/vault level, `OCI-only` for features with no
AWS counterpart, `backlog` for anything the OCI provider supports that this module
does not expose yet.

## Feature mapping

### Core / control

| Feature             | AWS                        | OCI                                        | Status   |
| ------------------- | -------------------------- | ------------------------------------------ | -------- |
| Create toggle       | `create`                   | `create`                                   | mapped   |
| Target compartment  | AWS account (implicit)     | `compartment_id` (required)                | mapped   |
| Per-resource region | `region`                   | none (provider carries the region)         | n/a      |
| Freeform tags       | `tags`                     | `tags`                                      | mapped   |
| Defined tags        | none                       | `defined_tags`                             | OCI-only |

> **No per-resource `region`**: the AWS module takes a `region` argument so a
> single provider can manage keys in several regions and build multi-region
> replicas. On OCI the provider is bound to one region; cross-region reach is the
> `replica_region` feature below, which asks OCI to stand up a replica vault in
> another region rather than declaring resources there directly.

### Vault

No AWS counterpart. AWS keys are not contained in anything.

| Feature                         | AWS  | OCI                                   | Status   |
| ------------------------------- | ---- | ------------------------------------- | -------- |
| Create a vault                  | none | `create` + `vault` (object)           | OCI-only |
| Use an existing vault           | none | `vault_id`                            | OCI-only |
| Vault type                      | none | `vault.vault_type` (`DEFAULT` / `VIRTUAL_PRIVATE`) | OCI-only |
| Display name                    | none | `vault.display_name`                  | OCI-only |
| Delete timeout override         | none | `vault.timeouts`                      | OCI-only |
| Freeform / defined tags         | none | `vault.tags` / `vault.defined_tags`   | OCI-only |
| Cross-region replica            | `multi_region`, `create_replica`, `primary_key_arn` | `replica_region` | mapped (different model) |
| External key manager (EXTERNAL) | `custom_key_store_id` (CloudHSM) | `vault.external_key_manager_metadata` | backlog  |

> **`create` + `vault_id`**: when `vault_id` is null the module creates a vault
> from the `vault` object and puts the keys in it. When `vault_id` is set the
> module manages **only the keys**, placing them in that existing vault (it reads
> the vault's `management_endpoint` with a data source). This is the shape
> `terraform-oci-secret` will use to add secrets to a vault this module created.
>
> **`vault_type`**: `DEFAULT` uses Oracle's shared HSM partitions. `VIRTUAL_PRIVATE`
> allocates a dedicated partition; it is materially more expensive and is billed
> for as long as the vault (or its 7-to-30-day pending-deletion window) exists.
> The module defaults to `DEFAULT` and validates the value.
>
> **`replica_region`**: OCI cross-region key material is done by asking the
> primary vault to replicate itself (`oci_kms_vault_replication`); OCI then
> maintains a replica vault, with mirrored keys sharing the same OCIDs, in the
> target region. This is closer to AWS `multi_region` (one logical key, regional
> replicas) than to the AWS module's `create_replica` flow (a separate module
> instance per region). Two constraints: the target region must be a subscribed
> region of the tenancy, and **OCI only replicates `VIRTUAL_PRIVATE` vaults
> today**, so `replica_region` requires `vault.vault_type = "VIRTUAL_PRIVATE"`
> (the module validates this).

### Key

AWS: a single key, configured by the top-level variables. OCI: a **map** of keys
in the vault, keyed by name, each configured by an object (the `iam` module's
map-of-objects style).

| Feature                    | AWS                                   | OCI                                          | Status   |
| -------------------------- | ------------------------------------- | ------------------------------------------- | -------- |
| Create key(s)              | one key (`create` + `create_*`)       | `keys` (map, name = key)                     | mapped (one to many) |
| Display name / description  | `description`                         | `keys[*].display_name` (defaults to map key) | mapped   |
| Key algorithm + size       | `customer_master_key_spec` / `key_spec` (`SYMMETRIC_DEFAULT`, `RSA_2048`, `ECC_NIST_P256`, ...) | `keys[*].key_shape` object: `algorithm` (`AES` / `RSA` / `ECDSA`) + `length` (bytes) + `curve_id` | mapped (different spelling) |
| Protection mode            | `custom_key_store_id` (HSM vs KMS)     | `keys[*].protection_mode` (`HSM` / `SOFTWARE`) | mapped (different model) |
| Key usage                  | `key_usage` (`ENCRYPT_DECRYPT` / `SIGN_VERIFY`) | implied by algorithm (`AES` encrypt, `RSA`/`ECDSA` sign or encrypt) | n/a |
| Enabled / disabled         | `is_enabled` (settable at create)     | none - OCI rejects creating a key `DISABLED` | backlog |
| Automatic rotation         | `enable_key_rotation` (bool, default true) | `keys[*].is_auto_rotation_enabled` (bool)   | mapped   |
| Rotation period            | `rotation_period_in_days` (90-2560)   | `keys[*].rotation_interval_in_days` (60-365) | mapped (different range) |
| Scheduled deletion window  | `deletion_window_in_days` (7-30)      | `vault.time_of_deletion` / `keys[*].time_of_deletion` (RFC 3339, destroy-only) | mapped (timestamp, not a day count) |
| Imported key material      | `key_material_base64`, `valid_to` (external key) | `keys[*].external_key_reference` | backlog  |
| Key policy                 | `policy` + the whole builder          | none at the key level (IAM policy)          | n/a      |
| Grants                     | `grants` (map)                        | none (IAM policy)                            | n/a      |
| Aliases                    | `aliases`, `computed_aliases`         | none (`display_name` only)                   | n/a      |
| Bypass policy lockout      | `bypass_policy_lockout_safety_check`  | none (no key policy to lock out)             | n/a      |
| Freeform / defined tags    | `tags`                                | `keys[*].tags` / `keys[*].defined_tags`      | mapped   |

> **Algorithm spelling**: AWS folds algorithm and size into one enum
> (`RSA_2048`). OCI's `key_shape` splits them: `algorithm` (`AES`, `RSA`,
> `ECDSA`), `length` in **bytes** (always required: AES 16/24/32, RSA
> 256/384/512, ECDSA 32/48/66), and `curve_id` (`NIST_P256` / `NIST_P384` /
> `NIST_P521`) for ECDSA. The module takes a `key_shape` object per key and
> validates the algorithm/length/curve combination.
>
> **Scheduled deletion.** OCI has no immediate key or vault delete.
> `terraform destroy` calls `ScheduleKeyDeletion` / `ScheduleVaultDeletion`, which
> set the resource to `PENDING_DELETION` with a deletion time 7 to 30 days out
> (OCI defaults to 30 when none is given); the resource (and, for
> `VIRTUAL_PRIVATE`, its billing) persists until then, and the deletion can be
> cancelled in that window. `vault.time_of_deletion` and `keys[*].time_of_deletion`
> are the nearest thing to AWS's `deletion_window_in_days`: an RFC 3339 timestamp
> the provider passes to the schedule-deletion call, so you can pin the window to
> the 7-day minimum instead of 30. It only affects the destroy path (the provider
> ignores it on create and update). It is not a day count, and OCI still rejects
> anything outside 7-30 days at destroy time.
>
> **`protection_mode`**: `HSM` keys never leave the HSM; `SOFTWARE` keys are
> stored (encrypted) outside it and are cheaper and faster for high-volume
> operations. It is fixed at creation. The module defaults to `HSM`.
>
> **Key usage is implied.** OCI does not take a `key_usage`; an `AES` key does
> symmetric encrypt/decrypt, an `RSA` key does encrypt/decrypt or sign/verify, an
> `ECDSA` key does sign/verify. There is nothing to map `SIGN_VERIFY` to.

### Key version

| Feature               | AWS                          | OCI                                  | Status  |
| --------------------- | ---------------------------- | ------------------------------------ | ------- |
| Rotate now (new version) | (implicit in rotation)    | `oci_kms_key_version`                 | backlog |

> Auto-rotation (above) covers the common need. An explicit "rotate on next
> apply" trigger is backlog.

### Access control

| Feature              | AWS                                       | OCI                                  | Status |
| -------------------- | ----------------------------------------- | ------------------------------------ | ------ |
| Who can use the key  | `key_users`, `key_service_users`, ...     | IAM policy in `terraform-oci-iam`    | n/a    |
| Who can administer   | `key_administrators`, `key_owners`        | IAM policy in `terraform-oci-iam`    | n/a    |
| Custom statements    | `key_statements`                          | IAM policy in `terraform-oci-iam`    | n/a    |
| Default key policy   | `enable_default_policy`                   | none (a compartment has no implicit key policy) | n/a |
| Delegated use        | `grants`                                  | IAM policy `where` conditions        | n/a    |
| Route53 DNSSEC preset | `enable_route53_dnssec`                   | none                                 | n/a    |

> **All of this is IAM.** To let a group use a key on OCI you write, in
> `terraform-oci-iam`,
> `Allow group data-eng to use keys in compartment app where target.key.id = '<ocid>'`
> (or drop the `where` clause to grant on every key in the compartment). The
> vault module's job is to create the key and expose its OCID; granting access to
> it is a policy statement elsewhere. The module README shows the common
> statements.

### Submodules and wrappers

| AWS                     | OCI                                   | Status                                       |
| ----------------------- | ------------------------------------- | -------------------------------------------- |
| root module (one key)   | root module (`vault` + `keys` map)    | mapped                                       |
| `wrappers/`             | `wrappers/`                           | mapped                                       |
| (no AWS submodule)      | `vault_id` BYO-vault path             | OCI-only                                     |

## Variable mapping

Equivalent concept, different name. Anything not listed maps by an identical name.

| AWS                          | OCI                              | Notes                                                          |
| ---------------------------- | -------------------------------- | ------------------------------------------------------------- |
| `create`                     | `create`                         | master toggle                                                 |
| `region`                     | none                             | provider carries the region; cross-region is `replica_region` |
| `description`                | `vault.display_name` / `keys[*].display_name` | OCI has display names, not descriptions, on these       |
| `key_spec` / `customer_master_key_spec` | `keys[*].algorithm` + `keys[*].length` + `keys[*].curve_id` | split into three fields          |
| `enable_key_rotation`        | `keys[*].is_auto_rotation_enabled` | default true on AWS; OCI provider default is off, module keeps that unless set |
| `rotation_period_in_days`    | `keys[*].rotation_interval_in_days` | AWS 90-2560, OCI 60-365                                      |
| `is_enabled`                 | none                             | OCI keys are always created enabled; disabling is a post-create op, backlog |
| `deletion_window_in_days`    | `vault.time_of_deletion` / `keys[*].time_of_deletion` | AWS: a day count that shifts the destroy window. OCI: an RFC 3339 timestamp passed straight to the schedule-deletion call, destroy-only |
| `multi_region` / `create_replica` / `primary_key_arn` | `replica_region`  | one string; OCI creates and maintains the replica vault       |
| `tags`                       | `tags` + per-object `tags`        | merged into `freeform_tags` on every resource                 |
| `policy`, `key_*` principal lists, `key_statements`, `grants`, `aliases` | none | key access is IAM policy (`terraform-oci-iam`); no aliases    |

OCI-only variables, no AWS counterpart:

| OCI variable              | What it does                                                              |
| ------------------------- | ------------------------------------------------------------------------ |
| `compartment_id`          | compartment that holds the vault and keys (required)                     |
| `vault_id`                | manage keys in an existing vault instead of creating one                 |
| `vault.vault_type`        | `DEFAULT` (shared HSM) or `VIRTUAL_PRIVATE` (dedicated, billed) partition |
| `vault.timeouts`          | create/update/delete timeout overrides                                   |
| `keys[*].protection_mode` | `HSM` (never leaves the HSM) or `SOFTWARE`                               |
| `keys[*].curve_id`        | curve for `ECDSA` keys                                                   |
| `keys[*].timeouts`        | per-key timeout overrides                                                |
| `replica_region`          | subscribed region to replicate the vault into                            |
| `defined_tags` everywhere | OCI's tag-namespace system, alongside freeform `tags`                    |

## Output mapping

| AWS                        | OCI                                     | Notes                                          |
| -------------------------- | --------------------------------------- | --------------------------------------------- |
| `key_id`                   | `key_ids` (map name to OCID)            | one key on AWS, a map here                     |
| `key_arn`                  | `key_ids`                               | OCID, no ARN                                   |
| `key_region`               | none                                    | provider region                               |
| `key_policy`               | none                                    | no key policy                                  |
| `external_key_*`           | none                                    | external key material is backlog              |
| `aliases`                  | none                                    | no alias resource                             |
| `grants`                   | none                                    | no grant resource                             |
| (none)                     | `vault_id`                              | OCID of the vault (created or passed in)       |
| (none)                     | `vault_management_endpoint` / `vault_crypto_endpoint` | endpoints callers need for SDK crypto ops |
| (none)                     | `keys` (curated objects)               | id, display_name, current_key_version, protection_mode, state, per key |
| (none)                     | `vault` (curated object)               | id, display_name, vault_type, state, endpoints |
| (none)                     | `replica_region` / replication id      | present when `replica_region` is set          |

Curated outputs mirror the `iam` module: per-name maps of a stable attribute
subset, not the raw provider objects (which carry computed cruft and, on some
resources, deprecated fields).

## Not applicable to OCI

| AWS feature                                              | Why it does not port                                                                      |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `policy`, `enable_default_policy`, `key_owners`, `key_administrators`, `key_users`, `key_service_users`, `key_service_roles_for_autoscaling`, `key_symmetric_encryption_users`, `key_hmac_users`, `key_asymmetric_public_encryption_users`, `key_asymmetric_sign_verify_users`, `key_statements`, `source_policy_documents`, `override_policy_documents` | OCI keys have no attached policy. Access is granted with IAM policy statements in the compartment, which is `terraform-oci-iam`'s job. |
| `grants`, `aws_kms_grant`                                | No grant primitive on OCI. Time-boxed or conditional delegation is an IAM policy `where` clause. |
| `aliases`, `computed_aliases`, `aliases_use_name_prefix` | No alias resource. A key has a `display_name` and an OCID.                              |
| `bypass_policy_lockout_safety_check`                     | No key policy to lock yourself out of.                                                 |
| `key_usage` (`SIGN_VERIFY` vs `ENCRYPT_DECRYPT`)         | Implied by the key algorithm on OCI.                                                   |
| `enable_route53_dnssec`, `route53_dnssec_sources`        | AWS-service-specific key-policy preset.                                                |
| `deletion_window_in_days` as a **day count**             | OCI takes an absolute RFC 3339 timestamp (`time_of_deletion`), not a number of days, and it is destroy-only. The module exposes the timestamp form; the day-count ergonomics do not port. |
| `key_region` / every `*_arn` output                     | OCI uses OCIDs and a provider-bound region.                                            |

## Out of scope

OCI supports these; this module does not (yet, or by design).

- **Secrets.** `oci_vault_secret` and its versions/rotation. The
  vault/secret split is a deliberate roadmap decision: `terraform-oci-secret`
  will take a `vault_id` (this module's output) and manage secrets against it.
- **Crypto operations as resources.** `oci_kms_encrypted_data`,
  `oci_kms_generated_key`, `oci_kms_sign`, `oci_kms_verify`. These perform a
  one-shot operation at apply time and store the result (often sensitive) in
  state. They are an SDK/runtime concern, not infrastructure.
- **External key management endpoints.** `oci_kms_ekms_private_endpoint` and the
  `EXTERNAL` vault type with `external_key_manager_metadata`. Bring-your-own
  external HSM via a private endpoint is a specialised setup; listed in the
  backlog.
- **Vault restore-from-backup.** The `restore_from_file` /
  `restore_from_object_store` / `restore_trigger` blocks on the vault and key
  resources. Disaster recovery is a separate runbook, not a module input.

## Not yet implemented

| Gap                         | Detail                                                                                                                                        | AWS analog                     |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| Create a key disabled       | OCI's provider rejects `Create` unless the key is `ENABLED` (`oci_kms_keys can only be created in ENABLED state`). Disabling would need a create-then-update two-apply, or an out-of-band `desired_state` change. | `is_enabled = false` |
| Explicit key version        | `oci_kms_key_version`: force a new key version on apply, independent of the auto-rotation schedule.                                            | (implicit)                     |
| Imported / external key material | `keys[*].external_key_reference`, `EXTERNAL` protection mode, `oci_kms_ekms_private_endpoint`. Bring-your-own-key from an external HSM.    | `key_material_base64`, `valid_to`, `custom_key_store_id` |
| Replica management from the replica side | The AWS module's `create_replica` / `primary_key_arn` flow (stand up just the replica, given a primary in another region). OCI's `replica_region` covers the primary-driven case only. | `create_replica`, `primary_key_arn` |

## Examples

| Example          | What it covers                                                                                          | AWS counterpart |
| ---------------- | ---------------------------------------------------------------------------------------------------- | --------------- |
| `simple`         | One `DEFAULT` vault, one `AES` key                                                                    | (minimal)       |
| `complete`       | `DEFAULT` vault, several keys (`AES` + `RSA` + `ECDSA`), auto-rotation with a custom interval, per-key and per-vault tags | `complete`      |
| `existing-vault` | `vault_id` passed in, module manages only keys against it (the shape `terraform-oci-secret` will use) | (none)          |
| `replicated`     | `VIRTUAL_PRIVATE` vault with `replica_region` set. Needs a second subscribed region and a billed dedicated partition, so its test is plan-only. | multi-region part of `complete` |

## Testing note

Because vault and key deletion is always **scheduled** (7-day minimum, not
immediate and not skippable), a real apply/destroy test cannot fully tear down
inside the run: `terraform destroy` succeeds but leaves the vault and keys in
`PENDING_DELETION` for at least 7 days, and a `VIRTUAL_PRIVATE` vault keeps
billing over that window. So the entire suite runs against a **mocked provider**
(`mock_provider "oci" {}`): a unit suite against the module root for all input and
mapping logic plus every `validation` block, and one mock test per example.
Running a real apply is a deliberate by-hand step, documented in
`docs/testing.md`.
