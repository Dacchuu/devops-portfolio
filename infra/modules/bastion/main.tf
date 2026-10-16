# Bastion Host Module
# SSH jump server for private instance access
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

# Bastion security group
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_ssh_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  })
}

# IAM role for bastion
resource "aws_iam_role" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM instance profile
resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  role        = aws_iam_role.bastion.name

  tags = var.tags
}

# IAM policy for bastion
resource "aws_iam_role_policy" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  role        = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ssm:StartSession"
        ]
        Resource = "*"
      }
    ]
  })
}

# SSH key pair (optional)
resource "aws_key_pair" "bastion" {
  count = var.create_key_pair ? 1 : 0

  key_name   = "${var.project_name}-${var.environment}-bastion-key"
  public_key = file(var.public_key_path)

  tags = var.tags
}

# Bastion instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.bastion[0].key_name : var.existing_key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = var.public_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    project_name    = var.project_name
    environment     = var.environment
    devops_ssh_keys = var.devops_ssh_keys
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion"
  })
}

# Elastic IP (optional)
resource "aws_eip" "bastion" {
  count = var.allocate_eip ? 1 : 0

  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-bastion-eip"
  })
}