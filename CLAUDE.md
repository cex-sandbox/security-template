> ⚠️ **Sandbox học tập** — bản sanitize công khai cho mục đích nghiên cứu/demo DevSecOps. Kiến trúc & context là ví dụ tham chiếu, không phải hệ thống thật.

# Security Rules for AI Coding Assistant

> **Mục đích:** File này được Claude Code, Cursor, GitHub Copilot, Cline và các AI coding assistant khác đọc tự động để ràng buộc code AI sinh ra tuân thủ chuẩn bảo mật của CEX.
>
> **Nguồn:** Tổng hợp từ CEX Secure Coding Guide (Confluence) và các production incident (Mixin Network 09/2023, Upbit 11/2019, Bybit 02/2025).

---

## CONTEXT — Dự án CEX

Đây là ví dụ tham chiếu cho một sàn giao dịch crypto (CEX) tại Việt Nam. Mọi code đụng đến **balance, withdrawal, order, authentication, KYC** đều có tác động tài chính trực tiếp đến người dùng.

**Tuân thủ pháp lý:** Nghị định 356/2025/NĐ-CP (PII), Nghị quyết 05/2025/NQ-CP (thí điểm CEX), Luật Công nghiệp Công nghệ số 71/2025/QH15, tiêu chuẩn ATTT Cấp độ 4 (§9.1: log retention 24 tháng), Luật PCRT 2022 (KYC retention ≥ 5 năm).

**Architecture zones:**
- **Z4 (VPC-VN)** — Việt Nam. BẮT BUỘC cho PII (CCCD, selfie, biometric, số TK ngân hàng). KHÔNG replicate ra Singapore.
- **VPC-1** (AWS ap-southeast-1) — App services, trading engine, non-PII data.
- **Cluster A** — Application Processing. **Cluster B** — Signing & Verification Critical (internal-only). **Hub Cluster** — Argo CD GitOps.

**Kiến trúc nguyên lý:** Zero Trust Architecture — identity-first, micro-segmentation, explicit verification, continuous monitoring.

**Stack key:** Aurora MySQL, ElastiCache Redis, MSK, Kong API Gateway (L2), Istio mTLS STRICT, AWS Secrets Store CSI Driver (qua IRSA), GitLab CI → Argo CD GitOps.

---

## CRITICAL RULES

## CRITICAL RULES — Tóm tắt

| # | Quy tắc | Chi tiết |
|---|---|---|
| 1 | Password: Argon2id, time_cost=3, memory=65536 | docs/auth.md |
| 2 | JWT: RS256 qua KMS, KHÔNG HS256 với static secret | docs/auth.md |
| 3 | Database: truy vấn tham số, IRSA, IAM DB Auth | docs/database.md |
| 4 | Money: Decimal, FOR UPDATE, Idempotency-Key, HSM | docs/wallet.md |
| 5 | Encryption: AES-256-GCM, nonce ngẫu nhiên, KMS | docs/crypto.md |
| 6 | Secrets: KHÔNG hardcode, dùng IRSA + CSI Driver | docs/crypto.md |
| 7 | Input: server-side validate, whitelist, reject unknown | docs/auth.md |
| 8 | PII: Z4 (VPC-VN), consent tường minh, NĐ 356/2025 | docs/data-protection.md |
| 9 | Logging: generic error ra ngoài, mask PII, correlation_id | docs/data-protection.md |
| 10 | Network: Istio mTLS STRICT, NetworkPolicy deny-all default | docs/infra.md |
| 11 | Mobile: BiometricPrompt backend-validated, cert pinning | docs/mobile.md |
| 12 | K8s: non-root, readOnlyRootFilesystem, IRSA | docs/infra.md |
| 13 | AI: đọc file này + steering trước khi gợi ý code | (file này) |

> **BẮT BUỘC đọc file chi tiết tương ứng trước khi gợi ý code. Không gợi ý chỉ dựa trên bảng tóm tắt.**
> Steering files bổ sung context tại `.security/steering/` (product, tech, compliance).

## ANTI-PATTERNS

