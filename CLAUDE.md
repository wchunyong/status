# CLAUDE.md · Status 状态栏系统监控 Agent 指南

本文件是本仓库 AI coding agent（Claude Code / Codex / 其他）的**唯一权威启动约束**。进入本仓库后，必须先读本文件，再读 `docs/PRD.md` 与 `docs/ROADMAP.md` 中和当前任务相关的章节。

不要新增 `AGENT.md` / `AGENTS.md`。如果某个工具需要自己的启动文件，它只能作为 bootstrap 指向本文件，不能复制一份独立规则。

> **文档分层（三份，各管一摊，别混）**：
> - **`CLAUDE.md`（本文件）**：agent 怎么工作——流程、测试纪律、git/PR、完成定义、技术铁律 B1–B8。
> - **`docs/PRD.md`**：产品定位、目标用户、三大监控功能、设置项、菜单详情、性能预算、UI/UX。
> - **`docs/ROADMAP.md`**：技术栈、分期里程碑（Phase 0–5）、任务主追踪表（R-###）、依赖关系、指标×信息面矩阵、待确认/风险项、架构决策记录（ADR D#）。
>
> 凡引用某条技术铁律，一律用本文件 §4 的 **B 编号**（如 B1 零泄漏、B4 睡眠唤醒边界）指过去，不在别处另写一套措辞，避免文档漂移。凡引用架构决策，一律用 ROADMAP §7 的 **D 编号**。

---

## 1. 项目定位

**Status** —— 常驻 macOS 菜单栏的轻量系统监控 App，实时显示网络上下行速率、内存占用、CPU 占用；点击图标弹菜单看详情、进设置。用原生技术栈做到**低占用 + 24h 稳定 + 拥抱 macOS 26（Tahoe）液态玻璃**。

当前仓库处于**规划阶段，尚未开始编码**，现有权威信息集中在：

- `docs/PRD.md`：产品规格、目标用户、三大监控（F1 网络 / F2 内存 / F3 CPU）、设置五 Tab、菜单详情、性能预算、UI/UX、风险、附录参考实现。
- `docs/ROADMAP.md`：技术栈、Phase 0–5 实施顺序、任务主追踪表（R-###）、依赖关系、指标×信息面矩阵、§6 待确认/风险项、§7 架构决策记录（ADR D1–D5）。

所有功能开发都必须围绕**三大核心指标 + 低占用/稳定**倒推，不允许为实现方便偏离 PRD 和 ROADMAP。Status 不是后端服务、不是 Electron 应用、不联网——这三点是不可移动的边界。

---

## 2. 技术架构

目标架构按 `docs/ROADMAP.md` §1 演进，未经文档正式更新不得引入第二套语言/框架或绕过采集契约的捷径。

- **语言**：Swift 6（**strict concurrency** 开启）。业务对象一律用值类型（`struct`/`enum`），跨 actor 传递的对象必须 `Sendable`。
- **状态栏 UI**：AppKit —— `NSStatusItem` + 自定义 `NSView` 绘制文本。禁止用 SwiftUI 渲染常驻状态栏（开销与可控性都不达标）。
- **菜单**：`NSMenu` + 自定义 `NSView` 的 `NSMenuItem`（详见 D4）。
- **设置窗口**：SwiftUI（`@AppStorage` 持久化）。
- **视觉材质**：`.glassEffect()`（macOS 26+）经 `GlassMaterial` 封装，旧系统回退 `.ultraThinMaterial`（详见 B7）。
- **数据采集**：Mach Kernel API（CPU `host_processor_info`、内存 `host_statistics64`）+ `getifaddrs`（网络）+ `sysctl`（`hw.memsize`）。**禁止引入第三方监控库**。
- **自启动**：`SMAppService.mainApp`（macOS 13+）。
- **时间**：`clock_gettime(CLOCK_MONOTONIC)`（详见 B5）。
- **持久化**：`UserDefaults` / `@AppStorage`，配置量小，不引入数据库。
- **包管理**：Swift Package Manager；**首发零三方依赖**，任何新增依赖必须在 ROADMAP ADR 记录理由。
- **构建/分发**：Xcode（.xcodeproj 或 SwiftPM 驱动 `xcodebuild`），Debug/Release 配置；DMG + Developer ID 签名 + `notarytool` 公证（详见 D5）。
- **测试体系**：TDD + 测试金字塔 + CI 提交门禁（见 §8、§9）。

---

## 3. 构建配置与签名

macOS 桌面 App 没有 backend 的 `MODE=debug|prod` 切换，但有以下必须守的配置纪律：

