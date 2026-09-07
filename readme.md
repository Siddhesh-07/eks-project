# EKS Microservices with GitOps & Automated CI/CD

A complete end-to-end DevOps project deploying a multi-service microservices application on AWS EKS using Terraform infrastructure-as-code, GitHub Actions CI/CD with intelligent change detection, and Argo CD GitOps for declarative deployments.

## 🎯 Core Concept

This project demonstrates how **code changes flow automatically from GitHub → ECR → EKS** through GitOps, with zero-downtime deployments and complete infrastructure automation.

```
                 ┌──────────────────┐
                 │    Developer     │
                 │   git push       │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │     GitHub       │ ◄─ Desired state
                 │  (source + gitops│    stored in git
                 │   manifests)     │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │ GitHub Actions   │
                 │                  │
                 │ • Detect changes │ ← Only rebuild changed services
                 │ • Build Docker   │
                 │ • Push to ECR    │
                 │ • Update git     │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │      AWS ECR     │ ◄─ Image: frontend:abc1234
                 │   Image Registry │    (commit SHA tag)
                 └──────────────────┘
                          │
                   GitHub Actions commits
                   new image tags to git
                          │
                          ▼
                 ┌──────────────────┐
                 │    GitHub git    │ ◄─ Kustomize updated:
                 │   Kustomize      │    frontend: *:abc1234
                 │   Tags Updated   │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │     Argo CD      │ ◄─ Watches git repo
                 │                  │    for state changes
                 │ • Detects change │
                 │ • Reconciles EKS │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │       EKS        │
                 │                  │
                 │ • Pull new image │
                 │ • Replace pods   │
                 │ • HPA manages    │
                 └────────┬─────────┘
                          │
                    ┌─────┴──────┐
                    │            │
                    ▼            ▼
               Frontend      Microservices
                    │            │
                    ▼            ▼
                 AWS ALB    ElastiCache Redis
                    │            (State)
                    ▼
                Internet
                 (Users)
```

---

## 🏗️ Architecture at a Glance

### Microservices Deployment

```
                    EKS Cluster
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
      Frontend       Microservices      Monitoring
     (HTTP 8080)     (gRPC ports)       (Prometheus
                                         Grafana)
        │
        │ Kubernetes ClusterIP
        ▼
      AWS ALB
        │
        ▼
    Internet
    (Users)


Microservices (10 services):
├── adservice (9555)
├── cartservice (7070) ──→ Redis (ElastiCache)
├── checkoutservice (5050)
├── currencyservice (7000)
├── emailservice (5000)
├── frontend (8080)
├── paymentservice (50051)
├── productcatalogservice (3550)
├── recommendationservice (8080)
└── shippingservice (50051)
```

### Infrastructure Overview

```
AWS Account (us-east-1)
│
├─ VPC (10.0.0.0/16)
│  ├─ Public Subnets → Internet Gateway
│  │  └─ NAT Gateway (single, cost-optimized)
│  │
│  └─ Private Subnets → NAT Gateway (egress only)
│     └─ EKS Nodes + Pods (secure, isolated)
│
├─ EKS Cluster (Kubernetes 1.36)
│  ├─ Control Plane (managed by AWS)
│  ├─ Node Group: 2× c7i-flex.large (ON_DEMAND)
│  └─ Add-ons: VPC-CNI, CoreDNS, kube-proxy
│
├─ ECR (10 repositories)
│  └─ online-boutique/{service-name}
│
├─ ElastiCache Redis
│  └─ Single node (at-rest encrypted)
│
└─ IAM + OIDC
   ├─ EKS OIDC Provider (pod → AWS permissions)
   └─ GitHub Actions OIDC (CI/CD → AWS ECR)
```

---

## 🔐 Security: No Static Credentials

### GitHub Actions → AWS (OIDC Federation)

```
GitHub Actions Workflow
         │
         │ Request OIDC token
         ▼
   GitHub OIDC Provider
         │
         │ Signed JWT token
         ▼
   AWS STS AssumeRole
         │
         │ Temporary credentials (1 hour)
         ▼
   AWS IAM Role: project-eks-github-actions-ecr
         │
         │ Permissions: ECR push/pull
         ▼
   Amazon ECR
```

