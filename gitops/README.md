# Popcorn GitOps

popcorn GitOps manages application deployments to Kubernetes using the ArgoCD App-of-Apps model.

This repository ensures:

- Automated deployments
- Environment consistency
- Version-controlled infrastructure
- Safe production releases
- GPU workload orchestration

# Step 1 – Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Access ArgoCD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Login via browser:
```
https://localhost:8080
```

---

# Step 2 – Bootstrap GitOps

Go to:

```
popcorn-gitops/bootstrap/
```

Apply root app:

```bash
kubectl apply -f root-app.yaml
```

ArgoCD will now:

- Create namespaces
- Create applications
- Deploy backend
- Deploy embedding service
- Deploy ingress
- Sync everything automatically

---

# Verify Deployment

Check applications:

```bash
kubectl get applications -n argocd
```

Check workloads:

```bash
kubectl get pods -n popcorn-staging
```

You should see:

- popcorn-backend
- popcorn-embedding
- ingress components

---

# GPU Verification

```bash
kubectl describe node | grep nvidia
```

Embedding pod should request:

```
nvidia.com/gpu: 1
```

---

# Making Changes

1. Modify manifests in **popcorn-gitops**
2. Commit & push
3. ArgoCD auto-syncs
4. Pods roll automatically

No manual kubectl deployments.

---

# Cost Control

Steady state: **1 GPU + 1 CPU**. Full weekend shutdown:

```bash
export AWS_REGION=us-west-1
export CLUSTER_NAME=popcorn-staging-eks

aws eks update-nodegroup-config --cluster-name "$CLUSTER_NAME" --nodegroup-name popcorn-gpu-ng --scaling-config minSize=0,maxSize=3,desiredSize=0 --region "$AWS_REGION"
aws eks update-nodegroup-config --cluster-name "$CLUSTER_NAME" --nodegroup-name popcorn-cpu-ng --scaling-config minSize=0,maxSize=2,desiredSize=0 --region "$AWS_REGION"
aws eks update-nodegroup-config --cluster-name "$CLUSTER_NAME" --nodegroup-name popcorn-cpu-az1-ng --scaling-config minSize=0,maxSize=1,desiredSize=0 --region "$AWS_REGION"
kubectl patch nodepool staging-general --type merge -p '{"spec":{"limits":{"cpu":"0"}}}'

aws rds stop-db-instance --db-instance-identifier staging-database --region "$AWS_REGION"
```

See `docs/DAILY_OPERATIONS_CHEATSHEET.md` §8 for Monday restore (1 GPU + 1 CPU baseline).

---

# Production Setup

Repeat infrastructure steps using:

```
tf/production/
```

Region:

```
us-east-1
```

Bootstrap using:

```
clusters/production
```

---

# Architecture Summary

```
Infrastructure (Terraform)
        │
        ▼
EKS Cluster (GPU Enabled)
        │
        ▼
ArgoCD (App-of-Apps)
        │
        ▼
Applications (Backend + Embedding)
```

---

# Common Issues

| Issue | Fix |
|-------|------|
| Pod Pending | Check GPU node group scaling |
| ImagePullBackOff | Verify ECR image exists |
| kubectl unauthorized | Add IAM ARN to admin_users |
| Argo not syncing | Check ArgoCD UI |

---

# Platform Flow Summary

1. Infrastructure provisions AWS resources
2. GitOps deploys applications
3. GPU workloads run in Kubernetes
4. ArgoCD ensures drift-free deployments
5. Scaling managed via AWS node groups

---

# You’re Ready

You now have:

- Secure AWS foundation
- GPU-enabled Kubernetes
- GitOps-managed deployments
- Automated release flow
- Scalable AI workload platform

**🚀Welcome to popcorn Platform 🚀**
