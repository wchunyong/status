@testable import StatusCore
import XCTest

final class NetworkCountersTests: XCTestCase {
    func testRateBasic() {
        let prev = NetworkCounters(bytesIn: 1000, bytesOut: 500)
        let curr = NetworkCounters(bytesIn: 3000, bytesOut: 1500)
        guard let rate = NetworkMath.rate(prev: prev, curr: curr, intervalSeconds: 2.0) else {
            return XCTFail("expected non-nil rate")
        }
        XCTAssertEqual(rate.bytesPerSecondIn, 1000, accuracy: 1e-9) // (3000-1000)/2
        XCTAssertEqual(rate.bytesPerSecondOut, 500, accuracy: 1e-9) // (1500-500)/2
    }

    func testRateZeroIntervalReturnsNil() {
        let prev = NetworkCounters(bytesIn: 0, bytesOut: 0)
        let curr = NetworkCounters(bytesIn: 100, bytesOut: 100)
        XCTAssertNil(NetworkMath.rate(prev: prev, curr: curr, intervalSeconds: 0))
        XCTAssertNil(NetworkMath.rate(prev: prev, curr: curr, intervalSeconds: -1))
    }

    func testRateRolloverInReturnsNil() {
        // 入向回绕 → 整体丢弃（B4）
        let prev = NetworkCounters(bytesIn: 5000, bytesOut: 100)
        let curr = NetworkCounters(bytesIn: 100, bytesOut: 200)
        XCTAssertNil(NetworkMath.rate(prev: prev, curr: curr, intervalSeconds: 1))
    }

    func testRateRolloverOutReturnsNil() {
        let prev = NetworkCounters(bytesIn: 100, bytesOut: 5000)
        let curr = NetworkCounters(bytesIn: 200, bytesOut: 100)
        XCTAssertNil(NetworkMath.rate(prev: prev, curr: curr, intervalSeconds: 1))
    }

    func testRateEqualCountersIsZeroRate() {
        let prev = NetworkCounters(bytesIn: 1000, bytesOut: 1000)
        let curr = prev
        let rate = NetworkMath.rate(prev: prev, curr: curr, intervalSeconds: 1)
        XCTAssertEqual(rate?.bytesPerSecondIn, 0)
        XCTAssertEqual(rate?.bytesPerSecondOut, 0)
    }
}
