import AppKit
import Combine
import StatusCore

/// 设置的可观察模型（SwiftUI 绑定用）。`@MainActor`，所有访问在主线程（B8）。
/// 改动经 `persist()` 写回 SettingsStore 并立即应用外观。
@MainActor
final class SettingsModel: ObservableObject {
    @Published var value: StatusSettings
    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        value = store.load()
        applyAppearance()
    }

    func reload() {
        value = store.load()
        applyAppearance()
    }

    func persist() {
        store.save(value)
        applyAppearance()
    }

    func applyAppearance() {
        switch value.appearance {
        case .system:
            NSApp?.appearance = nil
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
