# StackGen ClickHouse HA Cluster

Production-ready ClickHouse deployment on AWS EKS with workload isolation, sharding, and replication.

**Project:** StackGen DevOps Assessment  
**Stack:** ClickHouse, Kubernetes (EKS), Terraform  

---

## Architecture

```
AWS EKS Cluster (stackgen-ch)
│
├── Data Node Pool (4× t3.xlarge)
│   ├── Shard 1
│   │   ├── Replica 1 ──┐
│   │   └── Replica 2 ──┼─→ ReplicatedMergeTree
│   └── Shard 2         │
│       ├── Replica 1 ──┤
│       └── Replica 2 ──┘
│
└── Keeper Node Pool (1× t3.medium)
    └── ClickHouse Keeper → Coordination Layer
```

**Key Features:**
- ✅ 2 Shards × 2 Replicas (4 data pods)
- ✅ Dedicated Keeper node for coordination
- ✅ Workload isolation via node pools
- ✅ Persistent storage with Retain policy (gp3)
- ✅ 100% Infrastructure as Code

---

## Prerequisites

- **Terraform** ≥ 1.0
- **kubectl** ≥ 1.28
- **Helm** ≥ 3.0
- **AWS CLI** configured with credentials
- **AWS Account** with EKS permissions

---

## Quick Start

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

**Creates:** EKS cluster, VPC, node pools, storage class (~15 minutes)

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name stackgen-ch
kubectl get nodes
```

**Expected:** 5 nodes (4 data + 1 keeper)

### 3. Install ClickHouse Operator

```bash
helm repo add altinity https://docs.altinity.com/clickhouse-operator/
helm repo update
helm install clickhouse-operator altinity/clickhouse-operator \
  --namespace stackgen \
  --set operator.watchNamespaces="{stackgen}"
```

### 4. Deploy ClickHouse Cluster

```bash
cd ../kubernetes
kubectl apply -f stackgen-clickhouse.yaml

# Wait for pods
kubectl get pods -n stackgen -w
```

**Expected:** 1 Keeper + 4 Data pods Running

### 5. Initialize Schema

```bash
kubectl apply -f stackgen-tables.yaml

# Check job completion
kubectl get jobs -n stackgen
kubectl logs job/stackgen-init-tables -n stackgen
```

### 6. Ingest Test Data

```bash
# Port-forward ClickHouse
kubectl port-forward -n stackgen svc/chi-stackgen-cluster-stackgen-0-0 8123:8123 9000:9000 &

# Run ingestion
cd ../scripts
chmod +x ingest.sh
./ingest.sh
```

**Result:** 10,000 rows inserted across shards

---

## Validation

### Test Resilience

```bash
# Delete a pod
kubectl delete pod chi-stackgen-cluster-stackgen-0-0-0 -n stackgen

# Watch recovery
kubectl get pods -n stackgen -w

# Verify data persistence
kubectl exec -n stackgen chi-stackgen-cluster-stackgen-0-1-0 -- \
  clickhouse-client --query "SELECT count() FROM stackgen.readings"
```

**Success Criteria:** Pod recovers, data count = 10,000

### Verify Node Placement

```bash
# Check data pods on data nodes
kubectl get pods -n stackgen -l clickhouse.altinity.com/app=clickhouse -o wide

# Check keeper on keeper node
kubectl get pod -n stackgen -l app=stackgen-keeper -o wide
```

---

## Design Decisions

### Why Separate Node Pools?

**Decision:** Dedicated node pools for data (4 nodes) and coordination (1 node)

**Rationale:**
- Prevents coordination bottlenecks from data workload spikes
- Guarantees resources for Keeper (no CPU/memory competition)
- Simplifies scaling (adjust pools independently)
- Production best practice per ClickHouse documentation

### Why gp3 Storage?

**Decision:** AWS gp3 volumes with Retain policy

**Rationale:**
- **Cost:** 20% cheaper than gp2
- **Performance:** 3000 IOPS baseline (vs 3 IOPS/GB for gp2)
- **Flexibility:** Independent IOPS/throughput configuration
- **Retain Policy:** Data survives PVC deletion (disaster recovery)

### Why 2 Shards × 2 Replicas?

**Decision:** 4 total pods (2 shards, 2 replicas each)

**Rationale:**
- **Sharding:** Distributes data for parallel query processing
- **Replication:** High availability (1 replica can fail per shard)
- **Simplicity:** Proves clustering without over-complexity
- **Scalable:** Can easily add more shards/replicas

### Why ClickHouse Keeper vs ZooKeeper?

**Decision:** Native ClickHouse Keeper

**Rationale:**
- Lighter weight (512MB vs 2GB+ for ZooKeeper)
- C++ implementation (faster than Java-based ZooKeeper)
- Built for ClickHouse (better integration)
- Simpler operations (one less technology)

---

## Project Structure

```
stackgen-clickhouse/
├── README.md
├── .gitignore
├── terraform/
│   ├── provider.tf          # AWS provider config
│   ├── variables.tf         # Input variables
│   ├── terraform.tfvars     # Variable values
│   ├── main.tf              # EKS cluster & node pools
│   ├── storage.tf           # Storage class & namespace
│   └── outputs.tf           # Output values
├── kubernetes/
│   ├── stackgen-clickhouse.yaml  # ClickHouse deployment
│   └── stackgen-tables.yaml      # Schema initialization
└── scripts/
    └── ingest.sh            # Data ingestion script
```

---

## Cleanup

```bash
# Delete ClickHouse resources
kubectl delete -f kubernetes/

# Destroy infrastructure
cd terraform
terraform destroy
```

## Troubleshooting

### Pods Stuck in Pending
```bash
kubectl describe pod <pod-name> -n stackgen
# Check: resources, taints, PVC binding
```

### Data Not Replicating
```bash
kubectl exec -n stackgen chi-stackgen-cluster-stackgen-0-0-0 -- \
  clickhouse-client --query "SELECT * FROM system.replicas"
```

### Keeper Not Reachable
```bash
kubectl logs -n stackgen stackgen-keeper-0
kubectl get svc -n stackgen
```

---

## Resources

- [ClickHouse Documentation](https://clickhouse.com/docs)
- [Altinity Operator Docs](https://docs.altinity.com/clickhouse-operator/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

**License:** MIT  
