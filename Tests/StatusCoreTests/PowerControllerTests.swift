@testable import StatusCore
import XCTest

/// 测试电源控制功能（屏幕常亮）
final class PowerControllerTests: XCTestCase {
    func testPowerControllerInitialStateIsDisabled() {
        let controller = PowerController()
        XCTAssertFalse(controller.isEnabled)
    }

    func testPowerControllerToggle() {
        let controller = PowerController()

        XCTAssertFalse(controller.isEnabled)

        controller.toggle()
        XCTAssertTrue(controller.isEnabled)

        controller.toggle()
        XCTAssertFalse(controller.isEnabled)
    }

    func testPowerControllerSetEnabled() {
        let controller = PowerController()

        controller.setEnabled(true)
        XCTAssertTrue(controller.isEnabled)

        controller.setEnabled(false)
        XCTAssertFalse(controller.isEnabled)
    }
}
