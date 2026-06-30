# PRD：Status —— 状态栏系统监控 App

> 版本：v1.0（已夯实）
> 日期：2026-06-30
> 状态：需求定稿，待进入工程阶段
> 平台：macOS 原生（Swift 6 / SwiftUI / AppKit）

---

## 1. 项目概述

### 1.1 一句话定义
**Status** 是一款常驻 macOS 菜单栏的轻量系统监控工具，实时显示**网络上下行速率、内存占用、CPU 占用**；点击图标弹出菜单查看详情并进入设置。

### 1.2 背景与动机
现有同类工具普遍存在：基于 Electron 导致内存高（150–300 MB）、功能臃肿、长期运行不稳定。Status 用**原生技术栈**实现：

- **极致轻量**：常驻内存 < 40 MB，空闲 CPU < 1%，采样时 < 2%。
- **长期稳定**：7×24 小时常开，不泄漏、不卡顿、不崩溃；睡眠/唤醒、网络切换后无异常。
- **拥抱新系统**：在 macOS 26（Tahoe）+ 上自动启用 **Liquid Glass（液态玻璃）**，在 macOS 14（Sonoma）+ 上优雅回退。

### 1.3 核心目标（验收线）
| 维度 | 目标 |
|------|------|
| 资源占用 | 内存（RSS）稳态 < 40 MB；空闲 CPU < 1%；采样瞬时 < 2% |
| 稳定性 | 24h 连续运行内存增长 < 5 MB；唤醒风暴为「低」电量影响 |
| 兼容性 | macOS 14.0+ 全量运行；macOS 26+ 启用液态玻璃；macOS 27 回归通过 |
| 体验 | 状态栏一眼可读；菜单详情直观；设置完备；符合系统视觉语言 |

---

## 2. 目标用户

- 重度 Mac 用户（开发 / 设计 / 创作者）：需随时了解资源占用。
- 对电量与性能敏感的用户：拒绝 Electron 类工具的内存与电量消耗。
- 追求系统一致性的用户：希望状态栏小工具与 macOS 原生风格统一。

---

## 3. 设计原则

1. **原生优先**：系统框架（Mach / IOKit / SystemConfiguration / SwiftUI / AppKit），零重型三方依赖。
2. **按需工作**：单一低频采样定时器 + Timer Coalescing，最大化电量友好。
3. **零泄漏**：Mach 端口、`getifaddrs` 内存、CF 对象严格配对释放；睡眠/唤醒边界专门处理。
4. **可读至上**：状态栏紧凑高对比，自动适配浅/深色与刘海屏。
5. **渐进增强**：核心监控在 macOS 14+ 全可用，新视觉按系统版本优雅启用。

---

## 4. 关键决策（速查）

> D1–D5 的**权威详记**在 `docs/ROADMAP.md` §7 ADR（背景 / 决策 / 备选 / 后果）。变更**先改 ROADMAP §7**，再同步本节速查，保持单一事实来源。

| # | 议题 | 结论 |
|---|------|------|
| D1 | 部署目标 | macOS 14.0+（渐进增强） |
| D2 | App 名称 | Status |
| D3 | 首发 sparkline | 不做，留 v1.1 |
| D4 | 点击交互 | NSPopover 浮窗（明细 + 设置… + 退出，1s 刷新） |
| D5 | 分发方式 | 官网 DMG + Developer ID 公证 |

---

## 5. 功能需求

### 5.1 核心监控（MVP）

#### F1 网络速率
- **采集**：`getifaddrs()` 枚举接口，仅取 `AF_LINK` 项，读 `if_data` 的 `ifi_ibytes` / `ifi_obytes`；排除环回 `lo0` 与 down 接口。
- **聚合**：默认汇总所有「UP 且非环回」的物理接口（`en*` / `bridge*` / `utun*` 等）；可在设置中限定。
- **速率**：与上次采样的累计字节求差，除以**单调时钟**真实间隔（`clock_gettime(CLOCK_MONOTONIC)`），规避休眠导致的大 Δ。
- **回绕处理**：`ifi_ibytes` 类型用 64 位累加；若检测到计数回落（接口重置），丢弃该次差值。
- **展示**：状态栏 `↓5.2 ↑0.3 MB/s`。
- **验收**：与 `nettop` / 活动监视器误差 < 5%；唤醒后无尖峰。

