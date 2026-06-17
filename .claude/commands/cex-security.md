# /cex-security — CEX Security Review

Thực hiện security review chuyên sâu cho code CEX (crypto exchange).
Sử dụng skill `cex-security-scan` để scan code, phát hiện lỗ hổng đặc thù tài chính.

## Scope

Mặc định: scan git diff (uncommitted + staged changes).

Tham số: $ARGUMENTS
- `uncommitted` — chỉ scan thay đổi chưa commit (mặc định)
- `staged` — chỉ scan thay đổi đã staged
- `all` — scan toàn bộ codebase
- `commit <hash>` — scan 1 commit cụ thể
- `diff <branch>` — scan diff với branch cụ thể

## Workflow

1. Đọc skill tại `.claude/skills/cex-security-scan/SKILL.md`
2. Đọc rules tại `.claude/skills/cex-security-scan/rules/`
3. Đọc bối cảnh CEX tại `.security/steering/` (nếu có)
4. Áp dụng reasoning-first scan (không pattern matching)
5. Phân loại L1-L4 data flow cho mỗi finding
6. Output report bilingual VN + EN
7. Lưu report vào `security-reports/scan-<timestamp>.md`

## Lưu ý

- Mỗi finding chỉ thuộc 1 rule (không gắn nhiều tag)
- Verify finding bằng cách trace data flow, không chỉ match pattern
- Skip false positives: constants, env vars, trusted sources
- Bilingual report: VN tóm tắt, EN chi tiết JSON summary cho CI
