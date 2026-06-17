# API Design Conventions

> **Mục đích:** Quy ước thiết kế REST API cho dự án CEX. AI assistant follow để API consistent và secure.

---

## URL Conventions

### Resource Naming

```
GET    /api/v1/wallets                    # List
GET    /api/v1/wallets/{wallet_id}        # Get one
POST   /api/v1/wallets                    # Create
PATCH  /api/v1/wallets/{wallet_id}        # Update
DELETE /api/v1/wallets/{wallet_id}        # Delete

POST   /api/v1/wallets/{wallet_id}/withdraw   # Action on resource
GET    /api/v1/wallets/{wallet_id}/history    # Sub-resource
```

### Rules

- Plural noun cho collection: `/wallets`, không `/wallet`
- Kebab-case cho multi-word: `/withdrawal-requests`, không `/withdrawalRequests`
- Version trong URL: `/api/v1/`
- ID trong path, không query string: `/wallets/{id}`, không `/wallets?id={id}`
- Action verb cho non-CRUD: `/wallets/{id}/freeze`, `/orders/{id}/cancel`

---

## Authentication

### Auth Header

```http
Authorization: Bearer eyJhbGc...
```

✅ JWT trong `Authorization: Bearer ` header
❌ Không trong query string (lộ trong logs, browser history)
❌ Không trong body (không idiomatic)

### Token Lifecycle

- Access token: 15 phút expiry
- Refresh token: 7 ngày expiry, rotate khi sử dụng
- Token revocation: maintain blocklist trong Redis với TTL = remaining lifetime

---

## Request Format

### Headers

```http
Content-Type: application/json
Authorization: Bearer <token>
Idempotency-Key: <uuid>           # Required cho mutating operations
X-Request-ID: <uuid>              # Client gen, server propagate
Accept-Language: vi               # Optional, i18n
```

### Body

```json
{
  "amount": "100.50",
  "currency": "USDT",
  "address": "0xabc..."
}
```

**Rules:**
- Money: string (để tránh float precision loss in JSON parsers)
- Timestamps: ISO 8601 UTC (`2026-01-15T10:30:00Z`)
- Field naming: snake_case
- Enum: lowercase string (`"pending"`, không `"PENDING"`)

---

## Response Format

### Success

```json
{
  "data": {
    "id": "wd_abc123",
    "amount": "100.50",
    "currency": "USDT",
    "status": "pending",
    "created_at": "2026-01-15T10:30:00Z"
  },
  "meta": {
    "request_id": "req_xyz"
  }
}
```

### Error

```json
{
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Số dư không đủ để thực hiện giao dịch",
    "details": {
      "available": "50.00",
      "required": "100.50"
    }
  },
  "meta": {
    "request_id": "req_xyz",
    "correlation_id": "corr_abc"
  }
}
```

### List with Pagination

```json
{
  "data": [...],
  "meta": {
    "page": 1,
    "per_page": 50,
    "total": 1234,
    "has_more": true,
    "next_cursor": "eyJpZCI6..."
  }
}
```

---

## HTTP Status Codes

| Status | When |
|---|---|
| 200 | GET, PATCH success |
| 201 | POST resource created |
| 202 | Accepted, processing async |
| 204 | DELETE success |
| 400 | Invalid request (validation, malformed JSON) |
| 401 | Unauthenticated (missing/invalid token) |
| 403 | Authenticated nhưng không quyền |
| 404 | Resource không tồn tại |
| 409 | Conflict (duplicate, version mismatch) |
| 422 | Semantic error (insufficient funds, etc.) |
| 429 | Rate limit |
| 500 | Internal error (bug) |
| 503 | Service unavailable (maintenance, dependency down) |

⚠️ **Không return 200 với `success: false` body** — dùng đúng HTTP status.

---

## Idempotency

### Required For

- POST tạo financial resource: withdrawal, transfer, order
- POST trigger action: cancel, refund
- PATCH thay đổi state quan trọng

### Implementation

```python
@app.post("/api/v1/withdrawals")
def create_withdrawal(req, current_user):
    idem_key = req.headers.get("Idempotency-Key")
    if not idem_key:
        return error(400, "MISSING_IDEMPOTENCY_KEY")

    # Check existing
    cached = redis.get(f"idem:{current_user.id}:{idem_key}")
    if cached:
        return cached  # Return same response

    # Process
    response = process_withdrawal(...)

    # Cache (24h)
    redis.setex(f"idem:{current_user.id}:{idem_key}", 86400, response)
    return response
```

---

## Rate Limiting

### Limits (recommended)

| Endpoint type | Limit |
|---|---|
| Public (login, register) | 5/min/IP |
| Authenticated read | 60/min/user |
| Authenticated write | 30/min/user |
| Withdrawal | 5/hour/user |
| Trading | 100/min/user |

### Response Headers

```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1737020400
```

### Status When Exceeded

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
```

---

## Versioning

- URL path versioning: `/api/v1/`, `/api/v2/`
- Breaking change → new version
- Deprecated version giữ ít nhất 6 tháng + announcement
- Header `Sunset: <date>` cho deprecated endpoints

---

## Security Headers

Mọi response phải có:

```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

CORS strict:

```http
Access-Control-Allow-Origin: https://security.example   # Specific origin, không *
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PATCH, DELETE
Access-Control-Allow-Headers: Authorization, Content-Type, Idempotency-Key
```

---

## Forbidden in API Response

❌ Stack trace
❌ Internal IDs (auto-increment) — dùng UUID
❌ Internal hostname / IP
❌ User PII không cần thiết
❌ Full JWT trong response body
❌ Database column names trong error message
