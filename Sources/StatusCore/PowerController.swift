import Foundation

/// 电源控制器：使用 caffeinate 命令防止屏幕睡眠
///
/// 使用 caffeinate -d 防止屏幕进入睡眠状态。
/// 进程终止后自动恢复系统默认设置。
public final class PowerController: @unchecked Sendable {
    private let lock = NSLock()
    private var _isEnabled = false
    private var process: Process?

    /// 当前是否已启用屏幕常亮
    public var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isEnabled
    }

    public init() {}

    /// 设置启用/禁用屏幕常亮
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if enabled {
            enableCaffeinate()
            _isEnabled = true
        } else {
            disableCaffeinate()
            _isEnabled = false
        }
    }

    /// 切换状态
    public func toggle() {
        setEnabled(!isEnabled)
    }

    private func enableCaffeinate() {
        disableCaffeinate()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-d"]
        process.qualityOfService = .userInitiated

        do {
            try process.run()
            self.process = process
        } catch {
            print("[PowerController] Failed to start caffeinate: \(error)")
        }
    }

    private func disableCaffeinate() {
        if let process = process {
            if process.isRunning {
                process.terminate()
            }
            self.process = nil
        }

        // 也尝试终止任何剩余的 caffeinate -d 进程
        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killer.arguments = ["-f", "caffeinate.*-d"]
        killer.qualityOfService = .utility
        try? killer.run()
    }

    deinit {
        setEnabled(false)
    }
}
