import Foundation
import JarvisCore

public enum JarvisCLICommand: Equatable, Sendable {
    case observe
    case plan(PlanCommand)

    public static func parse(_ arguments: [String]) throws -> JarvisCLICommand {
        switch arguments.first {
        case "observe":
            guard arguments.count == 1 else { throw CLIError.usage }
            return .observe
        case "plan":
            return .plan(try PlanCommand.parse(arguments))
        default:
            throw CLIError.usage
        }
    }
}

public struct PlanCommand: Equatable, Sendable {
    public let transcript: String
    public let execute: Bool

    public init(transcript: String, execute: Bool) {
        self.transcript = transcript
        self.execute = execute
    }

    public static func parse(_ arguments: [String]) throws -> PlanCommand {
        guard arguments.first == "plan" else {
            throw CLIError.usage
        }

        var remaining = Array(arguments.dropFirst())
        let execute = remaining.first == "--execute"
        if execute {
            remaining.removeFirst()
        }

        let transcript = remaining.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw CLIError.usage
        }

        return PlanCommand(transcript: transcript, execute: execute)
    }

    public static func render(_ plan: AgentPlan) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(plan)
        return String(decoding: data, as: UTF8.self)
    }

    public static func renderExecutionResult(_ result: PlanExecutionResult) -> String {
        switch result {
        case .completed:
            return "Execution completed."
        case let .confirmationRequired(step):
            return "Confirmation required before step \(step.id): \(step.reason)"
        }
    }
}

public enum ObserveCommand {
    public static func render(_ observation: ScreenObservation) -> String {
        let tree = observation.accessibilityTree.trimmingCharacters(in: .whitespacesAndNewlines)
        if tree.isEmpty {
            return """
            Focused application: \(observation.focusedApplication ?? "unknown")

            Accessibility tree:
            No Accessibility elements were returned.

            If this is unexpected, grant Accessibility permission to the terminal app running Jarvis:
            System Settings > Privacy & Security > Accessibility
            """
        }

        return """
        Focused application: \(observation.focusedApplication ?? "unknown")

        Accessibility tree:
        \(tree)
        """
    }
}

public enum CLIError: Error, Equatable {
    case usage
}
