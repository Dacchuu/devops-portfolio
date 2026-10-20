# Quick Reference

Daily commands for the popcorn staging platform.

**Account:** `**********89` | **Region:** `us-west-1` | **Cluster:** `popcorn-staging-eks` | **Namespace:** `popcorn-staging`

---

## Kubeconfig (Run This First / When kubectl Breaks)

EKS tokens expire every ~15 minutes. Refresh with:

```bash
aws eks update-kubeconfig --region us-west-1 --name popcorn-staging-eks
```

Verify:

```bash
kubectl get nodes
```

---̌

## Daily kubectl

```bash
# Cluster health
kubectl get nodes -o custom-columns='NAME:.metadata.name,TYPE:.metadata.labels.node-type,INSTANCE:.metadata.labels.node\.kubernetes\.io/instance-type'
kubectl get pods -n popcorn-staging -o wide
kubectl get hpa -n popcorn-staging
kubectl get pods -A

# Deployments
kubectl get deployments -n popcorn-staging
kubectl rollout status deployment/popcorn-backend -n popcorn-staging
kubectl rollout status deployment/popcorn-embedding -n popcorn-staging

# Health
curl -s https://staging.popcorn.io/health

# Logs
kubectl logs -f deployment/popcorn-backend -n popcorn-staging
kubectl logs -f deployment/popcorn-embedding -n popcorn-staging

# Restart a deployment
kubectl rollout restart deployment/popcorn-backend -n popcorn-staging
kubectl rollout restart deployment/popcorn-embedding -n popcorn-staging

# Describe a pod (for crash debugging)
kubectl describe pod -l app=popcorn-backend -n popcorn-staging
```

Steady state: **1 GPU + 1 CPU**. Backend and embedding share the GPU node. Backend uploads use EFS (multi-AZ). See `docs/DAILY_OPERATIONS_CHEATSHEET.md` for weekend cost control, autoscaling, and EFS checks.
---

## Build & Push to ECR from Local

```bash
cd /Users/user-name/cloned-remote-repository/popcorn_backend

export AWS_REGION=us-west-1
export AWS_ACCOUNT_ID=**********89

./build-and-push.sh
```

ECR repos:
- `**********89.dkr.ecr.us-west-1.amazonaws.com/popcorn-shazam-backend`
- `**********89.dkr.ecr.us-west-1.amazonaws.com/popcorn-shazam-embedding`

> First build takes 15–20 min (PyTorch/CUDA layers). Re-runs are fast due to layer cache.

---

## Update Staging Image Tag (GitOps → ArgoCD)

After a build, update the tag so ArgoCD rolls it out:

```bash
cd /Users/user-name/cloned-remote-repository/popcorn-gitops

IMAGE_TAG=$(cd /Users/user-name/cloned-remote-repository/popcorn_backend && git rev-parse --short HEAD)

sed -i '' "s/newTag:.*/newTag: \"$IMAGE_TAG\"/" \
  apps/popcorn-backend/overlays/staging/kustomization.yaml
sed -i '' "s/newTag:.*/newTag: \"$IMAGE_TAG\"/" \
  apps/popcorn-embedding/overlays/staging/kustomization.yaml

git add apps/popcorn-backend/overlays/staging/kustomization.yaml \
        apps/popcorn-embedding/overlays/staging/kustomization.yaml
git commit -m "deploy(staging): backend+embedding $IMAGE_TAG"
git push
```

---

## Bastion SSH

```bash
ssh -i ~/.ssh/id_rsa ec2-user@$(cd tf/staging/vpc && terraform output -raw bastion_eip)
```

---

## Setup (One Time)

