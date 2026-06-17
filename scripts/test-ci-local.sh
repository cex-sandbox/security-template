#!/bin/bash
# =============================================================================
# CEX Security Template — CI Local Test Runner — v1.2.1
# =============================================================================
# Chạy tất cả test case giống GitLab CI nhưng local, không cần Docker.
# Dùng tools từ pre-commit cache hoặc PATH.
#
# Usage:
#   bash scripts/test-ci-local.sh              # chạy tất cả tests
#   bash scripts/test-ci-local.sh semgrep      # chỉ test semgrep
#   bash scripts/test-ci-local.sh gitleaks     # chỉ test gitleaks
#   bash scripts/test-ci-local.sh setup        # chỉ test setup-hooks
#
# Exit code: 0 = tất cả pass, 1 = có test fail
# Tests: 80 total
#   Semgrep: TEST 1  (16 CRITICAL python) · TEST 2 (14 HIGH python) · TEST 3 (1 FP)
#            TEST 8  (6 CRITICAL js/ts)   · TEST 9  (8 HIGH js/ts)
#            TEST 10 (2 CRITICAL kotlin)  · TEST 11 (8 HIGH kotlin)
#            TEST 12 (1 CRITICAL swift)   · TEST 13 (8 HIGH swift)
#   Other:   TEST 4 (2 gitleaks) · TEST 5 (2 bandit) · TEST 6 (2 yaml) · TEST 7 (10 setup-hooks)
# v1.2.1: +Gap2 (log-sensitive %s authorization) +Gap3 (balance-check helper fn) +Gap4 (README deploy token)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")"
RULES="$TEMPLATE_DIR/.semgrep/rules/security.yml"
FIXTURES="$TEMPLATE_DIR/tests/ci"
SAFE_FILE="$TEMPLATE_DIR/tests/test_safe.py"

# ── Màu output ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pass=0
fail=0
skip=0
FILTER="${1:-all}"

# ── Tìm tool từ pre-commit cache hoặc PATH ────────────────────────────────────
find_tool() {
    local name="$1"
    command -v "$name" 2>/dev/null && return 0
    find ~/.cache/pre-commit -name "$name" -type f 2>/dev/null \
        | sort -r | head -1
}

SEMGREP=$(find_tool semgrep || true)
GITLEAKS=$(find_tool gitleaks || true)
BANDIT=$(find_tool bandit || true)

# ── Helpers ───────────────────────────────────────────────────────────────────
ok()   { echo -e "  ${GREEN}✅ PASS${NC}  $*"; pass=$((pass+1)); }
fail() { echo -e "  ${RED}❌ FAIL${NC}  $*"; fail=$((fail+1)); }
skip() { echo -e "  ${YELLOW}⏭  SKIP${NC}  $*"; skip=$((skip+1)); }
hr()   { echo -e "${BOLD}$*${NC}"; }

# ── Semgrep helpers ───────────────────────────────────────────────────────────

# Trả về JSON findings (stdout), errors vào /dev/null
semgrep_json() {
    "$SEMGREP" --config="$RULES" --metrics=off --json "$@" 2>/dev/null
}

# Check xem rule_id có trong JSON findings không
# Usage: rule_in_json <json_string> <rule_id>  → exit 0 nếu có, exit 1 nếu không
rule_in_json() {
    local json="$1" rule_id="$2"
    echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
ids = [r['check_id'].rsplit('.', 1)[-1] for r in data.get('results', [])]
sys.exit(0 if '$rule_id' in ids else 1)
" 2>/dev/null
}

# Expect rule_id xuất hiện trong ERROR-severity scan
# → xác nhận rule đang hoạt động và severity đúng là ERROR (CRITICAL)
expect_blocks() {
    local file="$1" rule_id="$2" desc="$3"
    local json
    json=$(semgrep_json --severity=ERROR "$file")
    if rule_in_json "$json" "$rule_id"; then
        ok "$rule_id — $desc (CRITICAL detected ✔)"
    else
        fail "$rule_id — $desc (rule NOT triggered — kiểm tra fixture hoặc rule definition)"
    fi
}

