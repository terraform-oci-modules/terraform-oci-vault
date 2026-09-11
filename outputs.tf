################################################################################
# Vault
################################################################################

output "vault_id" {
  description = "OCID of the vault - the one this module created, or the vault_id that was passed in"
  value       = local.create ? local.vault_id : null
}

output "vault_management_endpoint" {
  description = "The vault management endpoint (Create/Update/List/Get/Delete of keys). Callers performing key management via an SDK need this"
  value       = local.create ? local.management_endpoint : null
}

output "vault_crypto_endpoint" {
  description = "The vault cryptographic endpoint (Encrypt/Decrypt/GenerateDataEncryptionKey). Callers performing crypto operations via an SDK need this"
  value       = local.create ? local.crypto_endpoint : null
}

output "vault" {
  description = "Curated attributes of the created vault (null when vault_id was passed in). Not the raw provider object"
  value = local.create_vault ? {
    id                  = oci_kms_vault.this[0].id
    display_name        = oci_kms_vault.this[0].display_name
    vault_type          = oci_kms_vault.this[0].vault_type
    state               = oci_kms_vault.this[0].state
    management_endpoint = oci_kms_vault.this[0].management_endpoint
    crypto_endpoint     = oci_kms_vault.this[0].crypto_endpoint
    time_created        = oci_kms_vault.this[0].time_created
  } : null
}

output "replica_region" {
  description = "Region the vault is replicated into, or null when replication is not configured"
  value       = try(oci_kms_vault_replication.this[0].replica_region, null)
}

################################################################################
# Keys
################################################################################

output "key_ids" {
  description = "Map of key name => key OCID"
  value       = { for k, key in oci_kms_key.this : k => key.id }
}

output "keys" {
  description = "Map of key name => curated key attributes (id, display_name, current_key_version, algorithm, protection_mode, state, vault_id). Not the raw provider objects"
  value = {
    for k, key in oci_kms_key.this : k => {
      id                  = key.id
      display_name        = key.display_name
      current_key_version = key.current_key_version
      algorithm           = key.key_shape[0].algorithm
      protection_mode     = key.protection_mode
      state               = key.state
      vault_id            = key.vault_id
      management_endpoint = key.management_endpoint
    }
  }
}
