# Eicon Production (EKS) — Architecture & Setup Reference

A single reference for the new EKS-based production platform: AWS infrastructure (Terraform),
GitOps (Argo CD), the CI/CD pipeline, and every real bug found and fixed while standing it up.

*Last consolidated: 2026-10-12.*

**Status: validating on `test.eicon.io`.** The live, real-traffic system today is still the
original **EC2 + Docker** deployment on `api.eicon.io`. This EKS platform runs **alongside** it,
in the same AWS account and region, sharing the same RDS/S3/Qdrant data, so it can be proven out
end-to-end before any DNS cutover. See [§10](#10-production-cutover-ec2--eks) for the cutover
plan — nothing in this document implies the cutover has happened.

---

## Table of contents

1. [Quick reference](#1-quick-reference)
2. [Network layer](#2-network-layer)
3. [EKS cluster & compute](#3-eks-cluster--compute)
4. [Storage](#4-storage)
5. [Secrets & IRSA](#5-secrets--irsa)
6. [Application layer](#6-application-layer)
7. [Ingress & DNS](#7-ingress--dns)
8. [GitOps structure (Argo CD)](#8-gitops-structure-argo-cd)
9. [CI/CD pipeline](#9-cicd-pipeline)
10. [Production cutover (EC2 → EKS)](#10-production-cutover-ec2--eks)
11. [Monitoring](#11-monitoring)
12. [Access management](#12-access-management)
13. [Build history — real bugs found and fixed](#13-build-history--real-bugs-found-and-fixed)
14. [Known gaps / not yet done](#14-known-gaps--not-yet-done)

---

## 1. Quick reference

| Item | Value |
|---|---|
| AWS account | `491085416489` |
| Region | `us-east-1` |
| EKS cluster | `eicon-production-eks` (v1.35, `API_AND_CONFIG_MAP` auth mode) |
| VPC | `vpc-020343d82749251ef` (`eicon-production-vpc`, CIDR `10.60.0.0/16`) |
| App endpoint (validation) | `https://test.eicon.io` |
| App endpoint (live, pre-cutover) | `https://api.eicon.io` (EC2 + Docker, unaffected by any of this) |
| Argo CD UI | `https://production-argocd.eicon.io` |
| Grafana | `https://k8s.grafana.eicon.io` |
| GitOps repo / branch | `eicon-gitops` / `production` |
| App repo | `eicon-backend` (`eicon_backend`) |
| Namespace | `eicon-production` |
| Shared secret | AWS Secrets Manager `eicon/backend/credentials` (us-east-1) — same secret the EC2 production app uses |

```bash
aws eks update-kubeconfig --name eicon-production-eks --region us-east-1
kubectl get applications -n argocd -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

---

## 2. Network layer

- **VPC**: `eicon-production-vpc` (`10.60.0.0/16`) — deliberately a different CIDR from the
  pre-existing EC2/RDS default VPC (`vpc-0fc2a8af2414a1386`, `172.31.0.0/16`) to avoid collision.
  - Public subnets: `10.60.10.0/24` (us-east-1a), `10.60.11.0/24` (us-east-1b)
  - Private subnets: `10.60.20.0/24` (us-east-1a), `10.60.21.0/24` (us-east-1b)
- **VPC peering** (`pcx-009ffb3385f8df54b`) connects this VPC to the EC2/RDS default VPC —
  required because this platform reuses the *same* production RDS instance and isn't a separate
  copy of the data. A security-group allow-list rule alone is not sufficient without this; routes
  were added on both sides of the peering connection.
- **DNS resolution over the peering connection** (`AllowDnsResolutionFromRemoteVpc`) is enabled
  on **both** sides. The RDS instance (`database-1`, `sg-03118bbac1d16fe79`) is
  `PubliclyAccessible: true`; without this setting, pods resolved the RDS hostname to its
  *public* IP and routed through NAT instead of the peering connection, where the security group
  silently dropped the traffic — indistinguishable from "no route" without checking DNS
  resolution specifically. See [§13](#13-build-history--real-bugs-found-and-fixed).
- No NAT-only pattern was used for RDS reachability (unlike how staging reaches Qdrant Cloud) —
  peering was required here because the RDS endpoint and security group belong to a different VPC
  entirely, not just a different region.

---

## 3. EKS cluster & compute

Two distinct compute tiers, each with a different scaling story — do not conflate them.

### 3.1 System node group (Terraform-managed, static floor)

| | |
|---|---|
| Name | `eicon-production-system-ng` |
| Instance type | `t3.medium` |
| Min / Desired / Max | 2 / 2 / 3 |
| Labels | `node-type: system` |

Hosts CoreDNS, Karpenter's own controller, Argo CD, External Secrets, the AWS Load Balancer
Controller, and the EBS/EFS CSI controllers — i.e. the platform control plane, not application
workload. **Deliberately not Karpenter-managed**: if Karpenter's own controller pod needed a
Karpenter-provisioned node to run on, and no node existed yet for it to provision from, that's a
deadlock. This floor is also **not a cost-saving target** — combined memory usage of what runs on
it already exceeds one `t3.medium`'s capacity, so merging to a single larger node costs about the
same as keeping two small ones, with less resilience.

### 3.2 Karpenter (workload capacity — the only autoscaler for application pods)

Two `NodePool`s (`apps/karpenter/overlays/production/`), both `WhenEmptyOrUnderutilized`
consolidation after 60s idle:

| NodePool | Instance family/size | Capacity type | CPU limit | Taint | Hosts |
|---|---|---|---|---|---|
| `production-general` | `m6i.large`/`xlarge` | on-demand | 40 | — | `eicon-backend` |
| `production-gpu` | `g4dn.xlarge` | on-demand | 16 | `nvidia.com/gpu=present:NoSchedule` | `eicon-embedding` |

**Deliberately Karpenter-only for workload capacity** — no second autoscaler (e.g. Cluster
Autoscaler) runs alongside it here. Staging's documented Karpenter-vs-Cluster-Autoscaler race
condition (see `docs/PLATFORM_ARCHITECTURE.md` §8 in this same repo) was a direct input to this
decision: two autoscalers reacting to the same pending-pod signal caused stranded nodes on
staging. Production sidesteps that entirely by not having a second one.

Both NodePools reference an `EC2NodeClass` of the same name — AL2023, `karpenter.sh/discovery:
eicon-production-eks` tag-based subnet/SG selection, gp3 root volume (20Gi general / 40Gi GPU).
The GPU `EC2NodeClass` pins the NVIDIA-optimized AMI via SSM parameter
(`/aws/service/eks/optimized-ami/1.35/amazon-linux-2023/x86_64/nvidia/recommended/image_id`).

**GPU nodes need the NVIDIA device plugin installed separately** — Karpenter provisioning a
`g4dn.xlarge` node does not by itself make `nvidia.com/gpu` schedulable; the device plugin
DaemonSet advertises the resource. Applied directly (not yet GitOps-managed):
`nvidia-device-plugin-daemonset` v0.17.4, mirroring staging's exact manifest.

**`metrics-server`** (v0.8.1, upstream manifest) is required for HPA to have real CPU/memory
targets — without it, HPAs report `<unknown>` and Argo CD's built-in health check flags the
Application `Degraded` even though the Deployment itself is healthy. Installed directly, not yet
GitOps-managed.

### 3.3 Live node snapshot (at time of writing)

```
2x t3.medium    (system floor)
2x m6i.large    (production-general, Karpenter)
1x g4dn.xlarge  (production-gpu, Karpenter)
```

---

## 4. Storage

| StorageClass | Provisioner | Reclaim | Binding |
|---|---|---|---|
| `efs-backend-uploads` | `efs.csi.aws.com` | Retain | Immediate |
| `gp2` | `kubernetes.io/aws-ebs` | Delete | WaitForFirstConsumer |

- **EFS CSI driver** is an EKS addon (`aws-efs-csi-driver`), not installed by default — had to be
  added explicitly via `aws eks create-addon`, with its own IRSA role
  (`AmazonEKS_EFS_CSI_DriverRole-production`) bound to the `efs-csi-controller-sa` service account.
- `eicon-backend`'s EFS PVC (`backend-uploads-efs`) uses RWX access for shared upload storage
  across backend replicas, same pattern as staging.
- `StorageClass.parameters` (e.g. `fileSystemId`) are **immutable** on an existing object — fixing
  a wrong value requires `kubectl delete storageclass` and letting Argo CD recreate it from
  corrected git content, not `kubectl apply`.

---

## 5. Secrets & IRSA

**Deliberate decision**: production EKS reuses the *same* Secrets Manager secret the EC2
production app already uses — `eicon/backend/credentials` (us-east-1) — rather than creating a
parallel `eicon/production/backend/credentials`. Both `eicon-backend` and `eicon-embedding`
External Secrets point at this one secret.

```bash
kubectl get externalsecret -n eicon-production
# backend-secrets, embedding-secrets — both ClusterSecretStore aws-secretsmanager, refresh 1h
```

**Consequence worth knowing**: this secret was written for an EC2 instance, which gets AWS
credentials from its instance profile — it has **no static `AWS_ACCESS_KEY_ID`/`SECRET_ACCESS_KEY`**
pair in it. Pods, unlike EC2, need an explicit identity. Solved with IRSA, not by adding static
keys to the shared secret:

| Role | Bound to | Purpose |
|---|---|---|
| `eicon-production-backend-irsa-role` | `eicon-production` namespace's `default` ServiceAccount | S3 (uploads/thumbnails/query images/models), SQS (`eicon-s3-upload-worker`), CloudWatch log streams + `PutMetricData` (scoped to `Eicon/S3Upload` namespace condition) |
| `AmazonEKS_EFS_CSI_DriverRole-production` | `efs-csi-controller-sa` | EFS provisioning |
| `eicon-production-loki-s3` / `eicon-production-prometheus-s3` | Loki / Prometheus (Thanos) service accounts | S3 object storage for logs/metrics |

**IRSA ordering trap** (bit us more than once during this build): if a ServiceAccount is created
by a Helm chart/addon *before* `eksctl create iamserviceaccount --override-existing-serviceaccounts`
annotates it, the already-running pod keeps its old (missing) token mounted. A pod restart after
annotating is required — `eksctl` updating the SA alone does not propagate to running pods.

---

## 6. Application layer

### 6.1 `eicon-backend`

| | |
|---|---|
| Replicas | HPA `minReplicas: 2`, `maxReplicas: 20` @ 75% CPU/mem (scale-up: 100%/60s, no stabilization delay; scale-down: 50%/60s after 300s) |
| Resources | requests 700m CPU / 2Gi, limits 2 CPU / 6Gi |
| Placement | soft affinity (weight 100) toward `node-type: cpu` — not a hard requirement, so Karpenter can still burst elsewhere under real overflow |
| PDB | present (`pdb.yaml`) |
| Storage | EFS RWX PVC, same pattern as staging |
| Config | RDS host (`database-1.cslwsecwut6c.us-east-1.rds.amazonaws.com`), Qdrant Cloud URL, S3 buckets — same buckets EC2 production already uses, not separate test buckets |
| Image | ECR `us-east-1`, repo `eicon-shazam-backend`, tag tracked per deploy (currently `a5d97aa`) |

### 6.2 `eicon-embedding`

| | |
|---|---|
| Replicas | HPA `minReplicas: 1`, `maxReplicas: 5` @ 75% CPU |
| Placement | soft affinity toward `node-type: gpu`; toleration for `nvidia.com/gpu=present:NoSchedule` |
| Image | ECR `us-east-1`, repo `eicon-shazam-embedding`, same tag as backend per deploy |
| Startup note | the DINOv2 model weights (~346MB) and repo are downloaded at container start, not baked into the image — cold start can take several minutes. Startup probe budget is `initialDelaySeconds:10, periodSeconds:10, timeoutSeconds:10, failureThreshold:30` (~310s max) — tight; a slow cold start has come close to exhausting it and shown as a transient Argo CD "Degraded" that self-resolves once the model finishes loading. Not yet fixed (e.g. baking the model into the image) — flagged, not actioned. |

Both Deployments source `DB_HOST`/`QDRANT_URL`/S3 bucket names etc. via `configMapGenerator` in
their production kustomize overlay — **these are now the real values** (RDS endpoint, Qdrant
Cloud URL), not placeholders.

---

## 7. Ingress & DNS

Each app gets its **own** ALB (via `alb.ingress.kubernetes.io/group.name`), not a shared one —
matches how this was done for every domain added during this build:

| Ingress | Namespace | Host | ALB group | ACM cert | Healthcheck path |
|---|---|---|---|---|---|
| `eicon-ingress` | `eicon-production` | `test.eicon.io` | `eicon-production` | `524f1ab6-...` | `/health` |
| `argocd-ingress` | `argocd` | `production-argocd.eicon.io` | `argocd-production` | `10ddfb98-...` | `/healthz` |
| `prometheus-grafana` | `monitoring` | `k8s.grafana.eicon.io` | `grafana-production` | `46331cae-...` | `/api/health` |

**Healthcheck path matters and is not the same across apps** — this bit us once already:
ArgoCD's ingress was initially set to `/health` (copied from the backend convention) but
argocd-server's real endpoint is `/healthz`, causing the ALB to mark the target `Unhealthy`
(`ResponseCodeMismatch`, 404) and produce intermittent `ERR_TIMED_OUT`. Always verify the app's
actual health endpoint rather than copying the last ingress's annotation.

**Argo CD also required** `argocd-cmd-params-cm`'s `server.insecure: "true"` — without it,
argocd-server 307-redirects HTTP→HTTPS, which the ALB's HTTP-only health check sees as a
non-200 and marks unhealthy. Staging already had this set; production initially didn't.

Grafana's ingress is the one exception to the "pure GitOps" pattern below — it's defined as a
native `ingress:` block in the kube-prometheus-stack Helm values (Terraform-managed), not a
Kustomize `Ingress` resource, because Grafana itself is Terraform/Helm-installed, not an Argo CD
Application. See `eicon-infrastructure/modules/monitoring/main.tf` (`grafana_ingress_*` variables).

---

## 8. GitOps structure (Argo CD)

App-of-apps pattern, root Application `eicon-root-production` pointing at
`clusters/production` on the `production` branch of this repo (`eicon-gitops`).

```
apps/
  eicon-backend/overlays/production/    → eicon-backend-prod   (ns: eicon-production)
  eicon-embedding/overlays/production/  → eicon-embedding-prod (ns: eicon-production)
  eicon-ingress/overlays/production/    → eicon-ingress-prod   (ns: eicon-production)
  argocd/overlays/production/           → argocd-ingress-prod  (ns: argocd)
  karpenter/overlays/production/        → karpenter-prod       (ns: karpenter)
```

All `syncPolicy.automated: { prune: true, selfHeal: true }`. `eicon-backend-prod` and
`eicon-embedding-prod` both `ignoreDifferences` on `/spec/replicas` so the HPA can own replica
count without Argo CD fighting it back to the kustomize-declared count on every sync.

**Not yet GitOps-managed** (installed directly via `kubectl`/`eksctl`, no git source of truth
yet): NVIDIA device plugin, `metrics-server`, EFS CSI driver addon config, `aws-auth` ConfigMap
entries. These are candidates for a future `apps/` entry if this becomes an ongoing maintenance
burden, but weren't blocking and weren't requested.

---

## 9. CI/CD pipeline

`eicon-backend` repo, `.github/workflows/production-cd-deploy.yml` — triggers on push to `main`
or manual `workflow_dispatch`. **Deliberately mirrors staging's workflow exactly**, by explicit
choice, rather than introducing a different pattern for production:

1. Builds backend + embedding images, pushes `:latest`/`:latest-amd64` to the existing us-east-1
   ECR repos (`eicon-shazam-backend`, `eicon-shazam-embedding`) — the same repos/tags EC2
   production already uses.
2. Additionally tags and pushes a commit-SHA tag (e.g. `a5d97aa`) for GitOps traceability, since
   `:latest` by itself can't be pinned in a kustomize overlay meaningfully.
3. Prints manual next-step instructions. **It does not auto-commit to `eicon-gitops`** — by
   explicit choice, to mirror staging's manual-update contract exactly.

The actual deploy (updating `newTag` in both overlay `kustomization.yaml` files, committing,
pushing to `production`, forcing an Argo CD refresh, watching rollout status) is a manual runbook
the user runs themselves — same shape as the existing staging runbook. **Claude does not run
`git commit`/`push` on the user's behalf for this step** without explicit authorization each time
— commands are handed over instead.

A real CI bug was found and fixed here: `build-and-push.sh`'s `backup_image()` always pulled the
previous `:latest-amd64` image before building, regardless of the `SKIP_BACKUP` env var both
staging's and production's workflows set — the script never actually read that variable. This
caused the first production CI run to fail with "no space left on device" partway through the
embedding image build. Fixed with an explicit `SKIP_BACKUP=true` early-return guard; confirmed
backward-compatible with EC2 production, which doesn't set the flag at all.

---

## 10. Production cutover (EC2 → EKS)

Not yet scheduled. Because this platform already shares the same RDS/S3/Qdrant with EC2
production, **the cutover is a traffic switch, not a data migration**:

1. Pre-cutover: confirm real load-test results, fix the `DB_HOST`/`QDRANT_URL` placeholders (now
   done — see §6), decide how the `eicon-s3-upload-worker` SQS consumer behaves with both EC2 and
   EKS potentially running it briefly during the switch (idempotency vs. draining EC2's worker first).
2. Issue an `api.eicon.io` ACM cert, add an ingress host rule, smoke-test via `/etc/hosts` before
   touching real DNS.
3. Lower `api.eicon.io`'s DNS TTL in advance, then flip the Squarespace record to the EKS ALB.
4. Soak with EC2 kept warm as an instant rollback for a few days.
5. Decommission EC2 only after the soak period is clean.

This is a distinct, high-risk, explicit-confirmation-required action — never treat "production
EKS setup is done" as implying the cutover should happen.

---

## 11. Monitoring

`kube-prometheus-stack` (Prometheus, Grafana, Alertmanager) + `loki-stack`, all Terraform/Helm
managed (`eicon-infrastructure/modules/monitoring`), **not** Argo CD-managed — this is the one
major piece of the platform installed outside the GitOps flow.

| Component | Storage | Exposure |
|---|---|---|
| Prometheus | `emptyDir` (ephemeral, retention 7d) | ClusterIP only |
| Grafana | no persistence (`persistence.enabled: false`) | ALB Ingress, `https://k8s.grafana.eicon.io` |
| Loki | S3 (via `eicon-production-loki-s3` IRSA role) | ClusterIP only |
| `dcgm-exporter` | — | GPU metrics, ServiceMonitor |

Grafana was originally exposed as a bare `LoadBalancer` Service (a Classic ELB, HTTP-only, no
custom domain). Converted 2026-10-12 to `ClusterIP` + ALB Ingress with its own ACM cert, to get a
stable hostname and TLS, consistent with how every other domain on this platform is set up. The
old Classic ELB was torn down as part of that change. Grafana admin credentials live in the
`grafana-credentials` K8s Secret (`monitoring` namespace), sourced from Terraform variables, not
from the shared `eicon/backend/credentials` secret.

---

## 12. Access management

EKS Access Entries (`authenticationMode: API_AND_CONFIG_MAP`) are the mechanism for **human** IAM
users — the `aws-auth` ConfigMap (`mapRoles`) is used only for **node** IAM roles (e.g.
`KarpenterNodeRole-eicon-production-eks`), matching staging's convention exactly.

```bash
aws eks create-access-entry --cluster-name eicon-production-eks --region us-east-1 \
  --principal-arn arn:aws:iam::491085416489:user/<username>

aws eks associate-access-policy --cluster-name eicon-production-eks --region us-east-1 \
  --principal-arn arn:aws:iam::491085416489:user/<username> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

Existing team convention (IAM groups, not cluster-specific): `dev` group (ECR push/pull +
`eks:DescribeCluster`/`ListClusters`/`AccessKubernetesApi`) vs. `DevOps` group (`eks:*` +
`AdministratorAccess`). New team members already in `DevOps` get full
`AmazonEKSClusterAdminPolicy` on both staging and production — matches staging's existing
precedent, not a new policy decision made for this platform.

---

## 13. Build history — real bugs found and fixed

In the order they were hit during the build (full detail in
`eicon-infrastructure/docs/PRODUCTION_MIGRATION_PLAN.md`):

1. **Karpenter nodes never joined the cluster** — `aws-auth` was missing the
   `KarpenterNodeRole` mapping. Fixed by adding the `mapRoles` entry, mirroring staging.
2. **EFS PVC stuck `Pending`** — two causes: the EFS CSI driver addon was never installed, and
   once it was, a stuck placeholder `fileSystemId` in the live `StorageClass` was immutable and
   had to be deleted (not patched) to pick up the corrected value.
3. **GPU pod stuck `Pending`, "Insufficient nvidia.com/gpu"** — the NVIDIA device plugin was
   never installed after the first GPU node appeared; a planned step got deferred and no one
   circled back. Fixed by applying staging's exact DaemonSet manifest.
4. **Backend/embedding pods crash-looping with `CredentialsProviderError`** — the reused EC2
   secret has no static AWS keys (EC2 uses its instance profile). Fixed via IRSA, not by adding
   static keys to the shared secret (see [§5](#5-secrets--irsa)).
5. **RDS connection timeouts despite a correct security-group rule** — root cause was two layers
   deep: no VPC peering existed at all initially (fixed), then DNS cross-VPC resolution returned
   RDS's public IP instead of routing over the peering connection (fixed via
   `AllowDnsResolutionFromRemoteVpc`). See [§2](#2-network-layer).
6. **Argo CD Applications stuck `Degraded` despite healthy Deployments** — `metrics-server` was
   missing entirely, so HPAs reported `<unknown>` targets, which Argo CD's health check flags as
   Degraded. Fixed by installing `metrics-server`.
7. **CloudWatch `AccessDenied` spam in backend logs** — the backend IRSA policy had log-stream
   permissions but not `cloudwatch:PutMetricData`. Fixed with an additional scoped policy
   statement.
8. **Argo CD ingress intermittent `ERR_TIMED_OUT`** — wrong healthcheck path (`/health` instead
   of `/healthz`) plus missing `server.insecure: "true"`. See [§7](#7-ingress--dns).
9. **CI build failure, "no space left on device"** — `SKIP_BACKUP` was silently ignored by
   `build-and-push.sh`. See [§9](#9-cicd-pipeline).
10. **Local DNS caching** blocked browser access to `test.eicon.io` after the ingress was already
    healthy — not a platform bug, but cost real debugging time; fixed by flushing the client's
    local DNS cache / switching DNS servers.

---

## 14. Known gaps / not yet done

- **Load testing**: agreed approach was an "infra-only sanity ramp" (500→3,000 synthetic users
  against `test.eicon.io`) before any real cutover decision — not yet executed.
- **Qdrant connection-pooling bug**: a known staging app-level bug, confirmed still present on
  `eicon-backend`'s `main` branch as of this writing. Relevant to production capacity testing,
  not yet fixed.
- **Write-path functional testing** (`/identify`, signup/login) against `test.eicon.io` has been
  deliberately out of scope so far — read-only validation only, since `test.eicon.io` shares real
  production data.
- **Staging has the identical ALB healthcheck-path and CI `SKIP_BACKUP`-adjacent bugs** — flagged
  during this build, not backported to staging since there was no explicit request to fix them
  there and staging "works" currently regardless.
- **NVIDIA device plugin, `metrics-server`, EFS CSI addon config, and `aws-auth` entries** are
  live-cluster changes without a GitOps/Terraform source of truth yet (see [§8](#8-gitops-structure-argo-cd)).
- **Embedding cold-start margin is tight** (~310s probe budget against a model download that has
  come close to it) — not yet fixed (e.g. baking the model into the image).
