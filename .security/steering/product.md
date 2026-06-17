# Product Context

> **Mục đích:** Context về sản phẩm CEX cho AI coding assistant. AI tham chiếu khi cần hiểu domain logic, terminology, và business constraints.

---

## What is CEX?

CEX là sàn giao dịch tài sản mã hoá tập trung (Centralized Exchange — CEX) tại Việt Nam, hoạt động theo **Nghị quyết 05/2025/NQ-CP** về thí điểm thị trường tài sản mã hoá. Sàn cung cấp:

- **Spot trading** — giao dịch giao ngay BTC, ETH, altcoin, stablecoin
- **Deposit / Withdrawal** — nạp/rút tài sản qua blockchain (crypto) và ngân hàng (fiat VND)
- **KYC / AML** — eKYC + on-chain AML screening
- **Custodial wallet** — sàn quản lý private key user qua MPC custody

**Strategic partnership:** CEX có partnership với **một sàn đối tác** (Korean exchange parent của Upbit). Session sharing, JWT JWKS verification, mTLS callback qua ACM PCA.

---

## Compliance Framework (Việt Nam)

| Văn bản | Phạm vi áp dụng |
|---|---|
| **Nghị quyết 05/2025/NQ-CP** (9/9/2025) | Thí điểm thị trường tài sản mã hoá. Bộ Tài chính giám sát. Vốn tối thiểu 10,000 tỷ VND. Sở hữu nước ngoài ≤ 49%. |
| **Luật Công nghiệp Công nghệ số 71/2025/QH15** (1/1/2026) | Định nghĩa tài sản mã hoá |
| **Tiêu chuẩn ATTT Cấp độ 4** | Yêu cầu kỹ thuật bắt buộc cho sàn. §9.1: log retention 24 tháng |
| **Nghị định 356/2025/NĐ-CP** | Bảo vệ dữ liệu cá nhân. PII của user VN phải lưu tại VPC-VN |
| **Luật Phòng chống rửa tiền 2022** | AML/CFT. KYC retention ≥ 5 năm sau đóng tài khoản |

---

## Architecture Zones

CEX infrastructure được phân vùng:

| Zone | Vị trí | Chứa | Constraint |
|---|---|---|---|
| **Z4 (VPC-VN)** | Việt Nam | PII, KYC data, CCCD, selfie, biometric | **BẮT BUỘC** cho PII. KHÔNG replicate ra Singapore |
| **VPC-1** | AWS Singapore (ap-southeast-1) | App services, trading engine, non-PII data | Cross-VPC mTLS qua ACM PCA |
| **VPC-2** | AWS Singapore | Hạ tầng phụ trợ | Cross-VPC mTLS |
| **Shared Services VPC** | AWS Singapore | Argo CD Hub, VPC Endpoints | Hub-and-Spoke control plane |

**EKS Multi-Cluster:**
- **Cluster A** — Application Processing (orders-svc, payment-svc, user-facing API)
- **Cluster B** — Signing & Verification Critical (signing-svc, MPC operations) — internal-only ALB
- **Hub Cluster** — Argo CD GitOps control plane (Shared Services VPC)

---

## Core Domain Concepts

| Term | Definition |
|---|---|
| **User** | Khách hàng đã đăng ký, status: basic / verified / full |
| **Wallet** | Bản ghi balance của user theo currency (Aurora MySQL) |
| **Balance** | available + locked, luôn ≥ 0, invariant qua mọi operation |
| **Order** | Lệnh mua/bán trên orderbook |
| **Trade** | Giao dịch khớp lệnh từ matching engine |
| **Deposit** | Nạp tài sản từ blockchain hoặc fiat VND |
| **Withdrawal** | Rút tài sản ra blockchain hoặc tài khoản ngân hàng |
| **Hot wallet** | Online, chứa <5%, withdrawal tự động |
| **Warm wallet** | Online, 2-of-3 multisig, thanh khoản trong ngày |
| **Cold wallet** | Air-gapped, >90%, HSM lưu trữ khoá, phê duyệt vật lý 3-of-5 |
| **MPC** | Multi-Party Computation + HSM, kết hợp phần cứng bảo mật chuyên dụng cho từng phần khoá |
| **SmartOTP** | TOTP RFC 6238 implementation của CEX Mobile SDK |
| **Fund Password** | Mật khẩu phụ tách biệt Login Password, dùng cho withdrawal cao |
| **Risk Engine** | Service phát hiện anomaly: IP / device / location / velocity |
| **Kong** | API Gateway — L2 scope enforcement |
| **SDK v0.5** | Mobile SDK nội bộ. Có GAP list (Passkey, Device Attestation, TEE storage) chưa có |

