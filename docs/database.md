# Database Security

> Quy tắc kết nối, truy vấn, và xác thực cơ sở dữ liệu.

### 3. Database — Parameterized + IRSA + IAM DB Auth

Stack: **Aurora MySQL** trên RDS, port 3306, ap-southeast-1 (PII tại VPC-VN/Z4).

❌ KHÔNG concat string vào SQL.
✅ Parameterized queries, ownership check (chống IDOR/BOLA).

```python
db.execute(
    "SELECT * FROM wallets WHERE id = %s AND user_id = %s",
    (wallet_id, current_user.id)
)
```

✅ **DB auth flow (GOV-01.1):** IRSA → STS AssumeRoleWithWebIdentity → `generate_db_auth_token()` (TTL 15 phút) → TLS `verify-full`. KHÔNG hardcode password.

```python
import boto3, pymysql

def get_connection():
    # IRSA inject AWS credentials qua projected SA token — không cần env var
    rds = boto3.client('rds', region_name='ap-southeast-1')
    token = rds.generate_db_auth_token(
        DBHostname=DB_HOST, Port=3306,
        DBUsername="app_user",  # IAM DB user — không phải root
        Region='ap-southeast-1'
    )
    return pymysql.connect(
        host=DB_HOST, user="app_user", password=token,
        ssl={'ca': '/etc/ssl/certs/rds-ca.pem'}
    )
```

✅ **BOLA defense:** trả `404` (không `403`) khi resource thuộc user khác — security through obscurity.

```python
if order.user_id != token_payload["sub"]:
    raise HTTPException(404, "Không tìm thấy")  # 404 thay vì 403
```
