# Tech Stack Guidance

> **Mục đích:** Hướng dẫn AI assistant về tech stack, library, và pattern được approved tại CEX.

---

## Approved Libraries — Security Critical

### Python

| Use case | ✅ Use | ❌ Avoid |
|---|---|---|
| Password hashing | `argon2-cffi` (Argon2id), `bcrypt` (cost ≥ 12) | `hashlib.md5`, `hashlib.sha1`, `hashlib.sha256` raw |
| Symmetric encryption | `cryptography` (AESGCM) | `pycrypto` (unmaintained), AES-ECB, DES, RC4 |
| Asymmetric / JWT | `cryptography`, `pyjwt` ≥ 2.x | Self-rolled, `python-jose` < 3.3 |
| Random for security | `secrets` module | `random` module |
| HTTP client | `requests`, `httpx` | `urllib2` raw |
| YAML parsing | `yaml.safe_load`, `yaml.SafeLoader` | `yaml.load` without SafeLoader |
| Serialization (untrusted) | `json` + `jsonschema` | `pickle`, `marshal`, `dill` |
| ORM / DB | `SQLAlchemy` (bound params), `pymysql` parameterized | Raw string concat |
| Decimal math | `decimal.Decimal` | `float` for money |
| AWS | `boto3` ≥ 1.34 (qua IRSA) | Static credentials trong env/code |
| Redis | `redis-py` 5.x | Hardcoded auth token |

### JavaScript / Node

| Use case | ✅ Use | ❌ Avoid |
|---|---|---|
| Password hashing | `argon2`, `bcrypt` | `crypto.createHash('md5')` |
| Encryption | `crypto` builtin (AES-GCM) | `crypto-js` < 4.2 |
| JWT | `jsonwebtoken` với `algorithms: ["RS256"]` explicit | `jwt-simple`, decode không verify |
| Random | `crypto.randomBytes`, `crypto.randomUUID` | `Math.random()` |
| HTTP | `axios`, `node-fetch`, `undici` | `request` (deprecated) |
| Decimal | `decimal.js`, `bignumber.js` | Native `Number` for money |
| SQL | parameterized via `mysql2` placeholders | Template literals into queries |

### Mobile

| Platform | Approved |
|---|---|
| Android secure storage | `EncryptedSharedPreferences`, `Android Keystore` (`setUserAuthenticationRequired(true)` cho seed/private key) |
| iOS secure storage | `Keychain Services` (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), `Secure Enclave` |
| Cert pinning | `OkHttp CertificatePinner` (Android) + backup pin, `TrustKit` hoặc `URLSessionDelegate` (iOS) |
| Biometric | `BiometricPrompt` + Keystore (Android), `LocalAuthentication` + `biometryCurrentSet` (iOS). **Backend validation bắt buộc.** |
| Device integrity | `Play Integrity API` (Android — SafetyNet đã EOL 01/2025), `App Attest` (iOS) |
| Network config | `network_security_config.xml` (Android), `ATS` (iOS, bật mặc định) |
| Anti-tamper | `ProGuard/R8` obfuscation (Android), strip symbols (iOS) |

---

## Database Patterns

### Stack

- **Aurora MySQL** trên RDS (ap-southeast-1, port 3306).
- **ElastiCache Redis** (cache, rate limit, jti blacklist, session, idempotency).
- **DB Auth:** IRSA → IAM DB Auth Token (TTL 15 phút) — KHÔNG password tĩnh (GOV-01.1).

### Connection Management

✅ Connection pooling với min/max bounds
✅ Statement timeout < 5 giây
✅ Connection retry với exponential backoff
✅ **Refresh DB token mỗi 10 phút** hoặc per-connection (token TTL 15 phút)
❌ Mở connection trong loop
❌ Cache DB token lâu hơn TTL

### Query Patterns

```python
# ✅ GOOD — parameterized với %s (pymysql/aiomysql)
db.execute("SELECT * FROM users WHERE email = %s", (email,))

# ✅ GOOD — SQLAlchemy bound params
session.query(User).filter(User.email == email).first()

# ❌ BAD — f-string
db.execute(f"SELECT * FROM users WHERE email = '{email}'")
```

