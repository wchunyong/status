@testable import StatusCore
import XCTest

final class MonotonicClockTests: XCTestCase {
    func testShouldDiscardAtBoundaries() {
        XCTAssertFalse(DeltaDecision.shouldDiscard(intervalSeconds: 1))
        XCTAssertFalse(DeltaDecision.shouldDiscard(intervalSeconds: 5))
        XCTAssertFalse(DeltaDecision.shouldDiscard(intervalSeconds: 10)) // == 阈值不丢弃
        XCTAssertTrue(DeltaDecision.shouldDiscard(intervalSeconds: 10.0001)) // 超过阈值丢弃
        XCTAssertTrue(DeltaDecision.shouldDiscard(intervalSeconds: 0)) // 0 丢弃
        XCTAssertTrue(DeltaDecision.shouldDiscard(intervalSeconds: -3)) // 负丢弃
    }

    func testCustomThreshold() {
        XCTAssertFalse(DeltaDecision.shouldDiscard(intervalSeconds: 3, threshold: 5))
        XCTAssertTrue(DeltaDecision.shouldDiscard(intervalSeconds: 6, threshold: 5))
    }

    func testMonotonicNowIsNonDecreasing() {
        let a = MonotonicClock.nowSeconds()
        let b = MonotonicClock.nowSeconds()
        XCTAssertGreaterThanOrEqual(b, a)
    }

    func testElapsedIsNonNegative() {
        let earlier = MonotonicClock.nowSeconds()
        let elapsed = MonotonicClock.elapsed(since: earlier + 1000) // 给一个「未来」点
        XCTAssertGreaterThanOrEqual(elapsed, 0)
    }
}
