# PR/MR Security Checklist — CEX

> **Dùng cho:** Mọi PR/MR liên quan auth / withdrawal / payment / PII / KYC / wallet.
> **Mức độ:** Mọi item là **BẮT BUỘC**, trừ khi note rõ "khi áp dụng".
> **Reference:** Confluence Secure Coding Guide + `CLAUDE.md` ở root.

---

## 0. Trước khi mở PR

- [ ] Đã chạy `pre-commit run --all-files` local — pass clean
- [ ] Đã chạy `pytest` hoặc test suite tương đương — pass
- [ ] Đã đọc `CLAUDE.md` cho rule set
- [ ] Đã cross-check với Confluence Secure Coding Guide nếu đụng:
  - Authentication, Authorization, MFA, API Auth
  - PII, Sensitive Data, Encryption
  - Mobile, Kubernetes, Workload Identity, Secrets

---

## 1. Authentication & Session

- [ ] Password hash dùng **Argon2id** (`time_cost=3, memory_cost=65536, parallelism=4`) hoặc bcrypt cost ≥ 12
- [ ] KHÔNG dùng MD5/SHA-1/SHA-256 cho password
- [ ] **Generic error message** cho login failure: `"Số điện thoại hoặc mật khẩu không đúng"`
- [ ] **Constant-time comparison** cho password verification
- [ ] **Rate limiting** áp dụng (5/phút/user, 20/phút/IP)
- [ ] Lockout 30 phút sau 5 lần fail (US-AUTH-001)
- [ ] Session token TTL hợp lý (Access 15-30 phút, Refresh có rotation + device binding)
- [ ] **Refresh token rotation:** không xóa token cũ trước khi save token mới thành công
- [ ] **Risk Engine check** mỗi refresh token (IP/device/location/velocity per GOV-01.2)
- [ ] MFA bắt buộc cho mọi tài khoản sau đăng ký

## 2. Authorization

- [ ] **Tái xác thực L3 trong service** cho Payment / Withdrawal / Bank Link / KYC / Admin — KHÔNG tin Kong L2 đơn thuần
- [ ] **Ownership check:** mỗi resource access verify `resource.user_id == token.sub`
- [ ] BOLA defense: trả **404** (không 403) cho resource thuộc user khác
- [ ] **JWT scope tối thiểu** — không có "super token"
- [ ] **device_id JWT** match với `device_id` trong request

## 3. JWT — 4 Patterns

- [ ] **Customer JWT:** RS256 với KMS, JWKS endpoint, `kid` lookup
- [ ] **Service-to-service:** IRSA + SPIFFE/SPIRE mTLS
- [ ] **một sàn đối tác partner:** verify mTLS client certificate (ACM PCA) trên callback
- [ ] **Bank API key:** Secrets Manager + HMAC-SHA256 + IP whitelist
- [ ] KHÔNG `algorithms=["none"]`, KHÔNG `verify=False`
- [ ] KHÔNG `algorithms=["HS256"]` khi server publish RS256
- [ ] BỎ QUA `jwk`/`jku`/`x5u` claims trong header

## 4. Withdrawal — 3-Tier Threshold

- [ ] **Mọi withdrawal:** SmartOTP bắt buộc. SMS OTP không dùng cho crypto.
- [ ] **≥ 10M VND (0.1 BTC):** step-up authentication
- [ ] **> 100M VND fiat:** chặn SMS OTP, bắt buộc TOTP/Passkey
- [ ] **> 500M VND:** SmartOTP + Fund Password, không downgrade
- [ ] **Cooling period** đúng: 0 / 24h / 48h / 48h+CS theo giá trị
- [ ] **Address holding period:** 24h (giá trị thấp/trung) hoặc 48h (cao)
- [ ] **Idempotency-Key** bắt buộc, check Redis TTL 24h trước process
- [ ] **Kill-Switch < 60s** khi Risk Engine detect anomaly

## 5. Database

- [ ] **Parameterized queries** với `%s` placeholders — không string concat / f-string
- [ ] **Aurora DB auth qua IRSA** + IAM DB Auth Token (TTL 15 phút) — không password tĩnh
- [ ] **TLS verify-full** với rds-ca.pem
- [ ] **`SELECT ... FOR UPDATE`** cho balance / withdrawal / order operations
- [ ] **Decimal cho money** — KHÔNG float
- [ ] Migration script reversible + tested trên staging

## 6. Input Validation

- [ ] **Server-side validation** mọi user input (không tin client validation)
- [ ] Type, length, format, range checks
- [ ] Whitelist approach (allow known good) thay vì blacklist
- [ ] Validate address format theo currency
- [ ] Validate currency code whitelist
- [ ] Reject unexpected fields trong JSON body

## 7. Encryption

- [ ] **AES-256-GCM** với nonce 96-bit **ngẫu nhiên mỗi lần** (`os.urandom(12)`)
- [ ] KHÔNG tái sử dụng nonce với cùng key
- [ ] KHÔNG AES-ECB, KHÔNG DES/3DES/RC4
- [ ] **RSA-OAEP** cho asymmetric encryption
- [ ] **HMAC-SHA256** cho integrity
- [ ] **TLS 1.2+** (ưu tiên 1.3), AEAD ciphers only
- [ ] **KMS Envelope encryption** cho PII — data key hủy ngay sau khi dùng
- [ ] Encryption key chỉ trong KMS — KHÔNG hardcode, KHÔNG env var

## 8. PII Protection — Nghị định 356/2025

