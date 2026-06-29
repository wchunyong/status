import ServiceManagement
import StatusCore

/// 开机自启动（SMAppService，macOS 13+）。
/// 注意：SMAppService.mainApp 需要签名的 .app bundle 才能真正生效；
/// 开发期（SPM 裸可执行）register 会抛错但不崩溃，发布签名后正常（D5/M7）。
@MainActor
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItem toggle failed: \(error.localizedDescription)")
        }
    }
}
