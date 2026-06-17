# Wallet, Money & Race Conditions

> Quy tắc xử lý tiền, số dư, giao dịch, và chống tranh chấp tài nguyên.

### 4. Money & Race Conditions

⚠️ Cực kỳ quan trọng cho CEX.

✅ `Decimal`/`BigDecimal` cho money. KHÔNG float.
✅ Atomic balance update với `SELECT ... FOR UPDATE`.

```python
from decimal import Decimal

def withdraw(user_id, amount: Decimal, db):
    with db.transaction():
        balance = db.query_one(
            "SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE",
            (user_id,)
        )
        if balance < amount:
            raise InsufficientFunds()
        db.execute(
            "UPDATE wallets SET balance = balance - ? WHERE user_id = ?",
            (amount, user_id)
        )
```

✅ **Idempotency key** bắt buộc cho withdrawal/transfer/order.
✅ **Holding period** cho địa chỉ rút mới: **24h** (giao dịch thấp/trung) hoặc **48h** (giao dịch cao). Địa chỉ chưa qua holding không thể rút.

### EXAMPLE — Withdrawal Flow chuẩn CEX

```python
from decimal import Decimal
import uuid

NGUONG_STEP_UP   = Decimal("10_000_000")    # 10M VND / 0.1 BTC
NGUONG_CHAN_SMS  = Decimal("100_000_000")   # 100M VND fiat — chặn SMS
NGUONG_SMARTOTP  = Decimal("500_000_000")   # 500M VND — SmartOTP + Fund Pass

@router.post("/withdrawal")
@require_scope("withdrawal:create")  # L3: tái xác thực, không tin Kong L2
async def create_withdrawal(req, token_payload):
    # 1. Ownership + device binding (GOV-01.2)
    if token_payload["sub"] != req.account_id:
        raise HTTPException(404, "Không tìm thấy")  # 404 chống BOLA fingerprinting
    if token_payload["device_id"] != req.device_id:
        raise HTTPException(403, "Thiết bị không khớp")

    # 2. SmartOTP — BẮT BUỘC cho mọi withdrawal
    if not verify_smartotp(req.account_id, req.otp):
        raise HTTPException(403, "INVALID_OTP")

    amount = Decimal(req.amount)

    # 3. > 500M VND: Fund Password bắt buộc
    if amount >= NGUONG_SMARTOTP:
        if not req.fund_password or not verify_fund_password(req.account_id, req.fund_password):
            raise HTTPException(403, "Fund Password bắt buộc cho withdrawal > 500M VND")

    # 4. Idempotency
    idem_key = req.headers.get("Idempotency-Key")
    if not idem_key:
        raise HTTPException(400, "MISSING_IDEMPOTENCY_KEY")
    cached = redis.get(f"idem:{req.account_id}:{idem_key}")
    if cached:
        return cached

    # 5. Validation + AML
    if not validate_address(req.address, req.currency):
        raise HTTPException(400, "INVALID_ADDRESS")
    if not is_whitelisted_with_holding(req.account_id, req.address, req.currency):
        # New address holding 24h/48h chưa qua
        raise HTTPException(403, "ADDRESS_HOLDING_PERIOD")
    if aml_check(req.address) == "flagged":
        raise HTTPException(403, "ADDRESS_FLAGGED")

    # 6. Cooling period check
    cooling_h = compute_cooling_hours(req.account_id, amount)  # 0/24/48
    if cooling_h > 0 and not cooling_period_satisfied(req.account_id, cooling_h):
        raise HTTPException(403, "COOLING_PERIOD")

    # 7. Atomic balance update (Aurora MySQL FOR UPDATE)
    with db.transaction():
        balance = db.query_one(
            "SELECT balance FROM wallets WHERE user_id = %s AND currency = %s FOR UPDATE",
            (req.account_id, req.currency)
        )
        if balance < amount:
            raise HTTPException(400, "INSUFFICIENT_FUNDS")

        withdrawal_id = str(uuid.uuid4())
        db.execute(
            """INSERT INTO withdrawals
               (id, user_id, amount, address, currency, status, idempotency_key)
               VALUES (%s, %s, %s, %s, %s, 'pending', %s)""",
            (withdrawal_id, req.account_id, str(amount), req.address, req.currency, idem_key)
        )
        db.execute(
            "UPDATE wallets SET balance = balance - %s WHERE user_id = %s AND currency = %s",
            (str(amount), req.account_id, req.currency)
        )

    # 8. Async dispatch
    queue_withdrawal_processing(withdrawal_id)

    # 9. Audit log với PII masking + Risk Engine result
    audit_logger.info("withdrawal_created", extra={
        "withdrawal_id": withdrawal_id,
        "user_id": req.account_id,
        "amount": str(amount),
        "currency": req.currency,
        "address_masked": f"{req.address[:6]}...{req.address[-4:]}",
        "risk_level": req.risk_level,
    })

    response = {"id": withdrawal_id, "status": "pending"}
    redis.setex(f"idem:{req.account_id}:{idem_key}", 86400, json.dumps(response))
    return response, 201
```

---