#### F2 内存占用
- **采集**：`host_statistics64(HOST_VM_INFO64)` → `vm_statistics64`，结合 `vm_kernel_page_size`。
- **总量**：`sysctl("hw.memsize")` 取物理内存总量。
- **口径（明确定义）**：
  - **已用** = 总量 − (free + inactive) × pagesize   （把可回收的 inactive 视为可用，与活动监视器口径对齐）
  - **明细**：Wired = `wire_count`；Compressed = `compressor_page_count`；App ≈ `active_count`（× pagesize）
- **展示**：状态栏 `12.4G` / `52%`（格式可配）。
- **验收**：与活动监视器「内存」标签页数值一致（M6 校准）。

#### F3 CPU 占用
- **采集**：`host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 取每核 `cpu_ticks[NUM_CPU_STATES]`（USER/SYSTEM/NICE/IDLE）。
- **总占用**：跨所有核累加两次采样差值
  - `usage% = busyΔ / totalΔ × 100`，`busyΔ = (user+system+nice)Δ`，`totalΔ = (user+system+nice+idle)Δ`
- **单核**：同公式按核计算（设置可选显示）。
- **释放**：返回的 `vm_offset_t` 数组必须 `vm_deallocate`，否则 24h 泄漏。
- **展示**：状态栏 `38%`。
- **验收**：与活动监视器 CPU 趋势一致（±2%）。

### 5.2 设置界面（SwiftUI，左侧 Tab）

| Tab | 可配置项 |
|-----|----------|
| **通用** | 开机自启动（`SMAppService`）、刷新间隔（1/2/5s）、外观（跟随系统/浅色/深色） |
| **网络** | 单位（自动/KB·s/MB·s/Kbps/Mbps）、自动进位、显隐方向箭头、监控接口（自动/勾选） |
| **内存** | 单位（GB/MB/百分比）、格式（仅已用 / 已用·总量 / 百分比）、口径（已用/可用） |
| **CPU** | 格式（总百分比）、是否显示单核 |
| **显示** | 状态栏项顺序拖拽、各指标显隐、紧凑模式（缩小字号/去箭头） |

> 全部设置经 `@AppStorage` / `UserDefaults` 持久化，改动实时反映到状态栏。

### 5.3 下拉浮窗详情（核心交互，2026-06-30 修订）

点击状态栏图标 → 弹出 **NSPopover**（SwiftUI `DetailPanelView`），分卡片展示，**默认随 1s 采样自动刷新**（绑定 `MonitorModel`）：

```
╭────────────────────────────────────╮
│  网络                    en0        │
│  ↓ 下行    5.20 MB/s                │
│  ↑ 上行    0.32 MB/s                │
├────────────────────────────────────┤
│  内存          12.4 / 24.0 GB  52% │
│  App 6.1 · Wired 4.2 · Comp 2.1 G  │
├────────────────────────────────────┤
│  CPU                         38%   │
├────────────────────────────────────┤
│  ⚙ 设置…                            │
│  ⏻ 退出 Status                      │
╰────────────────────────────────────╯
```

- macOS 26+ 经 `.glassEffect()` 液态玻璃；14–25 回退 `.ultraThinMaterial`（B7）。浮窗 `behavior=.transient`，点外部自动关闭。
- 原 NSMenu 方案见 ROADMAP ADR D4（已废弃、文件删除）。

### 5.4 后续规划（Post-MVP）

- 历史曲线 sparkline（**v1.1**，环形缓冲 + 折线 `NSView`）。
- 磁盘 I/O / 磁盘占用、GPU 占用、CPU 温度 / 风扇（SMC，评估稳定性）。
- 电池循环 / 放电速率。
- 阈值通知（如 CPU > 90% 持续 N 秒）。
- 主题 / 自定义颜色；菜单与弹窗两种交互可选。
- Sparkle 自更新。

---

## 6. 技术架构

### 6.1 技术选型

| 层 | 选型 | 可用性 |
|----|------|--------|
| 语言 | Swift 6（strict concurrency） | — |
| 状态栏 UI | AppKit（`NSStatusItem` + 自定义 `NSView`） | 14+ |
| 菜单 | `NSMenu` + 自定义 view 的 `NSMenuItem` | 14+ |
| 设置窗口 | SwiftUI | 14+ |
| 视觉材质 | `.glassEffect()`（26+）/ `.ultraThinMaterial` 回退 | `if #available(macOS 26)` |
| 数据采集 | Mach Kernel API + `getifaddrs` + `sysctl` | 14+ |
| 自启动 | `SMAppService.mainApp` | 13+ |
| 持久化 | `@AppStorage` / `UserDefaults` | 14+ |
| 包管理 | Swift Package Manager（首发零三方依赖） | — |

