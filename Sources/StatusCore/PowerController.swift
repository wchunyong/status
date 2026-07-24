import Foundation

/// 电源控制器：使用 caffeinate 命令防止屏幕睡眠
///
/// 使用 caffeinate -d 防止屏幕进入睡眠状态。
/// 进程终止后自动恢复系统默认设置。
public final class PowerController: @unchecked Sendable {
    private let lock = NSLock()
    private var _isEnabled = false
    private var caffeinatePID: pid_t?

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

        var pid: pid_t = 0
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup("/usr/bin/caffeinate"),
            strdup("-d"),
            nil,
        ]
        let result = posix_spawn(&pid, "/usr/bin/caffeinate", nil, nil, &args, environ)
        args.dropFirst().forEach { free($0) }
        if result == 0 {
            caffeinatePID = pid
        }
    }

    private func disableCaffeinate() {
        if let pid = caffeinatePID {
            kill(pid, SIGTERM)
            caffeinatePID = nil
        }
    }

    deinit {
        setEnabled(false)
    }
}
