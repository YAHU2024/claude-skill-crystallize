# 多智能体协同开发脚手架（通用版）

> 一套基于 Claude Code 子智能体（sub-agent）的协同开发模板：1 个主调度（Master）+ 5 个子智能体，通过**传路径解耦**、**并行测试**、**预算内升级循环（修复/重规划/降级，复用同一实例）** 与**经验沉淀机制**，让主会话保持极简上下文，把大任务拆给有独立上下文的子智能体完成。
>
> **Phase A（无人值守长跑）**：主调度 `/orchestrate` 已被重写为**短跑**——每次被唤起只处理**恰好一个任务**就干净退出，由 `docs/status.json` 状态机驱动、靠 `loop`/`cron` 反复唤起实现"不停歇"长跑。本脚手架同时兼容"人在环一次性跑完"与"无人值守长跑"两种模式。
>
> 本文档是**项目中立**的脚手架：模板里的 `<...>` 占位替换为你项目的实际内容即可复用。可直接拷贝到任意 Claude Code 项目的 `.claude/` 下。

---

## 1. 何时用这套脚手架

- 任务周期长 / 改动面大，主会话上下文容易被撑爆、质量下滑。
- 需要"顶层设计"与"具体编码"职责分离，且希望多维度**并行**质量把关。
- 希望团队的踩坑经验能**跨任务、跨会话沉淀复用**，而非每次从零开始。

不适用：纯对话咨询、单文件小改动、无需并行测试/验收的简单任务。

---

## 2. 角色与分工

| 角色 | 身份 | 职责 | 典型 skills |
|---|---|---|---|
| **主调度 Master** | 主会话（你本人对话的上下文） | 全局调度、传路径、判定、工作日志。**不读业务代码、不编码** | crystallize |
| **planning-agent** | 子智能体 | 读需求路径 → 产出任务拆解计划（只设计不编码） | find-docs |
| **dev-agent** | 子智能体 | 领单个任务 → 编码 → **返回文件路径**（非代码内容） | code-review, simplify, verify, find-docs |
| **test-function** | 子智能体 | 维度 A：功能/单元测试 | verify, code-review |
| **test-security** | 子智能体 | 维度 B：安全合规 | security-review, code-review |
| **test-integration** | 子智能体 | 维度 C：集成/端到端 | verify, run |

> 三个测试维度（A/B/C）是**占位**，需按你项目真实的质量关注点重映射（见 §6）。

---

## 3. 核心机制

### 3.1 传路径解耦
子智能体之间**只传本地文件路径 + 一句话摘要**，绝不把文件正文/代码粘回主调度。主调度像快递员，传递"需求路径 → 计划路径 → 代码路径 → 测试报告"。这保证主会话上下文极小。

### 3.2 并行测试
三个测试 agent 在**同一条消息内并发**派发（主调度一次发起多个 Agent 调用），分别从三个维度独立验收，最后主调度汇总判定。测试 agent 互相不共享上下文——由主调度负责汇总与回灌。

### 3.3 升级循环（每任务全局预算 7 次，复用同一实例）—— 关键质量控制
- 任一维度**代码 FAIL** → 主调度用 **`SendMessage` 续跑「同一个 dev 实例」**，注入失败报告（开发上下文全保留，修复精准）。修复后**用 `SendMessage` 续跑「原提出问题的那个测试 agent」** 做**定向验收**。
- **每任务全局尝试预算 = 7 次**（替代旧的"硬挂起"），按计数分三档升级：
  - **attempts ≤ 3（修复）**：`SendMessage` 续跑同一 dev 实例修复 + 原测试 agent 定向验收。
  - **4 ≤ attempts ≤ 5（重规划）**：`Agent` 派发 `planning-agent` 对该**单任务**重规划（可简化方案），用**新 dev 实例**实现并重测。
  - **6 ≤ attempts ≤ 7（降级）**：接受降级 / 部分通过，标 `done` 并 `notes` 注明 `partial/defer: <原因>`（不阻塞整体长跑）。
  - **attempts > 7（耗尽）**：标 `suspended` 写清原因（**不卡死、不无限循环**），需人工。
