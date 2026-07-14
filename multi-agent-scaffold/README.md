# multi-agent-scaffold

一个 Claude Code 技能（skill）：**一键在任意项目中铺设一套"多智能体协同开发"脚手架**。

> 1 个主调度（Master）+ 5 个子智能体（计划 / 开发 / 3 个测试维度）。
> 通过**传路径解耦、并行测试、预算内升级循环、双层经验账本**协作，主会话始终精简。
> 支持**人在环一次性跑完**与**无人值守长跑（loop/cron 反复唤起短跑驱动器）**。

## 这个脚手架解决什么

- 大任务 / 长周期开发时，主会话上下文容易被撑爆、质量下滑。
- 想要"顶层设计"与"具体编码"职责分离，并多维**并行**质量把关。
- 子智能体的踩坑经验希望**跨任务、跨会话沉淀复用**。
- 想做**无人值守长跑**：睡前丢需求，定时反复唤起，早上收报告。

## 角色与分工

| 角色 | 身份 | 职责 |
|---|---|---|
| 主调度 Master | 主会话 | 全局调度、传路径、判定、维护 `docs/status.json` 状态机。**不读业务代码、不编码** |
| planning-agent | 子智能体 | 读需求路径 → 产出任务拆解计划 `docs/PLAN.md`（只设计不编码） |
| dev-agent | 子智能体 | 领单个任务 → 编码 → **返回文件路径**（非代码内容）；崩后靠 `docs/task_state_<id>.md` 续跑 |
| test-function | 子智能体 | 维度 A：功能/单元测试 |
| test-security | 子智能体 | 维度 B：安全合规审计 |
| test-integration | 子智能体 | 维度 C：集成/端到端 |

## 安装

把本仓库的 `multi-agent-scaffold/` 目录复制到你的 Claude Code skills 目录：

```bash
# 全局（推荐，所有项目可用）
cp -r multi-agent-scaffold ~/.claude/skills/

# 或仅当前项目
cp -r multi-agent-scaffold <你的项目>/.claude/skills/
```

（Windows 上对应路径为 `%USERPROFILE%\.claude\skills\`。）

安装后，在 Claude Code 中对该项目说"帮我搭一套多智能体协同开发脚手架"或"铺设 agent 团队"，即可触发本 skill，
它会把 5 个 agent + 3 个命令 + 状态机/账本模板铺进项目，并按你的项目做少量适配。

## 铺设后怎么用

```bash
# ① 写一份需求文档 docs/YOUR_REQ.md（背景 / 目标 / 产出物 / 约束 / 验收维度）
# ② 首次规划：生成 docs/PLAN.md + 初始化 docs/status.json，然后退出
/orchestrate "docs/YOUR_REQ.md"
# ③ 人在环：再跑一次处理下一个任务；或无人值守长跑：
/loop 10m /orchestrate
# ④ 随时熔断（不用停 loop）：把 docs/status.json 的 circuit_breaker 改成 true
```

## 核心机制

- **传路径解耦**：子智能体间只传本地路径 + 摘要，绝不把代码正文粘回主调度，主会话上下文极小。
- **并行测试**：三个测试 agent 在同一条消息内并发派发，分别独立验收，主调度汇总。
- **升级循环（每任务预算 7 次）**：≤3 修复（SendMessage 续跑同实例）→ 4–5 重规划 → 6–7 降级 partial；>7 suspended。env-blocked 不计入失败预算。
- **状态机 `docs/status.json`**：长跑唯一真相源，跨进程重启靠它续跑。
- **工作态落盘 `docs/task_state_<id>.md`**：dev 实时写，进程重启后新实例读它无缝续跑。
- **双层经验账本**：顶部索引块（主调度只读前 ~40 行，token 精简）+ 底部完整记录（按需 Grep）。
- **短跑 + loop = 长跑**：驱动器每次只处理一个任务就退出，由 loop/cron 反复唤起；状态全在文件里，断点续跑是一等公民。

## 目录结构

```
multi-agent-scaffold/
├── SKILL.md                       # 触发 + 铺设/适配指南（本说明的精简版）
├── README.md
├── assets/scaffold/               # 铺设用的模板（原样拷进目标项目）
│   ├── agents/                    # planning / dev / 3×test 五个子智能体
│   ├── commands/                  # orchestrate / run-batch / crystallize-experience
│   └── docs/                      # status.json.example / AGENT_EXPERIENCE.md.example
└── references/                    # 深入文档（按需阅读，不必铺设）
    ├── MULTI_AGENT_SCAFFOLD.md    # 脚手架总览 + 完整模板 + 适配指南 + 实战经验
    └── MULTI_AGENT_USAGE.md       # 使用说明（状态机/升级/续跑/运维/已知天花板）
```

## 已知天花板

- 执行层已自治，但"需求是否被满意满足"对主观/质量类需求（如摘要生成好坏）无自动 oracle——测试只能验"返回了、字段非空"，验不了"好不好"，仍需人工抽检。
- 需求若有歧义/冲突/不可能项，agent 不会替你做产品决策，会在升级循环耗尽预算后 suspended。

## License

MIT
