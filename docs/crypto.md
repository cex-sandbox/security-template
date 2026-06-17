# Encryption & Secrets Management

> Quy tắc mã hoá, quản lý khoá, và bảo vệ thông tin bí mật.

### 5. Encryption

**Allowed:**
- Symmetric: AES-256-GCM, nonce 96-bit RANDOM mỗi lần, tag 128-bit
- Asymmetric: RSA-OAEP với SHA-256 (≥ 2048-bit)
- Signature: RSA-PSS hoặc ECDSA với SHA-256; RS256 cho JWT
- KDF: HKDF (RFC 5869) với SHA-256, unique salt
- Password: Argon2id (params trên)
- HMAC: HMAC-SHA256
- TLS: 1.2+ (ưu tiên 1.3), AEAD only

**TUYỆT ĐỐI CẤM:**
- AES-ECB (deterministic, không semantic security)
- MD5, SHA-1 (collision attacks)
- DES, 3DES (brute-force, Sweet32)
- RC4 (statistical bias)
- RSA-PKCS1v1.5 cho encryption (padding oracle ROBOT) — note: RS256 cho JWT vẫn OK

```python
# ✅ GOOD — AES-256-GCM
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def encrypt(plaintext: bytes, key: bytes) -> bytes:
    assert len(key) == 32
    nonce = os.urandom(12)  # KHÔNG BAO GIỜ reuse nonce với cùng key
    aesgcm = AESGCM(key)
    return nonce + aesgcm.encrypt(nonce, plaintext, None)
```

✅ **KMS Envelope Encryption** cho PII và dữ liệu nhạy cảm.
✅ **Random for security:** `secrets` module (Python), `crypto.randomBytes` (Node).

### 6. Secrets — KHÔNG hardcode, dùng IRSA + CSI Driver

❌ KHÔNG hardcode API key, password, private key trong code / env / ConfigMap.

✅ **Pattern ưu tiên (CEX production):** AWS Secrets Store CSI Driver → mount tmpfs từ AWS Secrets Manager qua IRSA. Pod read file:

```yaml
# SecretProviderClass
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: db-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "prod/orders-svc/db-password"
```

```yaml
# Pod
serviceAccountName: orders-sa
volumes:
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: db-secrets
volumeMounts:
- name: secrets-store
  mountPath: "/mnt/secrets"
  readOnly: true
```

```python
# App đọc file — không gọi boto3 trực tiếp
db_password = open("/mnt/secrets/db-password").read()
```

✅ **Lợi ích so với K8s Secret thường:** Không lưu trong etcd → không lộ qua etcd backup / K8s API access. Mount tmpfs (RAM). Auto-rotate khi Secrets Manager rotate.

**Fallback sources (legacy / dev):**
- AWS Secrets Manager trực tiếp qua boto3 (legacy)
- External Secrets Operator → K8s Secret (legacy)
- HashiCorp Vault
- Env variables (DEV only)

```python
# Legacy pattern (vẫn được dùng nhưng không recommend cho code mới)
import boto3
secrets = boto3.client("secretsmanager", region_name="ap-southeast-1")
API_KEY = secrets.get_secret_value(SecretId="prod/api-key")["SecretString"]
```

✅ **Workload Identity:** SPIFFE/SPIRE cho cross-cluster service-to-service (Cluster A → Cluster B). IRSA cho AWS API access. KHÔNG static credentials.

✅ **API key cho đối tác (bank, KYT, AML):** AWS Secrets Manager + KMS, rotate định kỳ, 1 key/đối tác, log mỗi API call.
