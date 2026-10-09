import Foundation
import Network
import XCTest
@testable import HarmonyScreen

final class ClientDisplayLifecycleTests: XCTestCase {
    private final class Preparation {
        private let lock = NSLock()
        private var callbacks: [(Bool) -> Void] = []
        func append(_ callback: @escaping (Bool) -> Void) {
            lock.lock(); defer { lock.unlock() }
            callbacks.append(callback)
        }
        func finish(_ index: Int = 0, ready: Bool = true) {
            lock.lock()
            let callback = callbacks[index]
            lock.unlock()
            callback(ready)
        }
    }

    private func connect(to server: StreamingServer) throws -> NWConnection {
        let port = try XCTUnwrap(server.boundPort)
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        connection.start(queue: DispatchQueue(label: "ClientDisplayLifecycleTests.client"))
        return connection
    }

    func testConfigurationWaitsForDisplayAndPreparationRunsOnce() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        let prepared = expectation(description: "preparation requested exactly once")
        prepared.assertForOverFulfill = true
        let gate = Preparation()
        server.onPrepareStream = { _, finish in gate.append(finish); prepared.fulfill() }
        try await server.start()
        let client = try connect(to: server)
        defer { client.cancel() }
        // The capability message and legacy timeout both try protocol startup.
        client.send(content: Data([8]), completion: .idempotent)
        let premature = expectation(description: "no connected event before display is ready")
        premature.isInverted = true
        server.onClientConnected = { premature.fulfill() }
        await fulfillment(of: [prepared], timeout: 2)
        await fulfillment(of: [premature], timeout: 0.2)
        let connected = expectation(description: "client ready after display setup")
        server.onClientConnected = { connected.fulfill() }
        server.setDisplaySize(width: 720, height: 1280)
        gate.finish()
        let config = expectation(description: "correct display configuration")
        client.receive(minimumIncompleteLength: 13, maximumLength: 13) { data, _, _, error in
            XCTAssertNil(error)
            XCTAssertEqual(Array(data ?? Data()), [1, 0, 0, 2, 208, 0, 0, 5, 0, 0, 0, 0, 0])
            config.fulfill()
        }
        await fulfillment(of: [connected, config], timeout: 2)
    }

    func testPeerEOFNotifiesDisconnectAndKeepsListenerAvailable() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        let connected = expectation(description: "initial connection")
        server.onClientConnected = { connected.fulfill() }
        let disconnected = expectation(description: "EOF detected without another frame")
        disconnected.assertForOverFulfill = true
        server.onClientDisconnected = { disconnected.fulfill() }
        try await server.start()
        let client = try connect(to: server)
        defer { client.cancel() }
        await fulfillment(of: [connected], timeout: 2)
        // Half-close with FIN rather than cancel(): cancelling a client with
        // unread configuration can cause RST, which the old code already saw.
        client.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .idempotent)
        await fulfillment(of: [disconnected], timeout: 2)
        server.onClientDisconnected = nil
        XCTAssertNotNil(server.boundPort)
        let reconnected = expectation(description: "new client on same listener")
        server.onClientConnected = { reconnected.fulfill() }
        let second = try connect(to: server)
        defer { second.cancel() }
        await fulfillment(of: [reconnected], timeout: 2)
    }

    func testStoppingDuringPreparationCannotActivateClient() async throws {
        let server = StreamingServer(port: 0)
        let gate = Preparation()
        let preparing = expectation(description: "preparing display")
        server.onPrepareStream = { _, finish in gate.append(finish); preparing.fulfill() }
        let connected = expectation(description: "no activation after Stop")
        connected.isInverted = true
        server.onClientConnected = { connected.fulfill() }
        try await server.start()
        let client = try connect(to: server)
        defer { client.cancel() }
        await fulfillment(of: [preparing], timeout: 2)
        server.stop()
        gate.finish()
        await fulfillment(of: [connected], timeout: 0.2)
    }

    func testUSBDisappearanceClosesLocalClientAndAcceptsReconnect() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        let connected = expectation(description: "USB viewer connected")
        server.onClientConnected = { connected.fulfill() }
        try await server.start()
        let client = try connect(to: server)
        defer { client.cancel() }
        await fulfillment(of: [connected], timeout: 2)
        let disconnected = expectation(description: "USB disappearance ends still-open local socket")
        server.onClientDisconnected = { disconnected.fulfill() }
        server.disconnectUSBClient()
        await fulfillment(of: [disconnected], timeout: 2)
        server.onClientDisconnected = nil
        let reconnected = expectation(description: "listener survives USB loss")
        server.onClientConnected = { reconnected.fulfill() }
        let next = try connect(to: server)
        defer { next.cancel() }
        await fulfillment(of: [reconnected], timeout: 2)
    }

    func testFailedDisplayPreparationClosesClientButNotListener() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        server.onPrepareStream = { _, finish in finish(false) }
        let disconnected = expectation(description: "failed display closes client")
        server.onClientDisconnected = { disconnected.fulfill() }
        let connected = expectation(description: "failed display never activates")
        connected.isInverted = true
        server.onClientConnected = { connected.fulfill() }
        try await server.start()
        let client = try connect(to: server)
        defer { client.cancel() }
        await fulfillment(of: [disconnected], timeout: 2)
        await fulfillment(of: [connected], timeout: 0.1)
        XCTAssertNotNil(server.boundPort)
    }

    func testReplacedConnectionCannotFinishOldPreparationOrDisconnectNewClient() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        let gate = Preparation()
        let firstPreparing = expectation(description: "first preparation")
        server.onPrepareStream = { _, finish in gate.append(finish); firstPreparing.fulfill() }
        try await server.start()
        let first = try connect(to: server)
        defer { first.cancel() }
        await fulfillment(of: [firstPreparing], timeout: 2)
        let secondPreparing = expectation(description: "replacement preparation")
        server.onPrepareStream = { _, finish in gate.append(finish); secondPreparing.fulfill() }
        let oldEnded = expectation(description: "replacement ends old session once")
        oldEnded.assertForOverFulfill = true
        server.onClientDisconnected = { oldEnded.fulfill() }
        let second = try connect(to: server)
        defer { second.cancel() }
        await fulfillment(of: [secondPreparing, oldEnded], timeout: 2)
        let disconnected = expectation(description: "late cancellation must not disconnect replacement")
        disconnected.isInverted = true
        server.onClientDisconnected = { disconnected.fulfill() }
        let premature = expectation(description: "old preparation cannot activate replacement")
        premature.isInverted = true
        server.onClientConnected = { premature.fulfill() }
        gate.finish(0)
        await fulfillment(of: [premature, disconnected], timeout: 0.15)
        let connected = expectation(description: "replacement activates after its own setup")
        server.onClientConnected = { connected.fulfill() }
        gate.finish(1)
        await fulfillment(of: [connected], timeout: 2)
        server.onClientDisconnected = nil
    }
}
