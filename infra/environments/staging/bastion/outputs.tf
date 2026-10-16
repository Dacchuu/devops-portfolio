output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = module.bastion.bastion_instance_id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = module.bastion.bastion_public_ip
}

output "bastion_eip" {
  description = "Bastion Elastic IP"
  value       = module.bastion.bastion_eip
}

output "bastion_ssh_command" {
  description = "SSH command for bastion"
  value       = module.bastion.bastion_ssh_command
}
