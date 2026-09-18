output "vault_id" {
  description = "OCID of the created vault"
  value       = module.vault.vault_id
}

output "vault_management_endpoint" {
  description = "Management endpoint of the created vault"
  value       = module.vault.vault_management_endpoint
}

output "key_id" {
  description = "OCID of the created key"
  value       = module.vault.key_ids["ex-simple-data"]
}
