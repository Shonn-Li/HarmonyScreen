import Foundation

/// A failed automatic resize must not leave the host waiting in a modal dialog.
struct StreamRecoveryPolicy {
    private(set) var requested = false
    private(set) var retryAt: TimeInterval?
    private var failures = 0

    mutating func requestStart(continuing: Bool) {
        requested = true
        retryAt = nil
        if !continuing { failures = 0 }
    }
    mutating func started() { failures = 0; retryAt = nil }
    mutating func failed(at now: TimeInterval) {
        guard requested else { return }
        failures += 1
        retryAt = now + min(30, 3 * Double(failures))
    }
    mutating func stop() { requested = false; retryAt = nil; failures = 0 }
    func shouldRetry(at now: TimeInterval) -> Bool {
        requested && retryAt.map { now >= $0 } == true
    }
}
