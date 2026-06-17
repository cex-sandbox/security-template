# Encryption & Key Management Rules

## WEAK-CRYPTO-MODE — HIGH

**Trigger:** AES mode ECB, DES, 3DES, RC4, Blowfish được dùng để encrypt data.

**Data flow:** N/A — crypto config rule.

**Bad:**
```python
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
cipher = Cipher(algorithms.AES(key), modes.ECB())  # ECB!
cipher = Cipher(algorithms.TripleDES(key), modes.CBC(iv))  # 3DES
```

**Good:**
```python
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os
nonce = os.urandom(12)
aesgcm = AESGCM(key)
ciphertext = aesgcm.encrypt(nonce, plaintext, associated_data)
```

**Vì sao:** ECB encrypt cùng plaintext → cùng ciphertext → lộ pattern (vd: ảnh ECB encrypted vẫn nhận diện được). AES-GCM là AEAD: vừa encrypt vừa authenticate, ngăn tamper.

---

## HARDCODED-KEY — CRITICAL

**Trigger:** Crypto key (AES key, RSA private, HMAC secret) là string literal trong code.

**Data flow:** Key material hardcoded.

**Bad:**
```python
AES_KEY = b"my_super_secret_key_32_bytes_!!"
HMAC_SECRET = "shared_secret_for_jwt"
```

**Good:**
```python
import boto3
kms = boto3.client('kms')
# Key không leave KMS
ciphertext = kms.encrypt(KeyId='alias/data-encryption', Plaintext=data)
```

---

## STATIC-NONCE — HIGH

**Trigger:** AES-GCM/ChaCha20 dùng nonce constant, đếm tăng dần, hoặc tái sử dụng.

**Data flow:** Nonce không random per encryption.

**Bad:**
```python
NONCE = b"\x00" * 12  # Static
nonce = counter.to_bytes(12, 'big'); counter += 1  # Predictable
```

**Good:**
```python
import os
nonce = os.urandom(12)  # Random per message
# Hoặc dùng AES-GCM-SIV (nonce misuse resistant)
```

**Vì sao:** Tái sử dụng nonce trong GCM = thảm hoạ. Hacker XOR 2 ciphertext có cùng nonce → recover plaintext + authentication key → forge messages.

---

## INSECURE-RANDOM — HIGH

**Trigger:** `random.randint`, `Math.random()`, `rand()` cho security context (token, password, OTP, session ID, nonce, IV).

**Data flow:** Random output → security-sensitive use.

**Skip:** `random` cho non-security (game logic, UI animation, A/B test bucket).

**Bad:**
```python
import random
otp = random.randint(100000, 999999)
session_id = ''.join(random.choices('abcdef0123456789', k=32))
```

**Good:**
```python
import secrets
otp = secrets.randbelow(900000) + 100000
session_id = secrets.token_hex(32)
```

```javascript
// Bad
const otp = Math.floor(Math.random() * 900000) + 100000;

// Good
const otp = crypto.randomInt(100000, 1000000);
const sessionId = crypto.randomBytes(32).toString('hex');
```

**Vì sao:** `random` là Mersenne Twister — predictable nếu hacker có vài output. `secrets`/`crypto` dùng OS entropy pool — cryptographically secure.