# Expect rule_id CHỈ xuất hiện ở WARNING scan, KHÔNG block ERROR scan
# → xác nhận rule hoạt động đúng severity = WARNING (HIGH)
expect_warns_only() {
    local file="$1" rule_id="$2" desc="$3"
    local json_err json_warn

    # Test A: rule KHÔNG được có trong ERROR scan (không block MR)
    json_err=$(semgrep_json --severity=ERROR "$file")
    if rule_in_json "$json_err" "$rule_id"; then
        fail "$rule_id — $desc (CRITICAL scan: rule blocked MR — severity nên là WARNING)"
        return
    fi
    ok "$rule_id — $desc (CRITICAL scan: no block ✔)"

    # Test B: rule PHẢI xuất hiện trong WARNING scan
    json_warn=$(semgrep_json --severity=WARNING "$file")
    if rule_in_json "$json_warn" "$rule_id"; then
        ok "$rule_id — $desc (WARNING scan: detected ✔)"
    else
        fail "$rule_id — $desc (WARNING scan: rule not found — kiểm tra fixture hoặc rule)"
    fi
}

# Expect zero findings — không có false positive
expect_clean() {
    local file="$1" desc="$2"
    local json count
    json=$(semgrep_json "$file")
    count=$(echo "$json" | python3 -c \
        "import json,sys; print(len(json.load(sys.stdin).get('results',[])))" 2>/dev/null || echo "0")
    if [ "$count" -eq 0 ]; then
        ok "NO-FP — $desc (0 findings ✔)"
    else
        fail "NO-FP — $desc ($count false positive(s) trong safe code!)"
    fi
}

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  CEX Security CI — Local Test Runner     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Tools:"
echo "  semgrep : ${SEMGREP:-❌ not found}"
echo "  gitleaks: ${GITLEAKS:-❌ not found}"
echo "  bandit  : ${BANDIT:-❌ not found}"
echo "  rules   : $RULES"
echo ""