**Why this matters:**
- ✅ No AWS access keys in GitHub secrets
- ✅ Temporary credentials (automatic expiration)
- ✅ Scoped to repo + main branch only
- ✅ Revocable without credential rotation

### Kubernetes → AWS (IRSA + EKS OIDC)

```
AWS Load Balancer Controller Pod
         │
         ▼
Kubernetes ServiceAccount
         │
         ▼
EKS OIDC Provider (exchanged via Webhook)
         │
         ▼
AWS IAM Role: ALBControllerRole
         │
         ▼
AWS ALB APIs
```

**Why this matters:**
- ✅ No IAM keys inside containers
- ✅ Automatic credential rotation
- ✅ Principle of least privilege (specific role per service)

---

## 🚀 CI/CD: Smart Change Detection

### The Problem (First Version)
```
Developer changes src/cartservice/
         │
         ▼
Build ALL 10 Docker images ❌
Push ALL 10 to ECR
         │
         ▼
Waste time + cost
```

### The Solution (Current)
```
Developer changes src/cartservice/
         │
         ▼
GitHub Actions detects changed files
         │
         ├─ cartservice changed ✅
         ├─ frontend NOT changed ✗
         ├─ checkout NOT changed ✗
         └─ etc.
         │
         ▼
Build ONLY cartservice
Push ONLY cartservice:abc1234 to ECR
         │
         ▼
Update kustomization.yaml with new tag
Commit + push to GitHub
         │
         ▼
Argo CD detects Git change
         │
         ▼
EKS rolls out new cartservice pods
```

**Efficiency:**
- Only changed services rebuilt
- Parallel matrix builds (if 3 services changed, all build at once)
- Commit hash tags (abc1234) make deployments reproducible & traceable

---

## 📦 Data Persistence: Why ElastiCache Over Pod Redis?

### What We Chose
```
cartservice Pod
        │
        ▼ gRPC calls
ElastiCache Redis
   (AWS managed)
        │
        ├─ Persistent (survives pod deletion)
        ├─ Backed up automatically
        ├─ Single-click failover ready
        ├─ No pod overhead
        └─ Monitoring included
```

### What We Avoided
```
Redis running as Kubernetes Pod ❌
        │
        ├─ Loses data if pod deleted
        ├─ Requires manual backup setup
        ├─ Requires manual failover
        ├─ Consumes cluster resources
        └─ Multiple failure modes
```

**Test Flow:**
```
1. Add item to cart
   → cartservice calls Redis
   → HSET cart-id:123 item-sku qty
   → Redis persists data

2. Refresh browser
   → Cart still has items ✓

3. Checkout
   → Redis cleared
   → HDEL cart-id:123
   → Verified via CLI: HGETALL returns empty
```

---

## 🎯 The GitOps Loop (Most Important Concept)

This is the critical innovation of the project. Here's the story:

### The Question
> GitHub Actions pushes images to ECR, but how does Argo CD know which image to deploy?

### The Answer
**GitHub Actions updates the Kubernetes GitOps manifest and commits it back to GitHub.**

### The Flow

**Step 1: Developer pushes code**
```bash
git push origin main
# Changed: src/cartservice/main.go
```

**Step 2: GitHub Actions builds & pushes**
```
Detect: cartservice changed
Build: docker build -t ECR/cartservice:abc1234 .
Push: docker push ECR/cartservice:abc1234
```

**Step 3: GitHub Actions updates Kustomize**
```yaml
# kubernetes-manifests/kustomization.yaml

images:
  - name: cartservice
    newName: 317990169591.dkr.ecr.us-east-1.amazonaws.com/online-boutique/cartservice
    newTag: abc1234  ◄─ Changed from old tag
```

**Step 4: GitHub Actions commits back to git**
```bash
git add kubernetes-manifests/kustomization.yaml
git commit -m "chore(gitops): update tags for modified services to abc1234"
git push origin main
```

**Step 5: Argo CD detects Git change**
```
Argo CD watches: kubernetes-manifests/ on main branch
Detects: kustomization.yaml changed
Compares: desired state (git) vs actual state (EKS)
```

**Step 6: Argo CD syncs to EKS**
```
Kustomize renders manifests with new tag
Kubectl applies new Deployment
Kubernetes pulls cartservice:abc1234 from ECR
Terminates old cartservice pods (5s grace period)
Starts new cartservice pods
HPA continues managing replicas (2-5 range)
```

