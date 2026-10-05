import Foundation
import AppKit
import CoreGraphics
import CGVirtualDisplayBridge

/// Manages virtual display creation and lifecycle using CGVirtualDisplay API
class VirtualDisplayManager {
    private var virtualDisplay: CGVirtualDisplay?
    private var displayDescriptor: CGVirtualDisplayDescriptor?
    private var displaySettings: CGVirtualDisplaySettings?
    private var screenParamsObserver: NSObjectProtocol?

    var displayID: CGDirectDisplayID? {
        return virtualDisplay?.displayID
    }

    var isActive: Bool {
        return virtualDisplay != nil
    }

    /// Create a virtual display with specified configuration
    /// - Parameters:
    ///   - width: Display width in pixels
    ///   - height: Display height in pixels
    ///   - refreshRate: Refresh rate in Hz (default: 60)
    ///   - hiDPI: Enable HiDPI mode (default: false)
    ///   - name: Display name (default: "Virtual Display")
    func createDisplay(
        width: Int,
        height: Int,
        refreshRate: Int = 60,
        hiDPI: Bool = false,
        name: String = "Virtual Display",
        physicalSizeMM: CGSize? = nil
    ) throws {
        // Physical pixels = 2x logical when HiDPI, 1x otherwise
        let physW = hiDPI ? width * 2 : width
        let physH = hiDPI ? height * 2 : height

        if virtualDisplay == nil {
            // Keep one identity across rotation/scaling. Recreating virtual displays
            // while Sidecar is active can corrupt macOS capture's display mapping.
            let descriptor = CGVirtualDisplayDescriptor()
            descriptor.name = name
            descriptor.maxPixelsWide = 8192
            descriptor.maxPixelsHigh = 8192

            // Prefer client panel measurements. Use the historical density
            // estimate only when the client cannot report its physical size.
            let ppi: Double = hiDPI ? 220.0 : 110.0
            descriptor.sizeInMillimeters = physicalSizeMM ?? CGSize(
                width: Double(physW) * 25.4 / ppi,
                height: Double(physH) * 25.4 / ppi
            )

            descriptor.productID = 0x484443
            descriptor.vendorID = 0xEEED
            descriptor.serialNum = 0x0001

            self.displayDescriptor = descriptor
            guard let display = CGVirtualDisplay(descriptor: descriptor) else {
                throw VirtualDisplayError.creationFailed("Failed to create CGVirtualDisplay")
            }
            self.virtualDisplay = display
        }

        // Create display settings
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = hiDPI ? 1 : 0

        // HiDPI: anchor mode (physical) + logical mode
        // The anchor tells macOS "this display is high-density" → unlocks HiDPI for logical mode
        // non-HiDPI: single mode at requested resolution
        var modes: [CGVirtualDisplayMode] = []
        if hiDPI {
            modes.append(CGVirtualDisplayMode(
                width: UInt32(physW),
                height: UInt32(physH),
                refreshRate: Double(refreshRate)
            ))
        }
        modes.append(CGVirtualDisplayMode(
            width: UInt32(width),
            height: UInt32(height),
            refreshRate: Double(refreshRate)
        ))
        settings.modes = modes

        self.displaySettings = settings

        guard let display = virtualDisplay else { throw VirtualDisplayError.displayNotCreated }

        // Apply settings
        let result = display.apply(settings)
        if !result {
            destroyDisplay()
            throw VirtualDisplayError.settingsApplyFailed("Failed to apply settings")
        }

        let modeDesc = hiDPI ? "\(width)x\(height) HiDPI (physical \(physW)x\(physH))" : "\(width)x\(height)"
        print("✅ Virtual display created: \(modeDesc) @ \(refreshRate)Hz (ID: \(display.displayID))")

        registerScreenParamsObserver()
    }

