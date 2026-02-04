variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "stackgen-ch"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Data node pool configuration
variable "data_node_instance_type" {
  description = "Instance type for ClickHouse data nodes"
  type        = string
  default     = "t3.xlarge"
}

variable "data_node_desired_size" {
  description = "Desired number of data nodes"
  type        = number
  default     = 4
}

variable "data_node_min_size" {
  description = "Minimum number of data nodes"
  type        = number
  default     = 4
}

variable "data_node_max_size" {
  description = "Maximum number of data nodes"
  type        = number
  default     = 6
}

# Keeper node pool configuration
variable "keeper_node_instance_type" {
  description = "Instance type for ClickHouse Keeper node"
  type        = string
  default     = "t3.medium"
}

variable "keeper_node_desired_size" {
  description = "Desired number of keeper nodes"
  type        = number
  default     = 1
}

variable "keeper_node_min_size" {
  description = "Minimum number of keeper nodes"
  type        = number
  default     = 1
}

variable "keeper_node_max_size" {
  description = "Maximum number of keeper nodes"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "StackGen-ClickHouse"
    ManagedBy   = "Terraform"
    Environment = "demo"
  }
}
