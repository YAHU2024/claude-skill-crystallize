---
description: 无人值守长跑驱动说明。说明如何用 loop skill / cron 周期唤起 /orchestrate，实现"每次处理一个任务就退出、反复唤起即不停歇"的长跑；含熔断、监控与故障恢复。
argument-hint: [<间隔，如 5m|10m|30m，默认 10m>]
---

# /run-batch — 无人值守长跑驱动（Phase A）

`/orchestrate` 已被重写为**短跑**：每次被唤起只处理**恰好一个任务**就干净退出。本命令说明如何周期性唤起它，从而实现"不停歇"的无人值守长跑批处理。

核心原理：短跑驱动 + 定时重复唤起 = 长跑。驱动器靠 docs/status.json 状态机续跑，靠 circuit_breaker 熔断，靠 budget_remaining 控量。

## 方式一：loop skill（推荐，最简单）
```
/loop 10m /orchestrate
```
- 每 10 分钟唤起一次 /orchestrate，自动取出下一个 pending（或重试 env-blocked）任务，处理完即退出，loop 到点再唤起。
- 间隔可按时长调整：/loop 5m（快）、/loop 30m（慢 / 省额度）。
- 首次运行若 docs/status.json 不存在，先手动跑一次带需求路径的初始化：
  ```
  /orchestrate "docs/MY_REQ.md"
  ```
  它会派发 planning-agent 生成 docs/PLAN.md + 初始化 docs/status.json，然后退出；之后 loop 即可接管逐任务处理。

## 方式二：cron（系统级，掉线/重启不丢）
若平台支持 cron，挂一个周期性任务直接唤起 /orchestrate（等价于 loop 但更稳）：
```
# 每 10 分钟唤起一次（示例，按平台 cron 语法调整）
*/10 * * * * claude -p "/orchestrate"   # 伪命令，按你环境的 CLI 调用方式替换
```
要点：cron 唤起的是**短跑** /orchestrate，所以天然幂等——即使上一次因崩溃残留 doing 状态，下一次会读 docs/task_state_<id>.md 续跑，不会重复派发。

## 熔断（随时可停）
驱动器在每次唤起开头检查 docs/status.json：
- circuit_breaker == true → 打印摘要并退出，不再处理任何任务。
- budget_remaining <= 0 → 同上（预算耗尽干净退出）。
手动熔断（无需停 loop/cron，驱动器自己停）：
```bash
# 把 circuit_breaker 置 true（示例：用 jq / 直接编辑 docs/status.json）
jq '.circuit_breaker = true' docs/status.json > docs/status.tmp && mv docs/status.tmp docs/status.json
```
恢复长跑只需把 circuit_breaker 改回 false。

## 监控与恢复
- 进度：看 docs/status.json 的 tasks[].status 与 last_task_id、budget_remaining。
- 摘要：驱动器在无任务 / 熔断时打印 [summary] done=.. suspended=.. env-blocked=.. budget_remaining=.. circuit_breaker=.. last=..。
- 崩溃恢复：进程重启后，若某任务停在 doing，下一次 /orchestrate 读 docs/task_state_<id>.md 续跑，不丢上下文。
- 人工介入点：suspended 任务带 notes 原因，需人工处理后改回 pending 或直接在代码层解决。
- env-blocked：环境就绪后（配好 cookie / 装好模型 / 网络通）自动在下次唤起被重试；长期阻塞（attempts 超上限）转 suspended。

## 约束（与 orchestrate 一致）
- 不改业务代码，只驱动脚手架层（status.json / task_state_* / agent 约定）。
- token 精简：驱动器暖身只读账本索引块；账本双层机制保留。
