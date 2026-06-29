// swift-tools-version: 6.0
//
// 构建系统决策见 docs/ROADMAP.md ADR D6：采用 Swift Package Manager。
// tools-version 6.0 → 默认 Swift 6 语言模式（strict concurrency）。
// per-target 语言模式 API 在本工具链不稳定，故不显式声明；B8 并发正确性
// 靠 @MainActor / actor / Sendable 在代码层保证（详见 CLAUDE.md §4 B8）。
import PackageDescription

let package = Package(
    name: "Status",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Status", targets: ["Status"]),
        .library(name: "StatusCore", targets: ["StatusCore"]),
    ],
    targets: [
        // 纯逻辑库：采集口径、格式化、设置模型。可被 swift test 完整覆盖。
        .target(name: "StatusCore"),
        // AppKit/SwiftUI 壳：状态栏、菜单、设置窗口。依赖 StatusCore。
        .executableTarget(name: "Status", dependencies: ["StatusCore"]),
        .testTarget(name: "StatusCoreTests", dependencies: ["StatusCore"]),
    ]
)
