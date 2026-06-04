import AppKit
import Foundation

public struct MacOSActionRunner: ActionRunning {
    public enum Error: Swift.Error, Equatable, LocalizedError, Sendable {
        case applicationNotFound(name: String)
        case unsupportedAction(AgentAction)

        public var errorDescription: String? {
            switch self {
            case let .applicationNotFound(name):
                return "Could not find a macOS application named '\(name)'."
            case let .unsupportedAction(action):
                return "MacOSActionRunner does not support action: \(action)."
            }
        }
    }

    private let openApplicationByName: @Sendable (String) async throws -> Bool

    public init() {
        self.openApplicationByName = { name in
            try await Self.openApplicationUsingWorkspace(named: name)
        }
    }

    public init(openApplicationByName: @escaping @Sendable (String) async throws -> Bool) {
        self.openApplicationByName = openApplicationByName
    }

    public func run(_ action: AgentAction) async throws {
        switch action {
        case let .openApplication(name):
            let opened = try await openApplicationByName(name)
            guard opened else {
                throw Error.applicationNotFound(name: name)
            }
        case .click, .typeText, .keyPress, .shell:
            throw Error.unsupportedAction(action)
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
}
