"""
Test fixture — intentionally vulnerable code (HIGH / Semgrep WARNING).
Dùng bởi scripts/test-ci-local.sh để verify HIGH rules warn nhưng KHÔNG block CI.
KHÔNG dùng code này trong production.

Expected:
  semgrep --severity=ERROR   --error → exit 0 (MR KHÔNG bị block)
  semgrep --severity=WARNING --error → exit 1 (warnings detected)
Test suite: 76/76 PASSED (xem scripts/test-ci-local.sh)
"""
import random
import logging
import jwt
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)

# ── FLOAT-FOR-MONEY (HIGH) ────────────────────────────────────────────────────
def calculate_fee(amount: float) -> float:
    fee: float = amount * 0.001
    return fee


# ── INSECURE-RANDOM (HIGH) ────────────────────────────────────────────────────
def generate_otp() -> int:
    return random.randint(100000, 999999)


# ── LOG-SENSITIVE-DATA (HIGH) — direct var ───────────────────────────────────
def handle_login(username: str, password: str):
    logger.info("Login attempt", password)


# ── LOG-SENSITIVE-DATA (HIGH) — %s format + authorization (Gap 2) ────────────
def handle_withdrawal(user_id: str, amount: float, authorization: str):
    logger.info("Withdrawal: user=%s amount=%s authorization=%s",
                user_id, amount, authorization)


# ── JWT-HS256-CONFUSION (HIGH) ────────────────────────────────────────────────
def decode_token(token: str, public_key: bytes):
    return jwt.decode(token, public_key, algorithms=["HS256"])


# ── STATIC-NONCE / AES-GCM-NONCE-REUSE (HIGH) — AESGCM variant ───────────────
def encrypt_data(key: bytes, data: bytes) -> bytes:
    nonce = b"fixednonce12"
    return AESGCM(key).encrypt(nonce, data, None)


# ── STATIC-NONCE / AES-GCM-NONCE-REUSE (HIGH) — cryptography.hazmat variant ──
def encrypt_hazmat_static_nonce(key: bytes, plaintext: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from cryptography.hazmat.backends import default_backend
    STATIC_IV = b"\x00" * 16   # static nonce reuse — plaintext recovery attack
    cipher = Cipher(algorithms.AES(key), modes.GCM(STATIC_IV), backend=default_backend())
    encryptor = cipher.encryptor()
    return encryptor.update(plaintext) + encryptor.finalize()


# ── IDOR — missing user_id filter (HIGH) ─────────────────────────────────────
def get_wallet(db, wallet_id: int):
    # Thiếu AND user_id = current_user.id → IDOR
    return db.query(
        "SELECT * FROM wallets WHERE id = %s",
        (wallet_id,),
    )
