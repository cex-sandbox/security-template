# CEX Security Template — Claude Code Context

> Đọc file này để tiếp tục phát triển template mà không cần giải thích lại từ đầu.

## Dự án là gì

Security template cho sàn giao dịch crypto CEX Vietnam (partnership một sàn đối tác). Tích hợp vào mọi project dưới dạng git submodule, cung cấp 4 lớp bảo vệ tự động từ pre-commit đến production.

**GitLab:** `https://gitlab.example.com/your-org/security-template`
**Slack:** `#dev-sec-ops` — kênh Security Team

---

## Trạng thái hiện tại — v1.2.1 (05/2026)

| Thành phần | Trạng thái |
|---|---|
| Semgrep rules | 44 rules, 5 ngôn ngữ |
| Test suite | **80/80 PASSED** |
| GitLab release | v1.2.1 → commit `a883da7` |
| Deck | `docs/deck.html` — 15 slides |

**Rule coverage:**
- Python: 23 rules
- JavaScript/TypeScript: 15 rules
- Kotlin/Android: 8 rules
- Swift/iOS: 7 rules
- Java: 5 rules (shared với Kotlin)

---

## Tech stack của team CEX

- **BE:** Python (FastAPI + SQLAlchemy + Aurora MySQL), Node.js/TypeScript
- **Mobile:** Kotlin (Android), Swift (iOS)
- **Infra:** AWS EKS, Istio mTLS STRICT, IRSA, Secrets Manager CSI Driver
- **CI/CD:** GitLab CI → Argo CD GitOps
- **Auth:** JWT RS256 qua KMS, JWKS, Argon2id password
- **Compliance:** NĐ 356/2025 (PII VN), ATTT Cấp độ 4

---

## File quan trọng

```
security-template/
├── .semgrep/rules/security.yml   # 44 Semgrep rules — đây là trái tim
├── scripts/
│   ├── test-ci-local.sh          # 80 tests — chạy bash scripts/test-ci-local.sh
│   └── setup-hooks.sh            # Setup cho dev project mới
├── tests/ci/
│   ├── vuln_critical.py          # Python CRITICAL fixtures
│   ├── vuln_high.py              # Python HIGH fixtures
│   ├── vuln_critical_js.ts       # JS/TS CRITICAL fixtures
│   ├── vuln_high_js.ts           # JS/TS HIGH fixtures
│   ├── vuln_critical_android.kt  # Kotlin CRITICAL fixtures
│   ├── vuln_high_android.kt      # Kotlin HIGH fixtures
│   ├── vuln_critical_ios.swift   # Swift CRITICAL fixtures
│   ├── vuln_high_ios.swift       # Swift HIGH fixtures
│   └── test_safe.py              # False positive check
├── docs/
│   ├── guide.md                  # Hướng dẫn đầy đủ cho dev
│   ├── deck.html                 # Presentation 15 slides (self-contained)
│   └── secure-checklist.md       # Checklist 15 mục trước MR
├── .gitlab-ci.yml                # CI template — project include 3 dòng là xong
├── CLAUDE.md                     # Rules binding cho AI assistants
└── CHANGELOG.md                  # Lịch sử đầy đủ
```

---

## Kiến thức kỹ thuật quan trọng — KHÔNG được quên

### 1. Semgrep dùng `re.fullmatch`, không phải `re.search`

`metavariable-regex` trong Semgrep apply `re.fullmatch` lên toàn bộ string của metavariable.

```yaml
# ❌ SAI — chỉ match REPORT_SECRET nếu nó là suffix của string
regex: '(?i)(?:^|_)(secret|token)$'

# ✅ ĐÚNG — fullmatch-compatible, match bất kể prefix/suffix
regex: '(?i)(?:^|.*_)(secret|token)(?:_.*|$)'
```

### 2. Test infrastructure — 3 loại hàm

