# Security Template v1.2.1 — Hướng dẫn sử dụng

> **Tài liệu chính thức** đi kèm Security Template. Cập nhật theo từng phiên bản.
> Mọi thành viên tham gia phát triển sản phẩm đều nên đọc mục 1-4.
> Developer đọc thêm mục 5-8 để cài đặt và sử dụng hàng ngày.

**Phiên bản:** 1.2.1
**Cập nhật lần cuối:** 27/05/2026
**Tác giả:** PhiLD · IT Security
**Repo:** `gitlab.example.com/your-org/security-template`

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Khác gì so với hỏi Claude AI bình thường?](#2-khác-gì-so-với-hỏi-claude-ai-bình-thường)
3. [So sánh các lớp bảo vệ](#3-so-sánh-các-lớp-bảo-vệ)
4. [Tương thích với các công cụ AI](#4-tương-thích-với-các-công-cụ-ai)
5. [Cài đặt và kiểm thử](#5-cài-đặt-và-kiểm-thử)
6. [Khi nào dùng công cụ nào?](#6-khi-nào-dùng-công-cụ-nào)
7. [Câu hỏi thường gặp](#7-câu-hỏi-thường-gặp)
8. [Liên hệ hỗ trợ](#8-liên-hệ-hỗ-trợ)

---

## 1. Tổng quan

Security Template là bộ công cụ bảo mật tích hợp trực tiếp vào quy trình phát triển phần mềm. Mục tiêu: **phát hiện lỗi bảo mật tại thời điểm sớm nhất có thể** — ngay trên máy developer, trước khi code được đưa lên GitLab.

Template cung cấp **bốn lớp bảo vệ:**

| Lớp | Công cụ | Thời điểm | Mô tả |
|---|---|---|---|
| **Lớp 1** — Pre-commit hook | Gitleaks, Bandit, Semgrep (custom CEX rules) | Tự động mỗi lần commit (~5 giây) | Phát hiện lỗi rõ ràng: mật khẩu gắn cứng, thuật toán yếu, SQL injection |
| **Lớp 2** — GitLab CI | Gitleaks, Semgrep, Bandit, pip-audit | Tự động mỗi Merge Request | Kiểm tra lần cuối trên server — không thể bỏ qua dù dùng `--no-verify` |
| **Lớp 3** — AI scan | Claude Code + `/cex-security` | Thủ công, trước khi tạo Merge Request | AI rà soát logic: thiếu xác thực, thiếu ghi log, race condition |
| **Lớp 4** — AI threat model | Claude Code + `/threat-model` | Thủ công, trước khi viết tính năng mới | AI phân tích mối đe doạ STRIDE¹, đề xuất biện pháp giảm thiểu |

Lớp 1 và Lớp 2 **tự động và bắt buộc**. Lớp 3 và 4 chạy thủ công, **khuyến nghị** cho feature quan trọng.

> ¹ **STRIDE** — khung phân tích 6 nhóm mối đe doạ: **S**poofing (giả mạo danh tính), **T**ampering (giả mạo dữ liệu), **R**epudiation (chối bỏ hành động), **I**nformation Disclosure (lộ thông tin), **D**enial of Service (từ chối dịch vụ), **E**levation of Privilege (leo thang đặc quyền).

---

## 2. Khác gì so với hỏi Claude AI bình thường?

Khi mở claude.ai và hỏi "code này có an toàn không?", Claude trả lời dựa trên kiến thức chung. Security Template khác ở nhiều điểm:

| Tiêu chí | Hỏi Claude AI trên claude.ai | Security Template |
|---|---|---|
| **Kiến thức** | Kiến thức chung về bảo mật | Quy tắc nội bộ CEX: NĐ 356/2025², wallet 3-layer⁴, KYC flow, A05³ |
| **Chủ động hay bị động** | Bị động — phải nhớ hỏi | Chủ động — tự chặn mỗi commit và MR, không cần nhớ |
| **Nhất quán** | Mỗi lần hỏi có thể trả lời khác | Rules cố định, output nhất quán |
| **Tốc độ** | Copy → paste → đọc (3-5 phút) | Pre-commit: 5 giây, tự động |
| **Bao phủ** | Chỉ file được hỏi | Quét toàn bộ file thay đổi |
| **Tuân thủ pháp lý** | Không biết NĐ 356, A05, ATTT Cấp 4 | Đã tích hợp sẵn |

**Tóm lại:** Hỏi Claude AI giống như hỏi ý kiến chuyên gia bên ngoài. Security Template giống như có chuyên gia bảo mật CEX ngồi cạnh developer, tự động kiểm tra mỗi dòng code.

> ² **NĐ 356/2025** — Nghị định 356/2025/NĐ-CP về bảo vệ dữ liệu cá nhân tại Việt Nam: quy định cách xử lý PII (CCCD, ảnh selfie, số tài khoản ngân hàng), yêu cầu lưu trữ trong vùng địa lý VN (Zone Z4).
>
> ³ **A05** — OWASP Top 10 2021, hạng mục A05:2021 "Security Misconfiguration": lỗi cấu hình bảo mật sai (ví dụ: để mTLS ở chế độ PERMISSIVE thay vì STRICT, bật debug mode trên production).
>
> ⁴ **wallet 3-layer** — kiến trúc ví 3 lớp: **Cold** (offline/air-gapped, HSM, lưu phần lớn tài sản), **Warm** (giới hạn ≤ 10% tổng, dùng cho top-up hot wallet), **Hot** (kết nối online, ≤ 2% tổng, dùng cho withdrawal hàng ngày). Cold wallet không bao giờ kết nối internet trực tiếp.

---

## 3. So sánh các lớp bảo vệ

### Lớp 1 (Pre-commit) vs Lớp 2 (GitLab CI)

| | Pre-commit hook | GitLab CI |
|---|---|---|
| **Chạy khi nào** | Mỗi `git commit` trên máy dev | Mỗi Merge Request trên server |
| **Có thể bỏ qua?** | Có — `git commit --no-verify` | **Không** — chạy trên server |
| **Tốc độ** | ~5 giây | ~2-3 phút |
| **Bắt được** | Lỗi pattern rõ ràng | Như Lớp 1, nhưng không thể bypass |

### Lớp 3 (AI scan) vs Lớp 4 (AI threat model)

| | `/cex-security` | `/threat-model` |
|---|---|---|
| **Mục đích** | Tìm lỗi trong code **đã viết** | Dự đoán mối đe doạ **trước khi viết code** |
| **Input** | Git diff (code thay đổi) | Mô tả tính năng bằng ngôn ngữ tự nhiên |
| **Output** | Danh sách finding + hướng dẫn khắc phục | Bảng STRIDE 6 nhóm + mitigation checklist |
| **Khi nào** | Trước khi tạo MR | Trước khi bắt đầu code feature mới |

Bốn lớp **bổ sung cho nhau**, không thay thế.

---

## 4. Tương thích với các công cụ AI

| Công cụ | Lớp 1 (Pre-commit) | Lớp 2 (GitLab CI) | Lớp 3 (`/cex-security`) | Lớp 4 (`/threat-model`) |
|---|---|---|---|---|
| **Claude Code** (Anthropic) | ✅ | ✅ | ✅ Slash command | ✅ Slash command |
| **Các AI tool khác** (Copilot, Cursor...) | ✅ | ✅ | 🔜 v1.x | 🔜 v1.x |
| **Không dùng AI** | ✅ | ✅ | ❌ | ❌ |

**v1.1 hỗ trợ chính thức Claude Code.** Lớp 1 và Lớp 2 hoạt động với mọi môi trường vì chạy ở tầng Git và GitLab CI, không phụ thuộc AI tool.

---

## 5. Cài đặt và kiểm thử

### 5.1 Yêu cầu chung

| Thành phần | Yêu cầu |
|---|---|
| Hệ điều hành | macOS 12+, Ubuntu 20.04+ (hoặc WSL trên Windows) |
| Git | 2.30 trở lên |
| Python | 3.10 trở lên |
| pre-commit | 4.0 trở lên |
| Node.js (cho Claude Code) | 18 trở lên — **chỉ cần nếu muốn dùng Lớp 3 & 4** |
| Kết nối | VPN nội bộ (truy cập GitLab) |

> 💡 **Lấy Deploy Token:** Nhắn PhiLD trên Slack kênh `#dev-sec-ops`. Token có dạng `gldt-xxxxxxxxxxxx`, Security team cấp trong vòng 1 ngày làm việc.

### 5.2 Cài đặt trên macOS

**Mở Terminal:** nhấn `Cmd + Space`, gõ **Terminal**, nhấn Enter.

```bash
# Kiểm tra công cụ đã có
git --version        # cần >= 2.30
python3 --version    # cần >= 3.10

# Nếu chưa có, cài qua Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git python@3.11

# Cài pre-commit (dùng brew để tránh lỗi PATH)
brew install pre-commit
```

### 5.3 Cài đặt trên Linux / WSL

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y git python3 python3-pip

# Cài pre-commit
# Ubuntu 22.04+ (pip mới, cần flag này):
pip3 install pre-commit --break-system-packages
# Ubuntu 20.04 (nếu lệnh trên báo lỗi "invalid option"):
pip3 install --user pre-commit
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

> 💡 **Kiểm tra phiên bản Ubuntu:** `lsb_release -rs` — nếu là `20.04` dùng dòng `pip3 install --user`.

### 5.4 Clone template và thiết lập

> 👤 **Ai cần đọc mục này?**
> - **Người đầu tiên thêm template vào project** → đọc toàn bộ 5.4.
> - **Thành viên clone project đã có template** → xem [**5.4b**](#54b-clone-project-đã-có-template) ngay bên dưới.

#### 5.4a Thêm template vào project mới

Thực hiện trong thư mục project muốn tích hợp:

```bash
cd <thư-mục-project>

# Bước 1: thêm template làm git submodule
git submodule add https://gitlab.example.com/your-org/security-template.git security
```

Khi Git hỏi **Username** và **Password:**

| Trường | Giá trị |
|---|---|
| Username | Tên đăng nhập GitLab (ví dụ: `john.doe`) hoặc địa chỉ email |
| Password | **Deploy Token** do Security team cấp — dạng `gldt-xxxxxxxxxxxx` |

> 💡 **Chưa có Deploy Token?** Nhắn PhiLD trên Slack `#dev-sec-ops` trước khi bắt đầu bước này.

```bash
# ⚠️ QUAN TRỌNG: Nếu bạn nhúng credentials vào URL (https://user:token@gitlab...)
# hãy xoá token khỏi .gitmodules TRƯỚC KHI commit:
# Đúng:  url = https://gitlab.example.com/...
# Sai:   url = https://user:gldt-xxx@gitlab.example.com/...

# Bước 2: commit submodule vào repo
git add .gitmodules security
git commit -m "chore: add security template submodule"

# Bước 3: chạy script thiết lập
bash security/scripts/setup-hooks.sh

# Bước 4: commit các file cấu hình được tạo ra bởi setup
# (CLAUDE.md, .pre-commit-config.yaml, pyproject.toml, .gitleaks.toml, ...)
git add .
git commit -m "chore: add security template config files"
```

> ⚠️ **pip-audit báo CVE khi commit Bước 4?** — Đây là CVE trong `requirements.txt` của project bạn (không phải lỗi của template). Hai lựa chọn:
> 1. **Nên làm:** Upgrade package lên phiên bản không có CVE theo hướng dẫn pip-audit, commit lại
> 2. **Tạm thời:** `git commit --no-verify -m "..."` để commit config files trước, tạo ticket fix CVE ngay sau đó

**Kết quả mong đợi:** tất cả hook hiển thị "Passed", kết thúc bằng `✅ Setup hoàn tất — version 1.2.1`.

#### 5.4b Clone project đã có template

Nếu project **đã có sẵn** submodule security (do người khác thêm), sau khi `git clone` chạy thêm:

```bash
# Tải submodule về (submodule không tự tải khi clone thông thường)
git submodule update --init --recursive

# Thiết lập pre-commit hooks cho máy này
bash security/scripts/setup-hooks.sh

# Commit các file cấu hình được tạo ra bởi setup
git add . && git commit -m "chore: setup security hooks"
```

> 💡 Git sẽ hỏi credentials khi `submodule update` — nhập cùng Deploy Token đã được cấp (xem bảng ở 5.4a).

### 5.5 Kiểm thử pre-commit hook (5 phút)

**Test A — Code có lỗi (phải bị chặn):**

```bash
cat > test_vuln.py << 'PY'
import hashlib
h = hashlib.md5(b"password").hexdigest()
API_KEY = "sk_live_abc123456789"
PY

git add test_vuln.py
git commit -m "test code có lỗi"
```

Kết quả: commit **bị chặn**. Gitleaks, detect-secrets, Bandit, và Semgrep đều báo lỗi.

> 💡 **Sau khi bị chặn → sửa thế nào?**
> 1. Sửa code vi phạm (hoặc xoá file test)
> 2. `git add <file-đã-sửa>`
> 3. `git commit -m "..."` — hook tự chạy lại

**Test B — Code đúng (phải thông qua):**

```bash
rm test_vuln.py

cat > test_safe.py << 'PY'
import os
import secrets
from decimal import Decimal

API_KEY = os.environ.get("API_KEY")   # OK: lấy từ env, không hardcode
token   = secrets.token_hex(32)       # OK: cryptographically secure
amount  = Decimal("100.00")           # OK: Decimal cho money, không dùng float
PY

git add test_safe.py   # chỉ add file test — không dùng git add -A ở đây
git commit -m "test code đúng"
```

Kết quả: commit **thành công**, tất cả hook hiển thị "Passed".

```bash
# Dọn dẹp sau test
git rm test_safe.py && git commit -m "chore: remove test file"
```

### 5.6 Tích hợp GitLab CI (Lớp 2)

> 👤 **Ai cần làm mục này?** Người setup CI/CD cho project (thường là tech lead hoặc người tạo repo). Chỉ cần làm **một lần** cho mỗi project.

Thêm vào file `.gitlab-ci.yml` của project (tạo mới nếu chưa có):

```yaml
include:
  - project: 'your-org/security-template'
    ref: 'v1.2.1'
    file: '.gitlab-ci.yml'
```

Nếu tên submodule của project không phải `security`, thêm variable:

```yaml
variables:
  SECURITY_SUBMODULE: "tên-thư-mục-submodule"

include:
  - project: 'your-org/security-template'
    ref: 'v1.2.1'
    file: '.gitlab-ci.yml'
```

Commit và push, sau đó tạo một MR bất kỳ để kiểm tra:

```bash
git add .gitlab-ci.yml
git commit -m "ci: add security template pipeline"
git push
```

Vào GitLab → MR → tab **Pipelines** → kiểm tra 6 jobs:

| Job | Trạng thái mong đợi |
|---|---|
| `security:gitleaks` | ✅ Passed |
| `security:semgrep-critical` | ✅ Passed |
| `security:semgrep-high` | ⚠️ Passed (warning) hoặc ✅ |
| `security:bandit` | ✅ Passed hoặc Skipped |
| `security:pip-audit` | ✅ Passed hoặc Skipped |
| `security:slack-alert` | ✅ Passed hoặc Skipped (chỉ chạy khi có CRITICAL) |

> ⚠️ **`security:gitleaks` failed?** Có thể runner chưa có quyền pull image từ Docker Hub. Liên hệ PhiLD để cấu hình registry mirror.

#### 5.6a Bật Slack alert cho #dev-sec-ops (tuỳ chọn)

Khi có CRITICAL finding, CI tự động gửi alert vào Slack `#dev-sec-ops`. Cần setup một lần:

**Bước 1 — Tạo Slack Incoming Webhook:**
1. Vào `https://api.slack.com/apps` → **Create New App** → **From scratch**
2. App Name: `CEX Security CI` · Workspace: chọn workspace công ty
3. Vào **Incoming Webhooks** → bật ON → **Add New Webhook to Workspace**
4. Chọn channel `#dev-sec-ops` → **Allow**
5. Copy URL webhook — dạng `https://hooks.slack.com/services/T.../B.../...`

**Bước 2 — Thêm vào GitLab CI variables:**

Vào project GitLab → **Settings → CI/CD → Variables → Add variable:**

| Key | Value | Flags |
|---|---|---|
| `SLACK_WEBHOOK_URL` | `https://hooks.slack.com/services/...` | ✅ Masked · ✅ Protected |

Từ MR tiếp theo, nếu có CRITICAL finding → `#dev-sec-ops` nhận ngay message với link MR và tên tác giả.

### 5.7 Cài Claude Code (tuỳ chọn — cho Lớp 3 & 4)

Chỉ cần nếu muốn sử dụng slash command `/cex-security` và `/threat-model`.

**macOS:**

```bash
brew install node
npm install -g @anthropic-ai/claude-code
```

**Linux / WSL:**

```bash
# Cài NVM (quản lý Node.js)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts

# Cài Claude Code (KHÔNG dùng sudo)
npm install -g @anthropic-ai/claude-code
```

**Xác thực:** chạy `claude` trong terminal, làm theo hướng dẫn đăng nhập (cần tài khoản Claude Pro/Max hoặc API key). Sau khi xác thực, gõ `/` để xem danh sách slash command. Kỳ vọng thấy `/cex-security` và `/threat-model`.

> ⚠️ **Không thấy `/cex-security` trong danh sách?** Thử theo thứ tự:
> 1. Đảm bảo đang chạy `claude` từ **thư mục gốc của project** (không phải thư mục con), ví dụ: `cd ~/my-project && claude`
> 2. Kiểm tra thư mục skills tồn tại: `ls security/.claude/skills/cex-security-scan/`
> 3. Nếu thiếu — chạy lại `bash security/scripts/setup-hooks.sh`
> 4. Thoát Claude Code (Ctrl+C), mở lại session mới: `claude`
> 5. Vẫn không thấy → liên hệ PhiLD (IT Security)

**Kiểm thử slash command:**

```bash
cd <thư-mục-project-đã-setup>
claude
```

Trong Claude Code:
- Gõ `/threat-model API rút tiền với 2FA` — AI sẽ hỏi 2-3 câu làm rõ, sau đó xuất phân tích STRIDE.
- Gõ `/cex-security` — AI quét code thay đổi và xuất báo cáo finding.

### 5.8 Cập nhật template

Khi Security team phát hành phiên bản mới:

```bash
cd security
git fetch --tags
git checkout <phiên-bản-mới>    # ví dụ: v1.2.1
cd ..
bash security/scripts/setup-hooks.sh

# ⚠️ QUAN TRỌNG: commit lại để repo ghi nhận phiên bản mới
# Bỏ qua bước này → đồng nghiệp pull về vẫn nhận phiên bản cũ
git add security
git commit -m "chore: update security template to <phiên-bản-mới>"
git push
```

Script thiết lập tự động sao lưu file cũ trước khi ghi đè.

---

## 6. Khi nào dùng công cụ nào?

### Sơ đồ quyết định

```
Bắt đầu làm việc
│
├─ Sắp viết tính năng mới liên quan bảo mật (auth, wallet, KYC, payment)?
│  └─ /threat-model <mô tả tính năng>
│     → AI phân tích mối đe doạ STRIDE, xuất danh sách mitigation
│     → Viết code theo danh sách mitigation
│
├─ Đang viết code bình thường
│  └─ Pre-commit hook TỰ ĐỘNG quét mỗi commit (~5 giây)
│     ├─ Bị chặn → Sửa code vi phạm → git add → commit lại
│     └─ Thông qua → Tiếp tục
│
├─ Chuẩn bị tạo Merge Request?
│  └─ /cex-security (khuyến nghị)
│     → AI rà soát toàn bộ diff, tìm lỗi logic, xuất báo cáo
│     → Tạo MR → GitLab CI tự động quét lần cuối (Lớp 2)
│        ├─ CRITICAL found → CI fail, MR bị block → phải fix
│        └─ HIGH found → CI warn, MR vẫn merge được
│
└─ Code đã merge → monitoring, incident response
```

### Bảng tóm tắt

| Tình huống | Công cụ | Bắt buộc? | Thời gian |
|---|---|---|---|
| Mỗi lần commit | Pre-commit hook | **Có** (tự động) | ~5 giây |
| Mỗi Merge Request | GitLab CI | **Có** (tự động) | ~2-3 phút |
| Trước MR cho feature quan trọng | `/cex-security` | Khuyến nghị | ~3 phút |
| Trước khi code tính năng mới | `/threat-model` | Khuyến nghị | ~5 phút |
| Cài đặt ban đầu | `setup-hooks.sh` | 1 lần duy nhất | ~5 phút |

---

## 7. Câu hỏi thường gặp

**Hook chặn code đúng — suppress thế nào?**

Mỗi tool có cách suppress riêng, thêm vào cuối dòng bị flag:

| Tool | Cú pháp suppress | Ví dụ |
|---|---|---|
| Semgrep | `# nosemgrep: rule-id` | `# nosemgrep: security-weak-hash` |
| Bandit | `# nosec BXXX` | `# nosec B324` (B324 = weak hash) |
| detect-secrets | `# pragma: allowlist secret` | `password = "test_only"  # pragma: allowlist secret` |
| Gitleaks | Thêm fingerprint vào `.gitleaksignore` | Xem `gitleaks detect --verbose` để lấy fingerprint |

> ⚠️ Suppress chỉ dùng khi **đã xác nhận false positive**. Nếu chặn nhầm liên tục → báo Security team để điều chỉnh rule, không suppress hàng loạt.

> 💡 **Multi-line match:** Một số rule dùng pattern nhiều dòng (ví dụ `security-sql-fstring` match cả `conn.execute(` lẫn `text(f"...")`). Trong trường hợp đó cần đặt `# nosemgrep: rule-id` trên **cả 2 dòng**:
> ```python
> rows = conn.execute(  # nosemgrep: security-sql-fstring  # field whitelisted
>     text(f"SELECT ... WHERE {field} LIKE :q"),  # nosec B608  # nosemgrep: security-sql-fstring
>     {"q": f"%{query}%"},
> ).fetchall()
> ```

**Developer có thể bỏ qua hook không?**

Có thể dùng `git commit --no-verify` để bỏ qua pre-commit (Lớp 1). Tuy nhiên GitLab CI (Lớp 2) vẫn chặn ở tầng server khi tạo MR — không thể bypass. Thiết kế defense in depth — không phụ thuộc một lớp duy nhất.

**Có ảnh hưởng tới tốc độ làm việc không?**

Pre-commit hook chạy ~5 giây, chỉ quét các file thay đổi (không quét toàn bộ project). GitLab CI chạy ~2-3 phút song song khi MR được tạo, không ảnh hưởng quá trình code. Trong trường hợp hiếm hoi hook chặn nhầm code hợp lệ (false positive), báo Security team để điều chỉnh rule.

**Template có cập nhật theo pháp luật mới không?**

Có. Security team cập nhật rule khi có thay đổi pháp lý hoặc phát hiện mẫu lỗi mới. Developer cập nhật bằng lệnh `cd security && git fetch --tags && git checkout <version-mới>`.

**Dữ liệu code có bị gửi ra ngoài không?**

Pre-commit hook (Lớp 1) và GitLab CI (Lớp 2): **không** — quét hoàn toàn cục bộ/nội bộ, không ra internet. Claude Code (Lớp 3 & 4): code được gửi tới Anthropic API để AI phân tích, tuân thủ chính sách bảo mật dữ liệu của Anthropic (không dùng dữ liệu khách hàng để huấn luyện). Nếu cần bảo mật cao hơn, có thể triển khai qua Amazon Bedrock (dữ liệu không rời VPC).

**Không dùng Claude Code thì có mất gì không?**

Pre-commit hook (Lớp 1) và GitLab CI (Lớp 2) hoạt động đầy đủ mà không cần Claude Code. Chỉ mất Lớp 3 (`/cex-security`) và Lớp 4 (`/threat-model`).

**Hỗ trợ Windows native không?**

Hiện tại khuyến nghị sử dụng qua WSL (Windows Subsystem for Linux). Hướng dẫn WSL có trong mục 5.3. Windows native đang trong roadmap (v1.4).

**Dùng nhiều dự án thì sao?**

Mỗi dự án cài đặt riêng (chạy `setup-hooks.sh` trong từng project). Template là submodule dùng chung, chỉ cần thêm 1 lần rồi setup.

**GitLab CI báo lỗi "image not found"?**

Runner chưa có quyền pull image từ Docker Hub (`zricethezav/gitleaks`, `semgrep/semgrep`, `python:3.12-slim`). Liên hệ PhiLD để cấu hình registry mirror cho GitLab Runner.

---

## 8. Liên hệ hỗ trợ

| Nội dung | Liên hệ |
|---|---|
| **Lấy Deploy Token** | PhiLD (IT Security) — Slack `#dev-sec-ops` |
| Cài đặt, lỗi kỹ thuật, false positive | PhiLD (IT Security) — Slack hoặc email |
| Quy tắc bảo mật, compliance, audit | Linh (Security Reviewer) |
| Đề xuất rule mới, feedback | Kênh Slack `#dev-sec-ops` hoặc GitLab Issue trên repo template |

---

*Tài liệu này thuộc Security Template v1.2.1. Nằm trong `docs/guide.md` của template repo.*

---

## Phụ lục — Tích hợp trên GitHub (bổ sung 06/2026)

Template gốc thiết kế cho GitLab (submodule same-host). Khi dùng trên GitHub, có 2 điểm khác:

### 1. Workflow thay cho `include:`

GitHub Actions không có cơ chế include cross-repo như GitLab CI. Project tích hợp template cần **copy** file `.github/workflows/security.yml` từ template vào repo của mình (workflow tự nhận diện ngữ cảnh submodule — không cần sửa đường dẫn).

### 2. Private submodule cần PAT

`GITHUB_TOKEN` mặc định của workflow **không có quyền** checkout submodule từ repo private khác. Cần:

1. Tạo fine-grained PAT với quyền `Contents: Read` trên repo `security-template`
2. Thêm secret `SUBMODULE_TOKEN` vào repo project (Settings → Secrets → Actions)
3. Sửa bước checkout trong workflow:

```yaml
- uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3
  with:
    submodules: recursive
    token: ${{ secrets.SUBMODULE_TOKEN }}
```

### 3. Enforcement (block merge thật sự)

GitHub plan Free **không hỗ trợ branch protection trên private repo** — job fail chỉ hiện dấu X đỏ, người có quyền write vẫn merge được (soft block). Để hard block: nâng GitHub Team, hoặc dùng GitLab self-hosted (có sẵn merge checks).
