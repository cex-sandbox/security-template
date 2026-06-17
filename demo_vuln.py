"""Demo file — lỗi cố ý để kiểm chứng pipeline chặn PR. Không dùng production."""
import hashlib
import jwt


def get_user(db, user_id):
    # SQL injection qua f-string → security-sql-fstring (CRITICAL)
    return db.execute(f"SELECT * FROM users WHERE id = {user_id}")


def run(expr):
    # eval injection → security-eval-injection (CRITICAL)
    return eval(f"compute({expr})")


def verify(token):
    # JWT alg none → security-jwt-alg-none (CRITICAL)
    return jwt.decode(token, algorithms=["none"])


def hash_pw(pw):
    # MD5 cho password → security-weak-hash (CRITICAL)
    return hashlib.md5(pw.encode()).hexdigest()
