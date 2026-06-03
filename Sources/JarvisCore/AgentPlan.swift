import Foundation

public struct AgentPlan: Codable, Equatable, Sendable {
    public let summary: String
    public let steps: [AgentStep]

    public init(summary: String, steps: [AgentStep]) {
        self.summary = summary
        self.steps = steps
    }
}

public struct AgentStep: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let reason: String
    public let action: AgentAction

    public init(id: String, reason: String, action: AgentAction) {
        self.id = id
        self.reason = reason
        self.action = action
    }
}