---

## Critical Business Rules

### Balance Rules

1. Balance luôn ≥ 0. KHÔNG bao giờ âm.
2. Balance = available + locked. Tổng invariant qua mọi operation.
3. Mọi balance update **PHẢI atomic** với row-level lock (`SELECT ... FOR UPDATE`).
4. Balance dùng `Decimal`. **TUYỆT ĐỐI KHÔNG float.**

### Withdrawal — 3-Tier Threshold (VND)

| Ngưỡng | Yêu cầu |
|---|---|
| **Mọi crypto withdrawal** | **SmartOTP bắt buộc.** SMS OTP tuyệt đối không được dùng cho crypto. |
| **Mọi fiat withdrawal** | SmartOTP khuyến nghị. SMS OTP cho phép nếu < 100M VND. |
| ≥ 10M VND (hoặc 0.1 BTC) | Step-up authentication thêm vào yêu cầu cơ bản |
| > 100M VND fiat | **Chặn SMS OTP hoàn toàn.** Bắt buộc TOTP hoặc Passkey (bất kể crypto/fiat). |
| > 500M VND | **SmartOTP + Fund Password.** KHÔNG downgrade. |

### Withdrawal — Cooling Period

| Giá trị | Cooling |
|---|---|
| < 10M VND | Không có |
| 10M - 100M VND | 24h |
| > 100M VND | 48h |
| VIP / Tổ chức | 48h + CS duyệt thủ công |
| Forgot Password | Risk-based (do Risk Engine quyết định) |

### Withdrawal — Khác

1. **Idempotency-Key** bắt buộc (UUID client gửi).
2. **Whitelist address holding period:** 24h (giá trị thấp/trung) hoặc 48h (giá trị cao). Địa chỉ mới không thể rút trong window này.
3. Withdrawal tự động pause nếu Risk Engine detect bất thường (**Kill-Switch < 60 giây**).

### Authentication Rules

1. **Password:** Argon2id (`time_cost=3, memory_cost=65536, parallelism=4`). Bcrypt cost ≥ 12 là fallback.
2. **Generic error:** "Số điện thoại hoặc mật khẩu không đúng" — bất kể tài khoản tồn tại hay không.
3. **Constant-time comparison:** chống timing attack.
4. **Rate limit:** 5/phút/user, 20/phút/IP. Lockout 30 phút sau 5 fail (US-AUTH-001).
5. **MFA bắt buộc** cho mọi tài khoản sau đăng ký.
6. **Quick login:** 30 ngày rolling từ full re-auth gần nhất. Đổi device → full re-auth.
7. **Risk Engine check** mỗi refresh token (GOV-01.2): IP / device / location / velocity.

### JWT Scopes (Customer)

| Role | Scopes | Điều kiện |
|---|---|---|
| `customer:basic` | profile:read, balance:read, trade:read | Sau đăng ký, chưa KYC |
| `customer:verified` | + trade:create, deposit:create | KYC pass |
| `customer:full` | + withdrawal:create, bank:link | Liên kết ngân hàng |

### Internal RBAC

| Role | Quyền | Xác thực |
|---|---|---|
| trader | Nghiệp vụ giao dịch, báo cáo | SSO + MFA |
| admin | Quản lý user, cấu hình | SSO + MFA + VPN |
| ops | Hạ tầng, monitoring | SSO + MFA + VPN |
| security | Audit logs, công cụ bảo mật (read-only) | SSO + MFA + VPN |

### KYC / AML Rules

1. User chưa KYC: chỉ được deposit, KHÔNG được withdrawal.
2. PII (CCCD, selfie, biometric, số tài khoản NH): **chỉ lưu tại Z4 (VPC-VN)** — vi phạm = có thể mất giấy phép.
3. **Ghi nhận đồng ý** TRƯỚC khi thu thập PII: version policy, IP, time, scope, method (checkbox tường minh, KHÔNG pre-checked).
4. AML screening on-chain trước mỗi deposit/withdrawal. Địa chỉ blacklisted (OFAC, mixer) → flag manual review.
5. Right to delete: **pseudonymize PII** (không thể đảo ngược). Giữ lịch sử giao dịch (nghĩa vụ AML/CFT).

