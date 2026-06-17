# Infrastructure & Cloud Rules

## IRSA-NOT-USED — MEDIUM

**Trigger:** Code AWS dùng access key/secret hardcoded hoặc trong env var thay vì IRSA (IAM Roles for Service Accounts).

**Data flow:** AWS credentials không từ IRSA.

**Bad:**
```python
import boto3
client = boto3.client(
    's3',
    aws_access_key_id='AKIAIOSFODNN7EXAMPLE',
    aws_secret_access_key='wJalrXUtnFEMI/...'
)

# Hoặc env var
os.environ['AWS_ACCESS_KEY_ID'] = '...'
```

**Good:**
```python
# IRSA tự động — pod có service account → AWS SDK pickup
import boto3
client = boto3.client('s3')  # Credentials từ projected token IRSA
```

**Cấu hình IRSA (Kubernetes manifest):**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/app-role
```

**Vì sao:** Access key static = lộ là vĩnh viễn. IRSA = short-lived token (1h), rotate tự động, audit qua CloudTrail.

---

## MTLS-PERMISSIVE — HIGH

**Trigger:** Istio `PeerAuthentication` mode `PERMISSIVE` hoặc `DISABLE` trong production namespace.

**Data flow:** N/A — config rule.

**Bad:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: prod
spec:
  mtls:
    mode: PERMISSIVE  # Cho phép cả plain HTTP
```

**Good:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: prod
spec:
  mtls:
    mode: STRICT  # Bắt buộc mTLS
```

**Vì sao:** PERMISSIVE = service nội bộ không cần verify mTLS. Hacker exploit 1 pod → giả mạo service khác → lateral movement. STRICT chặn 100% plain traffic.

---

## CONTAINER-AS-ROOT — HIGH

**Trigger:** Dockerfile không có `USER` directive non-root, hoặc Kubernetes pod không set `securityContext.runAsNonRoot`.

**Data flow:** N/A — config rule.

**Bad (Dockerfile):**
```dockerfile
FROM python:3.12
COPY . /app
CMD ["python", "app.py"]
# Chạy as root
```

**Good (Dockerfile):**
```dockerfile
FROM python:3.12-slim
RUN useradd -m -u 1000 appuser
USER appuser
COPY --chown=appuser:appuser . /app
CMD ["python", "app.py"]
```

**Good (Kubernetes):**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
```

**Vì sao:** Container escape vulnerability + root inside = root on host. Non-root + readOnly + dropped capabilities limit blast radius.

---

## NETWORK-POLICY-MISSING — MEDIUM

**Trigger:** Production namespace không có `NetworkPolicy` default-deny.

**Data flow:** N/A — config rule.

**Bad:** Không có NetworkPolicy → tất cả pod gọi nhau được.

**Good:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: prod
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
# Sau đó allow explicit từng service
```

**Vì sao:** Default Kubernetes = open network. 1 pod bị xâm nhập = scan/attack mọi pod khác. Default-deny + allow explicit = least privilege.
