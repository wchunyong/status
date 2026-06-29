# ROADMAP · Status

> 本文件是 Status 的**技术实施与任务追踪权威**。任务认领、依赖、里程碑、架构决策（ADR）、待确认/风险项均以此为准。
>
> 三份文档分工见 `CLAUDE.md` 顶部：本文件管「怎么做、做到哪了」，`docs/PRD.md` 管「做什么、口径是什么」，`CLAUDE.md` 管「agent 怎么工作 + 铁律 B#」。
>
> 编号体系：
> - **R-###**：任务（§3 主追踪表）。状态用 ⬜ 未开始 / 🟡 进行中 / ✅ 完成。
> - **B#**：技术铁律，定义在 `CLAUDE.md` §4（B1 零泄漏 / B2 口径 / B3 预算 / B4 唤醒 / B5 单调时钟 / B6 隐私 / B7 渐进增强 / B8 主线程 UI）。
> - **D#**：架构决策记录（ADR），见 §7，与 `PRD.md` §4 Decision Log 共享编号，**本文件 §7 为权威详记**。

---

## 1. 技术栈

| 层 | 选型 | 备注 |
|----|------|------|
| 语言 | Swift 6（strict concurrency） | 值类型优先；跨 actor 对象 `Sendable` |
| 状态栏 UI | AppKit（`NSStatusItem` + 自定义 `NSView`） | 禁止 SwiftUI 渲染常驻状态栏 |
| 菜单 | `NSMenu` + 自定义 `NSView` 的 `NSMenuItem` | D4：菜单而非 Popover |
| 设置窗口 | SwiftUI（`@AppStorage`） | macOS 14+ |
| 视觉材质 | `.glassEffect()`（26+）/ `.ultraThinMaterial` 回退 | 集中封装于 `GlassMaterial`，B7 |
| CPU 采集 | Mach `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | 释放见 B1 |
| 内存采集 | Mach `host_statistics64(HOST_VM_INFO64)` + `sysctl(hw.memsize)` | 口径见 B2 |
| 网络采集 | `getifaddrs` / `if_data` / `freeifaddrs` | 仅 `AF_LINK`、排除环回 |
| 时间 | `clock_gettime(CLOCK_MONOTONIC)` | B5，禁墙钟 |
| 自启动 | `SMAppService.mainApp` | macOS 13+ |
| 持久化 | `UserDefaults` / `@AppStorage` | 无数据库 |
| 包管理 | Swift Package Manager | 首发零三方依赖（B6） |
| 测试 | XCTest + Instruments | 见 `CLAUDE.md` §8 |
| 构建/分发 | Xcode / `xcodebuild`；DMG + Developer ID + `notarytool` + `stapler` | D5 |
| 部署目标 | **macOS 14.0（Sonoma）** | 26+ 特性 `if #available` 渐进启用，B7 |

> 未经 §7 ADR 正式记录，不得引入第二套语言/框架或任何第三方依赖。

---

## 2. 分期里程碑（Phase 0–5）

| Phase | 目标 | 关键产出 | 对应 PRD 里程碑 |
|-------|------|----------|-----------------|
| **Phase 0** | 工程脚手架与纪律底座 | Xcode 工程、门禁（SwiftLint/Format/XCTest）、`NSStatusItem` 占位、自启动/唤醒监听、状态栏静态文字 | M1 |
| **Phase 1** | 采集核心 | `Sample` + CPU/Mem/Net 三 Provider + 单调时钟 + 单一定时器 + 防泄漏回归 | M2 |
| **Phase 2** | 状态栏实时显示 | `AppSettings` + Formatter 三件套 + `StatusBarContentView` 绘制 + 设置联动 | M3 |
| **Phase 3** | 设置界面 | SwiftUI 五 Tab 设置窗口，全部可配项生效 | M4 |
| **Phase 4** | 菜单详情 + 液态玻璃 | `NSMenu` 区块视图 + `GlassMaterial` 适配 + 设置/退出入口 | M5 |
| **Phase 5** | 性能 / 稳定性 / 发布 | 24h 老化 + 唤醒/切换回归 + 可访问性/本地化/图标 + DMG 公证 | M6, M7 |

---

## 3. 任务主追踪表（R-###）

> 状态：⬜ 未开始 / 🟡 进行中 / ✅ 完成。依赖列的 `R-###` 必须先完成。

