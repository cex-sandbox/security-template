# Infrastructure & Kubernetes Security

> Mạng, service mesh, Kubernetes multi-cluster.

### 10. Network & Service Mesh

✅ TLS `verify-full` cho external calls.
✅ Istio mTLS STRICT mode (không PERMISSIVE trong prod).
✅ Egress: whitelist domains.

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

### 12. Kubernetes & Multi-Cluster

**Architecture:** Hub-and-Spoke EKS. **Cluster A** (Application Processing) + **Cluster B** (Signing/Critical, internal-only) + **Hub Cluster** (Argo CD GitOps).

✅ Pod Security:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
automountServiceAccountToken: false  # IRSA dùng projected token riêng
```

✅ **PSA (Pod Security Admission) Restricted** profile cho namespace prod.
✅ **NetworkPolicy default-deny**. SG for Pods cho VPC-level isolation.
✅ **EKS Access Entry** (thay aws-auth ConfigMap) — namespace-scoped policy.
✅ **RBAC least privilege:** ưu tiên Role (namespace) hơn ClusterRole. Hub không có cluster-admin trên Spoke.
✅ **SPIFFE/SPIRE** mTLS cho cross-cluster (Cluster A → Cluster B). SVID TTL 1h. Trust domain isolation.
✅ **Istio mTLS STRICT mode** (không PERMISSIVE trong prod).

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

✅ Image: distroless base, **Cosign signed**, **Trivy scanned** trong ECR, SBOM (Syft) generated trong CI.
✅ Egress qua **VPC Endpoints** trong Shared Services VPC — không NAT Gateway ra internet.
