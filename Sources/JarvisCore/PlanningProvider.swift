import Foundation

public struct ScreenObservation: Equatable, Sendable {
    public let focusedApplication: String?
    public let accessibilityTree: String
    public let screenshotDescription: String?

    public init(focusedApplication: String?, accessibilityTree: String, screenshotDescription: String?) {
        self.focusedApplication = focusedApplication
        self.accessibilityTree = accessibilityTree
        self.screenshotDescription = screenshotDescription
    }
}

public struct PlanningRequest: Equatable, Sendable {
    public let transcript: String
    public let observation: ScreenObservation

    public init(transcript: String, observation: ScreenObservation) {
        self.transcript = transcript
        self.observation = observation
    }
}

public protocol PlanningProvider: Sendable {
    func plan(for request: PlanningRequest) async throws -> AgentPlan
}

public enum PlannerProviderError: Error, Equatable, Sendable {
    case invalidResponse(String)
    case commandFailed(String)
}

