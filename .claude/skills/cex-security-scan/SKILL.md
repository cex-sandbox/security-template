---
name: cex-security-scan
description: Deep security scanner for CEX (crypto exchange) source code. Detects 20+ vulnerability categories with reasoning-first approach. Specialized for financial systems: race conditions, wallet security, MPC/HSM implementation, NĐ 356/2025 PII compliance, withdrawal flows. Use when reviewing code that handles money, user data, authentication, or wallet operations.
---

# CEX Security Scanner

Security scanner chuyên cho sàn giao dịch tiền mã hoá. Áp dụng reasoning-first analysis (không pattern matching đơn thuần) để giảm false positive. Tích hợp NĐ 356/2025 và đặc thù wallet/MPC/HSM.

## Triết lý

**Reasoning-first, không pattern counting.** Không chỉ grep cho `eval(`, `query(`, hay `MD5`. Mỗi finding phải:
1. Trace data flow từ nguồn đến sink
2. Verify input có thực sự reach dangerous sink không
3. Verify thiếu sanitization/validation
4. Skip nếu là constant, env var, hoặc trusted source

**One finding, one rule.** Một dòng code trigger cả IDOR + Race Condition → 2 findings riêng biệt, không gắn nhiều tag.

**Data flow classification L1-L4:**
- **L1 — Untrusted:** HTTP request, query param, form input, file upload, external API response
- **L2 — Semi-trusted:** Database (đã insert từ L1), cache (TTL ngắn)
- **L3 — Internal:** Internal service call (mTLS verified)
- **L4 — Trusted:** Constants, env vars, KMS secrets, signed config

Chỉ flag finding khi data flow L1 hoặc L2 reach dangerous sink.

## Workflow

### Bước 1 — Xác định scope

Đọc tham số:
- `uncommitted` (default): `git diff` + `git diff --staged`
- `staged`: `git diff --staged`
- `all`: toàn bộ files tracked bởi git
- `commit <hash>`: `git show <hash>`
- `diff <branch>`: `git diff <branch>...HEAD`

### Bước 2 — Identify primary language

Đếm files theo extension. Primary language = ngôn ngữ chiếm > 50% files trong scope. Load:
- Rules chung từ `rules/` (auth, wallet, compliance...)
- Steering files từ `.security/steering/` nếu có (product, tech, compliance)
- Project-specific context từ `security-local.md` nếu có

### Bước 3 — Size-aware routing

- Nhỏ (≤ 20 files main + ≤ 30 total): scan inline
- Lớn: delegate sub-agents cho từng top-level folder, aggregate findings dedupe by `(file, line, rule_id)`

### Bước 4 — Scan per rule

Cho mỗi rule trong `rules/`:
1. Đọc rule definition (trigger pattern, data flow requirement, severity)
2. Find code matching trigger
3. Trace data flow để verify thực sự vulnerable
4. Skip false positive
5. Record finding với context

### Bước 5 — Generate report

Format report:

```markdown
# CEX Security Scan Report

**Scope:** <scope>
**Time:** <ISO timestamp>
**Files scanned:** <count>
**Findings:** <total> (CRITICAL: <n>, HIGH: <n>, MEDIUM: <n>, LOW: <n>)

## Findings

### [CRITICAL] <rule-id> — <title>

**File:** path/to/file.py:42
**Data flow:** L1 (HTTP query param) → SQL sink without parameterization

**Code:**
\`\`\`python
<offending code>
\`\`\`

**Tại sao nguy hiểm (VN):** <giải thích>

**Why dangerous (EN):** <explanation>

**Cách sửa:** <recommendation với code example>

---

(Lặp lại cho mỗi finding)

## Summary (machine-readable)

\`\`\`json
{
  "scope": "uncommitted",
  "files_scanned": 23,
  "findings": [
    {"rule_id": "SQL-INJECTION", "severity": "CRITICAL", "file": "...", "line": 42}
  ],
  "by_severity": {"CRITICAL": 2, "HIGH": 5, "MEDIUM": 1, "LOW": 0}
}
\`\`\`
```

### Bước 6 — Lưu report

Lưu file: `security-reports/scan-YYYYMMDD-HHMMSS.md` trong project root.

Nếu folder chưa có → tạo. Thêm vào `.gitignore` nếu chưa có.

## Rules

Đọc chi tiết từng rule tại `rules/`:

> **Chú thích cột Pre-commit:**
> - ✅ Semgrep — rule có trong `.semgrep/rules/security.yml`, tự động chặn khi commit
> - 🔑 Gitleaks/detect-secrets — chặn bởi secret scanner
> - 🤖 AI-only — chỉ phát hiện qua `/cex-security` scan, không có pre-commit hook