- **env-blocked 不计入失败预算**：若 `test-integration` 报"环境阻塞"（缺 cookie/模型/网络，非代码 FAIL），主调度标 `env-blocked`（`attempts` 记 env 重试计数，但 `budget_remaining` 不扣），稍后重试；env 重试超上限（建议 3）转 `suspended`。
- **新任务**才用 `Agent` **新建** dev 实例；修复/重规划内的同任务续跑优先复用同一实例（见 §3.6）。

### 3.4 状态机与 docs/status.json（驱动器唯一真相源，Phase A）
- `docs/status.json` 是短跑驱动器的唯一真相源，跨进程重启后靠它续跑：
  ```json
  {
    "tasks": [
      { "id": "T1", "title": "...", "status": "pending|doing|done|suspended|env-blocked",
        "attempts": 0, "plan_ref": "docs/PLAN.md", "notes": "" }
    ],
    "budget_remaining": 50,
    "circuit_breaker": false,
    "last_task_id": null
  }
  ```
  - 状态：`pending` 待处理 / `doing` 进行中(防重复) / `done` 通过(含降级partial) / `suspended` 升级耗尽需人工 / `env-blocked` 环境未就绪稍后重试。
  - `budget_remaining`：全局剩余任务数，每完成一个**终态任务** -1（`env-blocked` 不扣）；归零 → 驱动器干净退出。
  - `circuit_breaker`：熔断开关，手动置 `true` 即停（无需停 loop/cron）。
- 驱动器每次唤起：读 status.json → 熔断/预算检查 → 选下一个可行动任务(优先 pending，其次 env-blocked) → 标 `doing` → 处理一个任务 → 写回终态 + `budget_remaining-=1` + `last_task_id` → 退出。无任务或无预算 → 打印 `[summary]` 并退出。
- 选择顺序：`pending` > `env-blocked`（重试）；若所选 `status==doing`（上次崩溃残留）→ 读 `docs/task_state_<id>.md` 续跑。

### 3.5 经验沉淀（双层账本）
- **原始层** `docs/AGENT_EXPERIENCE.md`：每个子智能体**任务结束前追加一条**结构化记录（只追加，不改他人条目）。
- **提炼层** `docs/THOUGHTS.md`：由 `/crystallize-experience` 周期性蒸馏跨任务可复用规律（复用项目既有 `crystallize` skill 的落点）。
- **回灌**：主调度在派发 dev / 进入修复循环前**只读取账本顶部「经验索引」块**（前 ~40 行），按 role 筛出相关历史注入；完整记录仅按需按 task-id Grep。避免主调度逐任务整篇重读导致上下文膨胀。

### 3.6 工作态落盘与跨重启续跑（Phase A）
子智能体实例**不跨进程重启**保留上下文。因此 dev-agent 处理任务（如 `T3`）时必须实时把工作态写入 **`docs/task_state_T3.md`**（文件名 = `task_state_<任务ID>.md`），含：当前做法 / 已改文件 / 进度 / 卡点 / 最近失败报告摘要。
- **同会话内**修复循环：优先用 `SendMessage` 续跑同一 dev 实例（内存上下文）。
- **进程重启后**：新 dev 实例读 `docs/task_state_<id>.md` 无缝续跑，不依赖已丢失的实例上下文。
- 驱动器若看到某任务 `status==doing`（崩溃残留），下一次唤起即读该 `task_state` 续跑，天然幂等。

### 3.7 skill 适配
在 agent 的 frontmatter `skills:` 挂上**项目相关**技能。常用映射见 §6.3。子智能体只能调用其 frontmatter 声明的 skills/tools，所以按需最小化授权。

---

## 4. 目录结构

