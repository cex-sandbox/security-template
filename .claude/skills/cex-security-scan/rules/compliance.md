# Vietnamese Compliance Rules — NĐ 356/2025

## PII-WRONG-REGION — CRITICAL

**Trigger:** Code lưu/xử lý PII của user VN trong vùng không phải VN (`ap-southeast-1` Singapore, `us-east-1`, etc).

**Data flow:** PII (CMND/CCCD, ảnh selfie, sinh trắc, số tài khoản ngân hàng) → S3/RDS/cache → lưu ngoài Z4 (VPC-VN).

**Bad:**
```python
s3 = boto3.client('s3', region_name='ap-southeast-1')  # Singapore — KHÔNG được lưu PII ở đây
s3.put_object(Bucket='kyc-selfies', Key=f'{user_id}/selfie.jpg', Body=image)
```

**Good:**
```python
# PII phải lưu tại Z4 (VPC-VN) — on-prem hoặc private cloud tại Việt Nam
# Vietnam không có AWS region — dùng private storage nội địa
storage = VNPrivateStorage(zone='Z4')
storage.put_object(Bucket='kyc-selfies-vn-z4', Key=f'{user_id}/selfie.jpg', Body=image)
```

**Vì sao:** NĐ 356/2025 — PII của user VN PHẢI lưu tại VN (Zone Z4 trong kiến trúc). Việt Nam chưa có AWS region — lưu lên bất kỳ AWS region nào (kể cả ap-southeast-1 Singapore) đều vi phạm. Vi phạm: thu hồi giấy phép. A05 (Cục An ninh mạng) kiểm tra định kỳ.

---

## CONSENT-PRE-CHECKED — HIGH

**Trigger:** Checkbox consent có `checked=True`, `default=True`, hoặc `checked` attribute hardcoded.

**Data flow:** N/A — UI rule.

**Bad:**
```html
<input type="checkbox" name="marketing_consent" checked>
<input type="checkbox" name="data_share" value="1" checked="checked">
```

```python
# Backend
user.marketing_consent = data.get('marketing_consent', True)  # Default True!
```

**Good:**
```html
<input type="checkbox" name="marketing_consent">  <!-- Unchecked -->
```

```python
user.marketing_consent = data.get('marketing_consent', False)  # Default False
```

**Vì sao:** NĐ 356 Điều 6 — cấm mặc định đồng ý. Consent phải là affirmative action (user tự bấm). Pre-checked = vô hiệu pháp lý.

---

## LOG-SENSITIVE-DATA — HIGH

**Trigger:** Log statement chứa biến: `password`, `otp`, `cccd`, `cmnd`, `selfie`, `biometric`, `private_key`, `seed_phrase`, `api_key`, `token`, `pin`.

**Data flow:** Sensitive variable → log output (console, file, log service).

**Skip:** Log với explicit masking: `password=***`, `redact(password)`, `mask_pii(...)`.

**Bad:**
```python
logger.info(f"User login: phone={phone}, password={password}")
logger.debug(f"OTP sent: {otp_code} to {phone}")
logger.info(f"KYC submitted: cccd={cccd_number}")
```

**Good:**
```python
logger.info(f"User login: phone={mask_phone(phone)}")
logger.debug(f"OTP sent to phone ending {phone[-4:]}")
logger.info(f"KYC submitted for user_id={user_id}")  # ID nội bộ, không PII
```

**Vì sao:** Log file có thể bị truy cập rộng (DevOps, monitoring tools, log aggregator). Log PII = lộ PII. NĐ 356 yêu cầu PII chỉ accessible bởi authorized personnel.

---

## NO-RIGHT-TO-DELETE — HIGH

**Trigger:** User model/schema không có cơ chế "soft delete" hoặc "pseudonymize" khi user request xoá.

**Data flow:** N/A — model design rule.

**Bad:**
```python
class User(db.Model):
    id = db.Column(...)
    cccd = db.Column(db.String)
    full_name = db.Column(db.String)
    # Không có deleted_at hay pseudonymized_at
```

**Good:**
```python
class User(db.Model):
    id = db.Column(...)
    cccd = db.Column(db.String)  # Sẽ được pseudonymize khi delete request
    full_name = db.Column(db.String)
    deleted_at = db.Column(db.DateTime, nullable=True)
    pseudonymized = db.Column(db.Boolean, default=False)

def handle_delete_request(user_id):
    user = User.query.get(user_id)
    user.cccd = f"DELETED_{hash(user.cccd)}"  # Pseudonymize không xoá
    user.full_name = "DELETED"
    user.pseudonymized = True
    user.deleted_at = datetime.utcnow()
    # Giữ user_id cho lịch sử giao dịch (PCRT yêu cầu 5 năm)
```

**Vì sao:** NĐ 356 cho user quyền xoá. Nhưng PCRT 2022 yêu cầu lưu lịch sử giao dịch 5 năm. Giải pháp: pseudonymize (xoá PII nhưng giữ ID).

---

## CROSS-BORDER-NO-DPIA — HIGH

**Trigger:** Code transfer PII ra khỏi VN không có check DPIA approval flag.

**Data flow:** PII (L1/L2) → external API/region → no compliance check.

**Bad:**
```python
def share_kyc_with_partner(user_id):
    user = User.query.get(user_id)
    requests.post('https://partner.com/api/kyc', json=user.to_dict())
```

**Good:**
```python
def share_kyc_with_partner(user_id):
    # Check DPIA approved
    if not user.dpia_consent or not partner.dpia_approved_by_a05:
        raise ComplianceError("DPIA chưa được duyệt hoặc thiếu thông báo A05")
    user = User.query.get(user_id)
    requests.post('https://partner.com/api/kyc', json=user.to_dict())
```

**Vì sao:** NĐ 356 yêu cầu DPIA (Data Protection Impact Assessment) + thông báo A05 trước khi chuyển PII xuyên biên giới.
