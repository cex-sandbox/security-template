# Compliance & Regulatory Framework

> **Mục đích:** Hướng dẫn AI assistant về compliance requirements Việt Nam áp dụng cho CEX. Mọi feature liên quan PII, KYC, audit log, retention phải tuân thủ tài liệu này.

---

## Khung pháp lý Việt Nam

### 1. Nghị quyết 05/2025/NQ-CP (hiệu lực 09/09/2025) — Thí điểm CEX

- Bộ Tài chính giám sát thị trường tài sản mã hoá
- Vốn tối thiểu **10,000 tỷ VND**
- Sở hữu nước ngoài ≤ **49%**
- Sàn phải có ATTT Cấp độ 4

### 2. Luật Công nghiệp Công nghệ số 71/2025/QH15 (hiệu lực 01/01/2026)

- Định nghĩa pháp lý "tài sản mã hoá"
- Tách biệt với chứng khoán, tiền tệ

### 3. Tiêu chuẩn ATTT Cấp độ 4

- Yêu cầu kỹ thuật bắt buộc cho sàn
- **§9.1** — log retention 24 tháng (S3 Object Lock Compliance mode)
- Network segmentation, encryption at rest/transit, audit logging
- IR plan + DR plan documented

### 4. Nghị định 356/2025/NĐ-CP — Bảo vệ dữ liệu cá nhân (thay thế NĐ 13/2023, hiệu lực 01/01/2026). Cơ quan kiểm tra: Cục An ninh mạng (A05) — Bộ Công an

- **Điều 2** — Dữ liệu cá nhân thông thường (tên, DOB, địa chỉ, phone, email)
- **Điều 9** — Dữ liệu cá nhân nhạy cảm (CCCD, biometric, tài khoản NH) — cần đồng ý tường minh
- **Điều 16** — Quyền xoá dữ liệu (pseudonymization)
- **Điều 25** — Chuyển dữ liệu xuyên biên giới — cần DPIA + Legal approval
- Vi phạm = có thể mất giấy phép

### 5. Luật Phòng chống rửa tiền 2022

- KYC retention **≥ 5 năm sau đóng tài khoản**
- Audit transaction record (rút tiền, giao dịch) — tham khảo AML/FATF
- SAR (Suspicious Activity Report) cho NHNN

---

## Data Residency — BẮT BUỘC

### Zone Constraint

| Data Type | Zone | Region |
|---|---|---|
| **PII (CCCD, selfie, biometric, số TK ngân hàng)** | **Z4 (VPC-VN)** | Việt Nam |
| KYC consent records, AML decision | **Z4 (VPC-VN)** | Việt Nam |
| App services, trading engine, non-PII | VPC-1 | AWS Singapore (ap-southeast-1) |
| Public market data, JWKS | Anywhere | — |

❌ **KHÔNG được:**
- Replicate PII của user VN sang AWS Singapore
- S3 bucket KYC với region `ap-southeast-1`
- Transit PII qua VPC-1 (Singapore) trong response

### Cross-Border Transfer Checklist

Mọi transfer PII xuyên biên giới phải có:
- [ ] Cơ sở pháp lý (đồng ý user HOẶC nghĩa vụ pháp định)
- [ ] DPIA (Data Protection Impact Assessment) nếu cần
- [ ] **Legal team ký duyệt** — không tự ý thêm
- [ ] Audit log mỗi lần transfer (user_id, purpose, legal basis, timestamp)
- [ ] User informed nếu transfer dựa trên đồng ý

```python
# ✅ Pattern bắt buộc
MUC_DICH_DUOC_PHEP = {
    "bao_cao_nhnn": "Nghĩa vụ pháp định — Báo cáo AML/CFT cho NHNN",
    # Chỉ thêm sau khi Legal ký duyệt
}

def kiem_tra_co_so_phap_ly(muc_dich: str, user_id: str):
    if muc_dich not in MUC_DICH_DUOC_PHEP:
        raise ValueError(f"Mục đích '{muc_dich}' chưa được Legal duyệt")
    audit_log.write({"event": "cross_border_transfer", "purpose": muc_dich, ...})
```

---

## Retention Policy

| Data Type | Retention | Storage |
|---|---|---|
| **KYC data** (CCCD, selfie, profile) | ≥ 5 năm sau đóng tài khoản | Aurora MySQL VPC-VN, S3 VPC-VN (KMS encrypted) |
| **Transaction records** | Theo AML/FATF (consult Legal) | Aurora + S3 Object Lock |
| **Audit logs** (security events) | 24 tháng (ATTT L4 §9.1) | S3 Object Lock **Compliance mode** (immutable) |
| **Application logs** | 24 tháng | CloudWatch + S3 |
| **Consent records** | Theo retention KYC | DB VPC-VN |
| **Session / refresh token** | TTL ngắn (15 phút - 30 ngày) | Redis (jti blacklist) |