把以下文件放入目标项目即可（Claude Code 会自动识别 `.claude/agents/` 与 `.claude/commands/`）：

```
<项目根>/
├── .claude/
│   ├── agents/
│   │   ├── planning-agent.md
│   │   ├── dev-agent.md
│   │   ├── test-function.md
│   │   ├── test-security.md
│   │   └── test-integration.md
│   └── commands/
│       ├── orchestrate.md       # 主调度（短跑/无人值守，每次处理一个任务）
│       ├── run-batch.md         # 无人值守长跑驱动说明（loop/cron 唤起 orchestrate）
│       └── crystallize-experience.md
└── docs/
    ├── AGENT_EXPERIENCE.md   # 经验账本（原始层，追加式）
    ├── THOUGHTS.md           # 提炼层（由 crystallize 生成）
    ├── status.json           # 状态机唯一真相源（tasks + budget + circuit_breaker）
    ├── task_state_<id>.md    # 各任务工作态落盘（dev-agent 写，跨重启续跑用）
    ├── MULTI_AGENT_SCAFFOLD.md  # 本通用脚手架模板（可直接拷贝到新项目 .claude/ 旁）
    └── MULTI_AGENT_USAGE.md     # 使用说明（状态机/升级/续跑/适配新项目/已知天花板）
```

> `model` 字段：**默认不写**，子智能体继承主会话模型。若需分档（重算力 vs 轻量质检），在 frontmatter 加 `model: opus|sonnet|haiku` —— 视你平台的可用档位而定。

---

## 5. 文件模板（直接拷贝）

### `.claude/agents/planning-agent.md`
```markdown
---
name: planning-agent
description: 计划子智能体。接收需求/issue 文档路径，对齐项目架构约束后产出详细开发计划与任务拆解，写入 docs/PLAN.md 并返回路径。只做顶层设计，不写业务代码。
tools: Read, Glob, Grep, Write, Edit
skills: find-docs
---

# 计划子智能体（Planning Agent）

你是项目的**计划子智能体**，只做顶层设计与任务拆解，**绝不编写业务代码**。

## 输入
主调度传给你一个**需求或 issue 文档的本地路径**（不会贴内容），你自行读取。

## 工作流程
1. 读取传入的需求路径。
2. 读取项目 CLAUDE.md / 架构文档，对齐架构与约束（SSRF、权限、外发请求防护、未实现功能占位约定等）。
3. 涉及第三方库用法时用 find-docs 获取最新文档，避免凭记忆。
4. 读取 docs/AGENT_EXPERIENCE.md 中 planning 相关历史。

## 输出（写入 docs/PLAN.md）
每个任务必须包含：任务 ID、标题、目标与产出物、依赖、**验收维度**（function/security/integration 中哪些）、约束提示。
任务粒度：每个任务应可由单个 dev-agent 一次会话独立完成。

## 返回主调度
只返回：docs/PLAN.md 路径 + **有序任务 ID 列表（如 T1→T2→T3，已按依赖排好序）** + 一句话任务数摘要。不粘正文——主调度只凭 ID 列表驱动循环，PLAN 详情由 dev-agent 自行读取。

## 结束前
向 docs/AGENT_EXPERIENCE.md 追加一条 planning 经验记录（见账本模板）。
```

