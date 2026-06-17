# Wallet & Crypto Operations Rules

## WALLET-HOT-LIMIT — CRITICAL

**Trigger:** Ví nóng (hot wallet) chứa > 10% tổng tài sản, hoặc không có hard cap configured.

**Data flow:** N/A — config/architecture rule.

**Cách check:** Tìm config wallet allocation. Verify hot wallet có max_balance hoặc % threshold.

**Bad:**
```python
HOT_WALLET_CONFIG = {
    "max_balance": None,  # Không giới hạn
    "auto_sweep_threshold": None,
}
```

**Good:**
```python
HOT_WALLET_CONFIG = {
    "max_balance": Decimal("100000"),  # USD equivalent
    "auto_sweep_threshold": Decimal("80000"),  # Sweep về warm/cold khi đạt
    "sweep_to": "warm_wallet_id",
}
```

**Vì sao:** Upbit 2019 — toàn bộ tài sản trong hot wallet → hacker chiếm 1 lần mất hết. Three-tier wallet (hot 1-5% / warm / cold > 90%) giới hạn thiệt hại.

---

## WITHDRAWAL-NO-WHITELIST — HIGH

**Trigger:** Endpoint rút tiền cho phép địa chỉ ví **mới** rút ngay, không có cooling period.

**Data flow:** L1 (địa chỉ ví do user submit) → withdraw → không check whitelist.

**Skip:** Có check `WHERE wallet_address IN (whitelisted_addresses)` + `whitelisted_at < NOW() - 24h`.

**Bad:**
```python
def withdraw(user_id, to_address, amount):
    return chain.send(from_wallet, to_address, amount)
```

**Good:**
```python
def withdraw(user_id, to_address, amount):
    whitelist = db.query(
        """SELECT 1 FROM whitelisted_addresses
           WHERE user_id = %s AND address = %s
           AND whitelisted_at < NOW() - INTERVAL '24 hours'""",
        (user_id, to_address)
    )
    if not whitelist:
        raise NotWhitelisted("Địa chỉ chưa đủ 24h chờ")
    return chain.send(from_wallet, to_address, amount)
```

**Vì sao:** Hacker chiếm tài khoản → thêm địa chỉ ví của mình → rút ngay. Cooling 24h cho chủ tài khoản phát hiện + chặn.

---

## MPC-WEAK-NONCE — CRITICAL

**Trigger:** MPC/threshold signature implementation dùng `random.randint`, `Math.random()`, hoặc nonce có entropy thấp.

**Data flow:** N/A — implementation rule cho crypto operation.

**Bad:**
```python
import random
nonce = random.randint(0, 2**256)  # Predictable!
```

**Good:**
```python
import secrets
nonce = secrets.randbits(256)  # Cryptographically secure
# Hoặc dùng HSM-backed RNG
```

**Vì sao:** Nonce có entropy thấp trong ECDSA/Schnorr → hacker thu thập nhiều chữ ký → dùng lattice attack recover private key. Đây là kỹ thuật tấn công đã được chứng minh trên nhiều blockchain implementation dùng non-CSPRNG (Sony PS3 2010, nhiều cold wallet tự cài đặt). MPC với biased nonce có thể bị crack sau vài chục chữ ký.

---

## HSM-NOT-USED — HIGH

**Trigger:** Code generate/store private key, signing key, master key, KMS root key trong filesystem hoặc env var.

**Data flow:** Sensitive key material → not in HSM.

**Skip:** Key được tham chiếu qua KMS API (`kms.sign`, `kms.decrypt`), không có direct access.

**Bad:**
```python
PRIVATE_KEY = open('/etc/wallet/private.pem').read()  # File system
PRIVATE_KEY = os.environ['WALLET_KEY']  # Env var
```

**Good:**
```python
# AWS KMS — key không bao giờ leave HSM
import boto3
kms = boto3.client('kms')
signature = kms.sign(
    KeyId='alias/wallet-signing-key',
    Message=tx_hash,
    SigningAlgorithm='ECDSA_SHA_256'
)
```

**Vì sao:** Key trong filesystem → ai có quyền đọc file là có khoá. HSM/KMS: key trong hardware chuyên dụng, chỉ sign được, không export được.

---

## COLD-WALLET-ONLINE — CRITICAL

**Trigger:** Code có endpoint/API trực tiếp gửi giao dịch từ cold wallet (không qua quy trình phê duyệt vật lý).

**Data flow:** L1/L2 → direct cold wallet operation.

**Bad:**
```python
@app.route('/admin/cold-withdraw', methods=['POST'])
def cold_withdraw():
    return cold_wallet.send(request.json)
```

**Good:**
```python
# Cold wallet không có endpoint network
# Withdrawal từ cold wallet phải:
# 1. Tạo unsigned tx online
# 2. Export qua USB/QR code
# 3. Sign offline trên air-gapped machine (HSM)
# 4. Import signed tx qua USB/QR
# 5. Broadcast
```

**Vì sao:** Cold wallet phải air-gapped. Có endpoint network = không còn "cold".