- **构建配置**：`Debug`（开发/测试，不签名或自动签名）与 `Release`（分发，Developer ID 签名 + 公证）。本地开发用 `Debug`；任何分发产物只能来自 `Release`。
- **部署目标**：`macOS 14.0`（Sonoma）。任何新 API 的最低版本要求高于 14 时必须 `if #available` 包裹（B7），不得抬高部署目标。
- **沙盒/权限**：首发**关闭 App Sandbox 之外无网络权限需求**（见 B6）。新增任何 entitlement（Network、Camera 等）必须先在 PRD/ROADMAP 论证并记录。
- **签名身份**：`Debug` 可用 `-`（ad-hoc）或个人开发证书；`Release` 必须用 Developer ID Application 证书，密钥不入库。
- **公证**：`Release` 产物必须经 `notarytool` 提交 + `stapler staple`（M7，见 D5）。未公证的 build 不得作为正式分发。
- 禁止提交真实证书、私钥、公证凭据、App Store Connect key；这类内容只存在于本地钥匙串或 CI secret。

---

## 4. 技术铁律（B1–B8，编码必守）

> 这些是不可违反的不变式，等同 PRD 的核心约束；流程与 review 一律引用 B 编号。

- **B1 零泄漏**：所有 Mach 分配必须配对释放——`host_processor_info` 返回的指针必须 `vm_deallocate`，`getifaddrs` 必须 `freeifaddrs`，全部走 `defer` 兜底。任何新增的系统句柄同样必须有释放路径。24h 内存增长 < 5 MB（PRD §7.2）。
- **B2 数据口径固定**：
  - 内存「已用」= `hw.memsize − (free_count + inactive_count) × pagesize`；
  - CPU 占用 = `busyΔ / totalΔ × 100`，`busyΔ = (user+system+nice)Δ`，`totalΔ` 含 idle；
  - 网络速率 = 「物理接口累计字节差 / 单调时钟 Δ」。
  - 口径变更必须**先改 `docs/PRD.md` §5.1**，再改代码；禁止在代码里悄悄换算法。
- **B3 资源预算**：RSS 稳态 < 40 MB；空闲 CPU < 1%；采样瞬时 < 2%；冷启动到图标出现 < 1s（PRD §7.1）。违反必须说明原因并记录到 ROADMAP 风险表。
- **B4 睡眠/唤醒边界**：监听 `NSWorkspace.didWakeNotification`，唤醒后**丢弃下一次采样**并重置 Provider 缓存；检测到采样 Δ 异常（如 > 10s）的差值必须丢弃，不得参与显示。
- **B5 单调时钟**：所有速率与时间间隔计算必须用 `clock_gettime(CLOCK_MONOTONIC)`，**禁止用 `Date()` / 墙钟时间**算 Δ（系统休眠会回跳/停滞）。
- **B6 隐私零外联**：首发不申请网络权限，不收集、不上传任何数据，不引入任何带网络/分析/遥测的第三方依赖。外部资源（图标素材等）不联网拉取。
- **B7 渐进增强**：部署目标 macOS 14+。所有 macOS 26+（Tahoe）新 API（`.glassEffect()` 等）必须 `if #available(macOS 26.0, *)` 包裹并提供 14+ 回退，回退集中封装在 `GlassMaterial`，不得散落硬调。
- **B8 主线程 UI**：`NSStatusItem` / `NSView` / `NSMenu` 及其内容一律 `@MainActor`；采集在后台（`.utility` QoS 的串行队列或 `actor`），结果通过 `Sendable Sample` hop 到主线程更新 UI。禁止后台线程碰 AppKit 对象。

---

## 5. 权威文档同步

`docs/PRD.md` 与 `docs/ROADMAP.md` 是开发的上游和回写目标。每做一个功能、修复或架构调整，都必须检查这两个文件是否需要反向更新。

强制检查点：

1. **开始前**：确认当前任务来自 ROADMAP 的哪个 Phase / 哪条 R-### 任务；若不是，先说明它映射到哪个 PRD 目标或为何需要插入。
2. **写 plan 时**：引用对应 ROADMAP Phase/任务、PRD 章节、验收标准、相关技术铁律（B#）。
3. **实现后**：检查实际行为、口径、命令、限制是否改变了 PRD 或 ROADMAP。
4. **完成前**：若进度推进，勾选/更新 ROADMAP 对应任务的状态；若产品定义/验收/架构决策变化，更新 PRD / ROADMAP ADR。
5. 若无需更新，也要在最终回复或 PR 描述里说明已检查、无需回写的原因。

