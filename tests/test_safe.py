"""
Safe code patterns — Semgrep rules KHÔNG được flag file này.
Dùng để verify rules không false positive.

Chạy: semgrep --config .semgrep/rules/security.yml tests/test_safe.py
Kết quả mong đợi: 0 findings
"""

import os
import secrets
import hashlib
import subprocess
from decimal import Decimal
import yaml

# ===== PASSWORD & HASHING =====
# OK: dùng SHA-256 cho integrity (không phải password)
digest = hashlib.sha256(b"data").hexdigest()
digest3 = hashlib.sha3_256(b"data").hexdigest()

# OK: dùng secrets cho token
token = secrets.token_hex(32)
otp = secrets.randbelow(1000000)
session_id = secrets.token_urlsafe(64)

# ===== MONEY / DECIMAL =====
# OK: Decimal cho money
amount: Decimal = Decimal("100.00")
balance = Decimal("500.00") + Decimal("100.00")
fee = Decimal("0.001")
total = amount + fee

# OK: float cho non-money
ratio = 0.5
percentage = 3.14

# ===== ENVIRONMENT VARIABLES =====
# OK: lấy secret từ env
API_KEY = os.environ.get("API_KEY")
secret = os.environ.get("DB_SECRET")
password = os.environ.get("DB_PASSWORD")
token_value = os.environ.get("JWT_TOKEN")

# ===== SUBPROCESS =====
# OK: shell=False (default), list args
result = subprocess.run(["ls", "-la"], capture_output=True)
result2 = subprocess.call(["echo", "hello"])

# ===== YAML =====
# OK: safe_load
with open("config.yaml") as f:
    config = yaml.safe_load(f)

# OK: yaml.load với SafeLoader
with open("config2.yaml") as f:
    config2 = yaml.load(f, Loader=yaml.SafeLoader)

# ===== PARAMETERIZED QUERY =====
# OK: parameterized query (không f-string)
def get_wallet(db, wallet_id: int, user_id: int):
    return db.query_one(
        "SELECT * FROM wallets WHERE id = %s AND user_id = %s",
        (wallet_id, user_id)
    )

def get_order(db, order_id: int, user_id: int):
    return db.query_one(
        "SELECT * FROM orders WHERE id = %s AND user_id = %s LIMIT 1",
        (order_id, user_id)
    )

# ===== ERROR MESSAGES (không phải secret) =====
# OK: string gán vào biến tên có "password" nhưng là message (có spaces)
password_error = "Mật khẩu không đúng định dạng"
token_expired = "Phiên đăng nhập đã hết hạn"
secret_question = "Tên thú cưng đầu tiên của bạn?"

# ===== AES-GCM với nonce ngẫu nhiên =====
# OK: os.urandom mỗi lần encrypt
def encrypt_safe(key: bytes, data: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    nonce = os.urandom(12)  # random mỗi lần — đúng
    return AESGCM(key).encrypt(nonce, data, None)