    /// Re-assert the physical-main invariant on every display-topology change:
    /// WindowServer can re-adopt the virtual display as main from a remembered
    /// arrangement at any point after creation (issue #39), not only during
    /// the one-shot restore — e.g. when a physical display is hot-plugged.
    /// Our own re-arrangement re-fires the notification, but the main-display
    /// guard in ensurePhysicalDisplayStaysMain makes that pass a no-op.
    private func registerScreenParamsObserver() {
        guard screenParamsObserver == nil else { return }
        screenParamsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.ensurePhysicalDisplayStaysMain()
        }
    }

    private func removeScreenParamsObserver() {
        if let token = screenParamsObserver {
            NotificationCenter.default.removeObserver(token)
            screenParamsObserver = nil
        }
    }

    /// Clone the main display configuration
    func cloneMainDisplay() throws {
        guard let mainDisplay = CGMainDisplayID() as CGDirectDisplayID? else {
            throw VirtualDisplayError.mainDisplayNotFound
        }

        let width = Int(CGDisplayPixelsWide(mainDisplay))
        let height = Int(CGDisplayPixelsHigh(mainDisplay))

        // Get refresh rate
        var refreshRate = 60
        if let mode = CGDisplayCopyDisplayMode(mainDisplay) {
            refreshRate = Int(mode.refreshRate)
        }

        try createDisplay(
            width: width,
            height: height,
            refreshRate: refreshRate,
            name: "Virtual Display (Clone)"
        )
    }

    /// Enable mirror mode with main display
    func enableMirrorMode() throws {
        guard let display = virtualDisplay else {
            throw VirtualDisplayError.displayNotCreated
        }

        let mainDisplay = CGMainDisplayID()

        var config: CGDisplayConfigRef?
        let beginResult = CGBeginDisplayConfiguration(&config)

        guard beginResult == CGError.success, let config = config else {
            throw VirtualDisplayError.configurationFailed("Failed to begin display configuration")
        }

        let mirrorResult = CGConfigureDisplayMirrorOfDisplay(
            config,
            display.displayID,
            mainDisplay
        )

        if mirrorResult != CGError.success {
            CGCancelDisplayConfiguration(config)
            throw VirtualDisplayError.mirrorModeFailed("Failed to configure mirror mode: \(mirrorResult)")
        }

        let completeResult = CGCompleteDisplayConfiguration(config, .permanently)

        if completeResult != CGError.success {
            throw VirtualDisplayError.mirrorModeFailed("Failed to complete mirror configuration: \(completeResult)")
        }

        print("✅ Mirror mode enabled")
    }

    /// Disable mirror mode (extend mode)
    func disableMirrorMode() throws {
        guard let display = virtualDisplay else {
            throw VirtualDisplayError.displayNotCreated
        }

        var config: CGDisplayConfigRef?
        let beginResult = CGBeginDisplayConfiguration(&config)

        guard beginResult == CGError.success, let config = config else {
            throw VirtualDisplayError.configurationFailed("Failed to begin display configuration")
        }

        // Setting mirror to kCGNullDirectDisplay disables mirroring
        let mirrorResult = CGConfigureDisplayMirrorOfDisplay(
            config,
            display.displayID,
            CGDirectDisplayID(kCGNullDirectDisplay)
        )

        if mirrorResult != CGError.success {
            CGCancelDisplayConfiguration(config)
            throw VirtualDisplayError.mirrorModeFailed("Failed to disable mirror mode: \(mirrorResult)")
        }

        let completeResult = CGCompleteDisplayConfiguration(config, .permanently)

        if completeResult != CGError.success {
            throw VirtualDisplayError.mirrorModeFailed("Failed to complete configuration: \(completeResult)")
        }

        print("✅ Extend mode enabled (mirror disabled)")
    }

    /// WindowServer may initially pick the 1x physical anchor. Select the
    /// requested logical mode explicitly before capture/arrangement.
    func selectMode(width: Int, height: Int, hiDPI: Bool) throws {
        guard let id = displayID else { throw VirtualDisplayError.displayNotCreated }
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
        let scale = hiDPI ? 2 : 1
        guard let mode = modes.first(where: { $0.width == width && $0.height == height && $0.pixelWidth == width * scale && $0.pixelHeight == height * scale }) else {
            throw VirtualDisplayError.configurationFailed("Requested desktop scale is unavailable")
        }
        guard CGDisplaySetDisplayMode(id, mode, nil) == .success else {
            throw VirtualDisplayError.configurationFailed("Could not apply desktop scale")
        }
    }

    /// Get current display position (origin)
    func getDisplayPosition() -> CGPoint? {
        guard let displayID = displayID else { return nil }
        let bounds = CGDisplayBounds(displayID)
        return bounds.origin
    }

    /// Set display position in arrangement
    func setDisplayPosition(x: Int32, y: Int32) throws {
        guard let display = virtualDisplay else {
            throw VirtualDisplayError.displayNotCreated
        }

        var config: CGDisplayConfigRef?
        let beginResult = CGBeginDisplayConfiguration(&config)

        guard beginResult == CGError.success, let config = config else {
            throw VirtualDisplayError.configurationFailed("Failed to begin display configuration")
        }

        let originResult = CGConfigureDisplayOrigin(config, display.displayID, x, y)

        if originResult != CGError.success {
            CGCancelDisplayConfiguration(config)
            throw VirtualDisplayError.configurationFailed("Failed to set display origin: \(originResult)")
        }

        // Session-scoped on purpose: position is persisted via UserDefaults, and
        // baking the virtual display into WindowServer's permanent prefs lets the
        // system re-adopt it as main on later startups (#39).
        let completeResult = CGCompleteDisplayConfiguration(config, .forSession)

        if completeResult != CGError.success {
            throw VirtualDisplayError.configurationFailed("Failed to complete configuration: \(completeResult)")
        }

        print("📍 Display position set to (\(x), \(y))")
    }

    /// Save current display position to UserDefaults
    func saveDisplayPosition() {
        guard let position = getDisplayPosition() else { return }
        let defaults = UserDefaults.standard
        defaults.set(Int(position.x), forKey: "HarmonyScreen_positionX")
        defaults.set(Int(position.y), forKey: "HarmonyScreen_positionY")
        defaults.set(true, forKey: "HarmonyScreen_hasPosition")
        print("💾 Saved display position: (\(Int(position.x)), \(Int(position.y)))")
    }

    /// Restore saved display position
    func restoreDisplayPosition() {
        // Run the main-display safety net on every path, including early
        // returns: WindowServer can re-adopt the virtual display as main from
        // its own remembered arrangement even when we restore nothing (#39).
        defer { ensurePhysicalDisplayStaysMain() }

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "HarmonyScreen_hasPosition") else {
            print("📍 No saved display position found")
            return
        }

        let x = defaults.integer(forKey: "HarmonyScreen_positionX")
        let y = defaults.integer(forKey: "HarmonyScreen_positionY")

        // A position saved while the tablet was the Mac's only screen is the
        // main slot (0,0). Re-applying it with a physical display attached
        // moves the menu bar and all input focus onto a screen that may not be
        // visible anywhere — e.g. right after the tablet was unpaired (#39).
        if x == 0 && y == 0 && !onlinePhysicalDisplays().isEmpty {
            print("🛟 Skipping saved main-slot position — a physical display is attached")
            return
        }

        do {
            try setDisplayPosition(x: Int32(x), y: Int32(y))
            print("📍 Restored display position: (\(x), \(y))")
        } catch {
            print("⚠️  Failed to restore display position: \(error)")
        }
    }

    /// Online displays other than this virtual display. Filters by the vendor
    /// ID our descriptor registers (0xEEED) so a stale HarmonyScreen display from
    /// a previous instance is not mistaken for a physical screen.
    private func onlinePhysicalDisplays() -> [CGDirectDisplayID] {
        var online = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &online, &count) == .success else { return [] }
        return online.prefix(Int(count)).filter { id in
            id != displayID && CGDisplayVendorNumber(id) != 0xEEED
        }
    }

    /// Safety net for #39: whenever at least one physical display is online,
    /// the main slot (0,0) must belong to a physical display, never to the
    /// virtual one. Otherwise the menu bar, dock, and keyboard focus land on a
    /// screen nobody can see, which presents as a completely unresponsive Mac.
    /// No-ops in true headless operation (no physical display online).
    func ensurePhysicalDisplayStaysMain() {
        guard let displayID = displayID else { return }
        guard CGMainDisplayID() == displayID,
              let physicalMain = onlinePhysicalDisplays().first else { return }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == CGError.success, let config = config else { return }

        // Give the physical display the main slot and park the virtual display
        // to its right.
        let physicalWidth = Int32(CGDisplayBounds(physicalMain).width)
        var result = CGConfigureDisplayOrigin(config, physicalMain, 0, 0)
        if result == CGError.success {
            result = CGConfigureDisplayOrigin(config, displayID, physicalWidth, 0)
        }
        guard result == CGError.success else {
            CGCancelDisplayConfiguration(config)
            print("⚠️  Failed to rearrange displays: \(result)")
            return
        }

        if CGCompleteDisplayConfiguration(config, .forSession) == CGError.success {
            print("🛟 Physical display restored as main — virtual display parked beside it")
        }
    }

    /// Verify the virtual display is registered in the system display list
    func verifyDisplayRegistered() -> Bool {
        guard let displayID = displayID else {
            debugLog("verifyDisplayRegistered: no displayID set")
            return false
        }

        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        let err = CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount)

        guard err == .success else {
            debugLog("verifyDisplayRegistered: CGGetOnlineDisplayList failed with \(err)")
            return false
        }

        let onlineIDs = Array(onlineDisplays.prefix(Int(displayCount)))
        let found = onlineIDs.contains(displayID)
        debugLog("verifyDisplayRegistered: displayID \(displayID) \(found ? "FOUND" : "NOT FOUND") in online displays \(onlineIDs)")
        return found
    }

    /// Destroy the virtual display
    func destroyDisplay() {
        removeScreenParamsObserver()
        if virtualDisplay != nil {
            virtualDisplay = nil
            displayDescriptor = nil
            displaySettings = nil
            print("🗑️  Virtual display destroyed")
        }
    }

    deinit {
        destroyDisplay()
    }
}

// MARK: - Error Types
enum VirtualDisplayError: Error, LocalizedError {
    case creationFailed(String)
    case settingsApplyFailed(String)
    case displayNotCreated
    case mainDisplayNotFound
    case configurationFailed(String)
    case mirrorModeFailed(String)

    var errorDescription: String? {
        switch self {
        case .creationFailed(let msg):
            return "Virtual display creation failed: \(msg)"
        case .settingsApplyFailed(let msg):
            return "Settings apply failed: \(msg)"
        case .displayNotCreated:
            return "Virtual display has not been created"
        case .mainDisplayNotFound:
            return "Main display not found"
        case .configurationFailed(let msg):
            return "Display configuration failed: \(msg)"
        case .mirrorModeFailed(let msg):
            return "Mirror mode operation failed: \(msg)"
        }
    }
}
