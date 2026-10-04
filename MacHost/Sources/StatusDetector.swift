import Foundation
import SystemConfiguration

enum StatusDetector {
    static func hdcInstalled() -> Bool { HDCBridge.executablePath() != nil }
    static func wifiReachable() -> Bool {
        guard let reach = SCNetworkReachabilityCreateWithName(nil, "1.1.1.1") else { return false }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reach, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    static func usbDevices() -> [String] { HDCBridge.devices() }
    static func hdcReverseConfigured(port: Int) -> Bool { HDCBridge.isConfigured(port: port) }
}
