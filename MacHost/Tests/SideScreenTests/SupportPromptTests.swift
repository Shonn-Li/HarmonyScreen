import XCTest
@testable import HarmonyScreen

final class SupportPromptTests: XCTestCase {
    private func qualify(_ policy: SupportPromptPolicy) {
        for second in 0...300 { policy.observeFrames(at: Double(second), connected: true, fps: 30) }
    }
    func testAsksAgainAfterEachQualifyingSessionButNeverTwiceForTheSameSession() {
        let policy = SupportPromptPolicy()
        policy.beginSession()
        qualify(policy)
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
        policy.endedSession()
        XCTAssertFalse(policy.takePresentation(configured: false, streaming: false, windowVisible: true, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: true, windowVisible: true, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: false, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: false))
        XCTAssertFalse(policy.hasPrompted)
        XCTAssertTrue(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))

        policy.beginSession()
        XCTAssertFalse(policy.hasPrompted)
        XCTAssertEqual(policy.usedSeconds, 0)
        qualify(policy)
        policy.endedSession()
        XCTAssertTrue(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))

        policy.beginSession()
        policy.observeFrames(at: 400, connected: true, fps: 30)
        policy.observeFrames(at: 401, connected: true, fps: 30)
        policy.endedSession()
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
    }
    func testSleepDisconnectedAndIdleTimeDoNotQualify() {
        let policy = SupportPromptPolicy()
        policy.beginSession()
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
    func testDisconnectAndAutomaticRebuildPreserveThisSessionsUse() {
        let policy = SupportPromptPolicy()
        policy.beginSession()
        for second in 0...150 { policy.observeFrames(at: Double(second), connected: true, fps: 30) }
        policy.pauseCounting()
        policy.observeFrames(at: 500, connected: true, fps: 30)
        XCTAssertEqual(policy.usedSeconds, 150)
        policy.endedSession()
        policy.beginSession(continuing: true)
        for second in 600...750 { policy.observeFrames(at: Double(second), connected: true, fps: 30) }
        policy.endedSession()
        XCTAssertTrue(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
    }
    func testManualPromptOnlyConsumesCurrentSessionAndRelaunchStartsFresh() {
        let policy = SupportPromptPolicy()
        policy.beginSession()
        qualify(policy)
        policy.markPresented()
        policy.endedSession()
        XCTAssertFalse(policy.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
        policy.beginSession(continuing: true)
        XCTAssertTrue(policy.hasPrompted)
        policy.endedSession()
        policy.beginSession()
        XCTAssertFalse(policy.hasPrompted)
        let relaunched = SupportPromptPolicy()
        relaunched.beginSession()
        qualify(relaunched)
        relaunched.endedSession()
        XCTAssertTrue(relaunched.takePresentation(configured: true, streaming: false, windowVisible: true, appActive: true))
    }
    func testCheckoutMustBeHttpsAndOneTime() {
        XCTAssertNil(SupportOffer(checkoutURL: "http://youwo.ai/support", paymentType: "one_time").url)
        XCTAssertNil(SupportOffer(checkoutURL: "https://youwo.ai/support", paymentType: "subscription").url)
        XCTAssertNil(SupportOffer(checkoutURL: "https://user:secret@youwo.ai/support", paymentType: "one_time").url)
        XCTAssertNotNil(SupportOffer(checkoutURL: "https://youwo.ai/support", paymentType: "one_time").url)
    }
}
