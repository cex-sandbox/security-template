# Changelog

Mọi thay đổi đáng chú ý của Security Template được ghi lại tại đây.

Format: [Semantic Versioning](https://semver.org/) — `MAJOR.MINOR.PATCH`

---

## [Unreleased]

---

## [1.3.0] — 2026-06-12

### Added — GitHub Actions support + AI review + rule metadata

- **GitHub Actions pipeline** (`.github/workflows/security.yml`) — 6 jobs ngang bản GitLab CI, hoạt động ở 2 ngữ cảnh (repo template / project tích hợp qua submodule). Hardening: GITHUB_TOKEN least-privilege, actions pin theo commit SHA, timeout-minutes, concurrency cancel-in-progress, Gitleaks scan cả git history của PR (bắt secret commit-rồi-xoá)
- **AI PR Security Review bot v0.1** (`.github/workflows/ai-review.yml` + `scripts/ai_pr_review.py`) — Claude API đọc diff PR, comment findings. AI chỉ đề xuất, không block. Mask secrets trước khi gửi, chỉ gửi diff
- **Metadata cho toàn bộ 44 Semgrep rules** — CWE, OWASP Top 10 2021 / OWASP Mobile Top 10 2024, references tới docs nội bộ, compliance tag (NĐ 356/2025) cho rule PII
- **Dependabot** (`.github/dependabot.yml`) — github-actions + pip weekly; chống version drift
- **docs/guide.md** — phụ lục tích hợp trên GitHub: workflow copy thay include, private submodule cần PAT, giới hạn branch protection plan Free

### Fixed

- **Bandit 1.7.10 → 1.9.4** trong `.pre-commit-config.yaml` — bản cũ không tương thích Python 3.14, bỏ qua file không cảnh báo (hook báo pass trong khi không scan)

### Notes

- Gitleaks trong GitHub Actions chạy binary trực tiếp thay vì gitleaks-action (action yêu cầu license trong organization)
- Test suite: 80/80 PASS sau toàn bộ thay đổi

---

## [1.2.1] — 2026-05-27

### Added — Multi-language rule coverage

- **18 Semgrep rules mới** — tổng 44 rules (từ 26), cover 5 ngôn ngữ: Python, TypeScript/JS, Kotlin, Swift, Java

**JavaScript / TypeScript (7 rules mới):**
- `security-command-injection-js` (CRITICAL) — `exec()`/`execSync()` với non-literal, `spawn()` với `shell: true`
- `security-eval-injection-js` (CRITICAL) — `eval($VAR)` và `new Function($VAR)` với input động
- `security-weak-hash-js` (CRITICAL) — `crypto.createHash('md5'/'sha1')`
- `security-sha256-password-js` (CRITICAL) — `createHash('sha256').update(passwordVar)`
- `security-aes-ecb-js` (HIGH) — `createCipheriv('aes-*-ecb', ...)`
- `security-static-iv-js` (HIGH) — `Buffer.alloc(N)` dùng làm IV/nonce
- `security-float-for-money-js` (HIGH) — `parseFloat()`/`Number()` cho monetary vars (camelCase + snake_case)

**Kotlin / Android (6 rules mới + 2 extended):**
- `security-weak-hash-android` (CRITICAL) — `MessageDigest.getInstance("MD5"/"SHA-1")`
- `security-sql-injection-android` (CRITICAL) — `rawQuery()` với string template `${variable}`
- `security-log-sensitive-android` (HIGH) — `Log.d/e/i/v()` với password/token trong message
- `security-static-iv-android` (HIGH) — `ByteArray(N)` zero-initialized dùng làm IV
- `security-weak-random-android` (HIGH) — `java.util.Random()` cho mục đích bảo mật
- `security-insecure-prefs-android` (HIGH) — `SharedPreferences.putString(sensitiveKey, ...)`
- `security-hardcoded-secret` — extended languages thêm `kotlin`
- `security-hardcoded-crypto-key` — extended languages thêm `kotlin`

**Swift / iOS (5 rules mới + 2 extended):**
- `security-weak-hash-ios` (CRITICAL) — `CC_MD5(...)` / `CC_SHA1(...)`
- `security-insecure-keychain-ios` (HIGH) — `kSecAttrAccessibleAlways`
- `security-log-sensitive-ios` (HIGH) — `print()`/`NSLog()` với password/token
- `security-static-iv-ios` (HIGH) — `Data(count: N)` zero bytes dùng làm IV
- `security-weak-random-ios` (HIGH) — `rand()`/`random()`/`drand48()`/`arc4random()`
- `security-hardcoded-secret` — extended languages thêm `swift`
- `security-hardcoded-crypto-key` — extended languages thêm `swift`

**Mở rộng rules hiện có:**
- `security-hardcoded-secret` — thêm `kotlin`, `swift` vào languages
- `security-hardcoded-crypto-key` — thêm `kotlin`, `swift` vào languages

### Fixed — End-to-end dev role-play gaps

- **Gap 1 (README):** Version stale (`v1.1.3`) + thiếu hướng dẫn deploy token an toàn. Fix: thêm bước 0 hướng dẫn `git config --local url.insteadOf` — token không bị embed vào `.gitmodules`.

- **Gap 2 (`security-log-sensitive`):** Không bắt được `authorization` log qua `%s` format string. Root cause: `$VAR` regex dùng `^...$` exact match, thiếu `authorization`. Fix: dùng fullmatch-compatible regex `(?i)(?:^|.*_)(password|token|...|authorization|auth_token)(?:_.*|$)`.

- **Gap 3 (`security-balance-check-no-lock`):** Không bắt được balance đọc từ helper function (chỉ bắt `$DB.$QUERY(...)` trực tiếp). Fix: thêm Pattern B dùng `$FUNC(...)` để bắt `balance = get_wallet_balance(conn, uid)`.

- **Gap 4 (severity whitelist):** TEST 6 trong `test-ci-local.sh` thiếu 11 rules mới trong `should_be_warning` set → FAIL. Fix: bổ sung tất cả rules mới vào whitelist.

### Added — Test infrastructure

- **6 test fixture files mới:** `vuln_critical_js.ts`, `vuln_high_js.ts`, `vuln_critical_android.kt`, `vuln_high_android.kt`, `vuln_critical_ios.swift`, `vuln_high_ios.swift`
- **6 test sections mới:** TEST 8–13 trong `test-ci-local.sh` (JS/TS CRITICAL, JS/TS HIGH, Android CRITICAL, Android HIGH, iOS CRITICAL, iOS HIGH)
- **Tổng: 76/76 tests PASSED** (từ 44)

### Added — Docs & assets

- **`docs/deck.html`** — presentation tự chứa (HTML/CSS/JS), dark theme, 10 slides, keyboard + swipe navigation

---

## [1.1.3] — 2026-05-27

### Fixed

- **`scripts/setup-hooks.sh` — bug 1:** Backup `.claude/skills/` entry dùng `cp` thay vì `cp -r` khi entry là directory (`cex-security-scan/`). Gây `exit 1` khi project đã có version cũ và chạy `setup-hooks.sh` để upgrade.

- **`scripts/setup-hooks.sh` — bug 2:** `cp -r src dst` khi `dst` đã tồn tại là directory → copy `src` vào **bên trong** `dst` thay vì overwrite, tạo ra nested directory `cex-security-scan/cex-security-scan/`. Fix: `rm -rf dst` sau bước backup, trước bước copy.

  Cả 2 bugs chỉ xuất hiện khi **upgrade** (project đã có `.claude/skills/` từ version cũ). Fresh install không bị ảnh hưởng.

- **`security-balance-check-no-lock` — rule broken since v1.0.0:** Pattern cũ dùng `metavariable-regex` trên `$SQL` (nội dung SQL string) — không đáng tin cậy vì Semgrep bind string literal kèm dấu ngoặc kép. Rule chưa bao giờ thực sự fire từ v1.0.0.

  **Fix:** Match trên **tên biến** `$BAL` với `regex: '(?i)(balance|bal|amount|amt|avail)'`. Đáng tin cậy hơn vì developer đặt tên biến theo nghĩa. Pattern B fallback: `db.query → if $BAL >= → db.execute` không cần metavar-regex.

  Bug bị mask bởi file-level testing cũ — chỉ phát hiện nhờ rule-level testing (JSON output, check từng `rule_id`).

- **`security-aes-gcm-static-nonce` — severity mismatch trong test:** Rule là WARNING nhưng fixture `modes.GCM(STATIC_IV)` nằm trong `vuln_critical.py` và được test bằng `expect_blocks` (ERROR scan) → luôn FAIL vì WARNING rule không xuất hiện trong ERROR scan.

  **Fix:** Di chuyển fixture sang `tests/ci/vuln_high.py`. `expect_warns_only "$VULN_H" "security-aes-gcm-static-nonce"` (TEST 2) giờ cover cả 2 variants: AESGCM + cryptography.hazmat `modes.GCM`.

- **`security-hardcoded-secret` — không bắt được biến tên suffix-style (`REPORT_SECRET`, `MY_TOKEN`):** Regex cũ dùng anchor `(?:^|_)` với Semgrep `metavariable-regex` — Semgrep dùng `re.fullmatch` nên pattern chỉ cover suffix của string, không cover full match. `REPORT_SECRET` không match vì `REPORT_` prefix không được account for.

  **Root cause:** Semgrep `metavariable-regex` dùng `re.fullmatch`, không phải `re.search`. Python `re.search` confirm match ✅ nhưng Semgrep không fire.

  **Fix:** Đổi regex thành `(?i)(?:^|.*_)(keyword)(?:_.*|$)` — dùng `.*_` prefix và `_.*|$` suffix để cover full string bất kể có bao nhiêu segment prefix. Verified:
  - `REPORT_SECRET` → MATCH ✅ (suffix segment)
  - `MY_TOKEN`, `DATABASE_PASSWORD` → MATCH ✅
  - `API_KEY`, `SECRET` → MATCH ✅ (no prefix)
  - `tokenizer` → no match ✅ (keyword không phải whole segment)
  - `os.environ["REPORT_SECRET"]` → no match ✅ (value không phải string literal)

- **`security-log-sensitive` — không bắt được `f"...token={authorization}"`:** Keyword `token` và `authorization` thiếu trong f-string regex pattern.

  **Fix:** Thêm `token|auth(?:_?key|orization)?` vào `pattern-regex`.

### Test suite

- **Overhaul toàn bộ methodology** — chuyển từ file-level (có findings không?) sang **rule-level** (JSON output, check từng `rule_id`):
  - `semgrep_json()` — trả về JSON findings
  - `rule_in_json()` — check rule ID cụ thể trong JSON
  - `expect_blocks()` — verify rule fire trong ERROR scan (CRITICAL)
  - `expect_warns_only()` — verify rule KHÔNG block ERROR scan, CHỈ xuất hiện trong WARNING scan (HIGH)
  - `expect_clean()` — count findings từ JSON, verify 0 false positive
- **TEST 7 mới:** setup-hooks integration test — fresh install + upgrade path
- **Thêm fixture:** `REPORT_SECRET = "s3cr3t_k3y_123!"` vào `vuln_critical.py` để test suffix-style matching
- **Tổng: 44/44 tests PASSED**

### Docs

- **`docs/guide.md`** — thêm note về `# nosemgrep` multi-line match: rule `security-sql-fstring` có 2 patterns match cùng lúc (`$DB.execute(text(f"..."))` line N và `text(f"...")` line N+1). Cần đặt `# nosemgrep` trên **cả 2 dòng** để suppress hoàn toàn.

---

## [1.1.2] — 2026-05-27

### Added

**Semgrep rules mới (tổng 26 rules):**

- **`security-eval-injection`** (ERROR) — Phát hiện `eval()` / `exec()` với input động: f-string, string concatenation, `.format()`, biến không phải constant. RCE trực tiếp — không có use case hợp lệ trong production CEX code. Trước đây chỉ Bandit B307 bắt được, Semgrep bỏ sót.

- **`security-aes-gcm-static-nonce` (mở rộng)** — Bổ sung patterns cho `cryptography.hazmat.primitives.ciphers.modes.GCM(static_nonce)`: biến nonce được gán từ bytes literal (`b"\x00" * 16`), rồi truyền vào `modes.GCM(nonce)` hoặc `Cipher($ALG, modes.GCM(b"..."), ...)`. Rule cũ chỉ cover AESGCM và Cryptodome (`AES.new(... MODE_GCM ...)`), bỏ sót cryptography.hazmat API.

**Test suite (methodology cũ — file-level):**
- Thêm 3 test cases mới: `eval(f-string)`, `exec(variable)`, `modes.GCM(STATIC_IV)` vào `tests/ci/vuln_critical.py`
- Tổng tại thời điểm release: **36/36 tests** (methodology cũ; xem v1.1.3 để biết methodology mới)

### Fixed

- Gaps phát hiện qua dev role-play test (Round 5):
  - `eval(template)` với f-string user input không bị Semgrep flag (Bandit B307 bắt được nhưng Semgrep thiếu rule riêng)
  - `modes.GCM(STATIC_IV)` từ cryptography.hazmat không bị rule `security-aes-gcm-static-nonce` bắt (chỉ cover AESGCM + Cryptodome, thiếu hazmat API)

---

## [1.1.1] — 2026-05-27

### Added

**Semgrep rules mới (tổng 25 rules):**

- **`security-hardcoded-crypto-key`** (ERROR) — Phát hiện AES/HMAC key hardcoded dưới dạng bytes literal (`AES_KEY = b"..."`) hoặc string literal với tên biến chứa `aes_key`, `hmac_key`, `encrypt_key`, v.v. Rule trước (`security-hardcoded-secret`) chỉ cover tên biến generic như `secret`, `api_key` — không cover crypto key.

- **`security-sha256-for-password`** (ERROR) — Phát hiện SHA-256/SHA-512/SHA-384 được dùng để hash password (`hashlib.sha256(password.encode())`). SHA-256 quá nhanh cho password hashing (~10^9 hash/s với GPU) → phải dùng Argon2id. Rule `security-weak-hash` chỉ flag MD5/SHA-1.

**Test suite:**
- Thêm 2 test cases CRITICAL mới vào `tests/ci/vuln_critical.py` và `scripts/test-ci-local.sh`
- Tổng: **30/30 tests** (tăng từ 28)

### Fixed

- Gaps phát hiện qua dev role-play test (Round 4): `AES_KEY` bytes literal và SHA-256 password hash không bị bắt bởi hooks.

---

## [1.1.0] — 2026-05-27

### GitLab CI Pipeline

**Trigger:** Merge Request only — không chạy khi push feature branch  
**Policy:** CRITICAL block MR · HIGH warn only

### Added

**CI jobs (`.gitlab-ci.yml`):**
- `security:gitleaks` — hardcoded secret scan, luôn block
- `security:semgrep-critical` — Semgrep ERROR severity (CRITICAL), block MR
- `security:semgrep-high` — Semgrep WARNING severity (HIGH), warn only
- `security:bandit` — Python SAST, warn only, chỉ chạy nếu có `.py`
- `security:pip-audit` — dependency CVE scan, warn only, chỉ chạy nếu có requirements file

**Tích hợp:** `include: project` — dev team thêm 3 dòng vào `.gitlab-ci.yml`, tự nhận update khi Security release version mới

**Slack alert (`security:slack-alert`):**
- Tự động gửi message vào `#security` khi CRITICAL finding block MR
- Message gồm: project, tên tác giả MR, link MR, link pipeline
- Opt-in: chỉ kích hoạt khi đặt `SLACK_WEBHOOK_URL` trong CI variables

---

## [1.0.0] — 2026-05-26

### Phát hành lần đầu

**Platform:** GitLab  
**AI tool chính thức:** Claude Code

### Added

**Pre-commit hooks (Lớp 1):**
- Gitleaks — phát hiện secret leak
- detect-secrets — baseline secret check
- Bandit — Python security scan
- Semgrep — 19 custom CEX rules (8 categories: auth, wallet, compliance, crypto, infra, injection, mobile, race-condition)

**Claude Code skills (Lớp 2 & 3):**
- `/cex-security` — AI scan code thay đổi, trace L1-L4 data flow, xuất báo cáo VN+EN
- `/threat-model` — AI phân tích mối đe doạ STRIDE, mitigation checklist

**Context & steering:**
- `CLAUDE.md` — 12 critical rules, anti-patterns, CEX architecture context
- `.security/steering/` — 6 file: product, tech, compliance, api-design, code-style, structure
- `docs/` — 8 file tài liệu: auth, crypto, data-protection, database, infra, mobile, wallet, workflow
- `docs/secure-checklist.md` — 15-item MR checklist

**Setup:**
- `scripts/setup-hooks.sh` — macOS + Linux compatible, auto-backup, version check, error handling rõ ràng
- Tự động copy config ra project root, update paths cho submodule

**Compliance tích hợp sẵn:**
- Nghị định 356/2025/NĐ-CP (PII protection)
- ATTT Cấp độ 4 (log retention 24 tháng)
- Luật PCRT 2022 (KYC retention ≥ 5 năm)

---

## Roadmap

| Version | Nội dung | Dự kiến |
|---|---|---|
| **v1.1** | GitLab CI pipeline — 5 jobs, block/warn policy, include: remote ✅ | 2026-05-27 |
| **v1.2** | MCP Jira: auto-tạo ticket từ findings có dedup theo fingerprint hash · Confluence doc pull | TBD |
| **v1.3** | Multi-AI: Cursor, Codex, GitHub Copilot, Windsurf, Cline | TBD |
| **v1.4** | Windows native — OS detection → PowerShell / bash path | TBD |
| **v2.0** | Confluence as source of truth — `docs/` tự pull từ Confluence theo template | TBD |
| **v2.1** | Security metrics & trending dashboard (GitLab Pages) | TBD |
| **v2.2** | IDE real-time hints — VSCode/JetBrains extension | TBD |
| **v2.3** | CEX rule pack mở rộng: seed phrase, rate limit, withdrawal flow coverage | TBD |
| **v3.x** | Secret lifecycle management · Compliance automation (NĐ 356 schema check) | TBD |
