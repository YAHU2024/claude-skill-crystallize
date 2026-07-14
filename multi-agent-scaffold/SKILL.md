---
name: multi-agent-scaffold
description: 一键在 Claude Code 项目中铺设一套"多智能体协同开发"脚手架（1 个主调度 + 5 个子智能体：计划/开发/3 个测试维度）。当用户想要把大任务拆给有独立上下文的子智能体并行开发+测试、希望主会话保持精简、需要断点续跑/无人值守长跑、或想搭建多 agent 协作工作流时，使用本 skill。即使用户没说"多智能体"，只要提到"大任务拆分给子 agent 协同做""搭一个开发流水线/agent 团队""无人值守跑开发任务""让多个 agent 并行测试验收"，都应触发。
---

# 多智能体协同开发脚手架 · 铺设器

把一整套基于 Claude Code 子智能体（sub-agent）的协同开发模板铺进**当前项目**：
**1 个主调度（Master）+ 5 个子智能体**（planning / dev / test-function / test-security / test-integration），
通过**传路径解耦、并行测试、预算内升级循环（修复/重规划/降级，复用同一实例）、双层经验账本**协作，
主会话始终精简。支持**人在环一次性跑完**与**无人值守长跑（loop/cron 反复唤起短跑驱动器）**两种模式。

> 这套脚手架已经在真实项目中冒烟验证过（短跑驱动 + status.json 状态机端到端跑通）。
> 本 skill 负责把模板铺到项目里，并按你的项目做少量适配。

## 何时用

- 任务周期长 / 改动面大，主会话上下文容易被撑爆。
- 想让"顶层设计"与"具体编码"职责分离，并多维**并行**质量把关。
- 希望子智能体的踩坑经验**跨任务、跨会话沉淀复用**。
- 想做**无人值守长跑**：睡前丢需求，定时反复唤起，早上收报告。

不适用：纯对话咨询、单文件小改动、无需并行测试/验收的简单任务。

## 铺设产物（文件树）

```
<项目根>/
├── .claude/
│   ├── agents/
│   │   ├── planning-agent.md      # 读需求 → 产出任务拆解 docs/PLAN.md（只设计不编码）
│   │   ├── dev-agent.md           # 领单个任务 → 编码 → 返回文件路径（不粘代码）；靠 task_state 续跑
│   │   ├── test-function.md       # 功能/单元维度测试
│   │   ├── test-security.md       # 安全合规维度测试
│   │   └── test-integration.md    # 集成/端到端维度测试
│   └── commands/
│       ├── orchestrate.md         # 主调度（短跑/无人值守，每次处理一个任务）
│       ├── run-batch.md           # 无人值守长跑驱动说明（loop/cron）
│       └── crystallize-experience.md  # 经验沉淀：蒸馏账本进 docs/THOUGHTS.md
└── docs/
    ├── status.json.example        # 状态机唯一真相源模板（复制为 status.json，长跑驱动器用）
    └── AGENT_EXPERIENCE.md.example # 经验账本种子模板（复制为 AGENT_EXPERIENCE.md）
```

所有模板文件已随本 skill 打包在 `assets/scaffold/`（路径相对于本 SKILL.md）。
直接把它们**原样拷贝**到上面对应的项目位置即可。

## 铺设步骤

