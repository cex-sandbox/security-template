# Data Protection & Logging

> Bảo vệ dữ liệu cá nhân (NĐ 356/2025), ghi nhật ký an toàn.

### 8. PII Protection — Nghị định 356/2025

⚠️ Vi phạm = có thể mất giấy phép.

**Phân loại — 4 tier (CEX):**

| Tier | Ví dụ | Xử lý |
|---|---|---|
| **BÍ MẬT TUYỆT ĐỐI** | Wallet private key, seed phrase, KMS master key, HSM creds | Chỉ trong KMS HSM / Secure Enclave. KHÔNG persist ra disk/network ngoài KMS/HSM boundary. KHÔNG BAO GIỜ log. KHÔNG BAO GIỜ vào API response. *(Lưu ý: key phải load vào secure memory trong lúc ký — đây là bình thường; cấm là persist/export ra ngoài KMS.)* |
| **MẬT** (NĐ 356 Điều 9) | CCCD/CMND + ảnh, selfie, biometric, OTP secret, refresh token, fund password, device fingerprint (IMEI, serial, wlan_mac, android_id), số TK ngân hàng | Đồng ý tường minh + AES-256-GCM + KMS envelope encryption. **Chỉ tại Z4 (VPC-VN).** KHÔNG transit qua VPC-1 (Singapore). Mask trong log (2 đầu + 4 cuối). |
| **NỘI BỘ** (NĐ 356 Điều 2) | JWT access token, API key external, user_id, transaction_id, tên, DOB, địa chỉ, phone, email | Mã hóa khi lưu. Mask trong API response. Log chỉ 4 ký tự cuối token, jti, hoặc id. |
| **CÔNG KHAI** | JWKS public key, tỷ giá, market data | Lưu / log / response tự do |

**Quy tắc cốt lõi:**
- ✅ **Data residency:** PII của user VN PHẢI tại Z4 (VPC-VN). KHÔNG replicate sang AWS Singapore. KHÔNG transit qua VPC-1.
- ✅ **Minimization:** chỉ thu thập PII cần thiết. Mask trong response (CCCD → `"03****8743"`).
- ✅ **Consent:** TRƯỚC khi thu thập, lưu version policy + IP + time + scope + method (checkbox tường minh, KHÔNG pre-checked). Người dùng có thể rút lại đồng ý.
- ✅ **Cross-border transfer:** cần cơ sở pháp lý (đồng ý hoặc nghĩa vụ pháp định) + DPIA + **Legal phải ký duyệt**. Audit log mỗi lần transfer.
- ✅ **Right to delete:** pseudonymize PII (không đảo ngược). Giữ lịch sử giao dịch (nghĩa vụ AML/CFT).
- ✅ **Retention:** KYC ≥ 5 năm sau đóng tài khoản. Audit logs 24 tháng (S3 Object Lock Compliance mode, ATTT L4 §9.1). App logs 24 tháng.

```python
def mask_cccd(cccd: str) -> str:
    if len(cccd) < 8: return "***"
    return f"{cccd[:2]}{'*' * (len(cccd) - 6)}{cccd[-4:]}"

def mask_email(email: str) -> str:
    user, domain = email.split("@", 1)
    return f"{user[0]}***@{domain}"

def mask_phone(phone: str) -> str:
    return f"{phone[:3]}***{phone[-4:]}"

def mask_bank_account(acc: str) -> str:
    return f"****{acc[-4:]}"
```

### 9. Logging & Errors

❌ KHÔNG log: password, token, full JWT, private key, CCCD, full card, CVV, biometric.

✅ Mask PII trong logs. Generic error ra client. Correlation ID cho mỗi request.

```python
import uuid

correlation_id = str(uuid.uuid4())

try:
    process_withdrawal(...)
except Exception:
    logger.exception("withdrawal failed", extra={"correlation_id": correlation_id})
    return jsonify({
        "error": "Internal error",
        "correlation_id": correlation_id
    }), 500

# Audit log:
audit_logger.info("user_login", extra={
    "user_id": user.id,
    "email_masked": mask_email(user.email),
    "ip": request.ip,
    "correlation_id": correlation_id,
})
```

✅ Fail Securely: default deny khi exception.
