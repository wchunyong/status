import AppKit
import Combine
import StatusCore

/// 设置的可观察模型（SwiftUI 绑定用）。`@MainActor`，所有访问在主线程（B8）。
///
/// 持久化是本模型的不变式：任何对 `value` 的变更（无论来自设置窗口、浮窗快捷控制，
/// 还是未来的其它入口）都经 `$value` 订阅立即写回 `SettingsStore`。此前仅
/// `SettingsView.onChange` 挂载时才持久化，从浮窗改「屏幕常亮」会丢失（P1）。
@MainActor
final class SettingsModel: ObservableObject {
    @Published var value: StatusSettings
    private let store: SettingsStore
    private var subscriptions = Set<AnyCancellable>()

    init(store: SettingsStore) {
        self.store = store
        value = store.load()
        applyAppearance()
        // P1：value 任一变更立即落盘 + 外观实时生效。
        // dropFirst 跳过 init 加载的首次发射；removeDuplicates 避免等值重复写回。
        $value
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newValue in self?.persist(newValue) }
            .store(in: &subscriptions)
    }

    func reload() {
        value = store.load()
        applyAppearance()
    }

    /// 显式持久化（保留给未走 `@Published` 的路径）。
    func persist() {
        persist(value)
    }

    private func persist(_ settings: StatusSettings) {
        store.save(settings)
        applyAppearance(settings)
    }

    func applyAppearance() {
        applyAppearance(value)
    }

    /// 参数化：`@Published` 在 willSet 发射，此时 `self.value` 可能尚未更新；
    /// 直接传入新值避免读到旧外观。
    private func applyAppearance(_ settings: StatusSettings) {
        switch settings.appearance {
        case .system:
            NSApp?.appearance = nil
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
