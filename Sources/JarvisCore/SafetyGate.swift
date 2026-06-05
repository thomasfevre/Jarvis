import Foundation

public struct SafetyGate: Sendable {
    private let riskyLabels: Set<String>
    private let riskyShellFragments: [String]

    public init(
        riskyLabels: Set<String> = [
            "buy", "checkout", "confirm", "delete", "install", "pay", "purchase",
            "remove", "run", "send", "submit", "transfer",
        ],
        riskyShellFragments: [String] = [
            "rm ", "rm\t", "sudo", "curl ", "chmod", "chown", "mv ", "git push",
        ]
    ) {
        self.riskyLabels = riskyLabels
        self.riskyShellFragments = riskyShellFragments
    }

    public func requiresConfirmation(_ action: AgentAction) -> Bool {
        switch action {
        case let .click(_, _, label):
            return containsRiskyLabel(label)
        case let .clickElement(label):
            return containsRiskyLabel(label)
        case let .keyPress(key, _, label):
            return key.lowercased() == "return" && containsRiskyLabel(label)
        case .shell:
            return true
        case .typeText, .openApplication:
            return false
        }
    }

    private func containsRiskyLabel(_ label: String?) -> Bool {
        guard let label else { return false }
        let normalized = label.lowercased()
        return riskyLabels.contains { normalized.contains($0) }
    }
}