**Step 7: Service discovery updates**
```
CoreDNS updates cartservice DNS record
Points to NEW pod IPs
Frontend pods seamlessly route to new cartservice
Zero downtime ✓
```

---

## 🛠️ Terraform Infrastructure as Code

### Project Structure
```
eks-project/
├── src/                          # Application source code (10 services)
│   ├── adservice/
│   ├── cartservice/
│   ├── checkoutservice/
│   └── ... (7 more services)
│
├── kubernetes-manifests/          # Kubernetes YAML + Kustomize
│   ├── kustomization.yaml        # Image tags & overlays
│   ├── adservice.yaml
│   ├── cartservice.yaml          # Frontend: 2-4 replicas (HPA)
│   ├── frontend.yaml             # Cartservice: 2-5 replicas (HPA)
│   └── ... (other services)
│
├── terraform/                     # Infrastructure as Code
│   ├── provider.tf               # AWS provider config
│   ├── vpc.tf                    # VPC + subnets + NAT
│   ├── eks.tf                    # EKS cluster
│   ├── nodegrp.tf                # Node group (2 nodes)
│   ├── iam.tf                    # IAM roles (cluster, nodes, OIDC)
│   ├── ecr.tf                    # 10 ECR repositories
│   ├── elasticache.tf            # Redis cluster
│   ├── alb-controller.tf         # IRSA setup
│   ├── argocd.tf                 # Argo CD Helm deployment
│   ├── github-actions.tf         # GitHub OIDC + IAM role
│   ├── monitoring.tf             # Prometheus + Grafana
│   └── outputs.tf                # Cluster info outputs
│
└── .github/
    └── workflows/
        └── build-push-ecr.yml    # CI/CD pipeline
```

### Terraform Highlights

| Component | File | Key Features |
|-----------|------|--------------|
| **VPC** | vpc.tf | Public + private subnets, single NAT Gateway (cost-optimized) |
| **EKS** | eks.tf + nodegrp.tf | K8s 1.36, 2× c7i-flex.large, public API endpoint |
| **Security** | iam.tf | OIDC providers, IRSA roles, no static keys |
| **Container Registry** | ecr.tf | 10 repos, image scan on push, AES256 encryption |
| **State Store** | elasticache.tf | Single-node Redis, at-rest encrypted, 6379 from VPC |
| **Ingress** | alb-controller.tf | AWS Load Balancer Controller via Terraform module |
| **GitOps** | argocd.tf | Helm deployment, watches kubernetes-manifests/, auto-sync |
| **Monitoring** | monitoring.tf | kube-prometheus-stack, Grafana + Prometheus |

---

## 🚧 Challenges Faced & Solutions

### Challenge 1: Insufficient CPU (Initial Cluster)
```
Symptom:
pod pending: "Insufficient cpu"

Root Cause:
10 microservices + Prometheus + Grafana + ArgoCD
couldn't fit on 1 node

Solution:
Added 2nd worker node
→ Now 2× c7i-flex.large (4 vCPU each)
→ All pods scheduled successfully
```

### Challenge 2: Metrics Server Missing (HPA Failing)
```
Symptom:
HPA showing: FailedGetResourceMetric
pods.metrics.k8s.io not available

Root Cause:
Metrics Server not installed (required for HPA to read CPU)

Solution:
Terraform eks-addons.tf auto-installs metrics-server
→ HPA now reads CPU metrics
→ Frontend scales 2-4 pods, cartservice scales 2-5 pods
```

### Challenge 3: Building All 10 Services Every Push
```
Symptom:
Change 1 file in frontend → build 10 Docker images
Takes ~15 minutes, wastes resources

Root Cause:
Initial GitHub Actions workflow too simple

Solution:
Implemented change detection:
• tj-actions/changed-files@v44 detects which services changed
• Creates dynamic matrix for parallel builds
• Only changed services rebuilt
• Result: Typical build now 2-3 minutes for 1-2 services
```

### Challenge 4: How Does Argo CD Know New Image Version?
```
Symptom:
GitHub Actions pushes image to ECR
But Argo CD keeps showing old deployment
Why doesn't it auto-update?

Root Cause:
Git manifests still reference old image tag
Argo CD syncs desired state from git, not ECR

Solution:
GitHub Actions also updates git manifest:
1. Build image: frontend:abc1234
2. Push to ECR
3. Update kustomization.yaml: newTag: abc1234
4. Commit + push to git
5. Argo CD sees git change → syncs new tag → pulls new image
```

