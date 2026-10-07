#!/usr/bin/env bash
# 一键将当前仓库代码同步到 https://github.com/jinbo8/openai.git
#
# 用法:
#   ./scripts/sync_to_github.sh              # 提交本地改动（如有）并推送当前分支
#   ./scripts/sync_to_github.sh --all        # 额外推送所有本地分支与标签
#   ./scripts/sync_to_github.sh --no-commit  # 不自动提交，仅推送已有提交
#   ./scripts/sync_to_github.sh --dry-run    # 只打印将要执行的操作
set -euo pipefail

REMOTE_NAME="${SYNC_REMOTE_NAME:-openai}"
REMOTE_URL="${SYNC_REMOTE_URL:-https://github.com/jinbo8/openai.git}"
COMMIT_MSG_DEFAULT="chore: sync local changes"

PUSH_ALL=0
AUTO_COMMIT=1
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --all) PUSH_ALL=1 ;;
    --no-commit) AUTO_COMMIT=0 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数: $arg" >&2
      echo "支持: --all | --no-commit | --dry-run | -h" >&2
      exit 1
      ;;
  esac
done

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  echo "错误: 当前目录不在 git 仓库中" >&2
  exit 1
fi
cd "$ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
  echo "错误: 当前处于 detached HEAD，请先切换到分支再同步" >&2
  exit 1
fi

echo "==> 仓库: $ROOT"
echo "==> 分支: $BRANCH"
echo "==> 远程: $REMOTE_NAME -> $REMOTE_URL"

# 配置/更新同步用远程（不影响 origin）
if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  CURRENT_URL="$(git remote get-url "$REMOTE_NAME")"
  if [[ "$CURRENT_URL" != "$REMOTE_URL" ]]; then
    run git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
  else
    echo "==> 远程已存在且 URL 正确"
  fi
else
  run git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

# 可选：自动提交未提交改动
if [[ "$AUTO_COMMIT" -eq 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    MSG="${SYNC_COMMIT_MSG:-$COMMIT_MSG_DEFAULT ($(date '+%Y-%m-%d %H:%M:%S'))}"
    echo "==> 发现本地改动，自动提交: $MSG"
    run git add -A
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] git commit -m \"$MSG\""
    else
      git commit -m "$MSG"
    fi
  else
    echo "==> 工作区干净，无需提交"
  fi
else
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "警告: 工作区有未提交改动，且使用了 --no-commit，这些改动不会被推送" >&2
  fi
fi

# 推送当前分支（空仓库首次推送也适用）
echo "==> 推送分支 $BRANCH ..."
run git push -u "$REMOTE_NAME" "$BRANCH"

if [[ "$PUSH_ALL" -eq 1 ]]; then
  echo "==> 推送所有本地分支 ..."
  # 跳过当前分支（已推送）与特殊引用
  while IFS= read -r b; do
    [[ -z "$b" || "$b" == "$BRANCH" ]] && continue
    run git push "$REMOTE_NAME" "$b"
  done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

  echo "==> 推送所有标签 ..."
  if [[ -n "$(git tag -l)" ]]; then
    run git push "$REMOTE_NAME" --tags
  else
    echo "==> 无本地标签"
  fi
fi

echo
echo "同步完成: $REMOTE_URL"
echo "查看: https://github.com/jinbo8/openai"
echo
echo "提示:"
echo "  - 日常同步: ./scripts/sync_to_github.sh"
echo "  - 推送全部分支/标签: ./scripts/sync_to_github.sh --all"
echo "  - 自定义提交说明: SYNC_COMMIT_MSG='你的说明' ./scripts/sync_to_github.sh"
echo "  - 若 HTTPS 需要登录，可改用 SSH URL:"
echo "      SYNC_REMOTE_URL='git@github.com:jinbo8/openai.git' ./scripts/sync_to_github.sh"