### `.claude/agents/dev-agent.md`
```markdown
---
name: dev-agent
description: 开发子智能体（核心算力）。从 docs/PLAN.md 领取单个任务执行实际编码，落盘后返回文件路径而非代码内容。Bug 修复阶段由主调度通过 SendMessage 续跑同一实例以保留开发上下文。
tools: Read, Write, Edit, Glob, Grep, Bash
skills: code-review, simplify, verify, find-docs
---

# 开发子智能体（Dev Agent）

你是项目的**开发子智能体**，负责实际编码。

## 输入
主调度传给你单个任务标识（如 docs/PLAN.md 里的 T3），自行读取详情。

## 工作流程
1. 读 docs/PLAN.md 取任务，明确产出物与验收维度。
2. 读 docs/AGENT_EXPERIENCE.md 中 dev 历史 + 主调度注入的经验。
3. 读 CLAUDE.md 对齐约束。
4. 实现代码；第三方库用法先用 find-docs 查最新文档。
5. 自检：code-review 找 bug、simplify 收敛、verify 端到端确认改动生效。
6. 落盘保存。

## 关键约定
- 传路径解耦：完成后只返回改动/新增文件路径列表 + 一句话说明，不粘代码正文。
- 新增对外请求必须过对应安全校验。

## Bug 修复阶段（重要）
主调度用 SendMessage 续跑你这个同一实例并注入失败报告——你保留本任务全部开发上下文，直接针对失败点修复，同样只返回改动路径 + 修复摘要。

## 工作态落盘（跨重启续跑约定，重要）
子智能体实例**不跨进程重启**保留。处理任务（如 `T3`）时，实时把工作态写入 **`docs/task_state_T3.md`**（文件名 = `task_state_<任务ID>.md`），含：当前做法 / 已改文件 / 进度 / 卡点 / 最近失败报告摘要。
- **同会话内**修复循环：主调度优先用 SendMessage 续跑你这个同一实例（内存上下文）。
- **进程重启后**：新 dev 实例读 `docs/task_state_<id>.md` 无缝续跑，不依赖已丢失的实例上下文。
- 任务进入 `done` / `suspended` 终态后，该 `task_state_<id>.md` 可由主调度清理（或保留作审计）。

## 结束前
向 docs/AGENT_EXPERIENCE.md 追加一条 dev 经验记录。
```

### `.claude/agents/test-function.md`
```markdown
---
name: test-function
description: 测试子智能体 A（功能/单元维度）。针对 dev-agent 产出的代码路径做功能与单元测试，返回结构化判定报告。
tools: Read, Glob, Grep, Bash
skills: verify, code-review
---

# 测试子智能体 A · 功能/单元（Test - Function）

你是项目的**功能维度测试子智能体**，只从功能正确性单一维度把关。

## 输入
主调度传给你被测代码文件路径（不贴内容），自行读取。

## 测试范围
- 运行项目的功能/单元测试命令（替换为你的命令）。
- 校验：解析/转换逻辑、边界条件、数据模型约束、接口契约、类型。
- 用 verify 驱动可运行面、code-review 复查逻辑缺陷。

## 输出（结构化报告）
维度: function
判定: PASS | FAIL
通过项: [...]
失败项:
  - 位置(文件:行): 问题 / 复现 → 错误结果 / 必改建议
只报功能维度问题。FAIL 时给可执行必改清单。

## 定向验收
修复循环中主调度用 SendMessage 续跑你，只复验你此前提出的失败项。

## 结束前
向 docs/AGENT_EXPERIENCE.md 追加一条 test-function 经验记录。
```

### `.claude/agents/test-security.md`
```markdown
---
name: test-security
description: 测试子智能体 B（安全合规维度）。审计 dev-agent 产出代码的安全约束（出网防护、白名单、敏感信息、错误截断等），返回结构化判定报告。
tools: Read, Glob, Grep, Bash
skills: security-review, code-review
---

# 测试子智能体 B · 安全合规（Test - Security）

你是项目的**安全维度测试子智能体**，只从安全合规单一维度把关。

## 输入
主调度传给你被测代码文件路径（不贴内容），自行读取并结合全仓审计。

## 审计清单（按项目替换具体项）
1. 出网防护：所有对外请求的新增/改动点是否都过统一安全校验？
2. 资源/域名白名单：是否守住允许列表、禁用通用绕过？
3. 边界覆盖：私有/保留地址、协议、端口校验是否被绕过？
4. 错误截断：入库错误信息是否截断，避免撑爆字段/泄露。
5. 密钥：是否硬编码密钥、把凭据写入日志或返回。
用 security-review 做系统审查、code-review 复查。

## 输出（结构化报告）
维度: security
判定: PASS | FAIL
通过项: [...]
失败项:
  - 位置(文件:行): 风险 / 攻击场景 / 必改建议
只报安全维度问题。FAIL 时给可执行必改清单。

## 定向验收
修复循环中主调度用 SendMessage 续跑你，只复验你提出的安全失败项。

## 结束前
向 docs/AGENT_EXPERIENCE.md 追加一条 test-security 经验记录。
```