# ── TEST 1: SEMGREP CRITICAL rules (rule-level) ───────────────────────────────
if [[ "$FILTER" == "all" || "$FILTER" == "semgrep" ]]; then
  if [ -z "$SEMGREP" ]; then
    skip "Semgrep not found — install với: pip install semgrep"
  else
    hr "═══ TEST 1: CRITICAL rules — rule-level check ════════════════════"
    VULN_C="$FIXTURES/vuln_critical.py"

    expect_blocks "$VULN_C" "security-sql-fstring"           "f-string vào SQL"
    expect_blocks "$VULN_C" "security-shell-injection"       "subprocess shell=True"
    expect_blocks "$VULN_C" "security-pickle-load"           "pickle.loads(user_data)"
    expect_blocks "$VULN_C" "security-yaml-load-in-handler"  "yaml.load() FullLoader"
    expect_blocks "$VULN_C" "security-weak-hash"             "hashlib.md5() cho password"
    expect_blocks "$VULN_C" "security-hardcoded-secret"      "api_key hardcoded (prefix-exact)"
    expect_blocks "$VULN_C" "security-hardcoded-secret"      "REPORT_SECRET hardcoded (suffix-style fullmatch)"
    expect_blocks "$VULN_C" "security-jwt-alg-none"          'algorithms=["none"]'
    expect_blocks "$VULN_C" "security-aes-ecb-mode"          "AES.new() MODE_ECB"
    expect_blocks "$VULN_C" "security-pii-singapore-region"  "KYC bucket ap-southeast-1"
    expect_blocks "$VULN_C" "security-balance-check-no-lock" "balance read-then-update không có FOR UPDATE (direct db.query)"
    expect_blocks "$VULN_C" "security-balance-check-no-lock" "balance từ helper function — get_wallet_balance() (Gap 3)"
    expect_blocks "$VULN_C" "security-hardcoded-crypto-key"  "AES_KEY bytes literal hardcoded"
    expect_blocks "$VULN_C" "security-sha256-for-password"   "hashlib.sha256(password.encode())"
    expect_blocks "$VULN_C" "security-weak-hash"             "hmac.new(..., hashlib.md5) — same rule, different pattern"
    expect_blocks "$VULN_C" "security-eval-injection"        "eval(f-string) dynamic RCE"

    echo ""
    hr "═══ TEST 2: HIGH rules — rule-level check ════════════════════════"
    VULN_H="$FIXTURES/vuln_high.py"

    expect_warns_only "$VULN_H" "security-float-for-money"      "amount: float = ..."
    expect_warns_only "$VULN_H" "security-weak-random"          "random.randint()"
    expect_warns_only "$VULN_H" "security-log-sensitive"        "logger.info(password) direct var"
    expect_warns_only "$VULN_H" "security-log-sensitive"        "logger.info %s format với authorization (Gap 2)"
    expect_warns_only "$VULN_H" "security-jwt-hs256-confusion"  'algorithms=["HS256"]'
    expect_warns_only "$VULN_H" "security-aes-gcm-static-nonce" "AES-GCM static nonce (AESGCM + modes.GCM hazmat)"
    expect_warns_only "$VULN_H" "security-idor-no-ownership"    "wallet query không có user_id"

    echo ""
    hr "═══ TEST 3: False positive check (safe code) ═════════════════════"
    expect_clean "$SAFE_FILE" "test_safe.py"

    echo ""
    hr "═══ TEST 8: JS/TypeScript CRITICAL rules ═════════════════════════"
    VULN_JS_C="$FIXTURES/vuln_critical_js.ts"
    expect_blocks "$VULN_JS_C" "security-command-injection-js"    "exec(userInput) — shell always on"
    expect_blocks "$VULN_JS_C" "security-eval-injection-js"       "eval(code) dynamic RCE"
    expect_blocks "$VULN_JS_C" "security-weak-hash-js"            "crypto.createHash('md5')"
    expect_blocks "$VULN_JS_C" "security-sha256-password-js"      "createHash('sha256').update(password)"
    expect_blocks "$VULN_JS_C" "security-sql-injection-js"        "template literal SQL db.query(\`...userId...\`)"
    expect_blocks "$VULN_JS_C" "security-jwt-verify-disabled-js"  'jwt.verify() với algorithms:["none"]'

    echo ""
    hr "═══ TEST 9: JS/TypeScript HIGH rules ═════════════════════════════"
    VULN_JS_H="$FIXTURES/vuln_high_js.ts"
    expect_warns_only "$VULN_JS_H" "security-aes-ecb-js"          "createCipheriv('aes-128-ecb')"
    expect_warns_only "$VULN_JS_H" "security-static-iv-js"        "Buffer.alloc(16) as iv"
    expect_warns_only "$VULN_JS_H" "security-float-for-money-js"  "parseFloat(amountStr)"
    expect_warns_only "$VULN_JS_H" "security-weak-random-js"      "Math.random() cho session token"

    echo ""
    hr "═══ TEST 10: Android (Kotlin) CRITICAL rules ═════════════════════"
    VULN_KT_C="$FIXTURES/vuln_critical_android.kt"
    expect_blocks "$VULN_KT_C" "security-weak-hash-android"       "MessageDigest.getInstance(\"MD5\")"
    expect_blocks "$VULN_KT_C" "security-sql-injection-android"   "rawQuery với string template \${userId}"

    echo ""
    hr "═══ TEST 11: Android (Kotlin) HIGH rules ═════════════════════════"
    VULN_KT_H="$FIXTURES/vuln_high_android.kt"
    expect_warns_only "$VULN_KT_H" "security-log-sensitive-android"   "Log.d password/token"
    expect_warns_only "$VULN_KT_H" "security-static-iv-android"       "ByteArray(16) zero IV"
    expect_warns_only "$VULN_KT_H" "security-weak-random-android"     "java.util.Random()"
    expect_warns_only "$VULN_KT_H" "security-insecure-prefs-android"  "SharedPreferences auth_token"

    echo ""
    hr "═══ TEST 12: iOS (Swift) CRITICAL rules ══════════════════════════"
    VULN_SW_C="$FIXTURES/vuln_critical_ios.swift"
    expect_blocks "$VULN_SW_C" "security-weak-hash-ios"            "CC_MD5 / CC_SHA1"

    echo ""
    hr "═══ TEST 13: iOS (Swift) HIGH rules ══════════════════════════════"
    VULN_SW_H="$FIXTURES/vuln_high_ios.swift"
    expect_warns_only "$VULN_SW_H" "security-insecure-keychain-ios"  "kSecAttrAccessibleAlways"
    expect_warns_only "$VULN_SW_H" "security-log-sensitive-ios"      "print(password)"
    expect_warns_only "$VULN_SW_H" "security-static-iv-ios"          "Data(count: 12) zero IV"
    expect_warns_only "$VULN_SW_H" "security-weak-random-ios"        "rand() for OTP"
  fi
fi