1. **确认目标项目根目录**（默认当前工作目录；若为他人项目，先 `cd` 或显式给定根目录）。
2. **拷贝 agents/**：把 `assets/scaffold/agents/*.md` 写入 `<根>/.claude/agents/`。
3. **拷贝 commands/**：把 `assets/scaffold/commands/*.md` 写入 `<根>/.claude/commands/`。
4. **初始化 docs/**：
   - 把 `assets/scaffold/docs/status.json.example` 复制为 `<根>/docs/status.json`。
   - 把 `assets/scaffold/docs/AGENT_EXPERIENCE.md.example` 复制为 `<根>/docs/AGENT_EXPERIENCE.md`。
   - 新建空的 `<根>/docs/THOUGHTS.md`（经验提炼层，首次蒸馏时自动填充）。
5. **按需适配**（见下节）。适配后即可用。

> 实操建议：用 Write 工具逐文件创建（内容取自 assets/scaffold 对应文件），避免相对路径/cwd 漂移。
> 校验 .claude 目录是否被正确识别：`.claude/agents/` 与 `.claude/commands/` 是 Claude Code 的约定目录，放入即自动生效。

## 三处必改适配（按项目落地）

模板里所有项目专有的约束都已**泛化为占位**，你需要用 AskUserQuestion 或读 CLAUDE.md 后替换：

1. **架构约束引用**：`planning-agent.md` / `dev-agent.md` 中"出网防护/外发请求防护/未实现功能占位约定"等处，换成你项目的真实约束（如 SSRF、白名单、错误截断、ORM 约定）。读 `CLAUDE.md` 取。
2. **测试命令与审计清单**：三个 `test-*.md` 里的运行命令（如 `pytest` / `npm test` / `python tests/xxx.py`）与 `test-security` 的审计清单，换成你项目的真实命令与安全边界。
3. **重映射三测试维度**：默认 function/security/integration。按你项目真实质量关注点改（如前端→布局/美观/动画；数据管线→解析/性能/端到端），保持"三个相互独立单一维度"便于并行与定向验收。

> 子智能体只能调用其 frontmatter 声明的 skills/tools，所以按需最小化授权。
> 若平台没有某 skill（如 security-review / verify / run / find-docs），删除对应声明即可，agent 仍可工作。
> `model` 字段默认不写（继承主会话）；如需分档在 frontmatter 加 `model: opus|sonnet|haiku`。

## 使用方式

铺设并适配完成后：

```
# ① 写一份需求文档 docs/YOUR_REQ.md（背景/目标/产出物/约束/验收维度）

# ② 首次规划：派发 planning-agent 生成 docs/PLAN.md + 初始化 status.json，然后退出
/orchestrate "docs/YOUR_REQ.md"

# ③ 人在环：再跑一次 /orchestrate 处理下一个任务（交互）
#    或无人值守：起 loop 每 10 分钟处理一个任务
/loop 10m /orchestrate

# ④ 随时熔断（不用停 loop）：把 docs/status.json 的 circuit_breaker 改成 true
```

## 验证清单（首次落地后冒烟）

- [ ] `.claude/agents/` 下 5 个文件、`commands/` 下 3 个命令 frontmatter 合法（name/description/tools/skills）。
- [ ] `docs/status.json` 结构合法（tasks + budget_remaining + circuit_breaker + last_task_id），含至少一个 env-blocked 示例。
- [ ] `/planning-agent` 对一个真实需求产出 `docs/PLAN.md`；主调度据其初始化 `docs/status.json`。
- [ ] `/dev-agent` 实现其中一个任务并写 `docs/task_state_<id>.md`，返回路径而非代码。
- [ ] 三个测试 agent 各自跑通并产出结构报告；"环境阻塞"被主调度识别为 `env-blocked`（非代码 FAIL）。
- [ ] 短跑 `/orchestrate` 单次只处理一个任务：pending → doing → done/env-blocked/suspended，`budget_remaining` 递减、`last_task_id` 更新，随后干净退出。
- [ ] 连续 FAIL 时先 SendMessage 续跑（修复）→ 再 planning-agent 重规划 → 再降级 partial；超 7 次转 suspended，不卡死、不无限循环。
- [ ] 熔断：`circuit_breaker=true` 或 `budget_remaining<=0` 时驱动器打印 `[summary]` 并干净退出。
- [ ] 幂等：进程重启后 `doing` 任务经 `docs/task_state_<id>.md` 续跑，不重复派发。

## 关键机制速记

- **传路径解耦**：子智能体间只传本地路径+摘要，绝不把代码正文粘回主调度，主会话上下文极小。
- **并行测试**：三个测试 agent 在同一条消息内并发派发，分别独立验收，主调度汇总。
- **升级循环（每任务预算 7 次）**：≤3 修复（SendMessage 续跑同实例）/ 4–5 重规划（planning-agent 重规划+新 dev）/ 6–7 降级 partial；>7 suspended。env-blocked 不计入失败预算（只记 env 重试，超 3 转 suspended）。
- **状态机 status.json**：长跑唯一真相源，跨进程重启靠它续跑。
- **工作态落盘 task_state_<id>.md**：dev 实时写，进程重启后新实例读它无缝续跑。
- **双层经验账本**：顶部索引块（主调度只读前~40 行，token 精简）+ 底部完整记录（按需 Grep）。
- **短跑+loop=长跑**：驱动器每次只处理一个任务就退出，由 loop/cron 反复唤起；状态全在文件里，断点续跑是一等公民。

## 深入阅读

机制理论、完整模板、实战踩坑与已知天花板，见随 skill 打包的参考文档（按需深读，不必铺设）：
- `references/MULTI_AGENT_SCAFFOLD.md` — 脚手架总览 + 完整可拷贝模板 + 适配指南（§6）+ 实战经验（§9）。
- `references/MULTI_AGENT_USAGE.md` — 使用说明（状态机/升级/续跑/运维/已知天花板）。

## 已知天花板（诚实告知）

- **执行层已自治**，但"需求是否被满意满足"对主观/质量类需求（如摘要生成好坏）无自动 oracle——测试只能验"返回了、字段非空"，验不了"好不好"，仍需人工抽检。
- 需求若有歧义/冲突/不可能项，agent 不会替你做产品决策，会在升级循环耗尽预算后 suspended。