### 6.2 模块划分

```
Status (App)
├── App 入口
│   ├── AppDelegate / SwiftUI App          # 生命周期、SMAppService、唤醒通知
│   └── StatusBarManager (@MainActor)      # 管理 NSStatusItem + NSMenu 生命周期
├── Monitoring（采集层）
│   ├── SystemMonitor (actor)              # 持有各 Provider，统一取样
│   ├── CPUProvider        (Mach)
│   ├── MemoryProvider     (Mach + sysctl)
│   ├── NetworkProvider    (getifaddrs)
│   ├── Sampler                          # 单一定时器，utility QoS，coalesce
│   └── Sample (Sendable)                # 一次采样的不可变快照
├── Formatting（格式化层）
│   ├── ByteRateFormatter / ByteFormatter / PercentFormatter
│   └── FormatterConfig                  # 由 AppSettings 驱动
├── Settings（设置层）
│   ├── AppSettings (@AppStorage)         # 全局配置模型
│   └── SettingsView (SwiftUI)
└── UI
    ├── StatusBarContentView (NSView)     # 状态栏文本绘制（仅 Sample 变化时重绘）
    ├── MenuSectionView (NSView)          # 菜单内各区块自定义视图
    ├── SettingsWindowController
    └── GlassMaterial                     # 材质可用性适配
```

### 6.3 数据流与并发模型

```
Sampler (单一定时器, .utility QoS, 1~2s)
    │ 后台采集
    ▼
SystemMonitor (actor) ──▶ CPU/Mem/Net Provider ──▶ Sample (Sendable)
    │ 切回主线程
    ▼
StatusBarManager (@MainActor)
    ├──▶ Formatter ──按 AppSettings──▶ String[]
    ├──▶ StatusBarContentView.setNeedsDisplay (仅在变化时)
    └──▶ MenuSectionView（菜单打开时读取最新 Sample）
```

并发约定（Swift 6 strict concurrency）：
- `Sample` 为 `struct: Sendable`，值类型快照。
- `SystemMonitor` 为 `actor`，串行化采集与上一次状态。
- `Sampler` 在 `.utility` 优先级的串行队列跑采集；结果 hop 到 `@MainActor` 更新 UI。
- UI 对象（`NSStatusItem`、`NSView`、`NSMenu`）一律 `@MainActor`。
- `AppSettings` 变更通过 `Combine`/回调通知 `Formatter` 与 `StatusBarManager` 刷新。

### 6.4 稳定性与性能要点（核心）

1. **单一采样定时器**：三类指标共用，避免多定时器频繁唤醒；非前台时降到 2–5s。
2. **单调时钟计时**：`clock_gettime(CLOCK_MONOTONIC)`，避免系统休眠大 Δ；检测到 Δ 异常（如 > 10s）则丢弃本次差值。
3. **睡眠/唤醒**：监听 `NSWorkspace.didWakeNotification`，唤醒后丢弃下一次采样，重置 Provider 缓存。
4. **零泄漏**：
   - `getifaddrs` → `freeifaddrs`；
   - `host_processor_info` 返回的指针 → `vm_deallocate`；
   - 所有路径用 `defer` 兜底。
5. **渲染节流**：状态栏 `NSView` 仅在 `Sample` 实际变化时 `setNeedsDisplay`；菜单非打开态不刷新视图。
6. **接口热插拔**：网卡消失时丢弃其缓存计数，再现时重新基线；全程不崩溃。
7. **回绕保护**：网络计数回落判定为接口重置，丢弃本次 Δ。

### 6.5 渐进增强：可用性分级

| 特性 | macOS 14–25 | macOS 26+ |
|------|-------------|-----------|
| 状态栏 / 菜单监控 | ✅ 标准 | ✅ 液态玻璃 |
| 设置窗口材质 | `.ultraThinMaterial` | `.glassEffect()` |
| `SMAppService` 自启动 | ✅（13+） | ✅ |
| 全部采集 API | ✅ | ✅ |

