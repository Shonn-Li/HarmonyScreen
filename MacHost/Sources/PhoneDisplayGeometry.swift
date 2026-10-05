import Foundation
import CoreGraphics

/// HDC client viewport, in physical pixels. DPI is the panel's reported x/y DPI,
/// never HarmonyOS's user-adjustable UI density. Zero means unavailable.
struct PhoneDisplayGeometry: Equatable, Sendable {
    let width: Int
    let height: Int
    let dpiX: Double
    let dpiY: Double

    static func decode(_ payload: [UInt8]) -> Self? {
        guard payload.count == 8, payload.allSatisfy({ $0 & 0x80 != 0 }) else { return nil }
        let values = stride(from: 0, to: 8, by: 2).map {
            Int(payload[$0] & 0x7f) << 7 | Int(payload[$0 + 1] & 0x7f)
        }
        guard (320...8192).contains(values[0]), (320...8192).contains(values[1]),
              values[0] * values[1] <= 32 * 1024 * 1024,
              values.dropFirst(2).allSatisfy({ $0 == 0 || (500...10000).contains($0) }) else { return nil }
        return Self(width: values[0], height: values[1], dpiX: Double(values[2]) / 10, dpiY: Double(values[3]) / 10)
    }

    var millimeters: CGSize? {
        // Suspicious/anisotropic DPI is not reliable physical-size evidence.
        guard dpiX >= 50, dpiY >= 50, abs(dpiX / dpiY - 1) < 0.1 else { return nil }
        let dpi = (dpiX + dpiY) / 2
        return CGSize(width: Double(width) * 25.4 / dpi, height: Double(height) * 25.4 / dpi)
    }

    func layout(matchMac: Bool, referenceBounds: CGRect, referenceMM: CGSize) -> PhoneDisplayLayout {
        let pixelW = width / 2 * 2, pixelH = height / 2 * 2 // HEVC 4:2:0 even dimensions
        var scale = 0.5 // Native 2x Retina fallback
        if matchMac, let mm = millimeters, referenceMM.width > 0, referenceBounds.width > 0 {
            let macPointsPerMM = referenceBounds.width / referenceMM.width
            scale = mm.width * macPointsPerMM / Double(width)
        }
        // Bound the desktop while preserving aspect ratio; the encoder retains
        // panel-sized output independently from the logical macOS desktop.
        scale = max(320.0 / Double(min(pixelW, pixelH)), min(scale, 4096.0 / Double(max(pixelW, pixelH))))
        return PhoneDisplayLayout(logicalWidth: Int((Double(pixelW) * scale / 2).rounded()) * 2,
                                  logicalHeight: Int((Double(pixelH) * scale / 2).rounded()) * 2,
                                  pixelWidth: pixelW, pixelHeight: pixelH, millimeters: millimeters)
    }
}

struct PhoneDisplayLayout: Equatable, Sendable {
    let logicalWidth: Int
    let logicalHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let millimeters: CGSize?
}

enum DisplayPlacement {
    /// CoreGraphics coordinates: origin at top-left, positive Y downward.
    static func origin(reference: CGRect, desktop: CGSize, side: String, alignment: String) -> CGPoint {
        let fraction: CGFloat = alignment == "center" ? 0.5 : alignment == "end" ? 1 : 0
        switch side {
        case "left": return CGPoint(x: reference.minX - desktop.width, y: reference.minY + (reference.height - desktop.height) * fraction)
        case "above": return CGPoint(x: reference.minX + (reference.width - desktop.width) * fraction, y: reference.minY - desktop.height)
        case "below": return CGPoint(x: reference.minX + (reference.width - desktop.width) * fraction, y: reference.maxY)
        default: return CGPoint(x: reference.maxX, y: reference.minY + (reference.height - desktop.height) * fraction)
        }
    }
}
