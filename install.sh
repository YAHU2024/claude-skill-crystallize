#!/usr/bin/env bash

# 定义高亮颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[Claude Skills] 开始安装技能集合...${NC}"

# 创建全局目标目录
TARGET_BASE="$HOME/.claude/skills"
mkdir -p "$TARGET_BASE"

# 要安装的技能（仓库内每个技能一个目录）
SKILLS=(crystallize multi-agent-scaffold)

for s in "${SKILLS[@]}"; do
  if [ -d "$s" ]; then
    cp -r "$s" "$TARGET_BASE/$s"
    echo -e "${GREEN}[成功] 已安装 $s -> $TARGET_BASE/$s${NC}"
  else
    echo "警告: 未找到 $s 目录，跳过。"
  fi
done

echo -e "${BLUE}[提示] 现在你可以在任意项目中启动 Claude Code 使用这些技能了。${NC}"