| Anti-pattern | Tại sao nguy hiểm |
|---|---|
| `eval(user_input)` / `exec(user_input)` | RCE |
| `pickle.loads(user_data)` | RCE qua `__reduce__` |
| `yaml.load()` không SafeLoader | RCE (xem Mixin 2023) |
| f-string vào SQL | SQL Injection |
| f-string vào shell command | Command Injection |
| Float cho money | Precision loss |
| `random` cho security | Predictable |
| MD5/SHA-1/SHA-256 cho password | Brute-force fast — dùng Argon2id |
| AES-ECB | No semantic security |
| Tái sử dụng nonce trong AES-GCM | Plaintext recovery |
| `jwt.decode(algorithms=["none"])` | Algorithm confusion |
| `algorithms=["HS256"]` khi server dùng RS256 | Public key as HMAC secret = bypass |
| `verify=False` trên JWT/TLS | Bypass auth / MITM |
| Tin `jwk`/`jku`/`x5u` claim trong JWT header | Public key injection |
| `try/except: pass` | Silent failure |
| Direct `s3:PutObject` từ workstation lên prod | Bypass CI/CD (xem Mixin 2023, Bybit 2025) |
| Static AWS credentials trong env/ConfigMap | Dùng IRSA |
| Long-lived AWS session token (`--duration-seconds 43200`) trên workstation | xem Bybit 2025 (12h token bị steal qua phishing) |
| Tin Kong L2 scope mà không tái xác thực L3 | Privilege escalation tại service |
| Log password/token/PII/device fingerprint không mask | Credential leak |
| AES key trong source code | Permanent compromise |
| Lưu PII VN ngoài Z4 (VPC-VN) | Vi phạm Nghị định 356/2025 |
| `region_name="ap-southeast-1"` cho KYC bucket | PII lưu sai vùng |
| Istio PeerAuth PERMISSIVE mode trong prod | Plaintext between services |
| `runAsRoot: true` trong Pod | Container escape risk |
| `automountServiceAccountToken: true` mặc định | Compromise container = K8s API token |
| Forward Kong L2 result thẳng vào withdrawal flow | Thiếu L3 verification |
| `403` thay vì `404` cho resource user khác | Information leak (BOLA fingerprinting) |
| SMS OTP cho crypto withdrawal hoặc fiat > 100M VND | SIM-swap risk cao tại VN |
| MFA chỉ unlock client-side, không Backend validation | Bypass biometric / Secure Enclave |
| Không bind `device_id` vào JWT / session token | Token bị steal = full account takeover từ thiết bị khác |

---

## REFERENCES

**CEX Secure Coding Guide (Confluence):**

Identity & Auth: Authentication Best Practice · Authorization & RBAC · Passwordless & MFA · API Authentication · Auto Refresh Access Token Flow

Data Protection: Sensitive Data Handling · PII Protection (Nghị định 356/2025) · Encryption Best Practices · Data in Transit & Rest

Infrastructure: Kubernetes Security · Network Security · Secrets Management in Kubernetes · Workload Identity (SPIFFE/SPIRE/IRSA)

App-level: App-to-Database Authentication Flow (IRSA + IAM DB Auth) · Mobile App Security

Strategic: AI-first Security Program · CEX Architecture Design

**Production Incidents:**
- Mixin Network 09/2023 (200M USD) — Cloud DB compromise + JS S3 manipulation
- Upbit 11/2019 (50M USD ETH) — Hot wallet drain
- Bybit 02/2025 (1.5B USD) — Safe{Wallet} supply chain attack

---

## Project-Specific Context

Nếu dự án có file `security-local.md` ở gốc — tham chiếu thêm file đó cho context cụ thể của project (stack riêng, quy tắc riêng, ngoại lệ đã được Security Team duyệt).

---

## Phát triển Template

> Chỉ áp dụng khi bạn đang **phát triển template này** (không phải dùng nó trong project khác).

Đọc **`ONBOARDING.md`** ở root repo này — chứa đầy đủ: trạng thái hiện tại, roadmap, conventions, kiến thức kỹ thuật quan trọng, và hướng dẫn setup môi trường dev.

```
# Lệnh chạy sau khi clone
bash scripts/test-ci-local.sh   # phải 80/80 PASS trước khi bắt đầu
```
