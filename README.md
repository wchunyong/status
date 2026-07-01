# Status

macOS 菜单栏轻量系统监控 —— 实时显示**网络上下行速率、内存占用、CPU 占用、Apple Silicon 风扇与温度**。原生 Swift，低占用、长时稳定，适配 macOS 26 液态玻璃（14+ 渐进增强）。

> 进度：**Phase 0–4 完成**（采集 + 状态栏 + 菜单详情 + 设置界面），**Phase 5 待人工**（签名/长跑/可视化 QA）。详见 [`docs/ROADMAP.md`](docs/ROADMAP.md)。

## 功能
- 状态栏常驻：`↓5.20 ↑0.32 MB/s · 12.4 / 24.0 GB · 38% · 49°C / 1400R`
- 点击图标弹菜单：网络/内存/CPU 明细 + 设置/退出
- 设置六 Tab：通用、网络、内存、CPU、风扇、显示（单位/格式/顺序/显隐/紧凑/外观/自启动/风扇转速）
- 风扇：仅 Apple Silicon 支持固定转速 / 恢复系统默认；Intel 自动禁用并提示

## 要求
- macOS 14.0+（开发机：macOS 26 Tahoe / Xcode 26.5 / Swift 6）
- 门禁工具：`brew install swiftlint swiftformat`

## 构建 / 测试 / 运行

```bash
swift build                       # 构建
swift test                        # 全部测试（55 用例）
./scripts/gate.sh                 # 完整门禁：swiftlint + swiftformat --lint + build + test

swift run Status                  # 直接运行（menu-bar-only）
# 或打成本地 .app：
./scripts/package.sh && open build/Status.app
```

## 架构

SwiftPM 双目标：

```
Sources/
├── StatusCore/          # 纯逻辑库（Swift 6，55 单测覆盖）
│   ├── Monitoring/      # CPU/Mem/Net/Fan 采集（Mach + sysctl + AppleSMC）+ Sampler + SystemMonitor(actor)
│   ├── Formatting/      # ByteRate/Byte/MemoryDisplay/Percent
│   └── Settings/        # StatusSettings + SettingsStore
└── Status/              # AppKit/SwiftUI 壳
    ├── StatusApp/AppDelegate     # @main + .accessory + 唤醒监听
    ├── StatusBarManager          # 状态栏 + NSMenu
    ├── SettingsView              # SwiftUI 五 Tab
    └── GlassMaterial             # macOS 26+ .glassEffect() / 回退
```

采集口径见 [`docs/PRD.md`](docs/PRD.md) §5.1；技术铁律（B1 零泄漏 / B2 口径 / B8 主线程 UI …）见 [`CLAUDE.md`](CLAUDE.md) §4。

## 文档
- [`CLAUDE.md`](CLAUDE.md) — agent 工作指南 + 技术铁律 B1–B8
- [`docs/PRD.md`](docs/PRD.md) — 产品规格
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — 技术栈 / 里程碑 / 任务 R-### / ADR D1–D6

## 路线图（Phase 5，待人工）
- **R-026** DMG + Developer ID 签名 + `notarytool` 公证 —— 需提供证书
- **R-021** 24h 内存老化 + Instruments —— 需挂机
- **R-023** 可访问性 / 刘海屏 —— 需可视化 QA
- **R-025** App 图标 —— 需设计稿
