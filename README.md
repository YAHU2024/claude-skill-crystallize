# claude-skills

一套可复用的 [Claude Code](https://claude.com/claude-code) 技能（skill）集合。每个技能独立成目录，按需取用。

[English](README.en.md)

## 包含的技能

| 技能 | 一句话说明 | 适用场景 |
|---|---|---|
| [`crystallize`](crystallize/) | 解题后深度复盘，把路径 / 失败尝试 / 影响范围沉淀到 `docs/THOUGHTS.md` | 攻克难题后自动 / 手动 `/crystallize` 沉淀经验 |
| [`multi-agent-scaffold`](multi-agent-scaffold/) | 一键铺设"多智能体协同开发"脚手架（1 主调度 + 5 子智能体） | 想搭 agent 团队、并行测试、断点续跑、无人值守长跑 |

两者互补：**搭脚手架**产出协同开发流程，**沉淀经验**把过程中的踩坑蒸馏复用——`multi-agent-scaffold` 里的 `/crystallize-experience` 命令直接复用 `crystallize` 的 `docs/THOUGHTS.md` 落点格式。

## 安装

**方式 A：一键安装（推荐）**

```bash
git clone https://github.com/YAHU2024/claude-skills.git
cd claude-skills
chmod +x install.sh
./install.sh
```

**方式 B：手动安装**

把需要的技能目录复制到 Claude Code 的 skills 目录：

```bash
# 全局（推荐，所有项目可用）
cp -r crystallize            ~/.claude/skills/
cp -r multi-agent-scaffold  ~/.claude/skills/

# 或仅当前项目
cp -r crystallize           <你的项目>/.claude/skills/
cp -r multi-agent-scaffold  <你的项目>/.claude/skills/
```

（Windows 对应路径为 `%USERPROFILE%\.claude\skills\`。）

## 目录结构

```
claude-skills/
├── README.md
├── README.en.md
├── LICENSE
├── install.sh
├── .gitignore
├── crystallize/             # 经验沉淀技能
│   └── SKILL.md
└── multi-agent-scaffold/    # 多智能体脚手架技能
    ├── SKILL.md
    ├── README.md
    ├── assets/scaffold/     # 铺设用的模板（agent / command / docs）
    ├── references/          # 深入文档（按需阅读，不必铺设）
    └── evals/               # 触发评测集（参考，不进 .skill 包）
```

## License

[MIT License](LICENSE)
