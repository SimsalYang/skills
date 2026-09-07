#!/usr/bin/env bash
# 同步本机已安装的 skills 到本仓库（Git Bash 运行：bash sync.sh）
# 新装的 skill 若不在 UPSTREAM 映射表中，默认按「无上游」复制到 local/ 并列入 README，
# 之后可手动把它加进 UPSTREAM 映射表改用上游链接。
set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="https://github.com/SimsalYang/skills"
USER_SKILLS_DIR="$HOME/.kimi-code/skills"
PLUGINS_DIR="$HOME/.kimi-code/plugins/managed"

# skill 名 → 上游 URL（有公开上游的 skill 放这里）
declare -A UPSTREAM=(
  [brainstorming]="https://github.com/obra/superpowers/tree/main/skills/brainstorming"
  [dispatching-parallel-agents]="https://github.com/obra/superpowers/tree/main/skills/dispatching-parallel-agents"
  [executing-plans]="https://github.com/obra/superpowers/tree/main/skills/executing-plans"
  [finishing-a-development-branch]="https://github.com/obra/superpowers/tree/main/skills/finishing-a-development-branch"
  [receiving-code-review]="https://github.com/obra/superpowers/tree/main/skills/receiving-code-review"
  [requesting-code-review]="https://github.com/obra/superpowers/tree/main/skills/requesting-code-review"
  [subagent-driven-development]="https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development"
  [systematic-debugging]="https://github.com/obra/superpowers/tree/main/skills/systematic-debugging"
  [test-driven-development]="https://github.com/obra/superpowers/tree/main/skills/test-driven-development"
  [using-git-worktrees]="https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees"
  [using-superpowers]="https://github.com/obra/superpowers/tree/main/skills/using-superpowers"
  [verification-before-completion]="https://github.com/obra/superpowers/tree/main/skills/verification-before-completion"
  [writing-plans]="https://github.com/obra/superpowers/tree/main/skills/writing-plans"
  [writing-skills]="https://github.com/obra/superpowers/tree/main/skills/writing-skills"
  [code-reviewer]="https://github.com/rmyndharis/antigravity-skills/tree/main/skills/code-reviewer"
  [frontend-design]="https://github.com/anthropics/skills/tree/main/skills/frontend-design"
  [ui-animation]="https://github.com/mblode/agent-skills/tree/main/skills/ui-animation"
  [modern-web-guidance]="https://github.com/GoogleChrome/modern-web-guidance/tree/main/skills/modern-web-guidance"
  [chrome-extensions]="https://github.com/GoogleChrome/modern-web-guidance/tree/main/skills/chrome-extensions"
)

# 收集本机已安装的 skill：名称<TAB>来源目录
declare -A FOUND
collect() { # $1=skill 目录（内含 SKILL.md）
  local dir="$1" name
  name="$(basename "$dir")"
  FOUND[$name]="$dir"
}
# 用户级 skills
if [ -d "$USER_SKILLS_DIR" ]; then
  for d in "$USER_SKILLS_DIR"/*/; do
    [ -f "$d/SKILL.md" ] && collect "${d%/}"
  done
fi
# 插件 skills：plugins/managed/<plugin>/skills/<skill>/SKILL.md
if [ -d "$PLUGINS_DIR" ]; then
  for d in "$PLUGINS_DIR"/*/skills/*/; do
    [ -f "$d/SKILL.md" ] && collect "${d%/}"
  done
  # 插件根目录直接放 SKILL.md 的（如 kimi-datasource）
  for d in "$PLUGINS_DIR"/*/; do
    [ -f "$d/SKILL.md" ] && collect "${d%/}"
  done
fi

# 有上游的 skill 若 local/ 里留有旧副本则删除
for name in "${!UPSTREAM[@]}"; do
  [ -d "local/$name" ] && rm -rf "local/$name"
done

# 无上游的 skill：同步副本到 local/
local_names=()
for name in $(printf '%s\n' "${!FOUND[@]}" | sort); do
  if [ -z "${UPSTREAM[$name]:-}" ]; then
    src="${FOUND[$name]}"
    rm -rf "local/$name"
    mkdir -p "local/$name"
    if [ -f "$src/kimi.plugin.json" ] || [ -f "$src/package.json" ]; then
      # 插件根目录（非纯 skill 目录）：只备份 SKILL.md，避免发布插件专有代码
      cp "$src/SKILL.md" "local/$name/"
    else
      cp -r "$src/." "local/$name/"
    fi
    local_names+=("$name")
  fi
done
# 清理 local/ 中已不在本机的 skill
for d in local/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  [ -z "${FOUND[$name]:-}" ] && { rm -rf "$d"; echo "removed stale local/$name"; }
done

# 生成 README.md
{
  echo "# My Agent Skills"
  echo
  echo "本仓库记录我（SimsalYang）在 Kimi Code 中安装的全部 skills，并备份无公开上游的本地 skills。"
  echo
  echo "安装新 skill 后，运行 \`bash sync.sh\` 即可自动同步本仓库。"
  echo
  echo "## 上游 Skills（链接到原仓库）"
  echo
  for name in $(printf '%s\n' "${!FOUND[@]}" | sort); do
    url="${UPSTREAM[$name]:-}"
    if [ -n "$url" ]; then
      echo "### $name"
      echo "链接: $url"
      echo
    fi
  done
  echo "## 本地 Skills（无公开上游，已备份到本仓库）"
  echo
  for name in $(printf '%s\n' "${local_names[@]:-}" | grep -v '^$' | sort); do
    echo "### $name"
    echo "链接: $REPO_URL/blob/main/local/$name/SKILL.md"
    echo
  done
} > README.md

# 提交并推送
git add -A
if git diff --cached --quiet; then
  echo "已是最新，无变更。"
else
  git commit -q -m "sync skills $(date +%F)"
  git push
  echo "已同步并推送。"
fi
