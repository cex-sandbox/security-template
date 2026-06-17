# Authentication & Authorization Rules

## HARDCODED-SECRET — CRITICAL

**Trigger:** String literals chứa pattern `sk_live_*`, `sk_test_*`, `AKIA*`, `gh[pousr]_*`, `eyJ*` (JWT), private keys (`-----BEGIN`), passwords ≥ 8 chars hardcode trong code.

**Data flow:** Không cần — chỉ cần secret tồn tại trong source.

**Skip:**
- Test files (`*test*.py`, `*spec*.js`, `tests/`)
- Example files (`.env.example`, `*.example.*`)
- Comments
- Constants explicitly marked `# pragma: allowlist secret`

**Bad:**
```python
API_KEY = "sk_live_abc123xyz789"
DB_PASSWORD = "ProductionPass2024"
```

**Good:**
```python
import os
API_KEY = os.environ["API_KEY"]
DB_PASSWORD = secrets_manager.get("db/password")
```

**Vì sao:** Secret trong code → đẩy lên git → lộ toàn bộ lịch sử. Vụ Mixin/Bybit khởi đầu từ workstation Dev bị lấy credentials.

---

## WEAK-PASSWORD-HASHING — CRITICAL

**Trigger:** `hashlib.md5`, `hashlib.sha1`, `hashlib.sha256` cho password (không phải data integrity).

**Data flow:** L1 (password user) → hash function → store DB.

**Skip:** Hash cho file integrity, ETag, cache key (không phải password).

**Bad:**
```python
hashed = hashlib.sha256(password.encode()).hexdigest()
```

**Good:**
```python
from argon2 import PasswordHasher
ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)
hashed = ph.hash(password)
```

**Vì sao:** SHA-256 nhanh → hacker dò 1 tỷ password/giây trên GPU. Argon2id chậm intentionally → 1 password/giây → không thể brute-force.

---

## JWT-NONE-ALGORITHM — CRITICAL

**Trigger:** `jwt.decode(token, algorithms=["none"])` hoặc `algorithms=[]` hoặc thiếu `algorithms` param.

**Data flow:** Token từ L1 (HTTP header) → decode → trust claims.

**Bad:**
```python
payload = jwt.decode(token, algorithms=["none"])
payload = jwt.decode(token)  # Thiếu algorithms = mặc định cho phép none
```

**Good:**
```python
payload = jwt.decode(token, public_key, algorithms=["RS256"])
```

**Vì sao:** Hacker tạo token với `alg: none` → server không verify chữ ký → giả làm bất kỳ user nào.

---

## JWT-HS256-CONFUSION — HIGH

**Trigger:** `jwt.decode(token, public_key, algorithms=["HS256"])` — dùng RSA public key làm HMAC secret.

**Data flow:** Public key (L4) bị dùng như secret (L4 confusion).

**Bad:**
```python
payload = jwt.decode(token, RSA_PUBLIC_KEY, algorithms=["HS256"])
```

**Good:**
```python
payload = jwt.decode(token, RSA_PUBLIC_KEY, algorithms=["RS256"])
```

**Vì sao:** Hacker biết public key (public!) → ký token với HMAC dùng public key → server verify pass → bypass auth.

---

## IDOR — HIGH

**Trigger:** Endpoint nhận `id` param → query DB → return data **không kiểm tra ownership**.

**Data flow:** L1 (URL param `/orders/<id>`) → query DB → return result trực tiếp.

**Skip:** Có check `WHERE user_id = current_user.id` hoặc tương đương.

**Bad:**
```python
@app.route('/orders/<order_id>')
def get_order(order_id):
    return db.query(f"SELECT * FROM orders WHERE id = {order_id}")
```

**Good:**
```python
@app.route('/orders/<order_id>')
def get_order(order_id):
    order = db.query(
        "SELECT * FROM orders WHERE id = %s AND user_id = %s",
        (order_id, current_user.id)
    )
    if not order:
        abort(404)  # 404 không 403 — tránh enumeration
    return order
```

**Vì sao:** User A đổi URL từ `/orders/12345` → `/orders/12346` xem được đơn hàng user B. Hacker duyệt 1→1M lấy toàn bộ giao dịch.

---

## BROKEN-ACCESS-CONTROL — CRITICAL

**Trigger:** Endpoint admin/sensitive thiếu authorization check ở tầng service.

**Data flow:** L1 (request) → handler → action **không verify role/permission**.

**Skip:** Có decorator `@require_role('admin')` hoặc check explicit `if current_user.role != 'admin': abort(403)`.

**Bad:**
```python
@app.route('/admin/users/<user_id>/delete', methods=['POST'])
def delete_user(user_id):
    db.execute("DELETE FROM users WHERE id = %s", (user_id,))
```

**Good:**
```python
@app.route('/admin/users/<user_id>/delete', methods=['POST'])
@require_role('admin')  # L3 re-verification
def delete_user(user_id):
    if current_user.role != 'admin':
        abort(403)
    db.execute("DELETE FROM users WHERE id = %s", (user_id,))
```

**Vì sao:** Không tin Kong L2 đơn thuần. Hacker có thể bypass gateway → gọi thẳng service nội bộ → action admin mà không có quyền.
