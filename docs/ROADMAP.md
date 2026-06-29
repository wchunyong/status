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
| 语言 | Swift 6（tools-version 6.0 → 默认 Swift 6 模式） | strict concurrency；B8 靠 @MainActor/actor/Sendable 保证 |
| 构建系统 | **Swift Package Manager**（ADR D6） | 核心库 + 可执行壳；.xcodeproj 打包留 M7 |
| 状态栏 UI | AppKit（`NSStatusItem` + `attributedTitle`） | 轻量；R-014 见 §3 备注 |
| 菜单 | `NSMenu` + 自定义 `MenuSectionView`（NSView） | D4：菜单而非 Popover |
| 设置窗口 | SwiftUI（`NSWindow` + `NSHostingController` + `@AppStorage` 思路） | macOS 14+ |
| 视觉材质 | `.glassEffect()`（26+）/ `.ultraThinMaterial` 回退 | 集中封装于 `GlassMaterial`，B7 |
| CPU 采集 | Mach `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | 释放见 B1 |
| 内存采集 | Mach `host_statistics64(HOST_VM_INFO64)` + `ProcessInfo.physicalMemory` | 口径见 B2；页大小 `getpagesize()` |
| 网络采集 | sysctl `NET_RT_IFLIST2`（`if_data64` 64 位计数） | 无 4GB 回绕；聚合 UP 且非环回接口 |
| 时间 | `clock_gettime(CLOCK_MONOTONIC)` | B5，禁墙钟 |
| 自启动 | `SMAppService.mainApp` | macOS 13+；需签名 bundle（D5/M7） |
| 持久化 | `UserDefaults`（JSON blob） | 无数据库 |
| 测试 | XCTest（48 用例） | 见 `CLAUDE.md` §8 |
| 构建/分发 | `swift build` / `xcodebuild`；DMG + Developer ID + `notarytool`（M7） | D5/D6 |
| 部署目标 | **macOS 14.0（Sonoma）** | 26+ 特性 `if #available` 渐进启用，B7 |
| 门禁 | SwiftLint + SwiftFormat + `swift test`（`scripts/gate.sh`） | R-002 |

> 未经 §7 ADR 正式记录，不得引入第二套语言/框架或任何第三方依赖。

---

## 2. 分期里程碑（Phase 0–5）

| Phase | 目标 | 状态 |
|-------|------|------|
| **Phase 0** | 工程脚手架与纪律底座 | ✅ 完成（R-001~R-005） |
| **Phase 1** | 采集核心（CPU/Mem/Net + Sampler + 防泄漏） | ✅ 完成（R-006~R-011） |
| **Phase 2** | 状态栏实时显示 + 格式化 | ✅ 完成（R-012~R-015） |
| **Phase 3** | 设置界面（五 Tab） | ✅ 完成（R-016~R-017） |
| **Phase 4** | 菜单详情 + 液态玻璃 | ✅ 完成（R-018~R-020） |
| **Phase 5** | 性能 / 稳定性 / 发布 | 🟡 阻塞：需签名证书 / 24h 老化 / 可视化 QA / 图标设计 / .app bundle（见 §6.3） |

---

## 3. 任务主追踪表（R-###）

### Phase 0 —— 工程脚手架与纪律底座 ✅

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-001 | 创建工程（SPM `Status.app`），部署目标 macOS 14，git 初始化 | — | ✅ | `swift build` 产出可执行；B6（无网络权限） |
| R-002 | 配置 SwiftLint + SwiftFormat + XCTest + `scripts/gate.sh` | R-001 | ✅ | 门禁全绿；48 用例通过 |
| R-003 | `NSStatusItem` + AppDelegate/`@main` 生命周期（`.accessory`） | R-001 | ✅ | 启动出现状态栏项；B8 |
| R-004 | `SMAppService` 自启动 + `NSWorkspace.didWakeNotification` 监听 | R-003 | ✅ | 唤醒回调触发 `monitor.resetAfterWake()`（B4） |
| R-005 | 状态栏显示文字（冒烟） | R-003 | ✅ | 启动存活 3s 无崩溃（headless 冒烟通过） |

