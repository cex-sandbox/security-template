# Race Condition & Money Rules

## RACE-CONDITION-BALANCE — CRITICAL

**Trigger:** Đọc balance → kiểm tra → ghi balance, KHÔNG khoá row trong transaction.

**Data flow:** Concurrent L1 requests → cùng đọc balance → cùng pass check → cùng trừ tiền.

**Skip:** Có `SELECT ... FOR UPDATE` trong transaction, hoặc `WITH (UPDLOCK)` (SQL Server), hoặc atomic UPDATE.

**Bad:**
```python
def withdraw(user_id, amount):
    balance = db.query("SELECT balance FROM wallets WHERE user_id = %s", (user_id,))
    if balance >= amount:
        db.execute("UPDATE wallets SET balance = balance - %s WHERE user_id = %s",
                   (amount, user_id))
```

**Good:**
```python
def withdraw(user_id, amount):
    with db.transaction():
        balance = db.query(
            "SELECT balance FROM wallets WHERE user_id = %s FOR UPDATE",
            (user_id,)
        )
        if balance < amount:
            raise InsufficientFunds()
        db.execute(
            "UPDATE wallets SET balance = balance - %s WHERE user_id = %s",
            (amount, user_id)
        )
```

**Vì sao:** 2 request rút 80 USDT cùng lúc với balance 100 → cả 2 đọc balance=100 → cả 2 pass check → cả 2 trừ → balance = -60. Sàn mất tiền.

---

## MISSING-IDEMPOTENCY-KEY — HIGH

**Trigger:** Endpoint POST/PUT thực hiện thao tác tiền (withdraw, transfer, order) KHÔNG có Idempotency-Key check.

**Data flow:** L1 retry request → tạo nhiều bản ghi giao dịch.

**Skip:** Có check `Idempotency-Key` header, lưu trong cache/DB 24h.

**Bad:**
```python
@app.route('/withdraw', methods=['POST'])
def withdraw():
    return create_withdrawal(request.json)
```

**Good:**
```python
@app.route('/withdraw', methods=['POST'])
def withdraw():
    idem_key = request.headers.get('Idempotency-Key')
    if not idem_key:
        abort(400, 'Idempotency-Key required')

    cached = redis.get(f"idem:{idem_key}")
    if cached:
        return cached  # Trả kết quả cũ — không xử lý lại

    with db.transaction():
        result = create_withdrawal(request.json)
        redis.setex(f"idem:{idem_key}", 86400, result)
    return result
```

**Vì sao:** Mạng chập chờn → client retry → tạo 2 lệnh rút → mất tiền.

---

## FLOAT-FOR-MONEY — HIGH

**Trigger:** Biến tiền (balance, amount, price, fee) dùng `float` hoặc `Number` (JavaScript).

**Data flow:** Bất kỳ — phép tính float trên tiền là sai về nguyên tắc.

**Skip:** Constants không đụng tiền (rate limit, timeout, percentage display).

**Bad:**
```python
balance: float = 0.1 + 0.2  # = 0.30000000000000004
total = price * quantity  # float drift
```

**Good:**
```python
from decimal import Decimal
balance: Decimal = Decimal("0.1") + Decimal("0.2")  # = Decimal("0.3")
total = Decimal(price) * Decimal(quantity)
```

**Trong JavaScript:**
```javascript
// Bad
const total = 0.1 + 0.2;  // 0.30000000000000004

// Good
const total = new Decimal("0.1").plus("0.2").toString();  // "0.3"
// Hoặc tính theo smallest unit (satoshi, wei, cents)
```

**Vì sao:** Float không lưu chính xác số thập phân. Sai 0.0000000001 trên triệu giao dịch = số dư lệch tích luỹ → kiểm toán fail.
