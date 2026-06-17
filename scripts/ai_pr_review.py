#!/usr/bin/env python3
"""
AI PR Security Review Bot — v0.1 (MVP)

Đọc diff của Pull Request, gửi cho Claude API để review bảo mật theo chuẩn CEX,
post findings thành comment trên PR.

Nguyên tắc an toàn dữ liệu:
  - CHỈ gửi diff của PR (không gửi toàn bộ repo)
  - Mask các chuỗi giống secret TRƯỚC khi gửi ra ngoài
  - Anthropic API không dùng dữ liệu khách hàng để train model
  - AI chỉ đề xuất (comment) — không block, không merge

Env vars (set bởi GitHub Actions):
  ANTHROPIC_API_KEY  — secret, bắt buộc (thiếu → skip, exit 0)
  GITHUB_TOKEN       — token mặc định của workflow (cần pull-requests: write)
  GITHUB_REPOSITORY  — owner/repo
  PR_NUMBER          — số PR
"""
import json
import os
import re
import sys
import urllib.request

import anthropic

MODEL = "claude-opus-4-8"
MAX_DIFF_BYTES = 150_000  # ~40k tokens — diff lớn hơn sẽ bị cắt và ghi chú rõ trong comment
MAX_OUTPUT_TOKENS = 8_000

SYSTEM_PROMPT = """\
Bạn là security reviewer cho một sàn giao dịch crypto (CEX) tại Việt Nam.
Mọi code đụng đến balance, withdrawal, order, authentication, KYC đều có tác động tài chính trực tiếp.

Review diff của Pull Request dưới đây và tìm các vấn đề bảo mật. Ưu tiên theo thứ tự:
1. CRITICAL: hardcoded secret/key, SQL injection, command injection, RCE (eval/pickle/yaml.load),
   JWT algorithms=["none"] hoặc verify=False, balance read-then-update thiếu FOR UPDATE,
   PII lưu ngoài region VN (vi phạm Nghị định 356/2025)
2. HIGH: float cho tiền, weak random cho security, log password/token/PII không mask,
   AES-ECB / static IV / nonce reuse, MD5/SHA1/SHA256 cho password (phải dùng Argon2id)
3. MEDIUM: IDOR thiếu ownership check, thiếu input validation tại boundary, error message lộ thông tin

Quy tắc output:
- Viết bằng tiếng Việt, format Markdown
- Mỗi finding: **[SEVERITY] Tiêu đề ngắn** — file:dòng (nếu xác định được), giải thích 1-2 câu, cách sửa 1-2 câu
- Đánh giá độ tin cậy mỗi finding: (chắc chắn) hoặc (cần người xác nhận)
- Nếu KHÔNG có finding nào: trả lời đúng một dòng "✅ Không phát hiện vấn đề bảo mật trong diff này."
- KHÔNG bịa finding. KHÔNG comment về style/naming. Chỉ bảo mật.
- Kết thúc bằng dòng: "_AI review chỉ mang tính đề xuất — quyết định cuối thuộc về reviewer._"
"""

# Pattern mask secret trước khi gửi ra ngoài — thà mask nhầm còn hơn lộ
SECRET_PATTERNS = [
    re.compile(r"(gh[pousr]_[A-Za-z0-9]{20,})"),                        # GitHub tokens
    re.compile(r"(glpat-[A-Za-z0-9._-]{15,})"),                          # GitLab PAT
    re.compile(r"(sk-(?:ant-)?[A-Za-z0-9-]{20,})"),                      # Anthropic/OpenAI keys
    re.compile(r"(AKIA[0-9A-Z]{16})"),                                   # AWS access key id
    re.compile(r"(xox[baprs]-[A-Za-z0-9-]{10,})"),                       # Slack tokens
    re.compile(r"((?i:secret|token|passwd|password|api_?key)\s*[=:]\s*['\"])([^'\"]{8,})(['\"])"),
]


def mask_secrets(text: str) -> str:
    for pat in SECRET_PATTERNS:
        if pat.groups >= 3:
            text = pat.sub(lambda m: m.group(1) + "***MASKED***" + m.group(3), text)
        else:
            text = pat.sub(lambda m: m.group(1)[:6] + "***MASKED***", text)
    return text


def github_api(url: str, token: str, accept: str = "application/vnd.github+json",
               method: str = "GET", body: dict | None = None) -> str:
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"token {token}")
    req.add_header("Accept", accept)
    if body is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(body).encode()
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode()


def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        print("⏭ ANTHROPIC_API_KEY chưa cấu hình — bỏ qua AI review (không fail pipeline)")
        return 0

    gh_token = os.environ["GITHUB_TOKEN"]
    repo = os.environ["GITHUB_REPOSITORY"]
    pr_number = os.environ["PR_NUMBER"]

    # 1. Lấy diff của PR (chỉ diff — không gửi cả repo)
    diff = github_api(
        f"https://api.github.com/repos/{repo}/pulls/{pr_number}",
        gh_token, accept="application/vnd.github.v3.diff",
    )

    truncated = False
    if len(diff.encode()) > MAX_DIFF_BYTES:
        diff = diff.encode()[:MAX_DIFF_BYTES].decode(errors="ignore")
        truncated = True

    # 2. Mask secrets trước khi gửi ra ngoài
    diff = mask_secrets(diff)

    # 3. Gọi Claude API
    client = anthropic.Anthropic(api_key=api_key)
    user_content = f"Diff của PR #{pr_number} (repo {repo}):\n\n```diff\n{diff}\n```"
    if truncated:
        user_content += "\n\n(Lưu ý: diff đã bị cắt do vượt giới hạn kích thước — chỉ review phần trên.)"

    response = client.messages.create(
        model=MODEL,
        max_tokens=MAX_OUTPUT_TOKENS,
        thinking={"type": "adaptive"},
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_content}],
    )

    if response.stop_reason == "refusal":
        print("⏭ Model từ chối review request này — bỏ qua")
        return 0

    review = next((b.text for b in response.content if b.type == "text"), "").strip()
    if not review:
        print("⏭ Không có nội dung review — bỏ qua")
        return 0

    usage = response.usage
    print(f"Tokens: in={usage.input_tokens} out={usage.output_tokens}")

    # 4. Post comment lên PR
    header = "## 🤖 AI Security Review\n\n"
    if truncated:
        header += "> ⚠️ Diff vượt giới hạn kích thước — chỉ phần đầu được review.\n\n"
    github_api(
        f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments",
        gh_token, method="POST",
        body={"body": header + review},
    )
    print(f"✅ Đã post AI review lên PR #{pr_number}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
