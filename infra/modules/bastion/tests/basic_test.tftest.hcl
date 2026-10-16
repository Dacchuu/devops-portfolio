# Plan-only test: uses placeholder VPC/subnet IDs. Requires AWS credentials for aws_ami data source.

run "validate_bastion_basic" {
  command = plan

  variables {
    project_name = "eicon"
    environment  = "staging"

    vpc_id             = "vpc-*********"
    public_subnet_id   = "subnet-***********"
    create_key_pair    = false
    existing_key_name  = "eicon-test"
    devops_ssh_keys    = []
    allocate_eip       = true
    bastion_ssh_cidr_blocks = ["203.0.113.0/24"]
  }

  assert {
    condition     = aws_security_group.bastion.vpc_id == "vpc-***********"
    error_message = "Bastion security group should be attached to the given VPC"
  }

  assert {
    condition     = aws_instance.bastion.subnet_id == "subnet-***********"
    error_message = "Bastion instance should use the given public subnet"
  }
}
