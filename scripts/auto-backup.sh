#!/bin/bash
# 自动备份：把工作区的文本类改动提交进本地 git；无改动则跳过
# 由定时任务调用，也可手动执行
set -u
cd "$(dirname "$0")/.." || exit 1

LOG=.git/auto-backup.log
STAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  echo "$STAMP  no changes" >> "$LOG"
  exit 0
fi

git add -A
if git commit -q -m "auto: $STAMP" 2>>"$LOG"; then
  echo "$STAMP  committed $(git rev-parse --short HEAD)" >> "$LOG"
else
  echo "$STAMP  commit failed" >> "$LOG"
  exit 1
fi

# 仓库体积控制（仅本地，不推送）
git gc --auto --quiet 2>/dev/null || true
tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
exit 0
