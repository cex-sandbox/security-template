# Mobile App Security Rules

## CERT-PINNING-MISSING — HIGH

**Trigger:** HTTPS client trên mobile (Android `OkHttpClient`, iOS `URLSession`) không có certificate pinning config.

**Data flow:** Mobile app → HTTPS → server, không pin cert.

**Skip:** Có `CertificatePinner` (Android) hoặc `URLSessionDelegate` validate cert (iOS), hoặc Network Security Config XML.

**Bad (Android Kotlin):**
```kotlin
val client = OkHttpClient.Builder().build()
```

**Good (Android Kotlin):**
```kotlin
val pinner = CertificatePinner.Builder()
    .add("api.cex.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    .add("api.cex.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=") // backup pin
    .build()
val client = OkHttpClient.Builder()
    .certificatePinner(pinner)
    .build()
```

**Bad (iOS Swift):**
```swift
let session = URLSession.shared
```

**Good (iOS Swift):**
```swift
class PinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Verify server cert matches pinned hash
    }
}
```

**Vì sao:** Không pin = ai cài root CA vào device là MITM được. WiFi công cộng + captive portal pushed CA = lộ hết traffic.

---

## BIOMETRIC-CLIENT-ONLY — HIGH

**Trigger:** Mobile app dùng biometric (Touch ID, Face ID, BiometricPrompt) cho authentication mà KHÔNG có server-side verification.

**Data flow:** Biometric → local check pass → trust → make sensitive request.

**Bad:**
```kotlin
biometricPrompt.authenticate(...)
// On success
withdrawMoney()  // Backend không biết biometric đã verify
```

**Good:**
```kotlin
biometricPrompt.authenticate(...)
// On success — get cryptographic proof
val signedNonce = keyStore.signWithBiometric(serverNonce)
api.withdraw(amount, signedNonce)  // Backend verify signature
```

**Vì sao:** Device rooted/jailbroken → có thể giả lập biometric success. Server phải verify cryptographic proof (signed challenge từ biometric-protected keystore key).

---

## SECRETS-IN-MOBILE-CODE — CRITICAL

**Trigger:** API key, OAuth client secret, encryption key hardcoded trong mobile source (Android `BuildConfig`, iOS plist, Info.plist).

**Data flow:** N/A — secret extractable từ APK/IPA.

**Bad:**
```kotlin
// Android - BuildConfig hoặc Constants.kt
const val API_KEY = "sk_live_abc123"
const val ENCRYPTION_KEY = "my_aes_key_32_bytes_long_!!"
```

**Good:**
```kotlin
// Không có secret trong app
// Backend cấp short-lived token sau khi user auth
val token = api.login(username, password)  // Returns 1-hour JWT
api.withdraw(amount, token)
```

**Vì sao:** APK decompile dễ (apktool, jadx). IPA dump string. Secret trong app = public.

---

## INSECURE-STORAGE — HIGH

**Trigger:** Mobile lưu session token, PIN, sensitive data trong `SharedPreferences` (Android plain), `UserDefaults` (iOS plain), `localStorage` (web view).

**Data flow:** Sensitive data → unencrypted storage.

**Bad (Android):**
```kotlin
val prefs = getSharedPreferences("auth", MODE_PRIVATE)
prefs.edit().putString("token", jwt).apply()
```

**Good (Android):**
```kotlin
// EncryptedSharedPreferences với key trong Keystore
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()
val prefs = EncryptedSharedPreferences.create(
    context, "auth", masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)
prefs.edit().putString("token", jwt).apply()
```

**Bad (iOS):**
```swift
UserDefaults.standard.set(token, forKey: "auth_token")
```

**Good (iOS):**
```swift
// Keychain với access control
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "auth_token",
    kSecValueData as String: token.data(using: .utf8)!,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]
SecItemAdd(query as CFDictionary, nil)
```

**Vì sao:** Device backup, malware có quyền read app data, hoặc thiết bị bẻ khoá → đọc plain storage. Encrypted storage cần key trong hardware-backed keystore.
