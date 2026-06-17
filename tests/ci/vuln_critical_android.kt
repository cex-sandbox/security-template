/**
 * Test fixture — intentionally vulnerable Kotlin/Android code (CRITICAL / Semgrep ERROR).
 * Dùng bởi scripts/test-ci-local.sh để verify Android CRITICAL rules.
 * KHÔNG dùng code này trong production.
 */
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.security.MessageDigest

// ── WEAK-HASH-ANDROID (CRITICAL) ────────────────────────────────────────────
fun hashLegacy(data: String): ByteArray {
    val md = MessageDigest.getInstance("MD5")
    return md.digest(data.toByteArray())
}

fun hashSha1(data: String): ByteArray {
    val md = MessageDigest.getInstance("SHA-1")
    return md.digest(data.toByteArray())
}

// ── SQL-INJECTION-ANDROID (CRITICAL) ────────────────────────────────────────
fun getUser(db: SQLiteDatabase, userId: String) {
    db.rawQuery("SELECT * FROM users WHERE id = ${userId}", null)
}

fun getUserConcat(db: SQLiteDatabase, userId: String) {
    db.rawQuery("SELECT * FROM wallets WHERE user_id = " + userId, null)
}