```bash
expect_blocks   "$FILE" "rule-id" "desc"   # Rule PHẢI fire trong ERROR scan (CRITICAL)
expect_warns_only "$FILE" "rule-id" "desc" # Rule KHÔNG block ERROR, chỉ fire WARNING (HIGH)
expect_clean    "$FILE" "desc"             # 0 findings — kiểm tra false positive
```

`expect_warns_only` = 2 passes (1 ERROR scan + 1 WARNING scan).

### 3. Rule severity mapping

- `severity: ERROR` → CRITICAL → block commit/MR
- `severity: WARNING` → HIGH → warn only

### 4. Thêm rule mới — checklist

1. Viết pattern vào `.semgrep/rules/security.yml` (validate: `semgrep --validate --config=.semgrep/rules/security.yml`)
2. Thêm fixture vào `tests/ci/vuln_critical_*.` hoặc `vuln_high_*.*`
3. Thêm `expect_blocks` hoặc `expect_warns_only` vào `test-ci-local.sh`
4. Nếu severity=WARNING: thêm rule vào `should_be_warning` set trong TEST 6
5. Chạy `bash scripts/test-ci-local.sh` — phải pass 100%
6. Update CHANGELOG + VERSION + header comment trong security.yml

### 5. Semgrep binary location (macOS dev machine)

```
/Users/<user>/.cache/pre-commit/repou5inuy2t/py_env-python3.11/bin/semgrep
```

Hoặc set `SEMGREP` env var trong test script.

### 6. Deploy token cho dev setup submodule

```bash
# Không embed token vào URL — dùng git config local
git config --local \
  url."https://secdev:gldt-xxx@gitlab.example.com".insteadOf \
  "https://gitlab.example.com"
```

Token `gldt-xxx` lấy từ PhiLD trên `#dev-sec-ops`.

---

## Roadmap — việc cần làm tiếp

### Ngắn hạn (v1.3)
- [ ] **Pilot rollout** — 1-2 dev, 1 Python project thật, test `.gitlab-ci.yml` end-to-end trên live MR
- [ ] **FP benchmark** — chạy rules trên production codebase, đo false positive rate
- [ ] **Go rules** — nếu team có service Go (check với tech lead)

### Trung hạn (v1.4+)
- [ ] **Race condition JS** — `balance = await db.query(...)` rồi update không có transaction lock
- [ ] **Prototype pollution** — `_.merge(obj, req.body)` pattern
- [ ] **SSRF** — `fetch(req.query.url)` / `axios.get(userInput)`
- [ ] **Path traversal** — `fs.readFile(req.params.file)` pattern

### Dài hạn
- [ ] JS/TS rule cho AWS wrong region (SDK `new S3Client({region: 'ap-southeast-1'})` cho KYC)
- [ ] Automated FP report sau mỗi release

---

## Lịch sử version

| Version | Ngày | Nội dung chính |
|---|---|---|
| v1.0.0 | 05/2026 | Initial — Python rules cơ bản |
| v1.1.3 | 05/2026 | setup-hooks fix, balance-check fix, test overhaul (44→80 tests) |
| v1.2.1 | 05/2026 | Multi-language: JS/TS + Kotlin + Swift, 44 rules, 80 tests, 4 gap fixes |

---

## Conventions

- **Version bump:** MINOR khi thêm rules mới, PATCH khi fix/docs
- **Commit message:** `feat:`, `fix:`, `docs:` prefix. Luôn thêm `Co-Authored-By: Claude Sonnet 4.6`
- **Tag + release:** Mỗi version cần tag + GitLab release (xem CHANGELOG để biết nội dung)
- **Test phải 100% pass** trước khi push bất kỳ thay đổi nào vào rules

---

## Environment setup trên máy mới

```bash
# 1. Clone repo
git clone https://gitlab.example.com/your-org/security-template.git
cd security-template

# 2. Cài tools
brew install pre-commit python@3.11 git
pip install semgrep pyyaml

# 3. Verify test suite
bash scripts/test-ci-local.sh

# 4. Tất cả 80 tests phải PASS trước khi bắt đầu phát triển
```