PRD §4 Decision Log 与 ROADMAP §7 ADR 共享 D1–D5 编号：**ROADMAP §7 为权威详记**，PRD §4 仅作速查摘要。任何决策变更先改 ROADMAP §7，再同步 PRD §4。

不允许只改代码不回看文档，也不允许让文档与实现长期分叉。

---

## 6. 任务入口协议

开始任何任务前，先判断任务类型：

- 用户要求**诊断 / 定位 / review / “先不要改”**：只读代码、日志、PRD、ROADMAP 和测试，不做文件修改，直到用户明确要求执行。
- 用户要求**实现 / 修复 / 补文档 / 提交**：按本文件流程执行，不停留在建议层。
- 用户**没指定任务来源**：从 ROADMAP 选择最高优先级、未完成、依赖已就绪的任务（优先 Phase 0 → Phase 1）。
- 用户指定任务但 ROADMAP 没有：先说明它映射到哪个 PRD 目标；必要时补进 ROADMAP（分配 R-###）后再开发。

所有 plan 必须**先列验收标准和测试策略，再列实现步骤和 review/回写步骤**。测试策略要说明哪些行为用 XCTest 单元测试、哪些用集成测试、哪些只能手动/性能验证（状态栏渲染、玻璃外观等无法自动化的部分）。

---

## 7. 开发总流程

标准流程，所有功能开发必须遵守（开销按改动尺码缩放：脚手架/单文件契约可精简 plan 到一两行；涉及采集口径/铁律的硬逻辑必须完整走 §7、§8）：

1. 从 ROADMAP 认领当前最高优先级、未完成的 R-### 任务。
2. 阅读 PRD 中相关功能、口径、验收章节，确认涉及哪条 B#。
3. 先明确验收标准：正常路径、异常路径（接口消失、唤醒、计数回绕）、边界条件、成功的可观察结果，并对应到 PRD 或某条技术铁律 B#。
4. 生成执行 plan；plan 第一部分必须是**测试策略**，不能直接跳到实现。
5. 按 TDD 写 XCTest：优先写最小、最快、最靠近口径/算法的测试；UI 外观类用手动 checklist / 截图（§8）。
6. 运行新增测试，确认它**因目标功能缺失而失败**（RED），失败原因正确，不得是语法/测试写错。
7. 写最小实现让测试通过（GREEN），改动聚焦当前任务。
8. 在测试通过前提下重构，不借重构新增未测试行为。
9. 自查 review：口径（B2）、释放（B1）、并发（B8）、可用性（B7）、隐私（B6）、文档回写点。
10. 跑提交门禁：`swiftlint`、`swiftformat --lint`、`xcodebuild test`（单元 + 集成）；涉及 UI 的变更补手动/截图 checklist。
11. 若有 bug，先补能复现的失败测试，再修复，再 review，再重跑相关测试。
12. 重复 `test -> implement -> review -> test -> fix`，直到测试通过且证据完整。
13. 反向更新 ROADMAP 对应 R-### 任务状态；如 PRD/ADR 变化同步更新。
14. 最终汇报或 PR 必须包含功能细节、测试证据、门禁状态、文档回写信息。

不能跳过测试直接实现；不能用“已手测”替代可自动化的测试；不能在相关测试红的状态下声称完成。

---

## 8. TDD 与测试金字塔

采用 TDD + 测试金字塔 + CI 门禁。“先写测试”不等于“先写 UI 测试”——正确顺序是先写能表达目标行为的最小测试（口径计算、单位换算、回绕处理），再用最小实现让其通过，最后在测试保护下重构；UI 外观（状态栏排版、玻璃材质）用手动 checklist + 截图对照。

### 8.1 验收标准先行

每个功能写测试前必须明确：正常路径、异常路径、边界条件、成功的可观察结果，以及对应 PRD/ROADMAP 哪条验收项或技术铁律 B#。写不成测试的验收标准，通常说明行为还不够明确（或确属无法自动化，需在 plan 中注明手动验证方式）。

### 8.2 红绿重构

1. **RED**：先写失败测试，名称清楚表达目标行为。
2. **Verify RED**：`xcodebuild test` 确认它因功能缺失而失败。
3. **GREEN**：写最小实现让测试通过。
4. **Verify GREEN**：重跑，确认新测试与相关旧测试通过。
5. **REFACTOR**：仅在测试保持通过前提下重构。

测试第一次运行就通过 = 没证明新行为，必须重写。Bug 修复必须先加可复现的失败测试再修。

### 8.3 测试金字塔

