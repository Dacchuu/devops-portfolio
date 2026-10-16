# Bastion module outputs

output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_eip" {
  description = "Bastion Elastic IP"
  value       = var.allocate_eip ? aws_eip.bastion[0].public_ip : aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command for bastion"
  value       = "ssh -i ~/.ssh/${var.create_key_pair ? aws_key_pair.bastion[0].key_name : var.existing_key_name}.pem ec2-user@${var.allocate_eip ? aws_eip.bastion[0].public_ip : aws_instance.bastion.public_ip}"
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = aws_security_group.bastion.id
}
