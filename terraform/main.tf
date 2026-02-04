# StackGen ClickHouse Cluster - Main Infrastructure
# High-availability ClickHouse deployment on AWS EKS

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      Name                                         = "${var.cluster_name}-vpc"
    }
  )
}

# EKS Cluster Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    # StackGen Data Node Pool - ClickHouse data pods
    stackgen_data = {
      name = "sg-data"

      instance_types = [var.data_node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.data_node_min_size
      max_size     = var.data_node_max_size
      desired_size = var.data_node_desired_size

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        workload-type = "stackgen-data"
        node-pool     = "data"
        project       = "stackgen"
      }

      taints = {
        stackgen_data = {
          key    = "stackgen-data"
          value  = "true"
          effect = "NoSchedule"
        }
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-data-node"
          Role = "stackgen-data"
        }
      )
    }

    # StackGen Keeper Node Pool - ClickHouse coordination
    stackgen_keeper = {
      name = "sg-keeper"

      instance_types = [var.keeper_node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.keeper_node_min_size
      max_size     = var.keeper_node_max_size
      desired_size = var.keeper_node_desired_size

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        workload-type = "stackgen-keeper"
        node-pool     = "keeper"
        project       = "stackgen"
      }

      taints = {
        stackgen_keeper = {
          key    = "stackgen-keeper"
          value  = "true"
          effect = "NoSchedule"
        }
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-keeper-node"
          Role = "stackgen-keeper"
        }
      )
    }
  }

  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    
    ingress_clickhouse_http = {
      description                   = "ClickHouse HTTP port"
      protocol                      = "tcp"
      from_port                     = 8123
      to_port                       = 8123
      type                          = "ingress"
      source_cluster_security_group = true
    }
    
    ingress_clickhouse_native = {
      description                   = "ClickHouse native port"
      protocol                      = "tcp"
      from_port                     = 9000
      to_port                       = 9000
      type                          = "ingress"
      source_cluster_security_group = true
    }
    
    ingress_clickhouse_interserver = {
      description = "ClickHouse interserver port"
      protocol    = "tcp"
      from_port   = 9009
      to_port     = 9009
      type        = "ingress"
      self        = true
    }
    
    ingress_keeper = {
      description = "ClickHouse Keeper port"
      protocol    = "tcp"
      from_port   = 9181
      to_port     = 9181
      type        = "ingress"
      self        = true
    }
  }

  tags = var.tags
}

# IAM role for EBS CSI Driver
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-ebs-csi"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}