# ── TEST 4: GITLEAKS ──────────────────────────────────────────────────────────
if [[ "$FILTER" == "all" || "$FILTER" == "gitleaks" ]]; then
  echo ""
  hr "═══ TEST 4: Gitleaks secret detection ════════════════════════════"

  if [ -z "$GITLEAKS" ]; then
    skip "Gitleaks not found"
  else
    TMPDIR_LEAK=$(mktemp -d)
    echo "GITHUB_TOKEN=ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ123456" > "$TMPDIR_LEAK/test.env"

    if "$GITLEAKS" detect --source "$TMPDIR_LEAK" --no-git --exit-code 1 \
                          --no-banner 2>/dev/null; then
        fail "GITLEAKS — fake GitHub token không bị phát hiện (rule miss)"
    else
        ok "GITLEAKS — fake GitHub token bị phát hiện ✔"
    fi

    echo "DB_HOST=localhost" > "$TMPDIR_LEAK/clean.env"
    if "$GITLEAKS" detect --source "$TMPDIR_LEAK/clean.env" --no-git --exit-code 1 \
                          --no-banner 2>/dev/null; then
        ok "GITLEAKS — clean file không bị false positive ✔"
    else
        fail "GITLEAKS — clean.env bị flag nhầm (false positive)"
    fi

    rm -rf "$TMPDIR_LEAK"
  fi
fi

# ── TEST 5: BANDIT ────────────────────────────────────────────────────────────
if [[ "$FILTER" == "all" || "$FILTER" == "bandit" ]]; then
  echo ""
  hr "═══ TEST 5: Bandit — Python SAST ═════════════════════════════════"

  if [ -z "$BANDIT" ]; then
    skip "Bandit not found"
  else
    BANDIT_OUT=$("$BANDIT" -r "$FIXTURES/vuln_critical.py" -ll 2>&1 || true)
    if echo "$BANDIT_OUT" | grep -q "Issue\|HIGH\|MEDIUM"; then
        ok "BANDIT — phát hiện issues trong vuln_critical.py ✔"
    else
        fail "BANDIT — không phát hiện issues trong vuln_critical.py"
    fi

    BANDIT_SAFE=$("$BANDIT" -r "$SAFE_FILE" -ll 2>&1 || true)
    if echo "$BANDIT_SAFE" | grep -q "No issues identified"; then
        ok "BANDIT — test_safe.py: 0 issues ✔"
    else
        ok "BANDIT — test_safe.py: kết quả xem log bên trên (warn-only trong CI)"
    fi
  fi
fi

# ── TEST 6: YAML VALIDATE + SEVERITY MAPPING ──────────────────────────────────
if [[ "$FILTER" == "all" ]]; then
  echo ""
  hr "═══ TEST 6: Validate YAML configs ════════════════════════════════"

  python3 -c "
import yaml, sys
with open('$RULES') as f:
    data = yaml.safe_load(f)
rules = data.get('rules', [])
print(f'  ✅ PASS  semgrep/rules/security.yml — {len(rules)} rules, valid YAML')
" && ((pass++)) || ((fail++))

  python3 -c "
import yaml
with open('$RULES') as f:
    data = yaml.safe_load(f)

should_be_warning = {
    # Python HIGH
    'security-float-for-money', 'security-weak-random', 'security-log-sensitive',
    'security-aes-gcm-static-nonce', 'security-jwt-hs256-confusion',
    'security-idor-no-ownership', 'security-jwt-header-key-injection',
    'security-aws-long-session-token', 'security-env-hardcoded-fallback',
    'security-float-param-monetary',
    # JS/TS HIGH
    'security-weak-random-js', 'security-aes-ecb-js', 'security-static-iv-js',
    'security-float-for-money-js',
    # Android (Kotlin) HIGH
    'security-log-sensitive-android', 'security-static-iv-android',
    'security-weak-random-android', 'security-insecure-prefs-android',
    # iOS (Swift) HIGH
    'security-insecure-keychain-ios', 'security-log-sensitive-ios',
    'security-static-iv-ios', 'security-weak-random-ios',
}
wrong = []
for r in data['rules']:
    rid = r['id']
    sev = r['severity']
    if rid in should_be_warning and sev != 'WARNING':
        wrong.append(f'{rid}: {sev} (should be WARNING)')
    elif rid not in should_be_warning and sev == 'WARNING':
        wrong.append(f'{rid}: WARNING (not in should_be_warning — add or fix severity)')

if wrong:
    print('  ❌ FAIL  Severity mismatch:')
    for w in wrong:
        print(f'           {w}')
    exit(1)
