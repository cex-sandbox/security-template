#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TEMPLATE_DIR")"
VERSION="$(cat "$TEMPLATE_DIR/VERSION" 2>/dev/null || echo "unknown")"

if [ "$TEMPLATE_DIR" = "$PROJECT_ROOT" ]; then
    echo "⚠️  Đang chạy standalone (không phải submodule)"
    PROJECT_ROOT="$TEMPLATE_DIR"
    IS_SUBMODULE=false
else
    IS_SUBMODULE=true
    SUBMODULE_NAME="$(basename "$TEMPLATE_DIR")"
fi

echo "╔══════════════════════════════════════════╗"
echo "║  Security Template v${VERSION}"
echo "║  Submodule: ${SUBMODULE_NAME:-(standalone)}"
echo "║  Project:   $PROJECT_ROOT"
echo "╚══════════════════════════════════════════╝"

# ===== Helper: portable relative path (macOS + Linux) =====
rel_path() {
    python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$2"
}

# ===== Helper: safe copy with warning =====
safe_copy() {
    local src="$1"
    local dst="$2"
    local name="$3"

    if [ -e "$dst" ]; then
        # File đã tồn tại — backup rồi mới ghi đè
        cp "$dst" "$dst.backup-$(date +%s)"
        echo "⚠️  $name đã có — backup tại $(basename $dst).backup-*"
    fi
    cp "$src" "$dst"
    echo "✅ $name → $(rel_path "$dst" "$PROJECT_ROOT")"
}

safe_copy_dir() {
    local src="$1"
    local dst="$2"
    local name="$3"

    if [ -d "$dst" ]; then
        local backup="$dst.backup-$(date +%s)"
        mv "$dst" "$backup"
        echo "⚠️  $name đã có — backup tại $(basename $backup)"
    fi
    cp -r "$src" "$dst"
    echo "✅ $name → $(rel_path "$dst" "$PROJECT_ROOT")"
}

echo ""
echo "=== Kiểm tra yêu cầu ==="

command -v python3 &>/dev/null || { echo "❌ Python 3 chưa cài"; exit 1; }
echo "✅ Python $(python3 --version 2>&1 | cut -d' ' -f2)"
python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" 2>/dev/null || \
    echo "⚠️  Python 3.10+ khuyến nghị (hiện tại: $(python3 --version 2>&1)) — một số type hint trong CEX code có thể lỗi"

command -v git &>/dev/null || { echo "❌ Git chưa cài"; exit 1; }
echo "✅ $(git --version)"

git -C "$PROJECT_ROOT" rev-parse --git-dir &>/dev/null || { echo "❌ $PROJECT_ROOT không phải git repo"; exit 1; }
echo "✅ Git repo"

echo ""
echo "=== Cài đặt pre-commit ==="

_install_precommit() {
    pip install pre-commit --break-system-packages -q 2>/dev/null && return 0
    pip install pre-commit -q 2>/dev/null && return 0
    pip3 install --user pre-commit -q 2>/dev/null && return 0
    return 1
}

if ! _install_precommit; then
    echo "❌ Không thể cài pre-commit tự động. Cài thủ công:"
    echo "   macOS:      brew install pre-commit"
    echo "   Linux/WSL:  pip3 install --user pre-commit"
    echo "               echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    exit 1
fi

PC_VERSION="$(pre-commit --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
PC_MAJOR="$(echo "$PC_VERSION" | cut -d. -f1)"
echo "✅ pre-commit $PC_VERSION"
if [ -n "$PC_MAJOR" ] && [ "$PC_MAJOR" -lt 4 ] 2>/dev/null; then
    echo "⚠️  Phiên bản $PC_VERSION < 4.0 được yêu cầu — nâng cấp:"
    echo "   brew upgrade pre-commit           (macOS)"
    echo "   pip install --upgrade pre-commit  (Linux)"
fi