Run from [popcorn-infrastructure](https://github.com/popcornVision/popcorn-infrastructure/blob/main/README.md).

```bash
# VPC
cd environments/staging/vpc && terraform apply

# EKS
cd environments/staging/eks && terraform apply

# kubeconfig
aws eks update-kubeconfig --region us-west-1 --name popcorn-staging-eks

# Import SSH key
aws ec2 import-key-pair --region us-west-1 --key-name xyz_asign \
  --public-key-material fileb://~/.ssh/id_rsa.pub
```

---

## Add Team Member

```bash
# Get their IAM ARN
aws iam get-user --user-name <username> --query User.Arn

# Add to popcorn-infrastructure/environments/staging/eks/terraform.tfvars
admin_users = ["arn:aws:iam::**********89:user/DevOps", "arn:aws:iam::**********89:user/<new-user>"]

terraform apply
```

---

## Common Fixes

### kubectl credentials error?
```bash
aws eks update-kubeconfig --region us-west-1 --name popcorn-staging-eks
```

### Wrong AWS identity / profile?
```bash
aws sts get-caller-identity
# Should show Account: **********89, user: Admin_User
export AWS_PROFILE=default
```

### ImagePullBackOff on pods?
```bash
# Check the tag exists in ECR
aws ecr describe-images \
  --repository-name popcorn-shazam-backend \
  --region us-west-1 \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags'
```

### State lock error (staging VPC)?
```bash
aws dynamodb delete-item \
  --table-name asign-terraform-locks \
  --key '{"LockID": {"S": "asign-terraform-state-bucket/environments/staging/vpc/terraform.tfstate-md5"}}' \
  --region us-west-1
```

### State lock error (staging EKS)?
```bash
aws dynamodb delete-item \
  --table-name asign-terraform-locks \
  --key '{"LockID": {"S": "asign-terraform-state-bucket/environments/staging/eks/terraform.tfstate-md5"}}' \
  --region us-west-1
```

## Scale Staging Down / Up (Cost Saving)

Staging doesn't need to run 24/7. This parks compute (and optionally RDS) while leaving the
EKS control plane, VPC, NAT Gateways, and ALB in place — so bring-up is a few minutes, not a
full `terraform apply` rebuild.

**Order matters, and there are two autoscalers to neutralize, not one.** ArgoCD, CoreDNS,
Karpenter's own controller, *and* Cluster Autoscaler's own pod all run on the CPU floor nodes
themselves — not on a separate system tier. If you scale the floor down before capping both of
them, whichever one is still running in its last moments sees the now-Pending ArgoCD/CoreDNS
pods and just launches a replacement node to host them — you'd see the ASG at `desired: 0`
while a node quietly keeps billing you anyway. Cap Karpenter **and** pause Cluster Autoscaler
**first**, scale the floor down **second** — reverse that order coming back up.

Also: EKS managed node groups reject `maxSize=0` (AWS enforces `maxSize >= 1`) — use `maxSize=1`
for the parked state. That's harmless once Cluster Autoscaler itself is paused, since nothing
is left to act on that headroom.

### Scale down

```bash
# 1. Cap Karpenter FIRST (while its controller still has somewhere to run) —
#    edit apps/karpenter/overlays/staging/nodepool.yaml:
#      limits:
#        cpu: "0"          # was "20"
git add apps/karpenter/overlays/staging/nodepool.yaml
git commit -m "chore(staging): pause Karpenter burst capacity (cost saving)"
git push origin staging
# wait for karpenter-stg to show Synced in ArgoCD before continuing

# 2. Pause Cluster Autoscaler too — same reason, same mechanism. Edit
#    clusters/staging/apps/apps.yaml, in the cluster-autoscaler-stg Application's helm values:
#      replicaCount: 0        # was 1
git add clusters/staging/apps/apps.yaml
git commit -m "chore(staging): pause Cluster Autoscaler (cost saving)"
git push origin staging
# wait for cluster-autoscaler-stg to show Synced, and its pod gone from kube-system

# 3. Scale both managed node group floors down. maxSize=1, not 0 — AWS rejects 0.
aws eks update-nodegroup-config --cluster-name popcorn-staging-eks \
  --nodegroup-name popcorn-cpu-ng-v2 \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 --region us-west-1

aws eks update-nodegroup-config --cluster-name popcorn-staging-eks \
  --nodegroup-name popcorn-gpu-ng \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 --region us-west-1

# 4. Optional — stop RDS too (AWS auto-restarts it after 7 days if left stopped, so
#    don't park it longer than that without noticing)
aws rds stop-db-instance --db-instance-identifier staging-database --region us-west-1
```

Verify: `kubectl get nodes` should go empty within a few minutes. Everything else (ArgoCD,
CoreDNS, monitoring, backend/embedding pods) goes `Pending`/terminates along with the nodes —
expected, nothing is managing scaling anymore once both autoscalers are paused and both floors
are at 0.

### Scale up

```bash
# 1. Node group floors FIRST — this brings back the nodes that host ArgoCD, CoreDNS,
#    Karpenter's controller, and Cluster Autoscaler. Everything reschedules automatically
#    once nodes are Ready — their Deployments/DaemonSets never went away, only their pods did.
aws eks update-nodegroup-config --cluster-name popcorn-staging-eks \
  --nodegroup-name popcorn-cpu-ng-v2 \
  --scaling-config minSize=2,maxSize=6,desiredSize=2 --region us-west-1

aws eks update-nodegroup-config --cluster-name popcorn-staging-eks \
  --nodegroup-name popcorn-gpu-ng \
  --scaling-config minSize=1,maxSize=6,desiredSize=1 --region us-west-1

kubectl get nodes -w   # wait for 3 nodes Ready, then Ctrl-C

# 2. Restore Cluster Autoscaler SECOND, now that it has somewhere to run — revert
#    clusters/staging/apps/apps.yaml's cluster-autoscaler-stg helm values:
#      replicaCount: 1        # back to normal
git add clusters/staging/apps/apps.yaml
git commit -m "chore(staging): restore Cluster Autoscaler"
git push origin staging

# 3. Restore Karpenter's burst capacity — revert
#    apps/karpenter/overlays/staging/nodepool.yaml:
#      limits:
#        cpu: "20"         # back to normal
git add apps/karpenter/overlays/staging/nodepool.yaml
git commit -m "chore(staging): restore Karpenter burst capacity"
git push origin staging

# 4. If you stopped RDS, start it back up (takes a few minutes)
aws rds start-db-instance --db-instance-identifier staging-database --region us-west-1

# 4. Confirm everything's back
kubectl get applications -n argocd -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
kubectl get deploy popcorn-backend popcorn-embedding -n popcorn-staging
```

Note: the `aws eks update-nodegroup-config` calls above are a live, fast toggle — they don't go
through Terraform, so they'll show as drift if you ever run `terraform plan` on
`environments/staging/eks` while parked (the plan will propose scaling back up to the tfvars
values — that's expected, just don't `apply` it while intentionally parked). The EKS control
plane (~$0.10/hr), NAT Gateways, and ALB keep running throughout either way — those are the
fixed cost of keeping bring-up fast, not something this toggles.

### Cleanup everything
```bash
kubectl delete svc --all -A --field-selector spec.type=LoadBalancer
kubectl delete pvc --all -A
cd tf/staging/eks && terraform destroy
cd tf/staging/vpc && terraform destroy
```