### Phase 1 —— 采集核心 ✅

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-006 | 定义 `Sample`（Sendable struct） | — | ✅ | 值类型 + Sendable |
| R-007 | `CPUProvider`（`host_processor_info` + `vm_deallocate`）+ delta 计算 | R-006, R-010 | ✅ | fake tick 单测 + 释放（B1）+ 口径（B2） |
| R-008 | `MemoryProvider`（`host_statistics64` + physicalMemory） | R-006 | ✅ | 已用 = 总量−(free+inactive)×ps；集成测试对照（B2） |
| R-009 | `NetworkProvider`（sysctl `NET_RT_IFLIST2`，64 位计数，flag 过滤） | R-006, R-010 | ✅ | 累计单调；回绕丢弃（B4）；无三方库 |
| R-010 | 单调时钟 + 异常 Δ 丢弃（`DeltaDecision`） | — | ✅ | 阈值边界单测；禁墙钟（B5） |
| R-011 | `Sampler`（单一定时器 utility QoS）+ `SystemMonitor` actor + 防泄漏冒烟 | R-007~R-010 | ✅ | 40 次采样不崩溃（B1 冒烟）；后台采集主线程 UI（B8） |

### Phase 2 —— 状态栏实时显示 ✅

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-012 | `StatusSettings`（Codable + 字段级默认）+ `SettingsStore` | R-001 | ✅ | 默认值/往返/部分 JSON/损坏回退单测 |
| R-013 | Formatter 三件套（ByteRate/Byte/MemoryDisplay/Percent） | R-012 | ✅ | 单位换算/边界单测全覆盖（B2） |
| R-014 | 状态栏渲染（**用 `button.attributedTitle`**，非自定义 NSView） | R-003, R-011, R-013 | ✅ | 仅 Sample 变化刷新；主线程（B8） |
| R-015 | 设置 → Formatter → 状态栏联动 | R-013, R-014, R-012 | ✅ | 改单位/顺序/显隐实时生效 |

> **R-014 实现备注**：PRD/原计划用自定义 `NSView` 绘制状态栏；实际采用 `NSStatusItem.button.attributedTitle`（等宽字体 + labelColor）。功能等价（紧凑文本、支持深浅色），且更轻、更可控；自定义 NSView 作为未来按段着色的增强项。属实现层选择，未改 PRD 口径/AC。

### Phase 3 —— 设置界面 ✅

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-016 | `SettingsView`（SwiftUI）五 Tab：通用/网络/内存/CPU/显示 | R-012 | ✅ | 全部 §5.2 配置项可编辑；14+ 可用 |
| R-017 | 设置变更实时反映状态栏 + 外观应用 | R-016, R-015 | ✅ | `onChange → persist()` 联动；外观即时切换 |

### Phase 4 —— 菜单详情 + 液态玻璃 ✅

| ID | 任务 | 依赖 | 状态 | 验收 / 关联铁律 |
|----|------|------|------|-----------------|
| R-018 | `NSMenu` + `MenuSectionView`（网络/内存/CPU，`menuWillOpen` 刷新） | R-011, R-014 | ✅ | 点击弹菜单，三区块读最新 `Sample`；D4 |
| R-019 | `GlassMaterial`：26+ `.glassEffect()` / 回退 `.ultraThinMaterial` | R-018 | ✅ | 编译期 `if #available` 分支；B7 |
| R-020 | 菜单「⚙ 设置…」「⏻ 退出」入口 | R-016, R-018 | ✅ | 打开设置窗口 / 终止 App |

### Phase 5 —— 性能 / 稳定性 / 发布 🟡（阻塞，详见 §6.3）

| ID | 任务 | 依赖 | 状态 | 验收 / 阻塞原因 |
|----|------|------|------|-----------------|
| R-021 | 24h 内存老化 + Instruments Allocations | R-011 | ⬜ | 需 24h 运行 + Instruments（GUI）；已有 40 次冒烟回归（B1） |
| R-022 | 唤醒 / 网络切换 / 显示器热插拔回归 | R-018 | 🟡 | 唤醒已接线+测试；网络热插拔随 `NET_RT_IFLIST2` 天然容错；显示器/手动回归待做 |
| R-023 | 可访问性 + 深浅色 + 刘海屏适配 | R-014, R-018 | 🟡 | 深/浅色已做（外观设置）；可访问性/刘海屏需手动可视化 QA |
| R-024 | 简体中文本地化（英文回退） | R-016, R-018 | ⬜ | 需 .app bundle 才能加载 strings 表（M7） |
| R-025 | App 图标（.iconset） | R-001 | ⬜ | 需设计稿 + .app bundle 装载 |
| R-026 | DMG + Developer ID 签名 + `notarytool` + `stapler` | 全部特性 | ⬜ | **硬阻塞**：需用户提供 Developer ID 证书（D5） |