### Right to Delete (NĐ 356 Điều 16)

**KHÔNG xoá cứng** dữ liệu giao dịch — vi phạm AML.

✅ **Pseudonymization pattern:**

```python
async def pseudonymize_pii(user_id: str, db_vn):
    salt = secrets.token_hex(16)
    pseudonym = hashlib.sha256(f"DELETED:{user_id}:{salt}".encode()).hexdigest()

    await db_vn.update_user_pii(user_id, {
        "usrfullname":    pseudonym[:16],
        "mobilenumber":   "DELETED",
        "usremail":       "DELETED",
        "usrgovidnum":    "DELETED",
        "cccd_image_ref": None,
        "selfie_ref":     None,
        "usrbnkacctnum":  "DELETED",
        "pii_deleted_at": now_utc(),
        "deletion_reason": "user_request",
    })
    # KHÔNG xoá: transaction history, audit log, order history
```

---

## Consent Management — Bắt buộc TRƯỚC khi thu thập PII

```python
async def record_consent(user_id, policy_version, ip, scope, db_vn):
    consent = {
        "user_id":         user_id,
        "policy_version":  policy_version,        # "privacy-policy-v2.1"
        "timestamp":       now_utc(),
        "ip_address":      ip,
        "scope":           scope,                  # ["kyc", "aml", "marketing"]
        "method":          "explicit_checkbox",    # KHÔNG pre-checked
        "withdrawable":    True,                   # User có quyền rút lại
    }
    await db_vn.save_consent(consent)  # DB VPC-VN
```

❌ **KHÔNG:**
- Pre-checked checkbox
- Bundled consent (one checkbox cho nhiều scope)
- Thu thập PII trước khi user click consent
- Lưu consent ngoài Z4

---

## Audit Logging Requirements

### Events bắt buộc log

- Authentication: login success/fail, MFA, password change, account lock
- Authorization: scope check, role change, admin actions
- PII access: read/write/delete on KYC, CCCD, biometric
- Withdrawal: create, approve, reject, settle
- Cross-border PII transfer
- Security events: rate limit hit, anomaly detection, kill-switch trigger

### Audit log structure

```python
audit_log.write({
    "event":           "withdrawal_created",
    "user_id":         user_id,
    "actor":           token_payload["sub"],     # who performed
    "timestamp":       now_utc(),
    "correlation_id":  request.correlation_id,
    "ip":              request.ip,
    "device_id":       token_payload["device_id"],
    "risk_level":      risk_engine_result,        # LOW/MEDIUM/HIGH
    "result":          "success",                 # success/failure/blocked
    # Mask sensitive fields
    "address_masked":  f"{address[:6]}...{address[-4:]}",
    "amount":          str(amount),               # Decimal as string
})
```

### Storage requirements

- **S3 Object Lock Compliance mode** — immutable, không thể xoá trong retention period
- 24 tháng retention minimum (ATTT L4 §9.1)
- Mã hoá KMS at rest
- CloudTrail integration cho AWS API events

❌ **KHÔNG log:**
- Password, OTP, private key, seed phrase, refresh token plaintext
- CCCD full, biometric template
- Device fingerprint (IMEI, serial, wlan_mac, android_id) plaintext

---

## Compliance Checks trong Code Review

PR liên quan compliance phải có:

- [ ] **Withdrawal / Payment:** L3 verification trong service (không tin Kong L2)
- [ ] **KYC / PII:** chỉ access tại Z4 (VPC-VN). Không cross-VPC PII transfer.
- [ ] **Auth:** Argon2id, generic error, rate limit, constant-time
- [ ] **Audit log:** đầy đủ correlation_id, mask PII, S3 Object Lock target
- [ ] **Consent:** ghi nhận TRƯỚC khi thu thập PII
- [ ] **Retention:** không hard-delete PII (chỉ pseudonymize)
- [ ] **Cross-border:** Legal approval + kiem_tra_co_so_phap_ly()
- [ ] **Encryption:** AES-256-GCM, KMS envelope, không hard-code key

---

## Reference Documents (Internal Confluence)

- `authentication-best-practice` — Argon2id, SmartOTP, withdrawal 3-tier
- `authorization-and-rbac` — JWT scopes, L3 re-verification, BOLA defense
- `passwordless-and-mfa` — TOTP, Passkey, SDK v0.5 GAP
- `API_Authentication` — 4 patterns (Customer/Service/một sàn đối tác/Bank)
- `pii-protection` — Nghị định 356/2025 chi tiết
- `sensitive-data-handling` — 4-tier classification
- `encryption-best-practices` — Algorithm whitelist
- `data-in-transit-and-rest` — TLS, mTLS, KMS envelope
- `Kubernetes_Security`, `Workload_Identity`, `Network_Security` — Infrastructure
- `Mobile_App_Security` — Android/iOS hardening