### Challenge 5: OIDC Trust Policy Scope
```
Symptom:
GitHub Actions OIDC works but too permissive
Any repository could potentially assume role

Root Cause:
Trust policy not restricted

Solution:
Restricted to specific repository + branch:
"Siddhesh-07/eks-project" + "refs/heads/main"
→ Only this repo on main branch can assume role
```

### Challenge 6: Pod Security (Running as Root)
```
Symptom:
Pods have unnecessary Linux capabilities
Security violation

Solution:
Applied SecurityContext to all pods:
• runAsNonRoot: true (UID 1000)
• readOnlyRootFilesystem: true
• capabilities: drop ALL
• No privileged containers
```

### Challenge 7: Monitoring Status vs Application Health
```
Symptom:
Argo CD shows: "Degraded" status
But application works fine!

Root Cause:
HPA in "Degraded" due to missing Metrics Server
(Not actual application failure)

Solution:
Installed Metrics Server add-on
→ HPA became "Synced"
→ Application health confirmed via logs + Grafana
```

---

## 📊 Monitoring & Observability

### What We Monitor

```
EKS Cluster
     │
     ├─ Pod Metrics
     │  ├─ CPU utilization (per pod)
     │  └─ Memory usage (per pod)
     │
     ├─ Node Metrics
     │  ├─ CPU + Memory
     │  ├─ Network I/O
     │  └─ Disk usage
     │
     └─ Kubernetes Objects
        ├─ Deployment replicas
        ├─ Pod state
        └─ Resource requests/limits
        
        ▼
        
Prometheus
• Scrapes metrics every 15s
• 7-day retention
• Time-series database

        ▼
        
Grafana
• Dashboards
• Pod CPU/Memory visualization
• Manual queries
• (Alerting intentionally not added yet)
```

### Manual Verification
```bash
# Check pod CPU
kubectl top pods

# Pod memory
kubectl top pods --containers

# Grafana dashboard
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Visit http://localhost:3000
```

---

## ✅ What's Completed

### Infrastructure
- ✅ AWS VPC (private + public subnets, NAT Gateway)
- ✅ EKS cluster (Kubernetes 1.36)
- ✅ 2 worker nodes (c7i-flex.large)
- ✅ EKS add-ons (VPC-CNI, CoreDNS, kube-proxy, metrics-server)
- ✅ ElastiCache Redis (single node, at-rest encrypted)
- ✅ 10 ECR repositories (image scan on push)

### Security & OIDC
- ✅ EKS OIDC provider
- ✅ IRSA (AWS Load Balancer Controller)
- ✅ GitHub Actions OIDC (no static keys!)
- ✅ IAM roles restricted to repo + branch
- ✅ Pod security contexts (non-root, read-only FS)

### Kubernetes
- ✅ 10 microservices deployed (gRPC-based)
- ✅ Kubernetes Services (ClusterIP)
- ✅ Kubernetes Ingress (AWS ALB)
- ✅ HPA (frontend 2-4, cartservice 2-5)
- ✅ Kustomize overlays
- ✅ Health checks (readiness + liveness)

### CI/CD
- ✅ GitHub Actions workflow
- ✅ Intelligent change detection (only rebuild changed services)
- ✅ Docker builds (commit hash tags)
- ✅ ECR push (with OIDC auth)
- ✅ Kustomize tag auto-update
- ✅ Git commit automation

### GitOps
- ✅ Argo CD deployment
- ✅ Git as single source of truth
- ✅ Automatic reconciliation
- ✅ Auto-sync + auto-prune + self-heal
- ✅ Zero-downtime deployments

### Application
- ✅ All 10 microservices running
- ✅ Frontend accessible via ALB
- ✅ Redis state persistence verified
- ✅ ECR image pulls working
- ✅ Service-to-service communication (gRPC)

### Monitoring
- ✅ Prometheus (metrics collection)
- ✅ Grafana (dashboards)
- ✅ Pod CPU/memory visibility
- ⏸️ Alerting (intentionally deferred)

---

## 🎓 Interview Story (The Simple Version)