- [ ] PII (CCCD, selfie, biometric, số TK NH) **chỉ lưu tại Z4 (VPC-VN)** — không AWS Singapore
- [ ] S3 bucket cho KYC: **KHÔNG** dùng region `ap-southeast-1` cho PII
- [ ] **Consent ghi nhận TRƯỚC khi thu thập** — version policy, IP, time, scope, method (checkbox tường minh)
- [ ] **Mask trong API response:** dùng `tao_profile_an_toan()` — không trả raw user object
- [ ] **Right to delete:** pseudonymize (không hard-delete) — giữ transaction history cho AML
- [ ] **Cross-border transfer:** `kiem_tra_co_so_phap_ly()` PASS + Legal ký duyệt
- [ ] Audit log mỗi PII access (read/write/delete)
- [ ] Retention: KYC ≥ 5 năm, audit log 24 tháng (S3 Object Lock Compliance mode)

## 9. Sensitive Data — 4-Tier Classification

- [ ] **BÍ MẬT TUYỆT ĐỐI** (private key, seed, KMS master): chỉ trong KMS/HSM/Secure Enclave. KHÔNG log, KHÔNG response, KHÔNG serialize
- [ ] **MẬT** (CCCD, biometric, OTP secret, refresh token, fund password, device fingerprint): AES-256-GCM + KMS, mask khi log
- [ ] **NỘI BỘ** (JWT, API key, user_id): mã hóa lưu, log 4 ký tự cuối
- [ ] Middleware logging mask mọi `TRUONG_NHAY_CAM` trước khi ghi
- [ ] Device fingerprint (IMEI, serial, wlan_mac, android_id) lưu mã hóa — không plaintext

## 10. Error Handling & Logging

- [ ] **Response lỗi:** chỉ generic message + `error_id` — không stack trace, không DB details, không ARN
- [ ] Log đầy đủ nội bộ với correlation_id để debug
- [ ] KHÔNG log: password, OTP, private key, seed, refresh token, full JWT, CCCD, biometric plaintext
- [ ] JWT access trong log: 4 ký tự cuối hoặc `jti`
- [ ] Audit log đầy đủ cho: auth, authorization decision, PII access, withdrawal, security event
- [ ] Audit log → S3 Object Lock Compliance mode (immutable, 24 tháng)

## 11. Secrets Management

- [ ] **Preferred:** AWS Secrets Store CSI Driver — mount tmpfs qua IRSA
- [ ] KHÔNG hardcode API key, password, private key trong code/env/ConfigMap
- [ ] KHÔNG K8s Secret thường cho prod secrets
- [ ] KHÔNG static AWS credentials — dùng IRSA
- [ ] Long-lived AWS session token > 1h cho human user: avoid (xem Bybit 2025)
- [ ] API key cho đối tác: rotate định kỳ, 1 key/đối tác, log mỗi call

## 12. Mobile (nếu áp dụng)

- [ ] **Android:** EncryptedSharedPreferences (không SharedPreferences thường), Android Keystore với `setUserAuthenticationRequired(true)` cho seed/private key
- [ ] **iOS:** Keychain `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, Secure Enclave
- [ ] **Biometric:** token Secure Enclave backend-validated — không chỉ unlock cục bộ
- [ ] **Cert pinning** với backup pin, expiration ~2030, có quy trình rotate
- [ ] **Request signing:** HMAC + timestamp ±5 phút + nonce 1 lần dùng (Redis)
- [ ] **Play Integrity API** (Android, SafetyNet đã EOL 01/2025) hoặc **App Attest** (iOS)
- [ ] **ProGuard/R8** obfuscation cho release Android, strip symbols iOS
- [ ] FLAG_SECURE cho màn hình rút tiền / seed / PIN
- [ ] **Refresh token rotation** không có race condition
- [ ] KHÔNG hardcode API endpoint/key trong mobile binary

## 13. Kubernetes & Cloud (nếu áp dụng)

- [ ] **Pod SecurityContext:** runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities
- [ ] `automountServiceAccountToken: false` — IRSA dùng projected token riêng
- [ ] **PSA Restricted** profile cho namespace prod
- [ ] **NetworkPolicy default-deny** cho namespace
- [ ] **IRSA per service** với IAM least privilege — không cluster-admin
- [ ] **Istio mTLS STRICT** cho intra-cluster traffic
- [ ] **SPIFFE/SPIRE** cho cross-cluster (Cluster A → Cluster B)
- [ ] Image: distroless base, Cosign signed, Trivy scanned, SBOM (Syft) trong CI

## 14. Tests

- [ ] Unit test cho mọi code path liên quan money / auth
- [ ] Integration test cho flow end-to-end (login, withdrawal, deposit)
- [ ] Negative tests: invalid input, edge case, race condition
- [ ] Mock external services (đối tác bank, KYT, AML)
- [ ] Coverage > 80% cho code đụng money

## 15. Documentation

- [ ] API doc updated (OpenAPI/Swagger)
- [ ] Architecture diagram updated nếu có thay đổi
- [ ] CHANGELOG entry
- [ ] Runbook cho ops nếu có operational change

---

## Sign-off

- [ ] Self-review pass — đã đọc full diff lại
- [ ] Peer review từ ít nhất 1 Dev khác
- [ ] **Security Team review** nếu PR/MR đụng:
  - Authentication / Authorization
  - Withdrawal / Payment / Bank
  - KYC / PII
  - Smart contract / wallet / signing
  - Encryption / secret management
  - IAM / network policy

---

## Escalation

Phát hiện vấn đề security trong PR/MR khác hoặc trong production?
- **Critical / High:** Slack `#security-alerts` ngay + page on-call
- **Medium / Low:** Tag `@security-team` trong PR/MR hoặc tạo Jira ticket
- **Suspected compromise:** Slack `#incident-response` + tạm dừng deploy
