# Workflow — Cách dùng Template Hằng Ngày

> Hướng dẫn flow áp dụng template cho dev. Đọc 1 lần, áp dụng hàng ngày.

## Flow tổng quát

```
┌─────────────────────────────────────────────────────────────┐
│  1. Threat Model trước khi code                              │
│     /threat-model <feature>                                  │
│     → 30 phút, identify threats, plan mitigations            │
├─────────────────────────────────────────────────────────────┤
│  2. Code với Claude Code                                     │
│     Claude tự đọc CLAUDE.md → gợi ý code đã có guard         │
├─────────────────────────────────────────────────────────────┤
│  3. Scan trước commit                                        │
│     /cex-security                                             │
│     → Trace L1-L4 data flow, tìm CEX-specific issues         │
├─────────────────────────────────────────────────────────────┤
│  4. Git commit                                                │
│     Pre-commit hook tự chạy ~5s                              │
│     → Gitleaks + Bandit + Semgrep custom                     │
├─────────────────────────────────────────────────────────────┤
│  5. Trước PR/MR                                               │
│     cat security/docs/secure-checklist.md                    │
│     → 15 hạng mục checklist                                  │
├─────────────────────────────────────────────────────────────┤
│  6. Push → GitLab CI pipeline (v1.1)                         │
│     Secret scan + SAST + Dependency scan                     │
│     Fail CRITICAL/HIGH → block merge                         │
└─────────────────────────────────────────────────────────────┘
```

## Chi tiết từng bước

### 1. `/threat-model <feature>` — Identify threats

**Khi nào dùng:** feature mới đụng auth, money, wallet, KYC, PII, external integration.

**Output:** file markdown trong `security-reports/threat-model-<slug>-<timestamp>.md` gồm:
- Data flow + trust boundaries
- STRIDE analysis (6 loại threat × component)
- Mitigation mapping với rules có sẵn
- Compliance touch-points (NĐ 356, ATTT L4)
- Open questions cho Security Team

**Ví dụ:**
```
/threat-model API rút tiền với 2FA
```

Claude sẽ hỏi clarification nếu cần, rồi output threat model.

### 2. Code với Claude Code

Claude Code tự đọc:
- `CLAUDE.md` — router 12 quy tắc + bảng dẫn tới docs chi tiết
- `docs/auth.md`, `docs/wallet.md`... — khi đụng domain tương ứng
- `.security/steering/*.md` — context nghiệp vụ + kỹ thuật + pháp lý
- `security-local.md` — nếu project có file này

→ Code sinh ra có sẵn pattern an toàn (parameterized query, FOR UPDATE, Idempotency-Key, generic error...).

### 3. `/cex-security` — Scan trước commit

**Tham số:**
- (không tham số) — scan uncommitted changes (default)
- `staged` — chỉ staged
- `all` — toàn bộ codebase
- `commit <hash>` — 1 commit cụ thể
- `diff main` — diff với branch main

**Output:** report VN + EN trong `security-reports/scan-<timestamp>.md`.

**Khi nào dùng:**
- Sau khi viết xong 1 feature/component
- Trước khi tạo commit lớn
- Khi muốn audit code AI đã sinh

### 4. Pre-commit hook tự chạy

Mỗi `git commit` chạy ~5s:
- **Gitleaks** — secret leak (regex + entropy)
- **detect-secrets** — secret baseline check
- **Bandit** — Python security
- **Semgrep** — custom CEX rules

Pass → commit thành công. Fail → commit chặn, terminal hiện chi tiết.

**Bypass khẩn cấp (KHÔNG khuyến khích):**
```bash
git commit --no-verify
```

### 5. PR/MR checklist

```bash
cat security/docs/secure-checklist.md
```

15 hạng mục — đi qua từng mục liên quan, đánh dấu ✓. Đính kèm checklist vào PR/MR description.

### 6. GitLab CI pipeline (v1.1)

Phát hành cùng **v1.1**. Pipeline tự chạy khi push/MR:
- Secret Detection (Gitleaks)
- SAST (Semgrep — custom CEX rules + community)
- Dependency scan (Trivy)

Finding CRITICAL hoặc HIGH → block merge tự động.

## Quy tắc vàng

1. **Threat model TRƯỚC khi code** cho feature security-sensitive — không phải sau
2. **Đừng skip pre-commit** — bypass = chấp nhận rủi ro
3. **Đừng commit `security-reports/`** — chứa findings nhạy cảm, đã có trong .gitignore
4. **Update template định kỳ** — `cd security && git fetch --tags && git checkout <tag>`
5. **Phản hồi false positive** — báo Security Team qua Slack, không silent suppress
