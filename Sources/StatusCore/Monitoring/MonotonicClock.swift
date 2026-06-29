import Foundation
#if canImport(Darwin)
    import Darwin
#endif

/// 采样间隔判定（B4 睡眠/唤醒边界）。
public enum DeltaDecision {
    /// 采样间隔异常阈值（秒）：超过则视为睡眠/挂起，丢弃差值。
    public static let abnormalThresholdSeconds: Double = 10.0

    /// 判断两次采样间的真实间隔是否应丢弃差值（B4）。
    public static func shouldDiscard(intervalSeconds: Double,
                                     threshold: Double = abnormalThresholdSeconds) -> Bool
    {
        intervalSeconds <= 0 || intervalSeconds > threshold
    }
}

/// 单调时钟封装。B5：所有间隔计算必须用 CLOCK_MONOTONIC，禁止墙钟。
public enum MonotonicClock {
    /// 当前单调时间（秒）。不受系统时间手动调整影响；系统休眠期间不推进。
    public static func nowSeconds() -> Double {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000
    }

    /// 距离 earlierSeconds 的真实流逝秒数，保底 0。
    public static func elapsed(since earlierSeconds: Double) -> Double {
        let now = nowSeconds()
        return now > earlierSeconds ? now - earlierSeconds : 0
    }
}