### Transaction Patterns — Race Condition Defense

```python
# ✅ GOOD — Balance update với row-level lock
with db.transaction():
    bal = db.query_one(
        "SELECT balance FROM wallets WHERE user_id = %s FOR UPDATE",
        (user_id,)
    )
    if bal < amount:
        raise InsufficientFunds()
    db.execute(
        "UPDATE wallets SET balance = balance - %s WHERE user_id = %s",
        (amount, user_id)
    )
```

⚠️ **Cẩn trọng đặc biệt cho:** balance update, withdrawal creation, order placement, OTP verification, idempotency key check.

→ **Pattern bắt buộc:**
- DB row lock (`SELECT ... FOR UPDATE`)
- Distributed lock (Redlock) cho cross-service operations
- Idempotency-Key check trước khi process (Redis TTL 24h)

---

## API Patterns

### API Gateway — Kong (L2)

✅ Kong validate JWT signature + basic scope (L2)
✅ **L3 re-verification BẮT BUỘC** tại service cho:
- Payment / Withdrawal / Bank Link / KYC
- Admin operations
- Anything đụng money

❌ KHÔNG tin Kong L2 đơn thuần — service layer phải tự verify scope (xem `authorization-and-rbac` doc Linh).

### Request / Response Conventions

✅ JSON body với content-type validation
✅ **`Idempotency-Key` header** bắt buộc cho mutating operations (withdrawal/transfer/order)
✅ **`Correlation-ID` header** propagate qua services
✅ Generic error response — `{error: ..., correlation_id: ...}` — không leak internal

### JWT Authentication — 4 Patterns

| Pattern | Use case | Verification |
|---|---|---|
| **Customer JWT** (CEX-issued) | App/Web users | RS256 qua KMS, JWKS endpoint, kid lookup |
| **Service-to-service** (intra-cluster) | Microservice calls | IRSA + SPIFFE/SPIRE mTLS SVID (TTL 1h) |
| **một sàn đối tác Partner JWT** | Session forward từ một sàn đối tác main app | JWKS từ một sàn đối tác, mTLS callback qua ACM PCA |
| **Bank/KYT/AML API key** | Outbound đến đối tác | API key (AWS Secrets Manager) + HMAC-SHA256 + IP whitelist |

```python
# ✅ GOOD — Decorator pattern
@require_auth
@require_scope("withdrawal:create")
async def create_withdrawal(req, current_user, token_payload):
    # L3 verification ở đây
    if token_payload["sub"] != req.account_id:
        raise HTTPException(404, "Không tìm thấy")  # 404 chống BOLA fingerprinting
    ...
```

### Rate Limiting

✅ Per-user và per-IP rate limit
✅ Stricter limit cho auth endpoints (login, OTP, password reset)
✅ Distributed rate limit qua Redis (không in-memory)
✅ Auth specific: 5/phút/user, 20/phút/IP, lock 30 phút sau 5 fail (US-AUTH-001)

---

## Async / Concurrency

### Background Jobs (MSK Kafka)

✅ **Idempotent jobs** — chạy 2 lần = chạy 1 lần
✅ Retry với exponential backoff + max retries
✅ Dead letter queue cho failed jobs
✅ **Distributed lock** (Redlock) cho jobs không được chạy concurrent

### Race Conditions — Crypto Exchange Specific

⚠️ **Cẩn trọng đặc biệt cho:**
- Balance update (double-spend risk)
- Withdrawal creation (idempotency)
- Order placement (matching engine consistency)
- TOTP verification (replay)
- Refresh token rotation (không xóa token cũ trước khi save token mới)

---

## Kubernetes & Multi-Cluster Patterns

### Architecture

- **Cluster A** (Application Processing) — orders-svc, payment-svc, user-facing
- **Cluster B** (Signing/Critical) — signing-svc, internal-only ALB
- **Hub Cluster** — Argo CD GitOps (Shared Services VPC)