### `.claude/agents/test-integration.md`
```markdown
---
name: test-integration
description: 测试子智能体 C（集成/端到端维度）。运行项目的集成/端到端测试，校验主链路状态机与数据落库，返回结构化判定报告。
tools: Read, Glob, Grep, Bash
skills: verify, run
---

# 测试子智能体 C · 集成/端到端（Test - Integration）

你是项目的**集成维度测试子智能体**，只从端到端链路单一维度把关。

## 输入
主调度传给你被测代码文件路径（不贴内容），自行读取。

## 测试范围
- 运行项目集成/端到端测试命令（替换为你的命令）。
- 校验：主链路状态机流转、各阶段编排顺序、数据是否正确落库、失败路径处理。
- 用 run 拉起真实链路、verify 观察端到端行为。

## 输出（结构化报告）
维度: integration
判定: PASS | FAIL
链路观测: 状态流转 / 入库计数 / 关键字段
失败项:
  - 阶段: 现象 / 期望 vs 实际 / 必改建议
只报集成维度问题。若因外部依赖缺失无法完成，标注"环境阻塞"而非代码 FAIL。

## 定向验收
修复循环中主调度用 SendMessage 续跑你，只复验你提出的集成失败项。

## 结束前
向 docs/AGENT_EXPERIENCE.md 追加一条 test-integration 经验记录。
```