---

## 4. 依赖关系

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

---

## 5. 指标 × 信息面 矩阵

| 指标 | 状态栏（常驻） | 菜单详情（点击） | 设置可配（Tab） |
|------|:--------------:|:----------------:|-----------------|
| 网络下行 ↓ | ✅ 速率 | ✅ 速率 | 网络：单位 / 箭头 |
| 网络上行 ↑ | ✅ 速率 | ✅ 速率 | 网络：同上 |
| 内存 | ✅ 已用/百分比 | ✅ 已用·总量（usedOfTotal） | 内存：单位 / 格式 |
| CPU | ✅ 总占用% | ✅ 总占用% | CPU：单核显隐（菜单占位） |
| （全局） | 顺序/显隐/紧凑 | — | 显示：顺序(↑↓) / 显隐 / 紧凑 |
| 设置入口 | — | ✅「⚙ 设置…」 | 通用：自启动 / 刷新间隔 / 外观 |
| 退出 | — | ✅「⏻ 退出」 | — |

> v1.1 规划：菜单增加 sparkline（D3）；接口手动勾选（§6.1）。

---

## 6. 待确认 / 风险项

### 6.1 待确认（owner 决策点，非阻塞）
1. 监控接口「手动勾选」默认候选清单（仅 `en*`，还是含 `utun*`/`bridge*`）？当前用 flag 过滤（UP 且非环回），留 R-009 增强时定。
2. 是否需要「窗口模式」详情面板？现阶段菜单足够。
3. 自动更新是否首发集成 Sparkle？倾向 v1.1（B6）。

### 6.2 风险与对策

| 风险 | 影响 | 对策 | 关联 |
|------|------|------|------|
| Mach 指针未释放 → 24h 泄漏 | 内存上涨 | `defer` 释放 + 40 次冒烟回归（R-011）；24h/Instruments 待 R-021 | B1/B3 |
| 睡眠唤醒后速率尖峰 | 数据失真 | 单调时钟 + 唤醒通知 + 异常 Δ 丢弃（已实现+测试） | B4/B5 |
| macOS 27 API 变更 | 兼容性 | 仅依赖稳定 Mach/C API；27 发布即回归 | B7 |
| 刘海机状态栏宽度不足 | 文字截断 | 紧凑模式（已实现）；自适应缩短待 R-023 | R-023 |
| 内存口径与活动监视器细微差异 | 用户困惑 | M6 校准（R-021）；口径 PRD §5.1 + tooltip | B2 |
| 公证/签名配置错误 | 无法分发 | 待 M7 流水线化；需用户提供 Developer ID | R-026, D5 |

### 6.3 Phase 5 阻塞说明（为什么停在这里）
R-021~R-026 无法在无人工介入下完成，原因：
- **R-021**：真 24h 老化需挂机运行；内存增量精测需 Instruments（GUI）。已用 40 次连续采样的冒烟回归（`testRepeatedSamplingIsCrashFree`）兜底 B1。
- **R-022 / R-023**：唤醒已接线并测试；网络切换随采集 API 天然容错。但显示器热插拔、刘海屏、可访问性（对比度/加大文本）需**人眼可视化 QA**，agent 无法自证。
- **R-024 / R-025**：本地化 strings 表与图标都需 **.app bundle** 才能加载；当前为 SPM 裸可执行（D6），bundle 化在 M7。
- **R-026**：DMG 签名/公证**硬阻塞**，需用户提供 Developer ID Application 证书。

> 推进方式：进入 M7 时（用户提供证书 + 设计稿后），用 XcodeGen 或 Xcode 生成 .xcodeproj → 正式 .app bundle（LSUIElement/图标/本地化）→ 签名 → `notarytool` 公证 → DMG。

---

## 7. 架构决策记录（ADR）

> 与 `PRD.md` §4 Decision Log 共享 D1–D5 编号；**本节为权威详记**；新增决策追加 D6+。变更先改这里，再同步 PRD §4。
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
- **后果**：注意与开源 `exelban/stats` 区分；Bundle ID 须唯一（建议 `com.<owner>.status` 或加前缀）。

