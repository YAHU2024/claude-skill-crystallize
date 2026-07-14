# 多智能体协同开发工作流 · 使用说明

> 本文档教你**如何复用**本次对话中搭建并验证过的多智能体协同开发系统。
> 配套的总览与可拷贝模板见 `docs/MULTI_AGENT_SCAFFOLD.md`；本文件只讲"怎么用"。
>
> 本系统已通过真实冒烟验证（Phase A 短跑驱动 + `status.json` 状态机端到端跑通）。

---

## 1. 这套系统是什么（一句话）

基于 Claude Code 子智能体的协同开发工作流：**1 个主调度（你本人对话的会话）+ 5 个子智能体**（计划 / 开发 / 3 个测试维度）。主调度只传路径、做判定、维护状态；子智能体各有独立上下文，通过"传路径解耦 + 并行测试 + 预算内修复循环 + 经验沉淀"协作。支持**人在环一次性跑完**，也支持**无人值守长跑**。

## 2. 文件地图（复用前先认得它们）

| 路径 | 角色 |
|---|---|
| `.claude/agents/planning-agent.md` | 子智能体：读需求 → 产出任务拆解计划 `docs/PLAN.md`（只设计不编码） |
| `.claude/agents/dev-agent.md` | 子智能体：领单个任务 → 编码 → 返回**文件路径**（不粘代码）；崩后靠 `docs/task_state_<id>.md` 续跑 |
| `.claude/agents/test-function.md` | 子智能体：功能/单元维度测试 |
| `.claude/agents/test-security.md` | 子智能体：安全合规维度测试（SSRF / 白名单 / 错误截断） |
| `.claude/agents/test-integration.md` | 子智能体：集成/端到端维度测试 |
| `.claude/commands/orchestrate.md` | **主调度命令**：短跑形态，每次处理一个任务就退出，可被 loop 反复唤起 |
| `.claude/commands/run-batch.md` | 无人值守长跑驱动说明（loop / cron） |
| `.claude/commands/crystallize-experience.md` | 经验沉淀：蒸馏账本进 `docs/THOUGHTS.md` |
| `docs/status.json` | **运行时状态机**（任务列表 + 预算 + 熔断），长跑的唯一真相源 |
| `docs/AGENT_EXPERIENCE.md` | 经验账本（原始层：索引块 + 完整记录） |
| `docs/THOUGHTS.md` | 经验提炼层（跨任务可复用规律） |

> `model` 字段未适配（继承主会话模型）；如需分档可在 agent 文件加 `model:`。

## 3. 两种用法

- **A. 人在环（交互）**：你盯着，跑完一轮看结果，再决定下一步。适合小需求、要即时把关。
- **B. 无人值守长跑（loop）**：睡前丢需求，定时反复唤起，早上收报告。适合大需求、批量任务。

两种都从"首次规划"开始。

---

## 4. 快速上手（最常用路径）

```bash
# ① 写一份需求文档（参考 docs/VERIFY_REQ.md 的写法）
#    说明：要做什么、目标、约束（来自 CLAUDE.md）、验收维度

# ② 首次规划：派发 planning-agent 生成计划 + 初始化 status.json，然后退出
/orchestrate "docs/YOUR_REQ.md"

# ③ 看一眼状态
cat docs/status.json        # 应出现若干 pending 任务

# ④ 选一种跑法：
#    A. 人在环：直接再跑一次 /orchestrate 处理下一个任务（交互）
#    B. 无人值守：起 loop，每 10 分钟处理一个任务
/loop 10m /orchestrate

# ⑤ 长跑期间随时熔断（不用停 loop）
#    把 docs/status.json 的 circuit_breaker 改成 true，驱动器下次唤起即打印摘要退出
```

---

## 5. 详细步骤

### 5.1 准备需求文档
- 放到 `docs/` 下，例如 `docs/YOUR_REQ.md`。
- 内容建议：背景、目标、产出物、**约束**（SSRF / extractor 白名单 / `error[:500]` / `TODO(Px)` / SQLAlchemy 2.0，按本项目 CLAUDE.md）、**验收维度**（function / security / integration 哪些适用）。
- 参考样本：`docs/VERIFY_REQ.md`（实现了 `GET /api/results/{id}` 的最小可用版）。

### 5.2 首次规划 `/orchestrate "<req>"`
- 主调度派发 `planning-agent`，只传需求**路径**。
- `planning-agent` 产出 `docs/PLAN.md`（任务拆解 + 每任务验收维度），并返回**有序任务 ID 列表**（如 `T1→T2→T3`）。
- 主调度据此初始化 `docs/status.json`（任务全 `pending`，`budget_remaining` 默认 50），然后**退出**。
- 注意：主调度**不读 PLAN.md 全文**，只凭 ID 列表驱动循环（token 精简）。

### 5.3 长跑 `/loop 10m /orchestrate`
- `loop` 每 10 分钟唤起一次 `/orchestrate`（短跑：处理恰好一个任务就退出）。
- 反复唤起 = "不停歇"。间隔可调：`/loop 5m`（快）/ `/loop 30m`（省额度）。
- 驱动器每次：读 `status.json` → 熔断/预算检查 → 选 `pending`（优先）或重试 `env-blocked` → 标 `doing` → 派 `dev-agent` → **同一条消息并发**派 3 个测试 agent → 预算内升级 → 写回终态 → 退出。

