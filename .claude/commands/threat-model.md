# /threat-model — Threat Model cho Feature Mới

Thực hiện threat modeling theo phương pháp STRIDE cho tính năng/component mới.
Sử dụng subagent `threat-modeler`.

## Khi dùng

**Trước khi viết code** cho:
- Feature mới đụng auth, money, wallet, KYC, PII
- API endpoint mới xử lý dữ liệu nhạy cảm
- Refactor logic bảo mật-sensitive
- Quyết định kiến trúc affect trust boundaries

## Tham số

`$ARGUMENTS` — tên feature hoặc mô tả ngắn.

Ví dụ:
```
/threat-model API rút tiền với 2FA
/threat-model KYC user nước ngoài
/threat-model partner-bank-webhook
```

## Workflow

1. Đọc subagent tại `.claude/agents/threat-modeler.md`
2. Đọc context từ `.security/steering/` (product, tech, compliance)
3. Hỏi user nếu spec chưa rõ
4. Identify trust boundaries (L1-L4)
5. STRIDE analysis cho từng component
6. Map mỗi threat vào mitigation + reference rule có sẵn
7. Output structured threat model
8. Lưu vào `security-reports/threat-model-<slug>-<timestamp>.md`

## Flow đầy đủ cho feature mới (recommend)

```
/threat-model <feature>          # 1. Identify threats trước khi code
  ↓
viết code (với guidance từ threat model)
  ↓
/cex-security                    # 2. Scan code sau khi viết
  ↓
git commit                       # 3. Pre-commit hook (~5s)
  ↓
/security-review                 # 4. Built-in generic OWASP check
  ↓
PR/MR
  ↓
CI pipeline                      # 5. Full scan + community rules
```

3 lớp guard rails: threat model trước, scan trong khi viết, CI sau push.
