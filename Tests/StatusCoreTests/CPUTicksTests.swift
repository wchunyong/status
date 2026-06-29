@testable import StatusCore
import XCTest

final class CPUTicksTests: XCTestCase {
    private func ticks(_ u: UInt64, _ s: UInt64, _ n: UInt64, _ i: UInt64) -> CPUTicks {
        CPUTicks(user: u, system: s, nice: n, idle: i)
    }

    func testBusyAndTotal() {
        let t = ticks(100, 50, 10, 40)
        XCTAssertEqual(t.busy, 160) // 100+50+10
        XCTAssertEqual(t.total, 200) // 160+40
    }

    func testFractionSingleCore60Percent() {
        // busy 100→250 (+150), total 250→500 (+250) → 0.6
        let prev = [ticks(100, 0, 0, 150)]
        let curr = [ticks(200, 50, 0, 250)]
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 0.6, accuracy: 1e-9)
        XCTAssertEqual(CPUUsage.percent(prev: prev, curr: curr), 60, accuracy: 1e-7)
    }

    func testFractionFullWhenIdleDoesNotAdvance() {
        // busy 推进、idle 不动 → 100%
        let prev = [ticks(100, 0, 0, 100)]
        let curr = [ticks(200, 50, 0, 100)]
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 1.0, accuracy: 1e-9)
    }

    func testFractionZeroWhenNoProgress() {
        let prev = [ticks(100, 50, 0, 100)]
        let curr = prev // 完全没变 → totalDelta 0
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 0)
    }

    func testFractionMultiCoreAggregation() {
        // core0 busy 100→110, total 100→110；core1 busy 0→0, total 100→200
        // busyDelta=10, totalDelta=110 → 0.0909...
        let prev = [ticks(100, 0, 0, 0), ticks(0, 0, 0, 100)]
        let curr = [ticks(110, 0, 0, 0), ticks(0, 0, 0, 200)]
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 10.0 / 110.0, accuracy: 1e-9)
    }

    func testMismatchedCoreCountReturnsZero() {
        let prev = [ticks(1, 0, 0, 0)]
        let curr = [ticks(2, 0, 0, 0), ticks(0, 0, 0, 1)]
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 0)
    }

    func testEmptyReturnsZero() {
        XCTAssertEqual(CPUUsage.fraction(prev: [], curr: []), 0)
    }

    func testCounterResetDoesNotOverflow() {
        // 核心计数回退（curr<prev）→ 该核 delta 记 0，totalDelta 也 0 → 返回 0，不溢出崩溃（B1）
        let prev = [ticks(200, 100, 0, 200)] // busy 300, total 500
        let curr = [ticks(100, 50, 0, 100)] // busy 150, total 250 (回退)
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 0)
    }

    func testPartialResetAcrossCores() {
        // core0 正常推进，core1 回退（只计 core0）
        // core0 busy 100→200 (+100), total 100→300 (+200)；core1 全 0 delta
        // busyDelta=100, totalDelta=200 → 0.5
        let prev = [ticks(100, 0, 0, 0), ticks(500, 0, 0, 500)]
        let curr = [ticks(200, 0, 0, 100), ticks(100, 0, 0, 100)]
        XCTAssertEqual(CPUUsage.fraction(prev: prev, curr: curr), 0.5, accuracy: 1e-9)
    }
}
