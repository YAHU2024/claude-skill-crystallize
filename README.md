# 🚀 Claude Code: Advanced Crystallize Skill

一个专为 **Claude Code (Anthropic CLI)** 打造的全局高级智能体技能。

当你在对话中攻克硬核 Bug、完成重构或重置环境配置后，该技能能够帮你**深度复盘解题路径、记录失败尝试、圈定波及模块**，并以极度整洁的 `<details>` 格式追加沉淀到项目的 `docs/THOUGHTS.md` 中。

---

## ✨ 核心特性

- **时间线追加 (Append-Only)**：像开发日记一样向前推进，永不破坏、覆盖历史资产。
- **深度记录“失败尝试” (Rejected Solutions)**：不仅记正确的解法，更记录走过的弯路，供后续人类查阅并防止 AI 再次陷入逻辑死循环。
- **VS Code 深度联动**：沉淀完成后自动在 VS Code 中执行 `code -r` 唤起文档。
- **面向未来的 RAG 检索**：内置高频工程分类标签、关键词标签与复用价值星级，方便 VS Code 全局搜索或向量知识库读取。

## 📦 快速安装

### 方式 A：一键全局安装 (推荐)
在你的终端中克隆仓库并运行安装脚本：

```bash
git clone [https://github.com/你的用户名/claude-skill-crystallize.git](https://github.com/你的用户名/claude-skill-crystallize.git)
cd claude-skill-crystallize
chmod +x install.sh
./install.sh
```
### 方式 B：手动全局安装

将本仓库中的 `crystallize/SKILL.md` 复制到你电脑的全局技能目录即可：

`~/.claude/skills/crystallize/SKILL.md`

## 🚀 使用指南

启动你的 `claude` 终端：

1. **手动精准触发**：

在攻克复杂问题后，直接在 Claude Code 中输入：

Bash
```bash
/crystallize

```
2. **自然语言触发**：

对 Claude 说：“帮我把刚刚折腾 Docker 踩坑的过程复盘记录一下。”

## 📄 开源协议

[MIT License](https://www.google.com/search?q=LICENSE)

```