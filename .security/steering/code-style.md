# Code Style Guide

> **Mục đích:** Coding style và security style conventions. AI assistant follow để code generate consistent với codebase.

---

## General Principles

1. **Readability over cleverness** — junior dev đọc hiểu được
2. **Explicit over implicit** — không dùng magic
3. **Fail fast** — validate đầu vào sớm, raise exception khi sai
4. **Boring is better** — chọn pattern quen thuộc, không tricks

---

## Python Style

### Formatting

- Black formatter, line length 100
- isort cho import organization
- Type hints cho mọi function public
- Docstring cho mọi class và public function

### Type Hints

```python
# ✅ GOOD
from decimal import Decimal
from typing import Optional

def transfer(
    from_user_id: str,
    to_user_id: str,
    amount: Decimal,
    currency: str,
    idempotency_key: str,
) -> Transfer:
    """Transfer amount from one user to another atomically."""
    ...

# ❌ BAD
def transfer(from_user, to_user, amount, currency, key):
    ...
```

### Error Handling

```python
# ✅ GOOD — Specific exceptions
class InsufficientFundsError(Exception):
    pass

class InvalidAddressError(Exception):
    pass

try:
    withdraw(user_id, amount, address)
except InsufficientFundsError:
    return "Insufficient balance", 400
except InvalidAddressError:
    return "Invalid address", 400
except Exception as e:
    logger.exception("withdrawal failed", extra={"user_id": user_id})
    return "Internal error", 500

# ❌ BAD — Generic except + pass
try:
    withdraw(user_id, amount, address)
except:
    pass  # ← Silent failure, security hole
```

### Logging

```python
# ✅ GOOD — Structured logging với context
logger.info(
    "withdrawal_created",
    extra={
        "withdrawal_id": withdrawal_id,
        "user_id": user_id,
        "amount": str(amount),  # Decimal serialize
        "currency": currency,
        # NOTE: KHÔNG log address full — mask hoặc skip
    },
)

# ❌ BAD — String interpolation, không structure
logger.info(f"User {user_id} withdrew {amount} {currency} to {address}")
```

---

## JavaScript / TypeScript Style

### TypeScript Required

- Mọi file mới phải là `.ts` / `.tsx`, không `.js`
- `strict: true` trong tsconfig
- Không `any` — dùng `unknown` rồi narrow

### Async/Await

```typescript
// ✅ GOOD
async function getWallet(userId: string): Promise<Wallet> {
  try {
    const wallet = await db.wallet.findUnique({
      where: { userId },
    });
    if (!wallet) throw new WalletNotFoundError(userId);
    return wallet;
  } catch (err) {
    logger.error('getWallet failed', { userId, err });
    throw err;
  }
}

// ❌ BAD — Promise chain + then/catch lẫn
function getWallet(userId) {
  return db.wallet.findUnique({where: {userId}}).then(w => {
    if (!w) return null;
    return w;
  }).catch(e => console.log(e));
}
```

### Money Handling

```typescript
// ✅ GOOD
import Decimal from 'decimal.js';

const balance = new Decimal('100.50');
const fee = new Decimal('0.10');
const total = balance.minus(fee);  // exact

// ❌ BAD
const balance = 100.50;
const fee = 0.10;
const total = balance - fee;  // 100.4 (precision loss accumulates)
```

---

## SQL Style

```sql
-- ✅ GOOD — Parameterized, locked
SELECT balance
FROM wallets
WHERE user_id = $1
  AND currency = $2
FOR UPDATE;

-- ❌ BAD — Concat, no lock
SELECT balance FROM wallets WHERE user_id = 'usr_abc' AND currency = 'BTC';
```

### Naming

- Tables: plural snake_case (`users`, `wallet_transactions`)
- Columns: snake_case (`user_id`, `created_at`)
- Indexes: `idx_<table>_<columns>` (`idx_wallets_user_id_currency`)
- Foreign keys: `fk_<table>_<ref_table>` (`fk_orders_users`)

---

## Comment Style

### When to Comment

✅ **Why** — lý do business hoặc lịch sử
✅ **Trade-off** — chọn pattern A thay vì B vì lý do
✅ **Gotcha** — pitfall mà future dev có thể vướng

❌ **What** — code đã nói rõ
❌ **TODO** không có owner và deadline
❌ Commented-out code

### Examples

```python
# ✅ GOOD
# Lock the wallet row to prevent race condition when concurrent
# withdrawals are submitted. Without FOR UPDATE, we'd have a TOCTOU
# bug allowing double-spend.
wallet = db.query("SELECT ... FROM wallets WHERE user_id = ? FOR UPDATE", ...)

# ❌ BAD
# Get wallet
wallet = db.query(...)
```

---

## Security Style

### Error Messages

```python
# ✅ GOOD — Generic public + detailed log
except Exception as e:
    correlation_id = str(uuid.uuid4())
    logger.exception("withdrawal failed",
                     extra={"correlation_id": correlation_id})
    return jsonify({
        "error": "Could not process withdrawal",
        "correlation_id": correlation_id,  # User report số này
    }), 500

# ❌ BAD — Leak internal info
except Exception as e:
    return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500
```

### Input Validation Order

1. **Existence** — required fields có không
2. **Type** — đúng kiểu dữ liệu
3. **Format** — regex, schema
4. **Range** — min/max, length
5. **Semantic** — business rule (vd: amount <= balance)
6. **Authorization** — user có quyền không

Mỗi level fail → return ngay, không tiếp tục.

### Logging Sensitive Data

```python
# ✅ GOOD — Masking helpers
def mask_email(email: str) -> str:
    user, domain = email.split("@", 1)
    return f"{user[0]}***@{domain}"

def mask_address(addr: str) -> str:
    return f"{addr[:6]}...{addr[-4:]}"

logger.info("user_login", extra={
    "user_id": user.id,
    "email_masked": mask_email(user.email),  # OK to log
    "ip": request.ip,
})

# ❌ BAD
logger.info(f"User {user.email} logged in with password {password}")
```
