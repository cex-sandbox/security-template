# Authentication & Authorization

> Chi tiết quy tắc bảo mật cho xác thực, phân quyền, và kiểm tra đầu vào.

### 1. Password Hashing — Argon2id (không phải bcrypt thông thường)

✅ **Argon2id** ưu tiên với tham số chuẩn CEX: `time_cost=3, memory_cost=65536 (64MB), parallelism=4`. Bcrypt cost ≥ 12 là fallback.
❌ TUYỆT ĐỐI KHÔNG dùng SHA-256, MD5, SHA-1 cho password.

```python
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
import hmac

ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)
GENERIC_ERROR = "Số điện thoại hoặc mật khẩu không đúng"

def login(phone, password, db, rate_limiter):
    if rate_limiter.is_locked(phone):
        raise HTTPException(429, "Tài khoản tạm khoá")
    user = db.find_user_by_phone(phone)
    if not user:
        # Hash giả — chống timing attack
        hmac.compare_digest(password.encode(), b"dummy")
        rate_limiter.record_failure(phone)
        raise HTTPException(401, GENERIC_ERROR)
    try:
        ph.verify(user.password_hash, password)
    except VerifyMismatchError:
        rate_limiter.record_failure(phone)
        raise HTTPException(401, GENERIC_ERROR)
    rate_limiter.reset(phone)
    return issue_tokens(user)
```

✅ **Generic error** cho mọi auth failure — chống account enumeration.
✅ **Rate limit:** 5/phút/user, 20/phút/IP. Lock 30 phút sau 5 fail (US-AUTH-001).
✅ **SmartOTP anti-replay:** mark used trong Redis TTL 90s, window ±1 step. (SDK v0.5 GAP — implement server-side).
✅ **Withdrawal 3 tầng (VND):**
- Mọi withdrawal: SmartOTP bắt buộc. SMS OTP KHÔNG dùng cho crypto withdrawal.
- ≥ 10M VND (0.1 BTC): step-up authentication.
- > 100M VND fiat: chặn SMS OTP hoàn toàn, bắt buộc TOTP/Passkey.
- > 500M VND: SmartOTP + Fund Password. KHÔNG downgrade.

✅ **Cooling period:** 0 (< 10M) / 24h (10-100M) / 48h (> 100M) / 48h+CS (VIP).
✅ **Holding period địa chỉ mới:** 24h (giá trị thấp/trung) hoặc 48h (cao).
✅ **Risk Engine check** mỗi refresh token (GOV-01.2): IP / device / location / velocity.
✅ **Quick login** 30 ngày rolling từ full re-auth. Đổi device → full re-auth bắt buộc.
✅ **Fund Password** tách biệt Login Password, Argon2id, rate limit riêng.
✅ **Passkey (FIDO2)** ưu tiên cao nhất khi user đã kích hoạt.
✅ **Biometric**: token Secure Enclave PHẢI Backend validate — không chỉ unlock cục bộ.

### 2. JWT — RS256 qua KMS + IRSA

CEX có **4 mẫu authentication:**
1. JWT RS256/KMS cho khách hàng CEX
2. Service-to-service qua IRSA (GOV-01.1)
3. JWT đối tác một sàn đối tác xác minh qua JWKS
4. API key + HMAC-SHA256 cho ngân hàng / KYT / AML provider

❌ KHÔNG `alg: none`, KHÔNG `verify=False`, KHÔNG dùng HS256.
❌ KHÔNG dùng `jwk`, `jku`, `x5u` claim trong header (chống public key injection).
✅ Specify algorithm explicit (RS256), verify signature/exp/iss/aud, lookup key theo `kid` từ JWKS.

```python
import jwt
from jwt import PyJWKClient

jwks_client = PyJWKClient(JWKS_URL)
signing_key = jwks_client.get_signing_key_from_jwt(token).key

payload = jwt.decode(
    token, signing_key,
    algorithms=["RS256"],
    audience="security-api",
    issuer="auth.security.vn",
    options={"verify_signature": True, "verify_exp": True}
)
```

✅ Access token TTL 15 phút. Refresh token rotate khi dùng + device binding (GOV-01.2) + Risk Engine check.
✅ **Tái xác thực L3** tại service cho Payment / Withdrawal / Bank Link / KYC — KHÔNG tin Kong L2 đơn thuần.
✅ **device_id trong JWT** phải match `device_id` trong request (GOV-01.2).
✅ **một sàn đối tác callback:** xác minh mTLS client certificate (ACM PCA) — không tin tầng mạng.

### 7. Input Validation

✅ Server-side, 4 check: type, length, format, range.
❌ KHÔNG dùng `pickle.load()`, `yaml.load()` (without SafeLoader), `eval()`, `exec()` trên untrusted input.

```python
from decimal import Decimal, InvalidOperation
import re

def create_withdrawal(req):
    try:
        amount = Decimal(req.json["amount"])
        if amount <= 0 or amount > Decimal("1000000"):
            raise ValueError()
        address = req.json["address"]
        if not isinstance(address, str) or len(address) > 100:
            raise ValueError()
        if not re.match(r"^0x[a-fA-F0-9]{40}$", address):
            raise ValueError()
    except (ValueError, KeyError, InvalidOperation):
        return "Invalid input", 400
```
