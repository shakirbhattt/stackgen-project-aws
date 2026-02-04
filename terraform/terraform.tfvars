# StackGen ClickHouse Deployment - Terraform Variables
# Customize these values for your deployment

# Cluster Configuration
cluster_name    = "stackgen-ch"
cluster_version = "1.28"
aws_region      = "us-east-1"

# Data Node Pool - ClickHouse Data Pods
data_node_instance_type = "t3.xlarge"  # 4 vCPU, 16GB RAM
data_node_desired_size  = 4
data_node_min_size      = 4
data_node_max_size      = 6

# Keeper Node Pool - ClickHouse Coordination
keeper_node_instance_type = "t3.medium"  # 2 vCPU, 4GB RAM
keeper_node_desired_size  = 1
keeper_node_min_size      = 1
keeper_node_max_size      = 1

# Environment
environment = "demo"

# Tags - Applied to all AWS resources
tags = {
  Project     = "StackGen-ClickHouse"
  ManagedBy   = "Terraform"
  Environment = "demo"
  Team        = "DevOps"
}
