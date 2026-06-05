import Foundation
import JarvisCore

public enum JarvisCLICommand: Equatable, Sendable {
    case doctor
    case observe
    case plan(PlanCommand)

    public static func parse(_ arguments: [String]) throws -> JarvisCLICommand {
        switch arguments.first {
        case "doctor":
            guard arguments.count == 1 else { throw CLIError.usage }
            return .doctor
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

    public static func resolveElementActions(in plan: AgentPlan, using observation: ScreenObservation) -> AgentPlan {
        let steps = plan.steps.map { step in
            guard case let .clickElement(label) = step.action,
                  let click = clickAction(for: label, in: observation.accessibilityTree)
            else {
                return step
            }

            return AgentStep(id: step.id, reason: step.reason, action: click)
        }

        return AgentPlan(summary: plan.summary, steps: steps)
    }

    private static func clickAction(for label: String, in accessibilityTree: String) -> AgentAction? {
        let normalizedLabel = label.lowercased()

        for line in accessibilityTree.split(separator: "\n").map(String.init) {
            guard line.lowercased().contains(normalizedLabel),
                  let bounds = parseBounds(from: line)
            else {
                continue
            }

            return .click(
                x: bounds.x + bounds.width / 2,
                y: bounds.y + bounds.height / 2,
                label: label
            )
        }

        return nil
    }

    private static func parseBounds(from line: String) -> (x: Int, y: Int, width: Int, height: Int)? {
        guard let range = line.range(of: #"bounds=\(([-0-9]+),([-0-9]+),([-0-9]+),([-0-9]+)\)"#, options: .regularExpression) else {
            return nil
        }

        let match = String(line[range])
        let values = match
            .replacingOccurrences(of: "bounds=(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .compactMap { Int($0) }

        guard values.count == 4 else { return nil }
        return (values[0], values[1], values[2], values[3])
    }
}

public struct DoctorReport: Equatable, Sendable {
    public let codexExecutable: String
    public let accessibilityTrusted: Bool
    public let focusedApplication: String?
    public let accessibilityTreeIsEmpty: Bool

    public init(
        codexExecutable: String,
        accessibilityTrusted: Bool,
        focusedApplication: String?,
        accessibilityTreeIsEmpty: Bool
    ) {
        self.codexExecutable = codexExecutable
        self.accessibilityTrusted = accessibilityTrusted
        self.focusedApplication = focusedApplication
        self.accessibilityTreeIsEmpty = accessibilityTreeIsEmpty
    }
}

public enum DoctorCommand {
    public static func render(_ report: DoctorReport) -> String {
        var lines = [
            "Codex executable: \(report.codexExecutable)",
            "Accessibility trusted: \(report.accessibilityTrusted ? "yes" : "no")",
            "Focused application: \(report.focusedApplication ?? "unknown")",
            "Accessibility tree empty: \(report.accessibilityTreeIsEmpty ? "yes" : "no")",
        ]

        if !report.accessibilityTrusted || report.accessibilityTreeIsEmpty {
            lines.append("")
            lines.append("If Accessibility is not working, grant permission to the terminal app running Jarvis:")
            lines.append("System Settings > Privacy & Security > Accessibility")
            lines.append("Then restart the terminal/cmux process and rerun `swift run jarvis doctor`.")
        }

        return lines.joined(separator: "\n")
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
