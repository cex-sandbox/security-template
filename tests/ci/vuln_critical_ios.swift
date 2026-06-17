/**
 * Test fixture — intentionally vulnerable Swift/iOS code (CRITICAL / Semgrep ERROR).
 * Dùng bởi scripts/test-ci-local.sh để verify iOS CRITICAL rules.
 * KHÔNG dùng code này trong production.
 */
import CommonCrypto
import Foundation

// ── WEAK-HASH-IOS CC_MD5 (CRITICAL) ─────────────────────────────────────────
func hashMd5(data: Data) -> Data {
    var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
    data.withUnsafeBytes { dataBytes in
        digest.withUnsafeMutableBytes { digestBytes in
            CC_MD5(dataBytes.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress)
        }
    }
    return digest
}

// ── WEAK-HASH-IOS CC_SHA1 (CRITICAL) ────────────────────────────────────────
func hashSha1(data: Data) -> Data {
    var digest = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { dataBytes in
        digest.withUnsafeMutableBytes { digestBytes in
            CC_SHA1(dataBytes.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress)
        }
    }
    return digest
}
