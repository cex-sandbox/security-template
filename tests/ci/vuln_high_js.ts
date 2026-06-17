/**
 * Test fixture — intentionally vulnerable TypeScript/JS code (HIGH / Semgrep WARNING).
 * Dùng bởi scripts/test-ci-local.sh để verify JS/TS HIGH rules.
 * KHÔNG dùng code này trong production.
 */
import * as crypto from 'crypto';

// ── AES-ECB-JS (HIGH) ────────────────────────────────────────────────────────
function encryptEcb(key: Buffer, data: Buffer): Buffer {
    const cipher = crypto.createCipheriv('aes-128-ecb', key, null);
    return Buffer.concat([cipher.update(data), cipher.final()]);
}

// ── STATIC-IV-JS (HIGH) ──────────────────────────────────────────────────────
function encryptStaticIv(key: Buffer, data: Buffer): Buffer {
    const iv = Buffer.alloc(16);            // zero-initialized — nonce reuse
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    return Buffer.concat([cipher.update(data), cipher.final()]);
}

// ── FLOAT-FOR-MONEY-JS (HIGH) ────────────────────────────────────────────────
function processWithdrawal(amountStr: string) {
    const amount = parseFloat(amountStr);   // precision loss risk
    const fee = Number(amountStr);          // same issue
    return { amount, fee };
}

// ── WEAK-RANDOM-JS (HIGH) ────────────────────────────────────────────────────
function generateSessionToken(): string {
    return Math.random().toString(36).slice(2);
}
