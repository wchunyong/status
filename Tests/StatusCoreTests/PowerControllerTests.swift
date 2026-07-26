import Darwin
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

    /// B1/P3：禁用后子进程必须被回收，不得残留僵尸。
    /// 修复前无人 waitpid → 子进程变僵尸 → 这里的 waitpid 会返回 pid（由测试自己收尸）→ 失败。
    /// 修复后 controller 同步收尸 → 这里的 waitpid 返回 -1（ECHILD）→ 通过。
    func testSetEnabledFalseReapsChildNoZombie() {
        let controller = PowerController()
        controller.setEnabled(true)
        let pid = controller._testCaffeinatePID ?? 0
        XCTAssertGreaterThan(pid, 0)

        controller.setEnabled(false)
        XCTAssertNil(controller._testCaffeinatePID)

        var status: Int32 = 0
        let result = waitpid(pid, &status, WNOHANG)
        XCTAssertEqual(result, -1, "禁用后子进程应已被 controller 回收，不得残留为僵尸")
    }

    /// P4：posix_spawn 失败时不得谎报启用。
    func testSpawnFailureLeavesDisabled() {
        let controller = PowerController(binaryPath: "/usr/bin/status-test-nonexistent-binary")
        controller.setEnabled(true)
        XCTAssertFalse(controller.isEnabled, "spawn 失败时应保持禁用")
        XCTAssertNil(controller._testCaffeinatePID)
    }
}