> 代码模式：`if #available(macOS 26.0, *) { view.glassEffect(...) } else { view.background(.ultraThinMaterial) }`，集中封装在 `GlassMaterial`，避免散落。

---

## 7. 非功能性需求

### 7.1 性能预算
- 内存（RSS）稳态 < 40 MB；CPU 空闲 < 1% / 采样 < 2%；冷启动到图标出现 < 1s。
- 24h Energy Impact 评级「低」，无频繁唤醒。

### 7.2 稳定性
- 24h 内存增长 < 5 MB；睡眠/唤醒、网络切换、外接显示器热插拔后正常。
- 异常接口降级显示，不崩溃。

### 7.3 兼容性
- macOS 14.0+ 全量；26+ 启用液态玻璃；27 发布后回归。

### 7.4 权限与隐私
- 仅读取本地统计，**不收集、不上传**；首发无网络权限；无内购。

### 7.5 可访问性
- 状态栏文本支持系统「加大文本」；深/浅色自动；对比度满足 WCAG AA。
- 本地化：**简体中文优先，英文回退**（菜单栏中文占位更宽，紧凑模式需验证）。

---

## 8. UI / UX 设计

### 8.1 状态栏外观（示意）

```
┌─────────────────────────────────────────────┐
│ …  ↓5.2 ↑0.3  ·  12.4G  ·  38%        🔋 ⌘ │
└─────────────────────────────────────────────┘
       └────────── 我们的监控项 ──────────┘
```
- 默认：`↓5.2 ↑0.3 · 12.4G · 38%`
- 可调：箭头显隐、单位、顺序、项数、紧凑模式（刘海机宽度受限时启用）。

### 8.2 菜单详情：见 §5.3。

### 8.3 设置窗口（示意）

```
╭─────────────────────────────────────────────╮
│ 通用  │  刷新间隔： [ 1s ▾ ]                  │
│ 网络  │  开机自启动： [ ● ]                    │
│ 内存  │  外观：       [ 跟随系统 ▾ ]           │
│ CPU   │                                          │
│ 显示  │                                          │
╰─────────────────────────────────────────────╯
```

---

## 9. 里程碑

| 阶段 | 内容 | 产出 |
|------|------|------|
| **M0：PRD** | 需求定稿（本文） | PRD v1.0 ✅ |
| **M1：骨架** | Xcode 工程、`NSStatusItem` 占位、SMAppService、唤醒监听 | 状态栏显示静态文字 |
| **M2：采集核心** | 三 Provider + Sampler + Sample + 防泄漏 + 单测 | 数据准确 |
| **M3：状态栏显示** | `StatusBarContentView` + Formatter，三项实时显示 | 状态栏实时刷新 |
| **M4：设置界面** | SwiftUI 设置窗口 + `@AppStorage` 联动 | 全部设置可用 |
| **M5：菜单详情 + 玻璃** | `NSMenu` 区块视图 + 液态玻璃适配 | 完整交互 |
| **M6：性能与稳定性** | 内存/CPU/电量压测、24h 老化、唤醒/切换回归 | 达成性能预算 |
| **M7：打磨与发布** | 图标、可访问性、本地化、DMG + 公证（Notarize） | 可分发 v1.0 |

---

## 10. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| Mach 指针未释放 → 24h 泄漏 | 内存上涨 | 封装 + `defer` + 单测；自动化老化测试（Instruments Allocations） |
| 睡眠唤醒后速率尖峰 | 数据失真 | 单调时钟 + 唤醒通知 + 异常 Δ 丢弃 |
| macOS 27 API 变更 | 兼容性 | 仅依赖稳定 Mach/C API；新特性做版本判断；27 发布即回归 |
| 刘海机状态栏宽度不足 | 文字被截断 | 紧凑模式 / 自适应缩短 / 动态宽度 |
| 内存口径与活动监视器细微差异 | 用户困惑 | M6 校准；口径在文档与 tooltip 说明 |
| 公证/签名配置错误 | 无法分发 | M7 流水线化 `codesign → notarytool → staple`，提前验证 |

---

## 11. 开放议题（仍可讨论，非阻塞）

1. 是否需要「窗口模式」详情面板（独立 `NSPanel`，留更多空间给未来的图表）？—— 现阶段菜单足够，暂不做。
2. 自动更新是否首发集成 Sparkle？—— 倾向 v1.1，避免首发引入三方依赖。
3. 监控接口「手动勾选」时的默认候选清单（仅 `en*`，还是包含 `utun*`/`bridge*`）？—— M2 实现时定。

