import XCTest
@testable import HarmonyScreen

final class StreamRecoveryTests: XCTestCase {
    func testFailedResizeRetriesWithoutAnotherUserStart() {
        var policy = StreamRecoveryPolicy()
        policy.requestStart(continuing: false)
        policy.started()
        policy.requestStart(continuing: true)
        policy.failed(at: 100)
        XCTAssertFalse(policy.shouldRetry(at: 102))
        XCTAssertTrue(policy.shouldRetry(at: 103))
        policy.requestStart(continuing: true)
        XCTAssertFalse(policy.shouldRetry(at: 103))
        policy.failed(at: 104)
        XCTAssertFalse(policy.shouldRetry(at: 109))
        XCTAssertTrue(policy.shouldRetry(at: 110))
        policy.requestStart(continuing: true)
        policy.started()
        XCTAssertFalse(policy.shouldRetry(at: 1000))
    }
    func testStopCancelsRecoveryEvenIfAnInFlightStartFailsLater() {
        var policy = StreamRecoveryPolicy()
        policy.requestStart(continuing: false)
        policy.failed(at: 0)
        policy.stop()
        policy.failed(at: 10)
        XCTAssertFalse(policy.requested)
        XCTAssertFalse(policy.shouldRetry(at: 1000))
    }
    func testLongFailureBackoffIsCappedAndManualStartResetsIt() {
        var policy = StreamRecoveryPolicy()
        for _ in 0..<20 {
            policy.requestStart(continuing: true)
            policy.failed(at: 100)
        }
        XCTAssertEqual(policy.retryAt, 130)
        policy.requestStart(continuing: false)
        policy.failed(at: 200)
        XCTAssertEqual(policy.retryAt, 203)
    }
}
