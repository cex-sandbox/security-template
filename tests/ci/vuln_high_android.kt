/**
 * Test fixture — intentionally vulnerable Kotlin/Android code (HIGH / Semgrep WARNING).
 * Dùng bởi scripts/test-ci-local.sh để verify Android HIGH rules.
 * KHÔNG dùng code này trong production.
 */
import android.content.Context
import android.util.Log
import java.util.Random
import javax.crypto.spec.IvParameterSpec

// ── LOG-SENSITIVE-ANDROID (HIGH) ────────────────────────────────────────────
fun handleLogin(username: String, password: String) {
    Log.d("Auth", "Login attempt with password=$password")
}

fun handlePayment(token: String) {
    Log.e("Payment", "Processing token=$token failed")
}

// ── STATIC-IV-ANDROID (HIGH) ────────────────────────────────────────────────
fun encryptData(key: ByteArray, data: ByteArray): ByteArray {
    val iv = ByteArray(16)                  // zero-initialized — nonce reuse
    val ivSpec = IvParameterSpec(iv)
    return data                             // stub
}

// ── WEAK-RANDOM-ANDROID (HIGH) ──────────────────────────────────────────────
fun generateOtp(): Int {
    val rng = java.util.Random()
    return rng.nextInt(999999)
}

// ── INSECURE-PREFS-ANDROID (HIGH) ───────────────────────────────────────────
fun saveToken(context: Context, token: String) {
    val prefs = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
    prefs.edit().putString("auth_token", token).apply()
}