---

## 附录 A：关键 API 与参考实现（草案，实现时细化）

### A.1 网络（getifaddrs）
```swift
func networkBytes() -> (in: UInt64, out: UInt64) {
    var first: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&first) == 0, let head = first else { return (0, 0) }
    defer { freeifaddrs(first) }
    var bin: UInt64 = 0, bout: UInt64 = 0
    var cur: UnsafeMutablePointer<ifaddrs>? = head
    while let p = cur {
        let a = p.pointee
        if a.ifa_addr?.pointee.sa_family == sa_family_t(AF_LINK),
           let data = a.ifa_data,
           Self.isPhysicalAndUp(a) {              // 排除 lo0 / down
            let ifd = data.load(as: if_data.self)
            bin  &+= UInt64(ifd.ifi_ibytes)
            bout &+= UInt64(ifd.ifi_obytes)
        }
        cur = a.ifa_next
    }
    return (bin, bout)   // 与上次累计值求差 → 除以单调时钟 Δ → 速率
}
```

### A.2 内存（host_statistics64）
```swift
func memoryUsage() -> (used: UInt64, total: UInt64) {
    let total = ProcessInfo.processInfo.physicalMemory            // hw.memsize
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    let kaddr = mach_host_self()
    withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(kaddr, HOST_VM_INFO64, host_info64_t($0), &count)
        }
    }
    let ps = UInt64(vm_kernel_page_size)
    let reclaimable = (UInt64(stats.free_count) + UInt64(stats.inactive_count)) * ps
    return (used: total - reclaimable, total: total)
    // 明细：wire_count / compressor_page_count / active_count × ps
}
```

### A.3 CPU（host_processor_info）
```swift
func cpuTicksDelta() -> (busy: UInt64, total: UInt64) {
    var numCPU: natural_t = 0
    var cpuInfo: UnsafeMutablePointer<integer_t>?
    var numCPUInfo: mach_msg_type_number_t = 0
    let kaddr = mach_host_self()
    host_processor_info(kaddr, PROCESSOR_CPU_LOAD_INFO,
                        &numCPU, &cpuInfo, &numCPUInfo)
    defer { if let p = cpuInfo { vm_deallocate(mach_task_self_, p, vm_size_t(numCPUInfo) * MemoryLayout<integer_t>.size) } }
    var busy: UInt64 = 0, total: UInt64 = 0
    guard let info = cpuInfo else { return (0, 0) }
    let inUse = CPU_STATE_MAX                            // user/system/nice/idle
    for core in 0..<Int(numCPU) {
        let base = core * Int(CPU_STATE_MAX)
        let user = UInt64(info[base + Int(CPU_STATE_USER)])
        let sys   = UInt64(info[base + Int(CPU_STATE_SYSTEM)])
        let nice  = UInt64(info[base + Int(CPU_STATE_NICE)])
        let idle  = UInt64(info[base + Int(CPU_STATE_IDLE)])
        busy  &+= user &+ sys &+ nice
        total &+= user &+ sys &+ nice &+ idle
    }
    return (busy, total)   // 与上次求 Δ → busyΔ/totalΔ × 100 = 占用%
}
```

> 以上为草案伪代码，仅说明思路与资源管理要点；M2 实现时以单元测试与活动监视器对照校准。

### A.4 其他
- 单调时钟：`clock_gettime(CLOCK_MONOTONIC, ...)`
- 唤醒监听：`NSWorkspace.shared.notificationCenter` 的 `didWakeNotification`
- 自启动：`SMAppService.mainApp.register()`
- 状态栏：`NSStatusBar.system.statusItem(withLength: .variable)`
- 玻璃材质：`if #available(macOS 26.0, *) { .glassEffect() } else { .ultraThinMaterial }`

---

## 附录 B：术语

- **Liquid Glass / 液态玻璃**：macOS 26（Tahoe）引入的系统级材质，比传统毛玻璃更具折射与层次。
- **Mach API**：Darwin 内核用户态接口，读取 CPU/内存统计的最廉价路径。
- **RSS**：Resident Set Size，进程实际占用的物理内存，用于评估「轻量」。
- **SMAppService**：macOS 13+ 的登录项注册 API，替代已废弃的旧登录项方式。