| Rule ID | Severity | File | Pre-commit |
|---|---|---|---|
| HARDCODED-SECRET | CRITICAL | `rules/auth.md` | ✅ Semgrep |
| WEAK-PASSWORD-HASHING | CRITICAL | `rules/auth.md` | 🤖 AI-only |
| JWT-NONE-ALGORITHM | CRITICAL | `rules/auth.md` | ✅ Semgrep |
| JWT-HS256-CONFUSION | HIGH | `rules/auth.md` | ✅ Semgrep |
| SQL-INJECTION | CRITICAL | `rules/injection.md` | ✅ Semgrep (Python + JS/TS) |
| COMMAND-INJECTION | CRITICAL | `rules/injection.md` | ✅ Semgrep |
| INSECURE-DESERIALIZATION | CRITICAL | `rules/injection.md` | ✅ Semgrep (pickle + yaml) |
| XSS | HIGH | `rules/injection.md` | 🤖 AI-only |
| IDOR | HIGH | `rules/auth.md` | ✅ Semgrep (heuristic) |
| BROKEN-ACCESS-CONTROL | CRITICAL | `rules/auth.md` | 🤖 AI-only |
| RACE-CONDITION-BALANCE | CRITICAL | `rules/race-condition.md` | ✅ Semgrep |
| MISSING-IDEMPOTENCY-KEY | HIGH | `rules/race-condition.md` | 🤖 AI-only |
| FLOAT-FOR-MONEY | HIGH | `rules/race-condition.md` | ✅ Semgrep |
| WALLET-HOT-LIMIT | CRITICAL | `rules/wallet.md` | 🤖 AI-only |
| WITHDRAWAL-NO-WHITELIST | HIGH | `rules/wallet.md` | 🤖 AI-only |
| MPC-WEAK-NONCE | CRITICAL | `rules/wallet.md` | 🤖 AI-only |
| HSM-NOT-USED | HIGH | `rules/wallet.md` | 🤖 AI-only |
| PII-WRONG-REGION | CRITICAL | `rules/compliance.md` | ✅ Semgrep |
| CONSENT-PRE-CHECKED | HIGH | `rules/compliance.md` | 🤖 AI-only |
| LOG-SENSITIVE-DATA | HIGH | `rules/compliance.md` | ✅ Semgrep |
| WEAK-CRYPTO-MODE | HIGH | `rules/crypto.md` | ✅ Semgrep (ECB + weak hash) |
| HARDCODED-KEY | CRITICAL | `rules/crypto.md` | 🔑 Gitleaks + ✅ Semgrep |
| STATIC-NONCE | HIGH | `rules/crypto.md` | ✅ Semgrep |
| INSECURE-RANDOM | HIGH | `rules/crypto.md` | ✅ Semgrep (Python + JS/TS) |
| CERT-PINNING-MISSING | HIGH | `rules/mobile.md` | 🤖 AI-only |
| BIOMETRIC-CLIENT-ONLY | HIGH | `rules/mobile.md` | 🤖 AI-only |
| INSECURE-STORAGE | HIGH | `rules/mobile.md` | 🤖 AI-only |
| SECRETS-IN-MOBILE-CODE | CRITICAL | `rules/mobile.md` | 🔑 Gitleaks |
| IRSA-NOT-USED | MEDIUM | `rules/infra.md` | 🤖 AI-only |
| MTLS-PERMISSIVE | HIGH | `rules/infra.md` | 🤖 AI-only |
| NETWORK-POLICY-MISSING | HIGH | `rules/infra.md` | 🤖 AI-only |
| CONTAINER-AS-ROOT | HIGH | `rules/infra.md` | 🤖 AI-only |
| NO-RIGHT-TO-DELETE | HIGH | `rules/compliance.md` | 🤖 AI-only |
| CROSS-BORDER-NO-DPIA | HIGH | `rules/compliance.md` | 🤖 AI-only |
| COLD-WALLET-ONLINE | CRITICAL | `rules/wallet.md` | 🤖 AI-only |
| SSRF | HIGH | `rules/injection.md` | 🤖 AI-only |

## Disclaimer

Đây là first-line scanner — **không thay thế professional security audit**. Cover các lỗi thường gặp khi vibe code với AI, nhưng không guarantee 100% coverage.

Chạy bổ sung: `pre-commit run --all-files`, `npm audit`/`pip-audit`, `trivy fs .` cho dependency và container CVE.