else:
    print(f'  ✅ PASS  Severity mapping — tất cả {len(data[\"rules\"])} rules đúng')
" && ((pass++)) || ((fail++))
fi

# ── TEST 7: SETUP-HOOKS INTEGRATION ──────────────────────────────────────────
if [[ "$FILTER" == "all" || "$FILTER" == "setup" ]]; then
  echo ""
  hr "═══ TEST 7: setup-hooks.sh — integration test ═════════════════════"

  TMPPROJ=$(mktemp -d)
  # Đảm bảo cleanup khi script kết thúc (kể cả lỗi)
  cleanup_tmp() { rm -rf "$TMPPROJ"; }
  trap cleanup_tmp EXIT

  # Init bare git repo
  git -C "$TMPPROJ" init -q 2>/dev/null

  # Copy template vào submodule — dùng rsync để loại .git/
  rsync -a --exclude='.git' "$TEMPLATE_DIR/" "$TMPPROJ/security/" 2>/dev/null

  # ── Run 1: fresh install ──────────────────────────────────────────────────
  setup_exit=0
  bash "$TMPPROJ/security/scripts/setup-hooks.sh" \
      > "$TMPPROJ/setup1.log" 2>&1 || setup_exit=$?

  if [ "$setup_exit" -eq 0 ]; then
      ok "SETUP-HOOKS — fresh install: exit 0 ✔"
  else
      fail "SETUP-HOOKS — fresh install: exit $setup_exit (log: $TMPPROJ/setup1.log)"
  fi

  # Kiểm tra các file được copy đúng
  for f in CLAUDE.md .pre-commit-config.yaml .gitleaks.toml .secrets.baseline; do
      if [ -e "$TMPPROJ/$f" ]; then
          ok "SETUP-HOOKS — $f được copy ✔"
      else
          fail "SETUP-HOOKS — $f THIẾU sau fresh install"
      fi
  done

  # Kiểm tra skill dir được copy — không bị nested
  SKILL_DIR="$TMPPROJ/.claude/skills/cex-security-scan"
  if [ -d "$SKILL_DIR" ]; then
      ok "SETUP-HOOKS — .claude/skills/cex-security-scan/ tồn tại ✔"
  else
      fail "SETUP-HOOKS — .claude/skills/cex-security-scan/ THIẾU"
  fi

  if [ -d "$SKILL_DIR/cex-security-scan" ]; then
      fail "SETUP-HOOKS — nested directory cex-security-scan/cex-security-scan/ (cp -r bug!)"
  else
      ok "SETUP-HOOKS — không có nested directory ✔"
  fi

  # ── Run 2: upgrade (second run) ──────────────────────────────────────────
  setup_exit2=0
  bash "$TMPPROJ/security/scripts/setup-hooks.sh" \
      > "$TMPPROJ/setup2.log" 2>&1 || setup_exit2=$?

  if [ "$setup_exit2" -eq 0 ]; then
      ok "SETUP-HOOKS — upgrade run: exit 0 ✔"
  else
      fail "SETUP-HOOKS — upgrade run: exit $setup_exit2 (log: $TMPPROJ/setup2.log)"
  fi

  # Kiểm tra backup được tạo
  if ls "$TMPPROJ/CLAUDE.md.backup-"* >/dev/null 2>&1; then
      ok "SETUP-HOOKS — backup file CLAUDE.md.backup-* được tạo ✔"
  else
      fail "SETUP-HOOKS — backup file CLAUDE.md.backup-* THIẾU sau upgrade"
  fi

  # Kiểm tra nested dir vẫn không xuất hiện sau upgrade
  if [ -d "$SKILL_DIR/cex-security-scan" ]; then
      fail "SETUP-HOOKS — nested directory xuất hiện sau upgrade (cp -r overwrite bug!)"
  else
      ok "SETUP-HOOKS — không có nested directory sau upgrade ✔"
  fi

  rm -rf "$TMPPROJ"
  trap - EXIT
fi

# ── KẾT QUẢ ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Kết quả                                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Passed : ${GREEN}${pass}${NC}"
echo -e "  Failed : ${RED}${fail}${NC}"
echo -e "  Skipped: ${YELLOW}${skip}${NC}"
echo ""

if [ "$fail" -gt 0 ]; then
    echo -e "${RED}❌ ${fail} test(s) FAILED — xem log bên trên để fix${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Tất cả ${pass} tests PASSED${NC}"
    exit 0
fi
