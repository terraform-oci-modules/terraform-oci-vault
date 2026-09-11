output "vault_id" {
  description = "OCID of the vault the keys were created in (echoes var.vault_id)"
  value       = module.keys.vault_id
}

output "key_ids" {
  description = "Map of key name => OCID for the keys created in the existing vault"
  value       = module.keys.key_ids
}