if [ "$IS_SUBMODULE" = true ]; then
    echo ""
    echo "=== Copy file ra gốc project ==="

    safe_copy "$TEMPLATE_DIR/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md" "CLAUDE.md"
    safe_copy "$TEMPLATE_DIR/.pre-commit-config.yaml" "$PROJECT_ROOT/.pre-commit-config.yaml" ".pre-commit-config.yaml"

    if [ ! -f "$PROJECT_ROOT/pyproject.toml" ]; then
        cp "$TEMPLATE_DIR/pyproject.toml" "$PROJECT_ROOT/pyproject.toml"
        echo "✅ pyproject.toml → gốc (mới)"
    else
        if ! grep -q "\[tool.bandit\]" "$PROJECT_ROOT/pyproject.toml"; then
            echo "" >> "$PROJECT_ROOT/pyproject.toml"
            cat "$TEMPLATE_DIR/pyproject.toml" >> "$PROJECT_ROOT/pyproject.toml"
            echo "⚠️  pyproject.toml đã có — đã APPEND [tool.bandit] config"
        else
            echo "⚠️  pyproject.toml đã có [tool.bandit] — bỏ qua"
        fi
    fi

    cp "$TEMPLATE_DIR/.secrets.baseline" "$PROJECT_ROOT/.secrets.baseline" 2>/dev/null && echo "✅ .secrets.baseline" || true

    cp "$TEMPLATE_DIR/.gitleaks.toml" "$PROJECT_ROOT/.gitleaks.toml" 2>/dev/null && echo "✅ .gitleaks.toml" || true

    # Merge .claude/ — không replace nguyên khối, tránh mất custom config
    if [ -d "$TEMPLATE_DIR/.claude" ]; then
        for subdir in agents commands skills; do
            src="$TEMPLATE_DIR/.claude/$subdir"
            dst="$PROJECT_ROOT/.claude/$subdir"
            if [ -d "$src" ]; then
                mkdir -p "$dst"
                for f in "$src"/*; do
                    [ -e "$f" ] || continue
                    fname="$(basename "$f")"
                    if [ -e "$dst/$fname" ]; then
                        cp -r "$dst/$fname" "$dst/$fname.backup-$(date +%s)"
                        echo "⚠️  .claude/$subdir/$fname đã có — backup"
                        # Xóa entry cũ sau backup — tránh cp -r copy vào bên trong dir
                        rm -rf "$dst/$fname"
                    fi
                    cp -r "$f" "$dst/$fname"
                done
                echo "✅ .claude/$subdir/ → merged"
            fi
        done
    fi

    # Setup .gitignore — append nếu cần
    if [ ! -f "$PROJECT_ROOT/.gitignore" ]; then
        cp "$TEMPLATE_DIR/.gitignore.example" "$PROJECT_ROOT/.gitignore"
        echo "✅ .gitignore (mới)"
    else
        if ! grep -q "security-reports" "$PROJECT_ROOT/.gitignore"; then
            echo "" >> "$PROJECT_ROOT/.gitignore"
            echo "# Security template entries" >> "$PROJECT_ROOT/.gitignore"
            echo "security-reports/" >> "$PROJECT_ROOT/.gitignore"
            echo "security-local.md" >> "$PROJECT_ROOT/.gitignore"
            echo "*.backup-*" >> "$PROJECT_ROOT/.gitignore"
            echo "*.backup-*/" >> "$PROJECT_ROOT/.gitignore"
            echo "✅ .gitignore — APPENDED security entries"
        fi
    fi

    echo ""
    echo "=== Cập nhật paths ==="
    python3 -c "
import os, sys
root = '$PROJECT_ROOT'
sub = '$SUBMODULE_NAME'

# Validate semgrep rule file tồn tại
semgrep_rule = os.path.join(root, sub, '.semgrep', 'rules', 'security.yml')
if not os.path.exists(semgrep_rule):
    print('⚠️  ' + semgrep_rule + ' không tìm thấy')
    print('   Semgrep hook sẽ báo lỗi khi chạy — kiểm tra lại submodule')
else:
    # Semgrep path trong pre-commit
    f = os.path.join(root, '.pre-commit-config.yaml')
    content = open(f).read()
    content = content.replace(\"'--config=.semgrep/rules/security.yml'\", \"'--config=\" + sub + \"/.semgrep/rules/security.yml'\")
    open(f, 'w').write(content)
    print('✅ Semgrep path → ' + sub + '/.semgrep/rules/security.yml')

# Docs path trong CLAUDE.md
f = os.path.join(root, 'CLAUDE.md')
content = open(f).read()
content = content.replace('docs/', sub + '/docs/')
open(f, 'w').write(content)
print('✅ Docs path → ' + sub + '/docs/')
"
fi

echo ""
echo "=== Cài đặt hooks ==="
cd "$PROJECT_ROOT"
pre-commit install || {
    echo "❌ pre-commit install thất bại"
    echo "   Kiểm tra PATH: which pre-commit"
    echo "   Thử chạy thủ công: cd $PROJECT_ROOT && pre-commit install"
    exit 1
}

echo ""
echo "=== Quét lần đầu ==="
pre-commit run --all-files 2>&1 || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ Setup hoàn tất — version ${VERSION}"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Sử dụng hàng ngày:"
echo "  • Viết code bình thường — pre-commit hook chặn lỗi ~5s mỗi commit"
echo "  • Claude Code: /cex-security              — scan code thay đổi"
echo "  • Claude Code: /threat-model <feature>    — threat model cho tính năng mới"
echo "  • Trước PR/MR: cat ${SUBMODULE_NAME:+$SUBMODULE_NAME/}docs/secure-checklist.md"
echo ""
if [ "$IS_SUBMODULE" = true ]; then
echo "Cập nhật template (khi Security release version mới):"
echo "  cd $SUBMODULE_NAME && git fetch --tags && git checkout <tag>"
echo "  cd .. && bash $SUBMODULE_NAME/scripts/setup-hooks.sh"
echo "  git add $SUBMODULE_NAME && git commit -m \"chore: update security template to <tag>\""
echo "  git push"
fi
echo ""
