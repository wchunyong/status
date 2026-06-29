import Foundation

/// 单一采样调度器（B3 节流 / B8 后台采集）。
///
/// 用一个 `DispatchSourceTimer`（`.utility` QoS + leeway）驱动 `SystemMonitor`，
/// 把 `Sample` 经 `@Sendable` handler 投递出去。handler 在后台队列被调用，
/// 消费方（AppKit 壳）需自行切回主线程更新 UI（B8）。
///
/// 线程约定：`start()` / `stop()` 必须从同一（通常为主）线程调用。
public final class Sampler: @unchecked Sendable {
    public typealias Handler = @Sendable (Sample) -> Void

    private let interval: TimeInterval
    private let monitor: SystemMonitor
    private let handler: Handler
    private var timer: DispatchSourceTimer?

    public init(interval: TimeInterval, monitor: SystemMonitor, handler: @escaping Handler) {
        self.interval = max(interval, 0.1)
        self.monitor = monitor
        self.handler = handler
    }

    public func start() {
        guard timer == nil else { return }
        let queue = DispatchQueue(label: "status.sampler", qos: .utility)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(500))
        timer.setEventHandler { [monitor, handler] in
            Task { await handler(monitor.sample()) }
        }
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }
}
