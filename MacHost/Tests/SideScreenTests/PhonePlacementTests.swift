import Foundation
import Network
import XCTest
@testable import HarmonyScreen

final class PhonePlacementTests: XCTestCase {
    func testAllPositionsRoundTripAndRejectInvalidPayloads() {
        for side in PhonePlacement.sides {
            for alignment in PhonePlacement.alignments {
                let value = PhonePlacement(side: side, alignment: alignment)
                XCTAssertEqual(PhonePlacement.decode(value.payload), value)
            }
        }
        for payload: [UInt8] in [[], [0x80], [0,1], [0x84,0x80], [0x80,0x83], [0xff,0xff]] {
            XCTAssertNil(PhonePlacement.decode(payload))
        }
    }

    func testFragmentedRequestAndQueryPreserveFollowingHeartbeat() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        var current = PhonePlacement(side: "right", alignment: "center")
        server.onPhonePlacement = { value in
            if let value { current = value }
            server.sendPhonePlacement(current)
        }
        try await server.start()
        let client = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: try XCTUnwrap(server.boundPort))!, using: .tcp)
        client.start(queue: DispatchQueue(label: "PhonePlacementTests.client"))
        defer { client.cancel() }
        let initial = try await receive(client, size: 13)
        XCTAssertEqual(initial.first, 1) // No placement response without opt-in.
        client.send(content: Data([16,0xff,0xff]), completion: .idempotent)
        let query = try await receive(client,size: 3)
        XCTAssertEqual(Array(query),[17,0x81,0x81])
        client.send(content: Data([16,0x80]), completion: .idempotent)
        // Last request byte coalesced with a complete heartbeat.
        client.send(content: Data([0x82,4,1,2,3,4,5,6,7,8]), completion: .idempotent)
        let replies = Array(try await receive(client,size: 12))
        // Pong can precede the asynchronously sent placement state.
        XCTAssertTrue(replies == [5,1,2,3,4,5,6,7,8,17,0x80,0x82] ||
                      replies == [17,0x80,0x82,5,1,2,3,4,5,6,7,8])
    }

    private func receive(_ client: NWConnection, size: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let timeout = DispatchWorkItem { client.cancel() }
            DispatchQueue.global().asyncAfter(deadline: .now()+3, execute: timeout)
            client.receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, error in
                timeout.cancel()
                if let error { continuation.resume(throwing: error) }
                else if let data, data.count == size { continuation.resume(returning: data) }
                else { continuation.resume(throwing: NSError(domain: "incomplete response", code: 1)) }
            }
        }
    }
}
