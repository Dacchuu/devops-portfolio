run "validate_eks_basic" {

  command = plan

  variables {

    # REQUIRED MODULE VARIABLES
    project_name = "eicon"
    environment  = "staging"
    region       = "us-east-1"

    vpc_id             = "vpc-12345678"
    private_subnet_ids = ["subnet-11111111", "subnet-22222222"]

    # EKS CONFIG
    cluster_name    = "eicon-staging"
    cluster_version = "1.35"

    cluster_endpoint_private_access      = true
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

    node_group_desired_size = 1
    node_group_min_size     = 1
    node_group_max_size     = 2

    node_group_instance_types = ["t3.medium"]
    node_group_capacity_type  = "ON_DEMAND"
    node_group_disk_size      = 20

    db_node_group_instance_types = ["t3.medium"]
    db_node_group_desired_size   = 0
    db_node_group_min_size       = 0
    db_node_group_max_size       = 0

    enable_ebs_csi_driver = true

    admin_users     = []
    developer_users = []
  }

  # Validate cluster name
  assert {
    condition     = aws_eks_cluster.main.name == "eicon-staging-eks"
    error_message = "EKS cluster name mismatch"
  }

  # Validate primary node group created
  assert {
  condition     = length(aws_eks_node_group.main) == 1 && aws_eks_node_group.main[0].scaling_config[0].desired_size == 1
  error_message = "Primary node group should be created"
  }

  # Validate DB node group not created
  assert {
    condition     = length(aws_eks_node_group.db) == 0
    error_message = "DB node group should not be created"
  }

}
