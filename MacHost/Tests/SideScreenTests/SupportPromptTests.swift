import XCTest
@testable import HarmonyScreen

final class SupportPromptTests: XCTestCase {
    private func policy() -> (SupportPromptPolicy, UserDefaults, String) {
        let name = "HarmonyScreenSupportTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        return (SupportPromptPolicy(defaults: defaults), defaults, name)
    }
    private func qualify(_ policy: SupportPromptPolicy) {
        for second in 0...300 { policy.observeFrames(at: Double(second), connected: true, fps: 30) }
    }
    func testOnlyOnceAfterUsefulSessionAndExplicitCheckout() {
        let (policy, defaults, name) = policy(); defer { defaults.removePersistentDomain(forName: name) }
        qualify(policy)
        XCTAssertFalse(policy.takePresentation(configured: false, streaming: false, windowVisible: true, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: true, windowVisible: true, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: false, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: false))
        XCTAssertFalse(policy.hasPrompted)
        XCTAssertTrue(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
        let restarted = SupportPromptPolicy(defaults: defaults)
        XCTAssertFalse(restarted.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
    }
    func testSleepDisconnectedAndIdleTimeDoNotQualify() {
        let (policy, defaults, name) = policy(); defer { defaults.removePersistentDomain(forName: name) }
        policy.observeFrames(at: 0, connected: true, fps: 30)
        policy.observeFrames(at: 1000, connected: true, fps: 30)
        policy.observeFrames(at: 1001, connected: false, fps: 30)
        policy.observeFrames(at: 1002, connected: true, fps: 0)
        policy.observeFrames(at: 1003, connected: true, fps: 30)
        XCTAssertEqual(policy.usedSeconds, 0)
        policy.observeFrames(at: 1004, connected: true, fps: 30)
        XCTAssertEqual(policy.usedSeconds, 1)
        policy.endedSession()
        policy.observeFrames(at: 1005, connected: true, fps: 30)
        XCTAssertEqual(policy.usedSeconds, 1)
    }
    func testCheckoutMustBeHttpsAndOneTime() {
        XCTAssertNil(SupportOffer(checkoutURL: "http://youwo.ai/support", paymentType: "one_time").url)
        XCTAssertNil(SupportOffer(checkoutURL: "https://youwo.ai/support", paymentType: "subscription").url)
        XCTAssertNil(SupportOffer(checkoutURL: "https://user:secret@youwo.ai/support", paymentType: "one_time").url)
        XCTAssertNotNil(SupportOffer(checkoutURL: "https://youwo.ai/support", paymentType: "one_time").url)
    }
}
