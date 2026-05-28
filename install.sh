#!/bin/bash

# 定义高亮颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[Claude Skill] 开始安装 Advanced Crystallize Skill...${NC}"

# 创建全局目标目录
TARGET_DIR="$HOME/.claude/skills/crystallize"
mkdir -p "$TARGET_DIR"

# 复制 Skill 文件
cp crystallize/SKILL.md "$TARGET_DIR/SKILL.md"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[成功] Skill 已成功安装到全局目录: $TARGET_DIR/SKILL.md${NC}"
    echo -e "${BLUE}[提示] 现在你可以在任意项目中启动 Claude Code，并使用 /crystallize 唤醒它了！${NC}"
else
    echo "错误: 安装失败，请检查权限。"
    exit 1
fi