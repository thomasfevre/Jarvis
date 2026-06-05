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
            guard case let .clickElement(label) = step.action else {
                return step
            }

            if let click = clickAction(for: label, in: observation.accessibilityTree)
                ?? clickAction(for: label, in: observation.visibleTexts) {
                return AgentStep(id: step.id, reason: step.reason, action: click)
            }

            return step
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

    private static func clickAction(for label: String, in visibleTexts: [VisibleTextObservation]) -> AgentAction? {
        guard let text = bestVisibleTextMatch(for: label, in: visibleTexts) else { return nil }

        return .click(
            x: text.x + text.width / 2,
            y: text.y + text.height / 2,
            label: text.text
        )
    }

    private static func bestVisibleTextMatch(
        for label: String,
        in visibleTexts: [VisibleTextObservation]
    ) -> VisibleTextObservation? {
        visibleTexts
            .compactMap { text -> (text: VisibleTextObservation, score: Double)? in
                let score = matchScore(label: label, text: text.text)
                guard score > 0 else { return nil }
                return (text, score)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.text.confidence > $1.text.confidence
                }
                return $0.score > $1.score
            }
            .first?
            .text
    }

    private static func matchScore(label: String, text: String) -> Double {
        let normalizedLabel = normalizedSearchString(label)
        let normalizedText = normalizedSearchString(text)
        guard !normalizedLabel.isEmpty, !normalizedText.isEmpty else { return 0 }

        if normalizedLabel == normalizedText { return 1.0 }
        if normalizedLabel.contains(normalizedText) || normalizedText.contains(normalizedLabel) { return 0.9 }

        let labelTokens = Set(normalizedLabel.split(separator: " ").map(String.init))
        let textTokens = Set(normalizedText.split(separator: " ").map(String.init))
        guard !labelTokens.isEmpty, !textTokens.isEmpty else { return 0 }

        let overlap = labelTokens.intersection(textTokens).count
        guard overlap > 0 else { return 0 }
        return Double(overlap) / Double(max(labelTokens.count, textTokens.count))
    }

    private static func normalizedSearchString(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
    public let screenCaptureTrusted: Bool
    public let focusedApplication: String?
    public let accessibilityTreeIsEmpty: Bool

    public init(
        codexExecutable: String,
        accessibilityTrusted: Bool,
        screenCaptureTrusted: Bool,
        focusedApplication: String?,
        accessibilityTreeIsEmpty: Bool
    ) {
        self.codexExecutable = codexExecutable
        self.accessibilityTrusted = accessibilityTrusted
        self.screenCaptureTrusted = screenCaptureTrusted
        self.focusedApplication = focusedApplication
        self.accessibilityTreeIsEmpty = accessibilityTreeIsEmpty
    }
}

public enum DoctorCommand {
    public static func render(_ report: DoctorReport) -> String {
        var lines = [
            "Codex executable: \(report.codexExecutable)",
            "Accessibility trusted: \(report.accessibilityTrusted ? "yes" : "no")",
            "Screen Recording trusted: \(report.screenCaptureTrusted ? "yes" : "no")",
            "Focused application: \(report.focusedApplication ?? "unknown")",
            "Accessibility tree empty: \(report.accessibilityTreeIsEmpty ? "yes" : "no")",
        ]

        if !report.accessibilityTrusted || !report.screenCaptureTrusted || report.accessibilityTreeIsEmpty {
            lines.append("")
            lines.append("If Accessibility is not working, grant Accessibility permission to the terminal app running Jarvis:")
            lines.append("System Settings > Privacy & Security > Accessibility")
            lines.append("")
            lines.append("If visible screenshot text is missing, grant Screen Recording permission to the terminal app running Jarvis:")
            lines.append("System Settings > Privacy & Security > Screen & System Audio Recording")
            lines.append("Then restart the terminal/cmux process and rerun `swift run jarvis doctor`.")
        }

        return lines.joined(separator: "\n")
    }
}

public enum ObserveCommand {
    public static func render(_ observation: ScreenObservation) -> String {
        let tree = observation.accessibilityTree.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleText = renderVisibleTexts(observation.visibleTexts)
        if tree.isEmpty {
            return """
            Focused application: \(observation.focusedApplication ?? "unknown")

            Accessibility tree:
            No Accessibility elements were returned.

            Visible text:
            \(visibleText)

            If this is unexpected, grant Accessibility permission to the terminal app running Jarvis:
            System Settings > Privacy & Security > Accessibility
            """
        }

        return """
        Focused application: \(observation.focusedApplication ?? "unknown")

        Accessibility tree:
        \(tree)

        Visible text:
        \(visibleText)
        """
    }

    private static func renderVisibleTexts(_ visibleTexts: [VisibleTextObservation]) -> String {
        guard !visibleTexts.isEmpty else { return "No screenshot text was detected." }

        return visibleTexts
            .map { text in
                #""\#(text.text)" bounds=(\#(text.x),\#(text.y),\#(text.width),\#(text.height)) confidence=\#(String(format: "%.2f", text.confidence))"#
            }
            .joined(separator: "\n")
    }
}

public enum CLIError: Error, Equatable {
    case usage
}
