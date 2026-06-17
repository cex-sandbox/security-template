/**
 * Test fixture — intentionally vulnerable TypeScript/JS code (CRITICAL / Semgrep ERROR).
 * Dùng bởi scripts/test-ci-local.sh để verify JS/TS CRITICAL rules.
 * KHÔNG dùng code này trong production.
 */
import * as crypto from 'crypto';
import { exec, execSync } from 'child_process';

// ── COMMAND-INJECTION-JS ──────────────────────────────────────────────────────
function runReport(userInput: string) {
    exec(userInput);                         // shell always on
}
function runReportSync(cmd: string) {
    execSync(cmd);                           // shell always on
}

// ── EVAL-INJECTION-JS ────────────────────────────────────────────────────────
function executeUserCode(code: string) {
    eval(code);
}
function buildDynamicFn(body: string) {
    return new Function(body);
}

// ── WEAK-HASH-JS (MD5) ───────────────────────────────────────────────────────
function checksumLegacy(data: string): string {
    return crypto.createHash('md5').update(data).digest('hex');
}

// ── SHA256-FOR-PASSWORD-JS ───────────────────────────────────────────────────
function hashPassword(password: string): string {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// ── SQL-INJECTION-JS ─────────────────────────────────────────────────────────
function getUser(db: any, userId: string) {
    return db.query(`SELECT * FROM users WHERE id = ${userId}`);
}

// ── JWT-VERIFY-DISABLED-JS ───────────────────────────────────────────────────
import jwt from 'jsonwebtoken';
function verifyTokenNone(token: string, secret: string) {
    return jwt.verify(token, secret, { algorithms: ['none'] });
}
