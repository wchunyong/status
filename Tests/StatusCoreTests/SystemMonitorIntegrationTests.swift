import Darwin
@testable import StatusCore
import XCTest

/// 集成测试：触及真实系统采集（Mach / sysctl）。
/// 这类测试验证「不崩溃 + 数值合理」，是 B1 防泄漏的冒烟回归；
/// 真正的 24h 内存增量测量见 ROADMAP R-021（Instruments Allocations）。
final class SystemMonitorIntegrationTests: XCTestCase {
    func testReadersReturnPlausibleValues() {
        guard let mem = MemorySnapshotReader.read() else {
            return XCTFail("memory reader returned nil")
        }
        XCTAssertGreaterThan(mem.totalBytes, 0)
        XCTAssertEqual(mem.pageSize, UInt64(getpagesize()))

        let net1 = NetworkSnapshotReader.read()
        let net2 = NetworkSnapshotReader.read()
        // 累计计数单调不减（64 位计数，除非接口重置）
        XCTAssertGreaterThanOrEqual(net2.bytesIn, net1.bytesIn)
        XCTAssertGreaterThanOrEqual(net2.bytesOut, net1.bytesOut)

        guard let cpu = CPUSnapshotReader.read() else {
            return XCTFail("cpu reader returned nil")
        }
        XCTAssertGreaterThan(cpu.count, 0)
    }

    func testFirstSampleHasZeroRates() async {
        let monitor = SystemMonitor()
        let first = await monitor.sample()
        XCTAssertEqual(first.cpuFraction, 0) // 首次用自身做基线 → delta 0
        XCTAssertEqual(first.networkRate.bytesPerSecondIn, 0)
        XCTAssertEqual(first.networkRate.bytesPerSecondOut, 0)
    }

    func testRepeatedSamplingIsCrashFree() async {
        let monitor = SystemMonitor()
        for _ in 0 ..< 40 {
            _ = await monitor.sample()
        }
        XCTAssertTrue(true) // 走到这里即未崩溃（B1 冒烟）
    }

    func testResetAfterWakeClearsBaseline() async {
        let monitor = SystemMonitor()
        _ = await monitor.sample()
        await monitor.resetAfterWake()
        let after = await monitor.sample() // 重置后等同「首次」
        XCTAssertEqual(after.networkRate.bytesPerSecondIn, 0)
        XCTAssertEqual(after.networkRate.bytesPerSecondOut, 0)
    }

    func testSecondSampleProducesRate() async {
        let monitor = SystemMonitor()
        _ = await monitor.sample()
        // 让单调时钟推进一点
        try? await Task.sleep(nanoseconds: 50_000_000)
        let second = await monitor.sample()
        // 第二次已有前值：cpuFraction 计算可达；速率结构存在（值可能为 0 但不再走 nil 分支）
        XCTAssertGreaterThanOrEqual(second.cpuFraction, 0)
        XCTAssertLessThanOrEqual(second.cpuFraction, 1)
    }
}