- **单元测试 60–70%**：口径与算法是重中之重——CPU 占用率（注入 fake tick 数组算 Δ→%）、内存已用（注入 fake `vm_statistics64`）、网络 Δ 与计数回绕、物理接口过滤判定、单调时钟异常 Δ 丢弃、Formatter 单位换算（KB/s/MB/s/Kbps/Mbps/自动进位）、`AppSettings` 默认值与序列化。
- **集成测试 20–30%**：`Sampler` 调度三个 Provider 产出 `Sample`、设置变更驱动 `Formatter` → 状态栏字符串联动、**防泄漏回归**（连续采样 N 次后 Provider 不增长内存，验证 B1）。
- **UI / 手动 / 性能 5–10%**：状态栏渲染与排版、菜单外观、液态玻璃效果、深/浅色与刘海屏、可访问性——用手动 checklist + 截图；性能与稳定性用 XCTest metric / Instruments Allocations / 24h 老化脚本。

选择原则：能用单元测试证明的口径/算法不上集成；多模块协作但无需真实 UI 的优先集成；只有真实渲染/外观/长期稳定性才用手动或性能测试。

### 8.4 手动/性能验证边界

手动与性能验证必须：可追溯（checklist 引用 ROADMAP R-### 或 PRD 章节）、先记录预期、隔离（本地或独立环境，不污染用户系统）、可重复、聚焦关键路径、覆盖高风险降级（接口消失、唤醒后尖峰、计数回绕、macOS 14 回退外观、刘海机截断）。性能结果（RSS、CPU、24h 增量）以数字记录进 M6 证据，不得只写“感觉没问题”。

---

## 9. CI 与提交门禁

提交前本地必须至少通过：

- `swiftlint`（lint）
- `swiftformat --lint .`（格式检查）
- `xcodebuild test`（单元 + 集成）
- 受影响的 UI 变更：附手动 checklist + 截图；涉及采集/采样的变更：附防泄漏/性能证据

合并到 `main` 前 CI 必须覆盖：SwiftLint、SwiftFormat、`xcodebuild build`（构建冒烟——能编译产出 .app）、`xcodebuild test`（单元 + 集成）、防泄漏回归。Release 产物在 M7 增加签名 + 公证流水线校验。

如果某项门禁暂不存在（工程未初始化时），PR 必须说明当前缺口、替代验证方式和补齐位置。**不能把“当前没有脚本/工程”当作跳过验证的理由**——门禁随 Phase 0 脚手架一并建立（R-002）。

---

## 10. Review 标准

每轮实现后必须自查 review：

- 是否仍符合 PRD 的产品定位、三大指标、口径定义。
- 是否推进了 ROADMAP 的明确 R-### 任务。
- 验收标准是否被自动化测试覆盖，而非只靠手测或口头描述；UI 部分手动项是否列入 checklist。
- 是否选对测试层级，避免把本该单元测试覆盖的口径塞进手动验证。
- 口径（B2）是否与 PRD §5.1 一致；算 Δ 是否用单调时钟（B5）。
- 释放（B1）是否完整：Mach 指针、`getifaddrs`、任何新句柄。
- 并发（B8）是否正确：UI 在主线程、采集在后台、跨线程经 `Sendable`。
- 可用性（B7）：26+ 新 API 是否 `if #available` 包裹、是否有 14+ 回退。
- 隐私（B6）：是否引入网络/分析依赖、是否新增非必要权限。
- 资源预算（B3）是否仍达标，是否需要补性能证据。
- 是否需要回写 PRD 或 ROADMAP（含 ADR）。

发现 bug：先补可复现的失败测试 → 修复 → review → 重跑相关层级测试。

---

## 11. Git 分支规范

- `main`：稳定分支，唯一合并目标，禁止直接提交功能。
- `feat/<short-name>` / `fix/<short-name>` / `docs/<short-name>` / `test/<short-name>` / `chore/<short-name>`。

开始新任务：

```bash
git checkout main
git pull --rebase
git checkout -b feat/<short-name>
```

如果工作区已有用户改动，必须保护它，不得 reset/checkout/覆盖；只 stage 本次任务相关文件。

commit 用 Conventional Commits：

```text
feat(monitor): add CPU provider with leak-safe vm_deallocate
fix(network): drop delta on interface counter rollover
test(memory): cover used-memory formula edge cases
docs(agent): define test-first workflow for native app
```

合并默认 squash merge 进 `main`。

---

## 12. PR 内容要求

PR 描述必须详细，至少包含：

