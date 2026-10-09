import Foundation

struct PhonePlacement: Equatable {
    static let sides = ["left", "right", "above", "below"]
    static let alignments = ["start", "center", "end"]
    let side: String
    let alignment: String

    var payload: [UInt8] {
        [0x80 | UInt8(Self.sides.firstIndex(of: side) ?? 1),
         0x80 | UInt8(Self.alignments.firstIndex(of: alignment) ?? 1)]
    }

    static func decode(_ payload: [UInt8]) -> Self? {
        guard payload.count == 2, (0x80...0x83).contains(payload[0]),
              (0x80...0x82).contains(payload[1]) else { return nil }
        return Self(side: sides[Int(payload[0] & 0x7f)], alignment: alignments[Int(payload[1] & 0x7f)])
    }
}
