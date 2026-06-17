"""Code sạch — pipeline phải PASS toàn bộ."""
from decimal import Decimal


def calc_fee(amount: Decimal, rate: Decimal) -> Decimal:
    """Dùng Decimal cho tiền, không float."""
    return (amount * rate).quantize(Decimal("0.00000001"))


def get_user(db, user_id: int):
    """Truy vấn tham số — không SQL injection."""
    return db.execute("SELECT * FROM users WHERE id = %s", (user_id,))
