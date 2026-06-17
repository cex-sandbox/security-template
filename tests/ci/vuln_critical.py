"""
Test fixture — intentionally vulnerable code (CRITICAL / Semgrep ERROR).
Dùng bởi scripts/test-ci-local.sh để verify các CRITICAL rules phát hiện được.
KHÔNG dùng code này trong production.

Expected: semgrep --severity=ERROR --error → exit 1 (findings found)
Test suite: 76/76 PASSED (xem scripts/test-ci-local.sh)
"""
import subprocess
import pickle
import hashlib
import yaml
import jwt
import boto3

# ── SQL-INJECTION ─────────────────────────────────────────────────────────────
def get_user(db, user_id):
    return db.execute(f"SELECT * FROM users WHERE id = {user_id}")


# ── COMMAND-INJECTION ─────────────────────────────────────────────────────────
def run_report(user_input):
    subprocess.run(user_input, shell=True)


# ── INSECURE-DESERIALIZATION (pickle) ─────────────────────────────────────────
def load_session(raw_bytes):
    return pickle.loads(raw_bytes)


# ── INSECURE-DESERIALIZATION (yaml) ───────────────────────────────────────────
def load_config(stream):
    return yaml.load(stream, Loader=yaml.FullLoader)


# ── WEAK-HASH ─────────────────────────────────────────────────────────────────
def hash_password(pw: str) -> str:
    return hashlib.md5(pw.encode()).hexdigest()


# ── HARDCODED-SECRET ──────────────────────────────────────────────────────────
api_key = "s3cr3t_k3y_123!"
REPORT_SECRET = "s3cr3t_k3y_123!"        # suffix-style — regex fullmatch coverage


# ── JWT-NONE-ALGORITHM ────────────────────────────────────────────────────────
def verify_token(token: str):
    return jwt.decode(token, algorithms=["none"])


# ── AES-ECB MODE ──────────────────────────────────────────────────────────────
def encrypt_ecb(key: bytes, data: bytes) -> bytes:
    from Crypto.Cipher import AES
    cipher = AES.new(key, AES.MODE_ECB)
    return cipher.encrypt(data)


# ── PII-WRONG-REGION ──────────────────────────────────────────────────────────
def upload_kyc(file_bytes: bytes):
    s3 = boto3.client("s3", region_name="ap-southeast-1")
    s3.put_object(Bucket="kyc-documents", Body=file_bytes, Key="user.jpg")


# ── RACE-CONDITION-BALANCE (direct db.query) ─────────────────────────────────
def withdraw(db, user_id: int, amount: float):
    balance = db.query("SELECT balance FROM wallets WHERE user_id = %s", (user_id,))
    if balance >= amount:
        db.execute(
            "UPDATE wallets SET balance = balance - %s WHERE user_id = %s",
            (amount, user_id),
        )


# ── RACE-CONDITION-BALANCE (helper function pattern — Gap 3) ──────────────────
def get_wallet_balance(conn, user_id, wallet_id):
    return 0  # stub

def process_withdrawal_no_lock(conn, user_id, amount):
    balance = get_wallet_balance(conn, user_id, "primary")
    if balance >= amount:
        conn.execute("UPDATE wallets SET balance = balance - :a WHERE user_id = :u",
                     {"a": amount, "u": user_id})


# ── HARDCODED-CRYPTO-KEY ──────────────────────────────────────────────────────
AES_KEY = b"hardcoded-aes-key-16"


# ── SHA256-FOR-PASSWORD ───────────────────────────────────────────────────────
def hash_password_sha(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


# ── SHA256-FOR-PASSWORD (prefixed var: old_password / new_password) ───────────
def change_password(old_password: str, new_password: str):
    old_hash = hashlib.sha256(old_password.encode()).hexdigest()
    new_hash = hashlib.sha256(new_password.encode()).hexdigest()
    return old_hash, new_hash


# ── WEAK-HASH-HMAC-MD5 (hmac.new digestmod) ───────────────────────────────────
def verify_webhook(secret: bytes, payload: bytes, sig: str) -> bool:
    import hmac as _hmac
    expected = _hmac.new(secret, payload, hashlib.md5).hexdigest()
    return expected == sig


# ── EVAL-INJECTION (f-string) ─────────────────────────────────────────────────
def run_compliance_report(report_name: str, user_id: str):
    template = f"generate_report('{report_name}', user_id='{user_id}')"
    return eval(template)


# ── EVAL-INJECTION (variable) ─────────────────────────────────────────────────
def execute_dynamic(user_command: str):
    exec(user_command)


