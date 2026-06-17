> ⚠️ **Sandbox học tập / Learning sandbox** — Bản công khai đã sanitize, dùng để nghiên cứu và document quy trình DevSecOps (CI security scan + GitOps + AI review). Nội dung công ty đã được thay bằng ví dụ generic.

# Security Template v1.2.1

> Bộ công cụ bảo mật tích hợp vào quy trình phát triển phần mềm cho dự án CEX.
> Security Team maintain — project add vào là dùng.

📖 **[Hướng dẫn đầy đủ → docs/guide.md](docs/guide.md)** · [Changelog](CHANGELOG.md)

---

## Cài đặt nhanh

### Bước 0 — Lấy Deploy Token

Nhắn **PhiLD** trên Slack `#dev-sec-ops`: *"Cần deploy token cho project `<tên-project>`"*. Token dạng `gldt-xxx`, cấp trong 1 ngày làm việc.

Sau khi có token, configure **local** (không commit vào repo):

```bash
# Thay secdev và gldt-xxx bằng username/token được cấp
git config --local \
  url."https://secdev:gldt-xxx@gitlab.example.com".insteadOf \
  "https://gitlab.example.com"
```

> ⚠️ Không paste token vào URL trực tiếp khi dùng `git submodule add` — token sẽ bị lưu vào `.gitmodules` và commit vào repo.

### Bước 1–4 — Setup

```bash
cd /path/to/your-project

# 1. Thêm template làm git submodule (URL không có token)
git submodule add https://gitlab.example.com/your-org/security-template.git security

# 2. Commit submodule
git add .gitmodules security
git commit -m "chore: add security template submodule"

# 3. Chạy setup
bash security/scripts/setup-hooks.sh

# 4. Commit các file cấu hình được tạo bởi setup
git add .
git commit -m "chore: add security template config files"
```

Kết quả: script kết thúc bằng `✅ Setup hoàn tất — version 1.2.1`.

> 💡 **pip-audit báo CVE trong bước quét đầu?** Đây là CVE trong `requirements.txt` của project — không phải lỗi template. Xem [hướng dẫn xử lý](docs/guide.md#54-clone-template-và-thiết-lập) trong guide §5.4a.

> 💡 **Hook auto-fix file (trailing-whitespace, end-of-file)?** Pre-commit tự sửa file nhưng commit vẫn fail — chạy lại `git add <file> && git commit` là xong.

---

## Bốn lớp bảo vệ

| Lớp | Công cụ | Thời điểm | Bắt buộc? |
|---|---|---|---|
| **1** — Pre-commit hook | Gitleaks, Bandit, Semgrep (custom CEX rules) | Tự động mỗi commit (~5 giây) | ✅ Có |
| **2** — GitLab CI | Gitleaks, Semgrep, Bandit, pip-audit | Tự động mỗi Merge Request | ✅ Có |
| **3** — AI scan | Claude Code `/cex-security` | Thủ công, trước MR | Khuyến nghị |
| **4** — AI threat model | Claude Code `/threat-model` | Thủ công, trước khi code feature mới | Khuyến nghị |

### Tích hợp GitLab CI

Thêm vào `.gitlab-ci.yml` của project:

```yaml
include:
  - project: 'your-org/security-template'
    ref: 'v1.2.1'
    file: '.gitlab-ci.yml'
```

Mặc định submodule tên `security`. Nếu khác → thêm variable:

```yaml
variables:
  SECURITY_SUBMODULE: "tên-submodule-của-bạn"
```

---

## Rule coverage — 44 rules · 5 ngôn ngữ

| Ngôn ngữ | Rules | Platform |
|---|---|---|
| Python | 23 | Backend APIs, FastAPI, SQLAlchemy |
| JavaScript / TypeScript | 15 | Node.js BE, React FE |
| Kotlin | 8 | Android |
| Swift | 7 | iOS |
| Java | 5 | Android (shared với Kotlin rules) |

---

## Sử dụng hàng ngày

**Pre-commit hook** chạy tự động mỗi `git commit` — không cần làm gì thêm.

**Claude Code:**

```
/cex-security              # scan uncommitted changes (default)
/cex-security all          # scan toàn bộ codebase
/cex-security diff main    # scan diff với branch main
/threat-model <tính năng>  # threat model trước khi code
```

**Trước mỗi MR:**

```bash
pre-commit run --all-files        # quét toàn bộ
cat security/docs/secure-checklist.md  # bảng kiểm 15 mục
```

---

## Yêu cầu

| Thành phần | Yêu cầu |
|---|---|
| Python | 3.10+ |
| Git | 2.30+ |
| pre-commit | 4.0+ |
| Node.js | 18+ *(chỉ cần cho Claude Code)* |

---

## Cập nhật template

```bash
cd security && git fetch --tags && git checkout <phiên-bản-mới>
cd .. && bash security/scripts/setup-hooks.sh
git add security && git commit -m "chore: update security template to <phiên-bản-mới>"
git push
```

---

## Xử lý sự cố

**False positive:**
- Gitleaks: thêm fingerprint vào `.gitleaksignore`
- Semgrep: thêm `# nosemgrep: rule-id` cuối dòng đó
- Bandit: thêm `# nosec BXXX` cuối dòng đó (ví dụ: `# nosec B324`)
- detect-secrets: thêm `# pragma: allowlist secret` cuối dòng đó
- Không chắc → hỏi Security Team trên `#dev-sec-ops`

**Bypass khẩn cấp** *(chỉ khi thực sự cần thiết)*:
```bash
git commit --no-verify
```

---

## Phản hồi

Báo Security Team qua Slack hoặc GitLab Issue:
- Hook chặn nhầm code đúng (false positive)
- `/cex-security` bỏ sót lỗi
- Đề xuất rule mới

---

**Security Team · 2026** · [Hướng dẫn đầy đủ](docs/guide.md)
