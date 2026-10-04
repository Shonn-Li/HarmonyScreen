import Foundation

/// Uses Huawei's authenticated HDC transport. Never substitutes ADB or enables TCP debugging.
enum HDCBridge {
    static func executablePath() -> String? {
        let home = NSHomeDirectory()
        let candidates = [ProcessInfo.processInfo.environment["HARMONYSCREEN_HDC"],
            "\(home)/.local/bin/hdc", "/opt/homebrew/bin/hdc", "/usr/local/bin/hdc",
            "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"]
        return candidates.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func run(_ arguments: [String]) -> String? {
        guard let path = executablePath() else { return nil }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        // HDC can hang after an unplug. Keep the UI and status worker bounded.
        let deadline = Date().addingTimeInterval(4)
        while task.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        if task.isRunning { task.terminate(); return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard task.terminationStatus == 0 else { return nil }
        let output = String(decoding: data, as: UTF8.self)
        guard !output.contains("[Fail]") else { return nil } // HDC sometimes exits 0 on errors.
        return output
    }

    static func parseTargets(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // USB connect keys only; exclude diagnostic lines and network targets.
            guard !value.isEmpty, value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return nil }
            return value
        }
    }

    static func devices() -> [String] { parseTargets(run(["list", "targets"]) ?? "") }

    static func containsReverse(_ output: String, device: String, port: Int) -> Bool {
        output.split(whereSeparator: \.isNewline).contains { line in
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            return fields == [device, "tcp:\(port)", "tcp:\(port)", "[Reverse]"]
        }
    }

    static func isConfigured(port: Int) -> Bool {
        let targets = devices()
        guard targets.count == 1, let output = run(["-t", targets[0], "fport", "ls"]) else { return false }
        return containsReverse(output, device: targets[0], port: port)
    }

    static func configure(port: Int) -> Bool {
        guard (1024...65535).contains(port) else { return false }
        let targets = devices()
        // Refuse ambiguous device selection rather than forwarding to the wrong phone.
        guard targets.count == 1 else { return false }
        if isConfigured(port: port) { return true }
        guard let output = run(["-t", targets[0], "rport", "tcp:\(port)", "tcp:\(port)"]),
              output.contains("Forwardport result:OK") else { return false }
        return isConfigured(port: port)
    }
}