> **I deployed Google's Online Boutique microservices application on AWS EKS using Terraform to manage infrastructure as code. This involved provisioning a VPC with public and private subnets, an EKS cluster with two worker nodes, ECR repositories for 10 microservices, and ElastiCache Redis for stateful data.**
>
> **For secure AWS access without static credentials, I configured two OIDC integrations: one for Kubernetes pods to assume IAM roles through EKS OIDC and IRSA (used by the AWS Load Balancer Controller), and another for GitHub Actions to authenticate to AWS via GitHub OIDC.**
>
> **The CI/CD pipeline is intelligent: instead of rebuilding all 10 services on every push, GitHub Actions detects which services changed, builds only those, and pushes them to ECR with a Git commit SHA as the image tag. It then automatically updates the Kustomize manifest with the new tags and commits this change back to GitHub.**
>
> **Argo CD watches the Git repository and automatically syncs the desired Kubernetes state into EKS. When the Kustomize image tags are updated, Argo CD detects the change, pulls the new images from ECR, and performs zero-downtime rolling deployments. Horizontal Pod Autoscaling handles traffic spikes automatically.**
>
> **The architecture includes an AWS Application Load Balancer (provisioned via Kubernetes Ingress), ElastiCache Redis for cart state persistence, and a monitoring stack with Prometheus and Grafana for observability.**
>
> **The entire system is secure: no static AWS credentials in GitHub, Kubernetes uses temporary STS tokens, and all pods run as non-root with read-only filesystems.**

---

## 🚀 Quick Start

### Prerequisites
```bash
# Terraform
terraform version  # >= 1.0

# AWS CLI
aws --version

# kubectl
kubectl version --client

# Docker (for local testing)
docker --version
```

### Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply

# Get kubeconfig
aws eks update-kubeconfig --name project-eks --region us-east-1

# Verify
kubectl get nodes
kubectl get pods -n argocd
```

### Deploy Application
```bash
# Argo CD auto-syncs from kubernetes-manifests/
# Just push code changes:

git push origin main

# GitHub Actions automatically:
# 1. Detects changes
# 2. Builds Docker images
# 3. Pushes to ECR
# 4. Updates Kustomize tags
# 5. Commits to git
# 6. Argo CD syncs
# 7. EKS rolls out new pods

# Monitor
kubectl get deployment
kubectl logs -f deployment/frontend
```

### Access Application
```bash
# Get ALB DNS
kubectl get ingress frontend-ingress

# Visit in browser
http://<ALB-DNS-NAME>

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# http://localhost:3000
```

---

## 📚 Key Learnings

### Architecture
- GitOps isn't just "Argo CD", it's **Git → YAML → Reality**
- Change detection enables efficient CI (not all services rebuilt)
- Image tags = commit SHA (reproducible deployments)

### Security
- OIDC federation > storing credentials
- IRSA + EKS OIDC = no keys in containers
- GitHub Actions OIDC = no keys in repos

### Kubernetes
- Kustomize > Helm for this use case (simpler, git-native)
- HPA needs Metrics Server (don't forget!)
- Service mesh not needed for basic microservices

### Observability
- Prometheus + Grafana gives visibility
- Degraded status ≠ broken app (check events!)
- Manual verification is still important

---

## 🔗 References

| Topic | Resource |
|-------|----------|
| EKS Documentation | https://docs.aws.amazon.com/eks/ |
| Terraform AWS Provider | https://registry.terraform.io/providers/hashicorp/aws/latest |
| Argo CD | https://argo-cd.readthedocs.io/ |
| Kustomize | https://kustomize.io/ |
| GitHub Actions OIDC | https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect |
| AWS Load Balancer Controller | https://kubernetes-sigs.github.io/aws-load-balancer-controller/ |

---

## 📝 Summary

This project is a **complete, production-grade example** of:
- ✅ Infrastructure as Code (Terraform)
- ✅ Container orchestration (Kubernetes on EKS)
- ✅ CI/CD automation (GitHub Actions)
- ✅ GitOps deployments (Argo CD)
- ✅ Security best practices (OIDC, IRSA, pod security)
- ✅ Observability (Prometheus + Grafana)

Built with a focus on **security**, **efficiency**, and **operational excellence**.

---


**GitHub:** https://github.com/Siddhesh-07/eks-project