- **Roadmap 来源**：对应 ROADMAP 哪个 Phase / 哪条 R-### 任务。
- **PRD 对齐**：引用相关 PRD 章节、AC 或技术铁律 B#。
- **变更类型**：`feat` / `fix` / `docs` / `test` / `chore`。
- **变更细节**：做了什么、关键文件、关键口径或行为变化。
- **验收标准**：正常路径、异常路径（接口消失/唤醒/回绕）、边界条件、可观察结果。
- **测试策略**：哪些用 XCTest 单元、哪些用集成、哪些用手动/性能 checklist。
- **RED 证据**：新增测试曾因功能缺失而失败的摘要。
- **门禁结果**：`swiftlint` / `swiftformat --lint` / `xcodebuild test` 的命令与结果摘要；UI 变更附 checklist/截图；采集变更附防泄漏/性能证据。
- **Review 信息**：自查过哪些铁律（B1/B2/B5/B7/B8…），是否有降级/异常路径。
- **文档回写**：ROADMAP（R-### 状态/ADR）是否更新、PRD 是否更新；若未更新说明原因。
- **已知限制**：尚未覆盖的手动项、性能长跑、owner 决策点。

推荐模板：

```markdown
## Summary
-

## Roadmap / PRD
- Roadmap (Phase / R-###):
- PRD / 技术铁律:

## Implementation
-

## Test Strategy
- Acceptance criteria:
- Unit tests (XCTest):
- Integration tests:
- Manual / perf checklist:

## Test Evidence
- RED:
- Commands:
- Results:

## Review Notes
-

## Docs Backfill
- Roadmap:
- PRD:

## Risks / Follow-ups
-
```

---

## 13. 完成定义（DoD）

只有同时满足以下条件才算完成：

- 验收标准已明确并能追溯到 PRD/ROADMAP 或用户请求。
- 对应 XCTest 先失败、实现后通过；测试层级按金字塔选（口径走单元、协作走集成、外观走手动 checklist）。
- `swiftlint`、`swiftformat --lint`、`xcodebuild test`（单元 + 集成）通过。
- 涉及采集/采样的变更附带防泄漏回归证据（B1）；涉及 UI 的变更附手动 checklist/截图。
- 相关铁律（B1–B8）自查通过；26+ 新 API 有 14+ 回退（B7）。
- review 中发现的问题已修复并重跑相关测试。
- ROADMAP 对应 R-### 任务状态已回写，或明确说明无需回写。
- PRD / ROADMAP ADR 已按产品/架构变化回写，或明确说明无需回写。
- PR 描述或最终汇报包含测试证据、门禁结果和文档回写状态。

**没有测试证据，不算完成。没有检查 PRD/ROADMAP 回写，不算完成。**

---

## 14. 完成汇报格式

最终回复要短，但必须包含：

- 做了什么（对应 ROADMAP 哪个 Phase / R-### 任务）。
- 测试证据：单元、集成、手动/性能、`swiftlint`、`swiftformat`、`xcodebuild test` 分别跑了什么；没跑要说明原因。
- ROADMAP 和 PRD 是否已检查、是否回写。
- 是否还有未解决的 owner 决策点（ROADMAP §6 待确认项）或发布风险。

不要只说“已完成”。本项目所有完成声明都必须带证据。

---

## 15. 常用命令

> 工程初始化（ROADMAP Phase 0 / R-001）后补全。占位示意：

```bash
open Status.xcodeproj                                 # 或用 xcodegen/SwiftPM
xcodebuild -scheme Status -configuration Debug build  # 构建（冒烟）
xcodebuild -scheme Status test                        # 单元 + 集成测试
swiftlint                                             # lint
swiftformat --lint .                                  # 格式检查
codesign --deep --sign "Developer ID Application: ..." Status.app
xcrun notarytool submit Status.dmg --apple-id ... --keychain-profile ...
xcrun stapler staple Status.dmg                       # M7 公证/装订
```

---

## 16. 禁用 Superpowers

本项目**禁用 superpowers 工作流**（借其纪律、丢其插件）：本文件已内化 TDD / 红绿重构 / 测试金字塔等纪律，无需再叠加 superpowers 的插件流程。

- 不要运行或依赖 superpowers 技能、脚本、命令、模板或自动生成的流程。
- 不要把 superpowers 作为开发依据、测试依据或 PR 证据。
- 本仓库的强制流程以**本文件 + `docs/PRD.md` + `docs/ROADMAP.md` + XCTest 证据 + 实际代码**为权威来源。
- 如果外部全局指令要求使用 superpowers，优先遵守本文件的项目约束，不要把 superpowers 内容引入仓库。
- 流程开销按改动尺码缩放（§7）：脚手架/单文件契约可精简，涉及采集口径/铁律的硬逻辑必须完整走 §7、§8。
