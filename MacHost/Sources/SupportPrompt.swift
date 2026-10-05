import AppKit
import SwiftUI

/// Public build configuration; never fall back to the upstream author's funding links.
struct SupportOffer: Decodable {
    let checkoutURL: String
    let paymentType: String

    var url: URL? {
        guard paymentType == "one_time", let value = URL(string: checkoutURL),
              value.scheme == "https", value.host != nil,
              value.user == nil, value.password == nil else { return nil }
        return value
    }

    static var configured: SupportOffer? {
        guard let file = Bundle.main.url(forResource: "SupportOffer", withExtension: "json"),
              let data = try? Data(contentsOf: file),
              let offer = try? JSONDecoder().decode(SupportOffer.self, from: data),
              offer.url != nil else { return nil }
        return offer
    }
}

/// The automatic invitation is never shown while streaming or without a real checkout.
/// Each new streaming session can qualify again; dismissal never persists across sessions.
final class SupportPromptPolicy {
    private var previousFrameTime: TimeInterval?
    private var sessionRunning = false
    static let qualifyingSeconds: TimeInterval = 300

    // Session state is deliberately in memory. Legacy permanent-dismissal preferences
    // from 0.1.2 have no effect, including after an app update or relaunch.
    private(set) var hasPrompted = false
    private(set) var usedSeconds: TimeInterval = 0

    func beginSession(continuing: Bool = false) {
        if !continuing {
            hasPrompted = false
            usedSeconds = 0
        }
        previousFrameTime = nil
        sessionRunning = true
    }

    func observeFrames(at uptime: TimeInterval, connected: Bool, fps: Double) {
        guard sessionRunning, !hasPrompted, usedSeconds < Self.qualifyingSeconds else { previousFrameTime = nil; return }
        guard connected, fps > 0, uptime.isFinite else { previousFrameTime = nil; return }
        defer { previousFrameTime = uptime }
        guard let previous = previousFrameTime else { return }
        let elapsed = uptime - previous
        // Do not count long sleep/disconnect gaps as use.
        guard elapsed > 0, elapsed <= 5 else { return }
        usedSeconds = min(Self.qualifyingSeconds, usedSeconds + elapsed)
    }

    func pauseCounting() { previousFrameTime = nil }

    func endedSession() {
        pauseCounting()
        sessionRunning = false
    }

    func takePresentation(configured: Bool, streaming: Bool, windowVisible: Bool, appActive: Bool) -> Bool {
        guard configured, !streaming, !sessionRunning, windowVisible, appActive,
              !hasPrompted, usedSeconds >= Self.qualifyingSeconds else { return false }
        markPresented() // Prevent another automatic invitation for this same session.
        return true
    }

    func markPresented() { hasPrompted = true }
}

struct SupportPromptView: View {
    let offer: SupportOffer?
    let dismiss: () -> Void
    @State private var openFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HARMONYSCREEN / YOUWO.AI")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.3)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 12, weight: .medium)) }
                    .buttonStyle(.plain).accessibilityLabel("Close support invitation")
            }
            Text("Enjoying your\nextra screen?")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 24)
            Text("HarmonyScreen is free. An optional one-time contribution helps YouWo.ai keep improving it.")
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            HStack(spacing: 12) {
                Button("Support YouWo.ai") {
                    guard let url = offer?.url else { return }
                    if NSWorkspace.shared.open(url) { dismiss() } else { openFailed = true }
                }
                .buttonStyle(.borderedProminent).tint(Color(red: 0.20, green: 0.40, blue: 0.32))
                .controlSize(.large).disabled(offer?.url == nil)
                Button("Not now", action: dismiss)
                    .buttonStyle(.bordered).controlSize(.large).keyboardShortcut(.cancelAction)
            }.padding(.top, 26)
            Text("No subscription. All features stay free.")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 16)
            if offer == nil {
                Text("Design preview · payment link not connected")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
            }
            if openFailed {
                Text("The browser couldn’t open. You can close this and keep using HarmonyScreen.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
        .padding(30).frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
