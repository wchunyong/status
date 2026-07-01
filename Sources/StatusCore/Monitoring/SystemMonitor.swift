import Foundation

/// 统一采集调度，持有各 Provider 的上一次基线，产出可显示的 `Sample`。
///
/// 设计为 `actor`（B8）：采样与基线状态串行化，跨线程安全。
/// 口径见 B2，睡眠/唤醒边界见 B4，单调时钟见 B5。
public actor SystemMonitor {
    private var prevCPUTicks: [CPUTicks]?
    private var prevNetwork: NetworkCounters?
    private var prevMonotonic: Double?
    private var settings = StatusSettings()
    private let fanController: FanController

    public init(fanController: FanController = FanController(driver: SMCFanDriver.makeDefault())) {
        self.fanController = fanController
    }

    /// 采集一次，返回显示快照。
    /// 首次调用只建立基线：CPU 返回 0，网络返回 0 速率（无前值可做差）。
    public func sample() -> Sample {
        let now = MonotonicClock.nowSeconds()

        // CPU
        let ticks = CPUSnapshotReader.read() ?? []
        let prevTicks = prevCPUTicks ?? ticks // 首次用自身做基线 → delta 0
        let cpuFraction = CPUUsage.fraction(prev: prevTicks, curr: ticks)
        prevCPUTicks = ticks

        // 内存
        let memory = MemorySnapshotReader.read() ?? .zero

        // 网络
        let network = NetworkSnapshotReader.read()
        var rate = NetworkRate(bytesPerSecondIn: 0, bytesPerSecondOut: 0)
        if let prevNet = prevNetwork, let prevTime = prevMonotonic {
            let interval = now - prevTime
            if !DeltaDecision.shouldDiscard(intervalSeconds: interval),
               let computed = NetworkMath.rate(prev: prevNet, curr: network, intervalSeconds: interval)
            {
                rate = computed
            }
        }
        prevNetwork = network
        prevMonotonic = now

        let fanStatus = fanController.sample(settings: settings)

        return Sample(cpuFraction: cpuFraction, memory: memory, networkRate: rate, fanStatus: fanStatus)
    }

    public func updateSettings(_ settings: StatusSettings) {
        self.settings = settings
    }

    public func restoreFanAutomatic() {
        fanController.restoreAutomatic()
    }

    /// 睡眠唤醒后重置基线（B4）：丢弃下一次差值，避免速率尖峰。
    public func resetAfterWake() {
        prevCPUTicks = nil
        prevNetwork = nil
        prevMonotonic = nil
    }
}
