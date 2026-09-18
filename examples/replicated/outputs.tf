output "vault_id" {
  description = "OCID of the primary vault"
  value       = module.vault.vault_id
}

output "replica_region" {
  description = "Region the vault is replicated into"
  value       = module.vault.replica_region
}

output "key_id" {
  description = "OCID of the key (shared between the primary and replica vaults)"
  value       = module.vault.key_ids["ex-replicated-data"]
}