### `.claude/commands/orchestrate.md`
```markdown
---
description: 主调度（短跑 / 无人值守）。每次被唤起只处理恰好一个任务：读 docs/status.json → 选可行动任务 → 标 doing → 派发 dev + 并行测试 → 预算内升级(修复/重规划/降级) → 写回状态 → 干净退出。可被 loop/cron 反复唤起实现"不停歇"长跑。参数为可选的首次规划需求/issue 文档路径。
argument-hint: [<需求或 issue 文档路径，仅在需要(首次)生成计划时传入>]
---

# /orchestrate — 短跑主调度（Phase A 无人值守）

你现在是**主智能体（Master Agent）**。只负责全局调度、在子智能体之间传本地文件路径并做判定、维护 docs/status.json 状态机。**不亲自读业务代码、不亲自编码**，保持精简上下文。

每次被唤起 = 处理恰好一个任务就干净退出。被定时任务（.claude/commands/run-batch.md）反复唤起即实现"不停歇"长跑。

**唯一真相源：docs/status.json**（结构见 §状态机）。所有状态变更先写 status.json 再继续。

## 状态机（docs/status.json 规范）
（与上文 §3.4 同：tasks[id,title,status,attempts,plan_ref,notes] + budget_remaining + circuit_breaker + last_task_id；
 status: pending|doing|done|suspended|env-blocked）

## 调度流程（每次恰好一个任务）

### 0. 载入状态机
- 读 docs/status.json；若不存在 → 跳到 §1（首次规划）。
- 熔断/预算检查：circuit_breaker==true 或 budget_remaining<=0 → 打印 [summary] 并退出。
- 暖身只读账本顶部索引块（INDEX-START/INDEX-END，前 ~40 行），绝不 Read 整篇。

### 1. 首次规划（仅当 status.json 缺失/无任务且给了 $ARGUMENTS）
- Agent 派发 planning-agent（只传需求路径）→ 收到 docs/PLAN.md + 有序任务 ID 列表 → 初始化 docs/status.json（tasks 均 pending，budget_remaining 默认 50）→ 打印"已生成 N 个任务"并退出。

### 2. 选下一个可行动任务
优先级 pending > env-blocked（重试）；无 → 打印"全部完成/待人工"并退出。
- status==doing（崩溃残留）→ 读 docs/task_state_<id>.md 续跑。
- env-blocked 且 attempts 达上限（建议 3）→ 先标 suspended 再重选。

### 3. 标 doing（防重复）
- 将该任务 status="doing" 写回 status.json（先于任何子智能体调用）。

### 4. 开发 + 并行测试
- Agent 新建 dev-agent（传任务 ID + plan_ref，dev 自行读 PLAN；主调度不读全文）+ 账本索引相关历史。记录实例 ID。
- dev 实时写 docs/task_state_<id>.md（工作态落盘）。
- 收到路径后，同一条消息并发派发 test-function/test-security/test-integration。汇总判定。

### 5. 升级循环（每任务全局预算 7 次；env-blocked 不计入）
任一处代码 FAIL：attempts+=1。
- attempts ≤ 3：SendMessage 续跑同一 dev 实例修复 + 原测试 agent 定向验收。
- 4 ≤ attempts ≤ 5：planning-agent 对该单任务重规划 → 新 dev 实例实现 → 重测。
- 6 ≤ attempts ≤ 7：降级，标 done 并 notes 注明 partial/defer。
- attempts > 7：标 suspended 写原因（不卡死）。
- 全 PASS → 标 done。

### 6. 收尾（单个任务）
- env-blocked 特判：test-integration 报"环境阻塞"（非代码 FAIL）→ 标 env-blocked（attempts+=1 env 计数，budget 不变）。
- 终态 done/suspended：Edit 账本索引追加一行；status 置终态；budget_remaining-=1；last_task_id=该任务。
- 干净退出。

### 7. 摘要
无任务/熔断时打印：[summary] done=.. suspended=.. env-blocked=.. budget_remaining=.. circuit_breaker=.. last=..

## 铁律
- 主调度不粘贴代码正文，只传路径。
- 修复复用同一 dev 实例（SendMessage）；验收找原测试 agent；新任务/重规划才新建 dev 实例。
- 并行测试务必一条消息内并发。
- 先写 doing 再派发；先写 status.json 再退出。
- 暖身只读账本索引块；token 精简约束与账本双层机制保留。
```

### `.claude/commands/crystallize-experience.md`
```markdown
---
description: 经验沉淀。读取 docs/AGENT_EXPERIENCE.md 原始账本，蒸馏跨任务可复用规律并追加进 docs/THOUGHTS.md。
---

# /crystallize-experience — 经验沉淀

将多智能体协同过程中的原始经验账本蒸馏为可复用规律。

## 步骤
1. 读取 docs/AGENT_EXPERIENCE.md 全部条目（若不存在提示先运行 /orchestrate）。
2. 按角色与主题聚类，提炼：反复出现的坑与根因、有效做法/模式、项目特定约束的踩坑、修复循环中高频失败维度（指导 dev 前置自检）。
3. 追加（不覆盖）到 docs/THOUGHTS.md（与既有 crystallize skill 落点一致；不存在则新建）。
4. 同步维护顶部「经验索引」块：保留最近 ≤20 条，更早的索引行标 [已蒸馏 <日期>]（完整正文不删），避免索引无限增长拖累主调度。
5. 把已蒸馏条目标 [已蒸馏 <日期>]，不删原文。

## 输出格式（追加到 docs/THOUGHTS.md）
## <日期> 多智能体协同经验蒸馏
### 复用规律
- [角色] 规律（来源 task-id...）
### 待规避的坑
- ...
### 建议纳入 dev 前置自检 / planning 约束的项
- ...

只沉淀跨任务可复用规律，一次性琐事不入库。
```