### Phase 0 —— 工程脚手架与纪律底座

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-001 | 创建 Xcode 工程 `Status.app`，部署目标 macOS 14，App/Sandbox 配置，git 初始化 | — | ⬜ | `xcodebuild build` 产出 .app；B6（无网络权限） |
| R-002 | 配置 SwiftLint + SwiftFormat + XCTest target，本地门禁脚本 | R-001 | ⬜ | `swiftlint`/`swiftformat --lint`/`xcodebuild test` 可跑（空测试通过） |
| R-003 | `NSStatusItem` 占位 + AppDelegate/SwiftUI App 生命周期 | R-001 | ⬜ | 启动后菜单栏出现图标；B8 |
| R-004 | `SMAppService` 自启动 + `NSWorkspace.didWakeNotification` 监听骨架 | R-003 | ⬜ | 自启动开关可注册/注销；唤醒回调可触发（B4 雏形） |
| R-005 | 调试构建在状态栏显示静态文字（冒烟） | R-003 | ⬜ | 状态栏渲染一段静态文本，无报错 |

### Phase 1 —— 采集核心

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-006 | 定义 `Sample`（`struct: Sendable`），含 cpu/mem/net 快照字段 | — | ⬜ | 值类型、`Sendable`；单测覆盖构造 |
| R-007 | `CPUProvider`（`host_processor_info` + `vm_deallocate`），含 delta 计算 | R-006, R-010 | ⬜ | 注入 fake tick 算 % 正确；指针释放（B1）；口径（B2） |
| R-008 | `MemoryProvider`（`host_statistics64` + `sysctl hw.memsize`） | R-006 | ⬜ | 已用 = 总量−(free+inactive)×ps；与活动监视器对照（B2） |
| R-009 | `NetworkProvider`（`getifaddrs`/`freeifaddrs`，接口过滤，回绕丢弃） | R-006, R-010 | ⬜ | 仅 `AF_LINK`、排除 `lo0`/down；回绕丢弃 Δ；释放（B1） |
| R-010 | 单调时钟工具（`CLOCK_MONOTONIC`）+ 异常 Δ 丢弃逻辑 | — | ⬜ | Δ>10s 丢弃；禁墙钟（B5）；单测覆盖边界 |
| R-011 | `Sampler`（单一定时器，`.utility` QoS）+ `SystemMonitor` actor + 防泄漏回归 | R-007, R-008, R-009, R-010 | ⬜ | 产出 `Sample`；连续采样 N 次内存不增长（B1）；后台采集主线程 UI（B8） |

### Phase 2 —— 状态栏实时显示

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-012 | `AppSettings`（`@AppStorage`）配置模型 + 默认值 + 序列化 | R-001 | ⬜ | 单测覆盖默认值/读写；配置量小无 DB |
| R-013 | Formatter 三件套：`ByteRateFormatter`/`ByteFormatter`/`PercentFormatter` | R-012 | ⬜ | 单位换算/自动进位单测全覆盖（B2） |
| R-014 | `StatusBarContentView`（`NSView`）绘制文本，仅 `Sample` 变化时重绘 | R-003, R-011, R-013 | ⬜ | 渲染三项指标；节流重绘；主线程（B8） |
| R-015 | `FormatterConfig` 联动：设置 → Formatter → 状态栏刷新 | R-013, R-014, R-012 | ⬜ | 改单位/顺序/显隐后状态栏实时变；集成测试 |

### Phase 3 —— 设置界面

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-016 | `SettingsView`（SwiftUI）五 Tab：通用/网络/内存/CPU/显示 | R-012 | ⬜ | 全部 §5.2 配置项可编辑；14+ 可用 |
| R-017 | 设置变更实时反映状态栏（顺序/显隐/单位/紧凑） | R-016, R-015 | ⬜ | 端到端联动；集成测试覆盖关键项 |

### Phase 4 —— 菜单详情 + 液态玻璃

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-018 | `NSMenu` + `MenuSectionView`（网络/内存/CPU 区块，读最新 `Sample`） | R-011, R-014 | ⬜ | 点击图标弹菜单，三区块明细正确；D4 |
| R-019 | `GlassMaterial` 封装：`if #available(macOS 26)` `.glassEffect()` / 回退 | R-018 | ⬜ | 26+ 玻璃、14–15 回退外观正确；B7 |
| R-020 | 菜单「⚙ 设置…」「⏻ 退出」入口 | R-016, R-018 | ⬜ | 打开设置窗口；退出 App |