---

## Sensitive Data Classification — 4 Tier

| Tier | Ví dụ | Storage | Logging | API Response |
|---|---|---|---|---|
| **BÍ MẬT TUYỆT ĐỐI** | Wallet private key, seed phrase, KMS master key, HSM credentials | Chỉ trong hardware (KMS HSM, Secure Enclave) | **KHÔNG BAO GIỜ log** | **KHÔNG BAO GIỜ trả về** |
| **MẬT** | CCCD/CMND + ảnh, selfie, biometric, OTP secret, refresh token, fund password, device fingerprint (IMEI, serial, wlan_mac, android_id) | AES-256-GCM + KMS. PII chỉ tại Z4 | Mask: 2 đầu + 4 cuối. Không log plaintext | Mask trong response |
| **NỘI BỘ** | JWT access token, API key (external), user_id, transaction_id | Mã hóa khi lưu. API key trong AWS Secrets Manager | Log 4 ký tự cuối, không log full | Trường không nhạy cảm |
| **CÔNG KHAI** | JWKS public key, tỷ giá, market data, API doc | Lưu bình thường | Log tự do | Trả tự do |

---

## Mobile SDK v0.5 — GAP List (Phải fix trước go-live)

| Tính năng | Status | Mức độ |
|---|---|---|
| TOTP anti-replay (Redis TTL 90s) | GAP — server-side workaround | BẮT BUỘC |
| Device Attestation (Firebase App Check / iOS App Attest) | GAP | BẮT BUỘC trước go-live |
| TOTP secret trong Mobile TEE (Keystore / Secure Enclave) | GAP | BẮT BUỘC trước go-live |
| Passkey (FIDO2/WebAuthn) | Chưa có | BẮT BUỘC khi kích hoạt |
| Certificate Pinning enforcement | GAP | BẮT BUỘC |
| Liveness Detection cho Face Recognition | Chưa có | BẮT BUỘC |

---

## Tech Stack (high-level)

> **Implementation details:** xem `tech.md`.

- **Backend:** microservices, RESTful + WebSocket. Behind **Kong API Gateway** (L2 scope enforcement).
- **Database:** **Aurora MySQL** (transactional), **ElastiCache Redis** (cache, rate limit, jti blacklist, session).
- **Message queue:** MSK (Kafka) cho async processing.
- **Blockchain:** node RPC + indexer.
- **Custody:** MPC platform (hot/warm), hardware HSM (cold).
- **Compliance:** on-chain AML screening, transaction monitoring.
- **CI/CD:** GitLab CI → SAST+SCA → ECR → Argo CD (GitOps Hub-and-Spoke) → EKS Cluster A/B.
- **Secrets:** AWS Secrets Store CSI Driver (tmpfs mount qua IRSA). ESO là legacy pattern.
- **API domain:** `api.security.vn`

---

## What This Project Should NOT Do

- ❌ Implement crypto primitives from scratch
- ❌ Lưu private key ở file system thường (chỉ KMS/HSM/Secure Enclave)
- ❌ Xử lý money bằng float
- ❌ Cho phép withdrawal mà không idempotency key
- ❌ Log raw private key, password, full JWT, CCCD, biometric, device fingerprint plaintext
- ❌ Return internal error / stack trace ra client (chỉ error_id + generic message)
- ❌ Cho phép user truy cập resource không thuộc về họ — **trả 404, không 403** (chống BOLA)
- ❌ Lưu PII của user VN ngoài Z4 (VPC-VN) — vi phạm NĐ 356/2025
- ❌ Tin Kong L2 scope đơn thuần — phải tái xác thực L3 trong service cho Payment / Withdrawal / Bank Link / KYC
- ❌ Cho phép `s3:PutObject` direct từ workstation lên prod bucket (xem Mixin 2023, Bybit 2025)
- ❌ Hard-code AWS credentials — dùng IRSA
- ❌ Trust SMS OTP cho crypto withdrawal hoặc fiat > 100M VND
