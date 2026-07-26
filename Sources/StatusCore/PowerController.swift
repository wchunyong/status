import Foundation
#if canImport(Darwin)
    import Darwin
#endif

/// 电源控制器：使用 caffeinate 命令防止屏幕睡眠。
///
/// B1 纪律贯穿此类型：
/// - **argv 字符串**：posix_spawn 只读 argv、不接管所有权；所有 `strdup` 的字符串
///   （含 argv[0]）在调用后一律 `free`，`defer` 兜底。
/// - **子进程句柄**：终止后用 `waitpid` 收尸，不残留僵尸进程；先 SIGTERM 礼貌退出，
///   超时再 SIGKILL 强杀并阻塞收尸。
/// - **spawn 失败**：不得谎报启用（`_isEnabled` 仅在真正起进程后置 true）。
public final class PowerController: @unchecked Sendable {
    /// 非阻塞收尸的轮询上限与间隔：20 × 10ms = 200ms 内 SIGTERM 未退出则强杀。
    private static let reapPollAttempts = 20
    private static let reapPollIntervalUs: useconds_t = 10000

    private let lock = NSLock()
    private let binaryPath: String
    private var _isEnabled = false
    private var caffeinatePID: pid_t?

    /// 当前是否已启用屏幕常亮
    public var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isEnabled
    }

    public init() {
        binaryPath = "/usr/bin/caffeinate"
    }

    /// 测试用注入点：可指定非默认二进制路径以验证 spawn 失败路径。
    init(binaryPath: String) {
        self.binaryPath = binaryPath
    }

    /// 测试观测点：当前子进程 pid（已回收后为 nil）。
    var _testCaffeinatePID: pid_t? {
        lock.lock()
        defer { lock.unlock() }
        return caffeinatePID
    }

    /// 设置启用/禁用屏幕常亮。
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if enabled {
            // P4：仅当成功起进程才置启用，失败保持禁用。
            _isEnabled = enableCaffeinate()
        } else {
            disableCaffeinate()
            _isEnabled = false
        }
    }

    /// 切换状态
    public func toggle() {
        setEnabled(!isEnabled)
    }

    /// 起一个 caffeinate -d 子进程。成功返回 true 并记录 pid。
    @discardableResult
    private func enableCaffeinate() -> Bool {
        disableCaffeinate() // 先清理上一个

        var pid: pid_t = 0
        // B1/P2：argv 字符串全部由本调用方拥有，posix_spawn 只读不释放 → 全部 free
        // （含 argv[0]；free(nil) 是 no-op）。用 defer 保证任意退出路径都不泄漏。
        var argv: [UnsafeMutablePointer<CChar>?] = [
            strdup(binaryPath),
            strdup("-d"),
            nil,
        ]
        defer { argv.forEach { free($0) } }

        let result = posix_spawn(&pid, binaryPath, nil, nil, &argv, environ)
        guard result == 0 else { return false }
        caffeinatePID = pid
        return true
    }

    private func disableCaffeinate() {
        guard let pid = caffeinatePID else { return }
        caffeinatePID = nil
        Self.terminate(pid)
    }

    /// 终止并回收子进程（B1）：SIGTERM → 轮询 waitpid(WNOHANG) → 超时 SIGKILL → 阻塞收尸。
    /// 静态方法：不触碰实例状态，可在 deinit 安全调用。
    private static func terminate(_ pid: pid_t) {
        var status: Int32 = 0
        kill(pid, SIGTERM)
        for _ in 0 ..< reapPollAttempts {
            let wp = waitpid(pid, &status, WNOHANG)
            if wp > 0 { return } // 子进程已退出并被本调用方回收
            if wp == -1, errno == ECHILD { return } // 子进程已被别处（如 init）回收，无需再管
            usleep(reapPollIntervalUs)
        }
        // 超时：尝试强杀；仅在进程确认存在时才发 SIGKILL，避免向不存在 PID 发信号。
        if waitpid(pid, nil, WNOHANG) == 0 {
            kill(pid, SIGKILL)
            waitpid(pid, &status, 0)
        }
    }

    deinit {
        // 对象析构时无并发；若仍有子进程则一并终止回收，避免泄漏到系统。
        if let pid = caffeinatePID {
            Self.terminate(pid)
        }
    }
}