### Phase 5 —— 性能 / 稳定性 / 发布

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-021 | 24h 内存老化 + Instruments Allocations 验证 | R-011 | ⬜ | RSS < 40 MB；24h 增量 < 5 MB；B1/B3 |
| R-022 | 唤醒 / 网络切换 / 显示器热插拔回归 | R-018 | ⬜ | 无速率尖峰、无崩溃；B4 |
| R-023 | 可访问性 + 深浅色 + 刘海屏适配 | R-014, R-018 | ⬜ | 加大文本/对比度 AA；刘海不截断 |
| R-024 | 简体中文本地化（英文回退） | R-016, R-018 | ⬜ | 中文优先；紧凑模式中文宽度验证 |
| R-025 | App 图标（多分辨率 .iconset） | R-001 | ⬜ | 满足 macOS 图标规范 |
| R-026 | DMG 打包 + Developer ID 签名 + `notarytool` 公证 + `stapler` 装订 | 全部特性任务 | ⬜ | 公证通过、可分发的 .dmg；D5 |

---

## 4. 依赖关系

关键依赖链（虚线 = 同 Phase 内强依赖）：

```
Phase 0:  R-001 ─┬─▶ R-002
                 ├─▶ R-003 ─▶ R-004 ─▶ R-005
                 └─▶ R-012
Phase 1:  R-006 ─┬─▶ R-007 ──┐
          R-010 ─┴─▶ R-008 ──┼─▶ R-011
                    R-009 ───┘
Phase 2:  R-012 ─▶ R-013 ─▶ R-015 ─▶ R-017
          R-003 + R-011 + R-013 ─▶ R-014 ─▶ R-015
Phase 3:  R-012 ─▶ R-016 ─▶ R-017
Phase 4:  R-011 + R-014 ─▶ R-018 ─▶ R-019
          R-016 + R-018 ─▶ R-020
Phase 5:  R-011 ─▶ R-021
          R-018 ─▶ R-022, R-023, R-024
          R-001 ─▶ R-025
          全部特性 ─▶ R-026
```

关键瓶颈（解阻塞优先级）：
- **R-001（工程脚手架）** 是全局前置，未完成则 R-002/R-003/R-012 都无法启动。
- **R-010（单调时钟）** 是 R-007/R-009 的前置，优先于具体 Provider 实现。
- **R-011（Sampler 集成）** 是 Phase 2/4 所有「显示/菜单」任务的统一数据源，是最大关键路径。

---

## 5. 指标 × 信息面 矩阵

> 哪个指标在哪个信息面出现，以及设置可配置项落点。对应 PRD §5。

| 指标 | 状态栏（常驻） | 菜单详情（点击） | 设置可配（Tab） |
|------|:--------------:|:----------------:|-----------------|
| 网络下行 ↓ | ✅ 速率 | ✅ 速率 + 接口名 | 网络：单位 / 自动进位 / 箭头 / 接口选择 |
| 网络上行 ↑ | ✅ 速率 | ✅ 速率 | 网络：同上 |
| 内存 | ✅ 已用/百分比 | ✅ 已用·总量·% + App/Wired/Compressed 明细 | 内存：单位 / 格式 / 口径 |
| CPU | ✅ 总占用% | ✅ 总占用% （单核可选） | CPU：格式 / 单核显隐 |
| （全局） | 顺序/显隐/紧凑 | — | 显示：项顺序拖拽 / 显隐 / 紧凑模式 |
| 设置入口 | — | ✅「⚙ 设置…」 | 通用：自启动 / 刷新间隔 / 外观 |
| 退出 | — | ✅「⏻ 退出」 | — |

> v1.1 规划：菜单/独立面板增加 sparkline（历史曲线），届时矩阵「菜单详情」列追加历史可视化。当前 R-### 不含此项（D3）。

---

## 6. 待确认 / 风险项

### 6.1 待确认（owner 决策点，非阻塞）
1. 监控接口「手动勾选」时的默认候选清单：仅 `en*`，还是包含 `utun*`/`bridge*`（VPN/桥接）？—— 留待 R-009 实现时定。
2. 是否需要「窗口模式」详情面板（独立 `NSPanel`，为未来图表留空间）？—— 现阶段菜单足够，暂不做。
3. 自动更新是否首发集成 Sparkle？—— 倾向 v1.1，避免首发引入三方依赖（B6）。

### 6.2 风险与对策

