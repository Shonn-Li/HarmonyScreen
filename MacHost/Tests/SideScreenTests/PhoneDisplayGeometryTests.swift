import XCTest
import Network
@testable import HarmonyScreen

final class PhoneDisplayGeometryTests: XCTestCase {
    private let mac = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let mm = CGSize(width: 344.2447, height: 222.5239)
    private func packet(_ values: [Int]) -> [UInt8] {
        values.flatMap { [UInt8(0x80 | ($0 >> 7)), UInt8(0x80 | ($0 & 127))] }
    }
    func testViewportRejectsMalformedAndOversizedReports() {
        XCTAssertNil(PhoneDisplayGeometry.decode([0,0,0,0,0,0,0,0]))
        XCTAssertNil(PhoneDisplayGeometry.decode(packet([8192,8192,4000,4000])))
        XCTAssertNil(PhoneDisplayGeometry.decode(packet([3184,2232,1,4000])))
        XCTAssertNotNil(PhoneDisplayGeometry.decode(packet([3184,2232,0,0])))
    }
    func testNativePortraitSwapsDesktopWithoutRotatingVideo() {
        let landscape = PhoneDisplayGeometry(width: 3184, height: 2232, dpiX: 0, dpiY: 0).layout(matchMac: false, referenceBounds: mac, referenceMM: mm)
        let portrait = PhoneDisplayGeometry(width: 2232, height: 3184, dpiX: 0, dpiY: 0).layout(matchMac: true, referenceBounds: mac, referenceMM: mm)
        XCTAssertEqual(landscape.logicalWidth, 1592)
        XCTAssertEqual(landscape.logicalHeight, 1116)
        XCTAssertEqual(portrait.logicalWidth, 1116)
        XCTAssertEqual(portrait.logicalHeight, 1592)
        XCTAssertEqual(portrait.pixelWidth, 2232)
        XCTAssertEqual(portrait.pixelHeight, 3184)
    }
    func testPhysicalScaleFollowsMacScalingAndKeepsPanelOutput() {
        let phone = PhoneDisplayGeometry(width: 3184, height: 2232, dpiX: 381, dpiY: 381)
        let layout = phone.layout(matchMac: true, referenceBounds: mac, referenceMM: mm)
        let largerMacDesktop = phone.layout(matchMac: true, referenceBounds: CGRect(x: 0, y: 0, width: 2056, height: 1329), referenceMM: mm)
        XCTAssertEqual(Double(layout.logicalWidth) / phone.millimeters!.width, mac.width / mm.width, accuracy: 0.01)
        XCTAssertGreaterThan(largerMacDesktop.logicalWidth, layout.logicalWidth)
        XCTAssertEqual(largerMacDesktop.pixelWidth, layout.pixelWidth)
        XCTAssertEqual(largerMacDesktop.pixelHeight, layout.pixelHeight)
    }
    func testPlacementRemainsEdgeAttachedInPortraitAndScaledMac() {
        let portrait = CGSize(width: 746, height: 1066)
        XCTAssertEqual(DisplayPlacement.origin(reference: mac, desktop: portrait, side: "left", alignment: "start"), CGPoint(x: -746, y: 0))
        let scaled = CGRect(x: 100, y: -50, width: 2056, height: 1329)
        let p = DisplayPlacement.origin(reference: scaled, desktop: portrait, side: "right", alignment: "center")
        XCTAssertEqual(p.x, scaled.maxX)
        XCTAssertEqual(p.y + portrait.height/2, scaled.midY)
        let above = DisplayPlacement.origin(reference: scaled, desktop: portrait, side: "above", alignment: "end")
        XCTAssertEqual(above.x + portrait.width, scaled.maxX)
        XCTAssertEqual(above.y + portrait.height, scaled.minY)
    }
    func testFragmentedViewportFollowedByCoalescedMessage() async throws {
        let server = StreamingServer(port: 0)
        defer { server.stop() }
        let report = expectation(description: "viewport reconstructed")
        let keyframe = expectation(description: "following message not swallowed")
        server.onPhoneViewport = { geometry in
            XCTAssertEqual(geometry.width, 2232)
            XCTAssertEqual(geometry.height, 3184)
            report.fulfill()
        }
        server.onKeyframeRequested = { force in XCTAssertTrue(force); keyframe.fulfill() }
        try await server.start()
        let client = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: server.boundPort!)!, using: .tcp)
        defer { client.cancel() }
        let ready = expectation(description: "connected")
        client.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        client.start(queue: DispatchQueue(label: "viewport-test"))
        await fulfillment(of: [ready], timeout: 2)
        let bytes = [UInt8(14)] + packet([2232,3184,3810,3810]) + [UInt8(7),UInt8(1)]
        client.send(content: Data(bytes.prefix(4)), completion: .contentProcessed { _ in })
        try await Task.sleep(nanoseconds: 20_000_000)
        client.send(content: Data(bytes.dropFirst(4)), completion: .contentProcessed { _ in })
        await fulfillment(of: [report,keyframe], timeout: 2)
    }
}
