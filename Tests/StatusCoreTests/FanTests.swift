@testable import StatusCore
import XCTest

final class FanTests: XCTestCase {
    func testAppleSiliconSupportGatesByMachineArchitecture() {
        XCTAssertTrue(AppleSiliconSupport.isSupported(machine: "arm64"))
        XCTAssertFalse(AppleSiliconSupport.isSupported(machine: "x86_64"))
    }

    func testFanRPMPolicyClampsToSafeRange() {
        XCTAssertEqual(FanRPMPolicy.clamp(800), 1200)
        XCTAssertEqual(FanRPMPolicy.clamp(2400), 2400)
        XCTAssertEqual(FanRPMPolicy.clamp(9000), 6500)
    }

    func testFanTemperaturePolicyRejectsZeroReadings() {
        XCTAssertFalse(FanTemperaturePolicy.isPlausible(0))
        XCTAssertFalse(FanTemperaturePolicy.isPlausible(4.9))
        XCTAssertTrue(FanTemperaturePolicy.isPlausible(50))
        XCTAssertFalse(FanTemperaturePolicy.isPlausible(130))
    }

    #if canImport(IOKit)
        func testSMCStructLayoutMatchesAppleSMCABI() {
            XCTAssertEqual(SMCLayout.keyInfoStride, 12)
            XCTAssertEqual(SMCLayout.paramStructStride, 80)
        }
    #endif

    func testFanControllerAppliesFixedRPMOnceAndRestoresSystemMode() {
        let driver = FakeFanDriver(status: FanStatus(
            averageTemperatureCelsius: 49,
            fanRPM: 1400,
            isSupported: true,
            unavailableReason: nil
        ))
        let controller = FanController(driver: driver)

        var settings = StatusSettings()
        settings.fanControlMode = .fixedRPM
        settings.fanFixedRPM = 2400

        let fixedStatus = controller.sample(settings: settings)
        _ = controller.sample(settings: settings)
        XCTAssertEqual(driver.fixedRPMCalls, [2400])
        XCTAssertEqual(fixedStatus.fanRPM, 2400)

        settings.fanControlMode = .system
        _ = controller.sample(settings: settings)
        XCTAssertEqual(driver.restoreCalls, 1)
    }

    func testFanControllerUsesFixedTargetWhenRealtimeRPMIsUnavailable() {
        let driver = FakeFanDriver(status: FanStatus(
            averageTemperatureCelsius: 49,
            fanRPM: 0,
            isSupported: true,
            unavailableReason: nil
        ))
        let controller = FanController(driver: driver)

        var settings = StatusSettings()
        settings.fanControlMode = .fixedRPM
        settings.fanFixedRPM = 2400

        let status = controller.sample(settings: settings)
        XCTAssertEqual(status.fanRPM, 2400)
    }

    func testFanControllerUsesFixedTargetWhenRealtimeRPMIsImplausible() {
        let driver = FakeFanDriver(status: FanStatus(
            averageTemperatureCelsius: 49,
            fanRPM: 16,
            isSupported: true,
            unavailableReason: nil
        ))
        let controller = FanController(driver: driver)

        var settings = StatusSettings()
        settings.fanControlMode = .fixedRPM
        settings.fanFixedRPM = 3000

        let status = controller.sample(settings: settings)
        XCTAssertEqual(status.fanRPM, 3000)
    }

    func testFanControllerReturnsUnsupportedStatusWithoutWriting() {
        let driver = FakeFanDriver(status: FanStatus.unsupported("仅支持 Apple Silicon Mac"))
        let controller = FanController(driver: driver)

        var settings = StatusSettings()
        settings.fanControlMode = .fixedRPM
        settings.fanFixedRPM = 2400

        let status = controller.sample(settings: settings)
        XCTAssertFalse(status.isSupported)
        XCTAssertEqual(status.unavailableReason, "仅支持 Apple Silicon Mac")
        XCTAssertTrue(driver.fixedRPMCalls.isEmpty)
        XCTAssertEqual(driver.restoreCalls, 0)
    }
}

private final class FakeFanDriver: FanDriver, @unchecked Sendable {
    private let status: FanStatus
    var fixedRPMCalls: [Int] = []
    var restoreCalls = 0

    init(status: FanStatus) {
        self.status = status
    }

    func readStatus() -> FanStatus {
        status
    }

    func setFixedRPM(_ rpm: Int) -> Bool {
        fixedRPMCalls.append(rpm)
        return true
    }

    func restoreAutomatic() -> Bool {
        restoreCalls += 1
        return true
    }
}
