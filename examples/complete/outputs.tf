output "vault_id" {
  description = "OCID of the created vault"
  value       = module.vault.vault_id
}

output "vault" {
  description = "Curated attributes of the created vault"
  value       = module.vault.vault
}

output "key_ids" {
  description = "Map of key name => OCID"
  value       = module.vault.key_ids
}

output "keys" {
  description = "Curated attributes of each created key"
  value       = module.vault.keys
}