### IRSA — Service Account Pattern

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: orders-sa
  namespace: prod
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/eks-orders-role
```

Trust policy enforce ServiceAccount mapping:
```json
{
  "Condition": {
    "StringEquals": {
      "oidc.eks.ap-southeast-1.amazonaws.com/id/XXX:sub":
        "system:serviceaccount:prod:orders-sa"
    }
  }
}
```

### Secrets — CSI Driver (preferred)

✅ AWS Secrets Store CSI Driver → mount tmpfs từ Secrets Manager. Không lưu trong etcd.

```yaml
volumeMounts:
- name: secrets-store
  mountPath: "/mnt/secrets"
  readOnly: true
volumes:
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: orders-secrets
```

### Network

✅ Egress qua **VPC Endpoints** trong Shared Services VPC (ECR, S3, STS, CloudWatch, KMS, Secrets Manager) — không NAT Gateway ra internet
✅ NetworkPolicy default-deny per namespace
✅ SG for Pods cho VPC-level isolation
✅ Istio mTLS STRICT mode
✅ SPIFFE/SPIRE SVID TTL 1h cho cross-cluster

---

## CI/CD Stack

GitLab CI → SAST/SCA → ECR → Argo CD (Hub-and-Spoke) → EKS

| Stage | Tools |
|---|---|
| Code repo | GitLab (signed commits, MR approval) |
| CI | GitLab CI (build, test, push image) |
| SAST | Semgrep, SonarQube (CEX custom rules tại `.semgrep/`) |
| SCA | Trivy (deps), Syft (SBOM generation) |
| Secret scan | Gitleaks, detect-secrets |
| Container scan | Trivy, ECR scan on push |
| Image signing | Cosign (verify pre-deploy) |
| IaC scan | Checkov / Trivy IaC |
| Deploy | Argo CD (GitOps), Helm charts |
| Mobile | MobSF (binary scan), Firebase App Distribution |

---

## Testing Requirements

✅ Unit test coverage > 80% cho code đụng money
✅ Integration test cho mọi auth flow
✅ Load test cho balance/withdrawal endpoints
✅ Security test: SQLi, XSS, auth bypass, IDOR/BOLA
✅ Negative testing: malformed input, edge cases, race condition
✅ Mobile: MobSF static scan, dynamic emulator test

---

## Performance Constraints

- API response time p99 < 500ms
- DB query timeout: 5s
- Background job timeout: 5 phút
- WebSocket message rate: < 100/sec/client
- DB Auth Token refresh: every 10 phút (TTL 15 phút)
- TOTP anti-replay TTL: 90s
- Kill-Switch activation: < 60s
- Reconciliation interval: 5-10 phút

---

## Forbidden Practices

| Practice | Why forbidden |
|---|---|
| Direct `s3:PutObject` từ workstation → prod bucket | Bypass CI/CD, supply chain risk (xem Mixin 2023, Bybit 2025) |
| Shared service account cho nhiều services | Audit trail impossible, blast radius lớn |
| Long-lived API key cho service-to-service | Dùng IRSA / SPIFFE short-lived tokens |
| AWS session token TTL > 1h cho human users | Xem Bybit 2025 (12h token bị steal qua phishing) |
| Debug logging enabled in production | PII leak risk |
| Self-signed certificate trong production | MITM vulnerable |
| Implementing crypto from scratch | Almost guaranteed to have bug |
| Trust Kong L2 mà không tái xác thực L3 | Privilege escalation tại service |
| `automountServiceAccountToken: true` mặc định | Compromise container = K8s API token |
| K8s Secret thường cho prod secrets | Lộ qua etcd / API access — dùng CSI Driver |
| Lưu PII tại region khác Z4 (VPC-VN) | Vi phạm Nghị định 356/2025 |
| Float cho money fields | Precision loss → balance drift |
| SMS OTP cho crypto withdrawal hoặc fiat > 100M VND | SIM-swap risk cao tại VN |