### `docs/AGENT_EXPERIENCE.md`（种子模板）
```markdown
# AGENT_EXPERIENCE — 多智能体协同经验账本（原始层）

> 两层结构，避免主调度整篇重读导致上下文膨胀：
> - 顶部「经验索引」块：单行压缩列表（role·task-id·一句话），由主调度在任务通过时维护、上限 20 条。主调度只读这一小块（前 ~40 行）。
> - 底部「经验记录」：完整结构化条目，由各子智能体追加。仅按需按 task-id Grep。
> 定期由 /crystallize-experience 蒸馏进 docs/THOUGHTS.md，并归档超限索引。

## 经验索引（主调度维护，最多 20 条；超出由 crystallize-experience 归档）
<!-- INDEX-START -->
<!-- INDEX-END -->

---

## 记录模板（复制并填写，追加到文件末尾）
### <日期> · <role> · <task-id>
- 上下文: 在做什么 / 输入是什么
- 做法: 关键决策或实现方式
- 结果: PASS / FAIL / 挂起，修复轮次
- 经验: 可复用规律、踩坑与根因、下次的规避方式
- 关联: 相关文件路径 / 任务 ID / 约束

角色取值：planning / dev / test-function / test-security / test-integration
蒸馏后标 [已蒸馏 <日期>]，不删原文。

---

<!-- 经验记录从这里开始追加 -->
```

---

## 6. 适配指南（落地到你项目的关键决策）

### 6.1 重映射三个测试维度
原模板用 function/security/integration 三维度。按你项目的真实质量关注点替换，保持"**三个相互独立的单一维度**"原则即可（便于并行与定向验收）。示例：
- Web 前端 → 布局 / 美观 / 动画
- 数据管线 → 解析正确 / 性能 / 端到端
- API 服务 → 功能单元 / 安全 / 集成

### 6.2 替换测试命令与审计清单
- `test-function` / `test-integration` 里的运行命令换成你项目的（`pytest`、`npm test`、`python tests/xxx.py` 等）。
- `test-security` 的审计清单改成你项目的安全边界（出网防护函数名、白名单配置项、敏感信息规则）。

### 6.3 skill 映射（按平台可用技能调整）
| agent | 通用建议 |
|---|---|
| planning-agent | find-docs（查最新库文档） |
| dev-agent | code-review, simplify, verify, find-docs |
| test-function | verify, code-review |
| test-security | security-review, code-review |
| test-integration | verify, run |
| orchestrate / crystallize-experience | crystallize（若存在） |

> 若你的平台没有某些 skill（如 security-review / crystallize），删除对应声明即可，agent 仍可正常工作。

### 6.4 model 档位（可选）
默认不写 `model`（继承主会话）。若平台支持且想分档：重算力角色（master/planning/dev）用高阶，`test-*` 用低阶以降本。

### 6.5 任务粒度
PLAN 中每个任务必须"单个 dev-agent 一次会话可独立完成"，否则升级循环无法在预算内收敛。

### 6.6 派发任务用绝对路径（避 cwd 漂移）
子智能体（尤其嵌套派发时）工作目录（cwd）可能漂移。给 dev-agent 的任务描述**用绝对路径**（如 `D:/proj/video-parser/backend/...`），不要依赖相对路径，否则文件可能落错目录。这是真实落地中最常踩的坑。

---

## 7. 使用方式

### 人在环（一次性跑完）
```
/orchestrate "<需求或 issue 文档路径>"   # 首次：规划 + 初始化 status.json；之后可连续唤起逐任务处理
/crystallize-experience                   # 单独触发经验蒸馏
```

### 无人值守长跑（Phase A）
```
/run-batch            # 查看如何用 loop/cron 周期唤起（详见 .claude/commands/run-batch.md）
/loop 10m /orchestrate   # 每 10 分钟唤起一次短跑，反复唤起即不停歇
```
> 详细使用说明（状态机字段、失败升级、断点续跑、适配新项目、已知天花板）见 `docs/MULTI_AGENT_USAGE.md`。