| 风险 | 影响 | 对策 | 关联 |
|------|------|------|------|
| Mach 指针未释放 → 24h 泄漏 | 内存上涨、违背 B1/B3 | `defer` 释放 + 防泄漏回归（R-021）+ Instruments Allocations | R-011, R-021 |
| 睡眠唤醒后速率尖峰 | 数据失真 | 单调时钟 + 唤醒通知 + 异常 Δ 丢弃（B4/B5） | R-010, R-022 |
| macOS 27 API 变更 | 兼容性 | 仅依赖稳定 Mach/C API；新特性 `if #available`；27 发布即回归 | B7 |
| 刘海机状态栏宽度不足 | 文字截断 | 紧凑模式 / 自适应缩短 / 动态宽度 | R-023 |
| 内存口径与活动监视器细微差异 | 用户困惑 | M6 校准；口径在 PRD §5.1 与 tooltip 说明 | R-008, B2 |
| 公证/签名配置错误 | 无法分发 | M7 流水线化 `codesign → notarytool → stapler`，提前验证 | R-026, D5 |

---

## 7. 架构决策记录（ADR）

> 与 `PRD.md` §4 Decision Log 共享 D1–D5 编号。**本节为权威详记**；变更先改这里，再同步 PRD §4。
> 格式：背景 / 决策 / 备选 / 后果。

### D1 · 部署目标设为 macOS 14.0+（渐进增强）
- **背景**：需兼顾「适配 macOS 26 液态玻璃」与「覆盖更广用户」。
- **决策**：部署目标 macOS 14.0（Sonoma）；26+ 新 API 一律 `if #available(macOS 26.0, *)` 包裹并提供 14+ 回退。
- **备选**：部署目标直接设 macOS 26.0+（放弃旧系统）——被否，覆盖面过窄。
- **后果**：需在 `GlassMaterial` 集中维护回退；测试须覆盖 14–15 回退外观与 26+ 玻璃两套（B7）。

### D2 · App 名称定为 Status
- **背景**：需一个简短、贴合用途的名字。
- **决策**：`Status`（Bundle / 工程 / 菜单显示名）。
- **备选**：Pulse / Stats-mini 等。
- **后果**：注意与开源项目 `exelban/stats` 区分；命名空间、Bundle ID 须唯一（建议 `com.<owner>.status` 或加前缀）。

### D3 · 首发不做 sparkline，留 v1.1
- **背景**：v1 优先级是「低占用 + 24h 稳定」，sparkline 增加绘制与状态面。
- **决策**：v1 纯数字（状态栏 + 菜单）；sparkline 放 v1.1，补环形历史缓冲 + 折线 `NSView`。
- **备选**：首发即带 sparkline——被否，抬高出 bug 概率，与稳定优先冲突。
- **后果**：架构在 `SystemMonitor` 侧不阻塞后续加历史缓冲（数据天然可得）；矩阵「菜单详情」列 v1.1 追加。

### D4 · 点击交互用 NSMenu（非 Popover）
- **背景**：需在「详情 + 设置 + 退出」之间选一个主交互载体。
- **决策**：`NSMenu`，内含网络/内存/CPU 区块（自定义 `NSView` 的 `NSMenuItem`）+ 设置/退出项；26+ 自动获得液态玻璃。
- **备选**：`NSPopover` + SwiftUI 内容——更灵活但更重、渲染开销更高。
- **后果**：菜单内容用自定义 view，灵活度低于 SwiftUI，但更省更原生；未来图表若超出菜单空间，再评估独立 `NSPanel`。

### D5 · 分发用官网 DMG + Developer ID 公证
- **背景**：需选择分发渠道。
- **决策**：官网提供 `.dmg`，用 Developer ID Application 签名，`notarytool` 公证 + `stapler` 装订。
- **备选**：Mac App Store——被否，权限审核更严、更新链路更重，与「轻量」定位不符。
- **后果**：需维护签名/公证流水线（R-026）；首发无内嵌自动更新（v1.1 评估 Sparkle）。

---

## 附：与 PRD 的章节映射

| ROADMAP | PRD | 关系 |
|---------|-----|------|
| §1 技术栈 | §6.1 技术选型 | 同源，本文件为技术实施权威 |
| §2 Phase 0–5 | §9 里程碑 M1–M7 | Phase 细化 M，映射 R-### |
| §3 R-### 任务 | §5 功能 / §9 里程碑 | 每条任务挂 AC + B# |
| §5 指标×信息面矩阵 | §5.1–§5.3 + §8 UI | 落点对照 |
| §6 待确认/风险 | §10 风险 / §11 开放议题 | 合并与扩充 |
| §7 ADR D1–D5 | §4 Decision Log D1–D5 | 本文件权威详记 |
