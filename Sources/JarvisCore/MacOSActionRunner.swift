import AppKit
import Foundation

public struct MacOSInputFlags: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = MacOSInputFlags(rawValue: 1 << 0)
    public static let shift = MacOSInputFlags(rawValue: 1 << 1)
    public static let option = MacOSInputFlags(rawValue: 1 << 2)
    public static let control = MacOSInputFlags(rawValue: 1 << 3)
}

public enum MacOSInputCommand: Equatable, Sendable {
    case mouseDown(x: Int, y: Int)
    case mouseUp(x: Int, y: Int)
    case keyDown(keyCode: UInt16, flags: MacOSInputFlags)
    case keyUp(keyCode: UInt16, flags: MacOSInputFlags)
    case setPasteboardString(String)
}

public struct MacOSActionRunner: ActionRunning {
    public enum Error: Swift.Error, Equatable, LocalizedError, Sendable {
        case applicationNotFound(name: String)
        case unsupportedKey(String)
        case unsupportedAction(AgentAction)

        public var errorDescription: String? {
            switch self {
            case let .applicationNotFound(name):
                return "Could not find a macOS application named '\(name)'."
            case let .unsupportedKey(key):
                return "MacOSActionRunner does not support key: \(key)."
            case let .unsupportedAction(action):
                return "MacOSActionRunner does not support action: \(action)."
            }
        }
    }

    private let openApplicationByName: @Sendable (String) async throws -> Bool
    private let performInputCommand: @Sendable (MacOSInputCommand) async throws -> Void

    public init() {
        self.openApplicationByName = { name in
            try await Self.openApplicationUsingWorkspace(named: name)
        }
        self.performInputCommand = { command in
            try await Self.performSystemInputCommand(command)
        }
    }

    public init(openApplicationByName: @escaping @Sendable (String) async throws -> Bool) {
        self.openApplicationByName = openApplicationByName
        self.performInputCommand = { command in
            try await Self.performSystemInputCommand(command)
        }
    }

    init(
        openApplicationByName: @escaping @Sendable (String) async throws -> Bool,
        performInputCommand: @escaping @Sendable (MacOSInputCommand) async throws -> Void
    ) {
        self.openApplicationByName = openApplicationByName
        self.performInputCommand = performInputCommand
    }

    public func run(_ action: AgentAction) async throws {
        switch action {
        case let .openApplication(name):
            let opened = try await openApplicationByName(name)
            guard opened else {
                throw Error.applicationNotFound(name: name)
            }
        case let .click(x, y, _):
            try await performInputCommand(.mouseDown(x: x, y: y))
            try await performInputCommand(.mouseUp(x: x, y: y))
        case let .typeText(text):
            try await performInputCommand(.setPasteboardString(text))
            try await performInputCommand(.keyDown(keyCode: Self.keyCode(for: "v")!, flags: .command))
            try await performInputCommand(.keyUp(keyCode: Self.keyCode(for: "v")!, flags: .command))
        case let .keyPress(key, modifiers, _):
            guard let keyCode = Self.keyCode(for: key) else {
                throw Error.unsupportedKey(key)
            }
            let flags = Self.flags(for: modifiers)
            try await performInputCommand(.keyDown(keyCode: keyCode, flags: flags))
            try await performInputCommand(.keyUp(keyCode: keyCode, flags: flags))
        case .shell:
            throw Error.unsupportedAction(action)
        }
    }

    public static func keyCode(for key: String) -> UInt16? {
        keyCodes[key.lowercased()]
    }

    public static func flags(for modifiers: [String]) -> MacOSInputFlags {
        modifiers.reduce(into: []) { flags, modifier in
            switch modifier.lowercased() {
            case "cmd", "command":
                flags.insert(.command)
            case "shift":
                flags.insert(.shift)
            case "opt", "option", "alt":
                flags.insert(.option)
            case "ctrl", "control":
                flags.insert(.control)
            default:
                break
            }
        }
    }

    @MainActor
    private static func openApplicationUsingWorkspace(named name: String) async throws -> Bool {
        guard let appURL = applicationURL(named: name) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        _ = try await NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: configuration
        )
        return true
    }

    private static func applicationURL(named name: String) -> URL? {
        let fileManager = FileManager.default

        if name.hasPrefix("/") {
            let url = URL(fileURLWithPath: name)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }

        let appBundleName = name.hasSuffix(".app") ? name : "\(name).app"
        let searchDirectories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]

        return searchDirectories
            .map { $0.appendingPathComponent(appBundleName, isDirectory: true) }
            .first { fileManager.fileExists(atPath: $0.path) }
    }

    @MainActor
    public static func performSystemInputCommand(_ command: MacOSInputCommand) async throws {
        switch command {
        case let .mouseDown(x, y):
            postMouse(type: .leftMouseDown, x: x, y: y)
        case let .mouseUp(x, y):
            postMouse(type: .leftMouseUp, x: x, y: y)
        case let .keyDown(keyCode, flags):
            postKey(keyCode: keyCode, keyDown: true, flags: flags)
        case let .keyUp(keyCode, flags):
            postKey(keyCode: keyCode, keyDown: false, flags: flags)
        case let .setPasteboardString(text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    private static func postMouse(type: CGEventType, x: Int, y: Int) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: CGPoint(x: x, y: y),
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }

    private static func postKey(keyCode: UInt16, keyDown: Bool, flags: MacOSInputFlags) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown)
        event?.flags = flags.cgEventFlags
        event?.post(tap: .cghidEventTap)
    }

    private static let keyCodes: [String: UInt16] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "1": 0x12,
        "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
        "7": 0x1A, "8": 0x1C, "0": 0x1D, "o": 0x1F, "u": 0x20, "i": 0x22,
        "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D, "m": 0x2E,
        "tab": 0x30, "space": 0x31, "delete": 0x33, "backspace": 0x33,
        "escape": 0x35, "esc": 0x35, "return": 0x24, "enter": 0x24,
        "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
    ]
}

private extension MacOSInputFlags {
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        return flags
    }
}
