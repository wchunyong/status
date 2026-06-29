import AppKit

/// 程序化 AppKit 入口。`@MainActor` 满足 Swift 6 下对 NSApplication（MainActor）的访问。
/// `setActivationPolicy(.accessory)` 实现 menu-bar-only（不进 Dock），运行期等价 LSUIElement。
@main
struct StatusApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