### 5.4 状态机字段
```json
{
  "tasks": [
    { "id":"T1", "title":"...", "status":"pending|doing|done|suspended|env-blocked",
      "attempts":0, "plan_ref":"docs/PLAN.md", "notes":"" }
  ],
  "budget_remaining": 50,
  "circuit_breaker": false,
  "last_task_id": null
}
```
- `pending` 待处理 · `doing` 进行中（防重复；重启后看到 `doing` 说明上次崩溃，按 `task_state_<id>.md` 续跑）· `done` 通过 · `suspended` 升级耗尽需人工 · `env-blocked` 环境未就绪稍后重试（**不计失败预算**）。
- `budget_remaining`：全局剩余可处理任务数，每完成一个**终态任务** -1（`env-blocked` 不扣）；归零 → 干净退出。
- `circuit_breaker`：熔断开关，置 `true` 即停。

### 5.5 失败升级（不再"卡死交人工"）
每任务**全局尝试预算 = 7 次**，分层：
- 前 3 次：**修复** —— `SendMessage` 续跑同一 dev 实例注入失败报告（保留开发上下文），修复后交**原测试 agent** 定向验收。
- 中 2 次：**重规划** —— 派 `planning-agent` 对该单任务重规划（可简化方案），新 dev 实例实现。
- 后 2 次：**降级** —— 接受降级/部分通过，标 `done` 并 `notes` 注明 `partial/defer`。
- 超 7 次 → `suspended`（带原因），不无限循环。
- `env-blocked` 不计入该预算；env 重试达上限（默认 3）转 `suspended`。

### 5.6 断点续跑
- 状态全在 `docs/status.json` + `docs/task_state_<id>.md`，跨进程重启可续。
- 重启后驱动器读 `status.json`：若某任务 `doing`（崩溃残留）→ 读其 `task_state_<id>.md` 续跑，不新建 dev 实例。
- `doing` 标志防止被 loop 重复触发同一任务。

### 5.7 经验沉淀
- 每个子智能体任务结束向 `docs/AGENT_EXPERIENCE.md` 追加一条（顶部索引块只存一行摘要，完整记录在底部）。
- 主调度暖身**只读索引块前 ~40 行**，绝不读全文（token 精简关键）。
- 全部跑完或定期运行 `/crystallize-experience` 把账本蒸馏进 `docs/THOUGHTS.md`。

## 6. 监控与运维
- **看进度**：`docs/status.json` 的 `tasks[].status` / `last_task_id` / `budget_remaining`。
- **摘要**：驱动器无任务 / 熔断时打印 `[summary] done=.. suspended=.. env-blocked=.. budget_remaining=.. circuit_breaker=.. last=..`。
- **人工介入点**：`suspended` 任务带 `notes` 原因，处理后改回 `pending` 或直接在代码层解决。
- **env-blocked**：环境就绪（配 cookie / 装模型 / 网络通）后下次唤起自动重试；长期阻塞转 `suspended`。
- **熔断**：`circuit_breaker=true` 即停；改回 `false` 恢复长跑。

## 7. 关键约定与坑（务必看）
1. **token 精简是设计核心**：主调度只传路径、只读账本索引、不读 PLAN/账本全文。子智能体上下文隔离，主窗口始终精简。
2. **传路径解耦**：子智能体间只传本地文件路径，不把代码正文粘回主调度。
3. **尽量用绝对路径派发任务**：子代理的工作目录（cwd）可能漂移；给 dev-agent 的任务描述用绝对路径（如 `D:/.../video-parser/backend/...`），避免文件落错目录。
4. **三测试维度可重映射**：默认 function/security/integration；换项目时按真实质量关注点改（如前端布局/美观/动画）。改 `.claude/agents/test-*.md` 的测试命令与审计清单即可。
5. **环境依赖会 env-block**：集成测试依赖网络/cookie/模型，缺失时标 `env-blocked` 而非 FAIL，不阻塞整体。
6. **模型档位未适配**：agent 不写 `model`，继承主会话；如需分档自行加 `model:` 字段。

## 8. 适配到全新项目（复用脚手架）
1. 把 `.claude/agents/`（5 个）、`.claude/commands/`（orchestrate / run-batch / crystallize-experience）拷到新项目的 `.claude/` 下。
2. 拷 `docs/AGENT_EXPERIENCE.md`（种子模板）、`docs/THOUGHTS.md` 留空。
3. 改三处项目相关项：
   - `planning-agent.md` / `dev-agent.md` 里的架构约束引用（SSRF / 白名单 / TODO 等）换成新项目约束；
   - 三个 `test-*.md` 的**测试命令**（如 `pytest`、`npm test`）与**审计清单**；
   - 重映射三测试维度（见 §7.4）。
4. 详细可拷贝模板见 `docs/MULTI_AGENT_SCAFFOLD.md`。

## 9. 已知天花板（诚实告知）
- **执行层已自治**（写码/测试/修复/续跑/报错），但**"需求是否被满意地满足"对主观/质量类需求（如 P2 摘要生成）无自动 oracle**——测试只能验"返回了、字段非空"，验不了"好不好"。这类仍需人工抽检。这是 Phase B 范畴，非工程能完全消除。
- 需求若有歧义/冲突/不可能项，agent 不会替你做产品决策，会卡在升级循环耗尽预算后 `suspended`。

## 10. 当前仓库状态（验证后）
- `docs/status.json` 已复位为干净可初始化状态（首次 `/orchestrate "<req>"` 会重新生成）。
- 冒烟产物 `video-parser/backend/tests/test_submit_validation.py` 已保留（真实有用、离线可跑、三维验收通过）。
- 经验账本 `docs/AGENT_EXPERIENCE.md` 含 T1/T2/T-SMOKE 等真实记录，可跨任务复用。
