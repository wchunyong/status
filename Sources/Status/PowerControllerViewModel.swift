import Combine
import Foundation
import StatusCore

/// PowerController 的 SwiftUI ViewModel 封装，通过 SettingsModel 持久化状态
@MainActor
final class PowerControllerViewModel: ObservableObject {
    private let controller = PowerController()
    private let settings: SettingsModel

    /// 屏幕常亮是否已激活
    @Published private(set) var isScreenAlwaysOnActive: Bool = false

    init(settings: SettingsModel) {
        self.settings = settings
        // 从持久化设置恢复状态
        let savedState = settings.value.screenAlwaysOn
        if savedState {
            controller.setEnabled(true)
        }
        updateState()
    }

    /// 切换屏幕常亮状态
    func toggleScreenAlwaysOn() {
        let newState = !isScreenAlwaysOnActive
        controller.setEnabled(newState)
        // 持久化到设置
        settings.value.screenAlwaysOn = newState
        updateState()
    }

    private func updateState() {
        isScreenAlwaysOnActive = controller.isEnabled
    }
}