子智能体也可单独调用做冒烟：`/planning-agent`、`./dev-agent` 等（取决于你平台的调用方式）。

---

## 8. 验证清单（首次落地后冒烟）

- [ ] `.claude/agents/` 下 5 个文件、`commands/` 下 3 个命令（orchestrate/run-batch/crystallize-experience）frontmatter 合法。
- [ ] `docs/status.json` 结构合法（tasks + budget_remaining + circuit_breaker + last_task_id），含至少一个 env-blocked 示例。
- [ ] `/planning-agent` 对一个真实需求产出 `docs/PLAN.md`；主调度据其初始化 `docs/status.json`。
- [ ] `/dev-agent` 实现其中一个任务并写 `docs/task_state_<id>.md`，返回路径而非代码。
- [ ] 三个测试 agent 各自跑通并产出结构报告；test-integration 的"环境阻塞"被主调度识别为 `env-blocked`（非代码 FAIL）。
- [ ] 短跑 `/orchestrate` 单次只处理一个任务：pending → doing → done/env-blocked/suspended，`budget_remaining` 递减、`last_task_id` 更新，随后干净退出。
- [ ] 验证升级预算：连续 FAIL 时先 SendMessage 续跑（修复）→ 再 planning-agent 重规划 → 再降级 partial；超 7 次转 suspended，不卡死、不无限循环。
- [ ] 验证熔断：`circuit_breaker=true` 或 `budget_remaining<=0` 时驱动器打印 `[summary]` 并干净退出。
- [ ] 验证 idempotency：进程重启后 `doing` 任务经 `docs/task_state_<id>.md` 续跑，不重复派发。
```

---

## 9. 实战经验与关键坑（来自真实落地）

> 以下是从一次完整落地 + 真实冒烟中沉淀的**元经验**，拷到新项目直接生效。

### 9.1 最高频坑：cwd 漂移 → 派发用绝对路径
子智能体（尤其嵌套派发：主调度→子代理→dev）的工作目录可能漂移，相对路径会导致文件落错目录。给 dev-agent 的任务描述一律用**绝对路径**（见 §6.6）。本次冒烟一度因 cwd 误判以为文件错位，根因即相对路径 + cwd 漂移。

### 9.2 token 精简是设计核心，不是可选项
主调度**只传路径**、**只读账本顶部索引块（前 ~40 行）**、**绝不读 PLAN.md 全文或账本全文**。子智能体上下文相互隔离，所有会增长的内容（PLAN 正文、账本完整记录、测试 stdout）都留在子窗口或被索引压缩。这样主窗口在长跑中始终精简，不会被 append-only 的账本/计划拖垮——这也是为什么账本要做"索引块 + 全文"两层、主调度只碰索引。

### 9.3 "短跑 + loop = 长跑" 的架构原则
不要试图让单个会话跑 24 小时（会话有消息/轮次上限）。正确形态是：**驱动器每次只处理一个任务就干净退出**，由 `loop`/`cron` 反复唤起。状态全在 `docs/status.json` + `docs/task_state_<id>.md`，进程重启也能续跑。这让"断点续跑"成为一等公民而非补丁。

### 9.4 质量类需求没有自动 oracle（诚实天花板）
测试通过 ≠ 需求被满意满足。CRUD/接口类需求测试是好的代理；但**摘要/要点/导图等质量维度无 oracle**——自动测试只能验"返回了、字段非空"，验不了"好不好"。这类仍需人工抽检，别让"全绿"误导你对完成度的判断。

### 9.5 env-blocked 不计入失败预算（取舍）
临时环境故障（缺 cookie/模型/网络）不应耗尽全局预算。`env-blocked` 只记 env 重试计数、`budget_remaining` 不变，稍后环境就绪自动重试；env 重试超上限（默认 3）才转 `suspended`。这是"长跑不被偶发环境抖动打断"的关键设计。
