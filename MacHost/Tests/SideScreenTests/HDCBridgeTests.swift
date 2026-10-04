import XCTest
@testable import HarmonyScreen

final class HDCBridgeTests: XCTestCase {
    func testTargetsRejectErrorsAndNetworkEndpoints() {
        XCTAssertEqual(HDCBridge.parseTargets("[Empty]\r\n"), [])
        XCTAssertEqual(HDCBridge.parseTargets("[Fail] unauthorized\n"), [])
        XCTAssertEqual(HDCBridge.parseTargets("USB123\n192.168.1.2:8710\nUSB456\n"), ["USB123", "USB456"])
    }
    func testReverseMustMatchDeviceDirectionAndBothPorts() {
        XCTAssertTrue(HDCBridge.containsReverse("USB123 tcp:54322 tcp:54322 [Reverse]\n", device: "USB123", port: 54322))
        for s in ["OTHER tcp:54322 tcp:54322 [Reverse]", "USB123 tcp:54322 tcp:54322 [Forward]", "USB123 tcp:54322 tcp:54323 [Reverse]"] {
            XCTAssertFalse(HDCBridge.containsReverse(s, device: "USB123", port: 54322))
        }
    }
}
