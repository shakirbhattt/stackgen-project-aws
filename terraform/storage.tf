# StackGen Storage Configuration

# Custom StorageClass for ClickHouse using gp3 volumes
resource "kubernetes_storage_class" "stackgen_storage" {
  depends_on = [module.eks]

  metadata {
    name = "stackgen-storage"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    iops      = "3000"
    throughput = "125"
    fsType    = "ext4"
  }
}

# Namespace for StackGen ClickHouse deployment
resource "kubernetes_namespace" "stackgen" {
  depends_on = [module.eks]

  metadata {
    name = "stackgen"
    labels = {
      name        = "stackgen"
      environment = var.environment
      project     = "stackgen-clickhouse"
    }
  }
}
