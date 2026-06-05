import Foundation

public struct VisibleTextObservation: Equatable, Sendable {
    public let text: String
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let confidence: Double

    public init(text: String, x: Int, y: Int, width: Int, height: Int, confidence: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.confidence = confidence
    }
}

public struct ScreenObservation: Equatable, Sendable {
    public let focusedApplication: String?
    public let accessibilityTree: String
    public let screenshotDescription: String?
    public let visibleTexts: [VisibleTextObservation]

    public init(
        focusedApplication: String?,
        accessibilityTree: String,
        screenshotDescription: String?,
        visibleTexts: [VisibleTextObservation] = []
    ) {
        self.focusedApplication = focusedApplication
        self.accessibilityTree = accessibilityTree
        self.screenshotDescription = screenshotDescription
        self.visibleTexts = visibleTexts
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