### D3 · 首发不做 sparkline，留 v1.1
- **背景**：v1 优先级是「低占用 + 24h 稳定」，sparkline 增加绘制与状态面。
- **决策**：v1 纯数字（状态栏 + 菜单）；sparkline 放 v1.1，补环形历史缓冲 + 折线 `NSView`。
- **备选**：首发即带 sparkline——被否，抬高出 bug 概率，与稳定优先冲突。
- **后果**：`SystemMonitor` 侧不阻塞后续加历史缓冲（数据天然可得）；矩阵「菜单详情」列 v1.1 追加。

### D4 · 点击交互用 NSMenu（非 Popover）
- **背景**：需在「详情 + 设置 + 退出」之间选一个主交互载体。
- **决策**：`NSMenu`，内含网络/内存/CPU 区块（自定义 `MenuSectionView` 的 `NSMenuItem`）+ 设置/退出项；26+ 自动获得液态玻璃。
- **备选**：`NSPopover` + SwiftUI 内容——更灵活但更重、渲染开销更高。
- **后果**：菜单内容用自定义 view，灵活度低于 SwiftUI，但更省更原生；未来图表若超出菜单空间，再评估独立 `NSPanel`。

### D5 · 分发用官网 DMG + Developer ID 公证
- **背景**：需选择分发渠道。
- **决策**：官网提供 `.dmg`，用 Developer ID Application 签名，`notarytool` 公证 + `stapler` 装订。
- **备选**：Mac App Store——被否，权限审核更严、更新链路更重，与「轻量」定位不符。
- **后果**：需维护签名/公证流水线（R-026）；首发无内嵌自动更新（v1.1 评估 Sparkle）。

### D6 · 构建系统采用 Swift Package Manager（非 .xcodeproj）
- **背景**：需可在命令行完整构建+测试（agent 自主推进环境无 Xcode GUI 操作）。核心逻辑要可被 `swift test` 全覆盖。
- **决策**：用 SPM（`Package.swift`）。`StatusCore` 库承载全部纯逻辑（采集口径/格式化/设置，48 单测覆盖）；`Status` 可执行目标承载 AppKit/SwiftUI 壳；`setActivationPolicy(.accessory)` 实现 menu-bar-only（运行期等价 LSUIElement，开发期无需 .app bundle）。
- **备选**：① XcodeGen 生成 .xcodeproj——未安装，且 pbxproj 易错；② 手写 pbxproj——脆弱。均被否。
- **后果 / 取舍**：
  - 网络采集改用 **sysctl `NET_RT_IFLIST2`**（原生 64 位 `if_data64`，无 4GB 回绕），比 PRD 附录 A.1 草案的 `getifaddrs`（32 位 `ifi_ibytes`）更准；属实现改进，口径（B2）不变。
  - 页大小用 `getpagesize()`（并发安全），而非 `vm_kernel_page_size`（Swift 6 strict 下被判非并发安全）。
  - **per-target Swift 语言模式 API 在本工具链不稳定**（仅 package 级 `swiftLanguageModes`，语义是「声明支持」），故不显式声明；tools-version 6.0 默认即 Swift 6 模式，B8 靠代码层 `@MainActor`/`actor`/`Sendable` 保证。
  - SMAppService 自启动、本地化、图标、签名都**需要正式 .app bundle**——这些落到 M7：届时用 XcodeGen/Xcode 生成 .xcodeproj，做 bundle（LSUIElement/Info.plist/图标/strings）→ 签名 → 公证 → DMG。
  - R-014 状态栏用 `attributedTitle`（见 §3 备注）。

---

## 附：与 PRD 的章节映射

| ROADMAP | PRD | 关系 |
|---------|-----|------|
| §1 技术栈 | §6.1 技术选型 | 同源，本文件为技术实施权威（含 D6 更新） |
| §2 Phase 0–5 | §9 里程碑 M1–M7 | Phase 细化 M，映射 R-### |
| §3 R-### 任务 | §5 功能 / §9 里程碑 | 每条任务挂 AC + B# |
| §5 指标×信息面矩阵 | §5.1–§5.3 + §8 UI | 落点对照 |
| §6 待确认/风险 | §10 风险 / §11 开放议题 | 合并与扩充 |
| §7 ADR D1–D6 | §4 Decision Log D1–D5 | 本文件权威详记（D6 为新增） |
