/**
 * Test fixture — intentionally vulnerable Swift/iOS code (HIGH / Semgrep WARNING).
 * Dùng bởi scripts/test-ci-local.sh để verify iOS HIGH rules.
 * KHÔNG dùng code này trong production.
 */
import Security
import Foundation

// ── INSECURE-KEYCHAIN-IOS (HIGH) ────────────────────────────────────────────
func savePrivateKey(keyData: Data) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrAccessible as String: kSecAttrAccessibleAlways,  // accessible when locked
        kSecValueData as String: keyData
    ]
    SecItemAdd(query as CFDictionary, nil)
}

// ── LOG-SENSITIVE-IOS (HIGH) ─────────────────────────────────────────────────
func handleLogin(password: String) {
    print("Login attempt password: \(password)")
}

// ── STATIC-IV-IOS (HIGH) ────────────────────────────────────────────────────
func encryptGcm(key: Data, plaintext: Data) -> Data {
    let iv = Data(count: 12)                // zero bytes — nonce reuse
    return plaintext                        // stub
}

// ── WEAK-RANDOM-IOS (HIGH) ──────────────────────────────────────────────────
func generateOtp() -> Int32 {
    return rand() % 1000000
}
