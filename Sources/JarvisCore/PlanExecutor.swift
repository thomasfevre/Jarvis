import Foundation

public protocol ActionRunning: Sendable {
    func run(_ action: AgentAction) async throws
}

public enum PlanExecutionResult: Equatable, Sendable {
    case completed
    case confirmationRequired(step: AgentStep)
}

public struct PlanExecutor: Sendable {
    private let safetyGate: SafetyGate
    private let actionRunner: any ActionRunning

    public init(safetyGate: SafetyGate, actionRunner: any ActionRunning) {
        self.safetyGate = safetyGate
        self.actionRunner = actionRunner
    }

    public func run(_ plan: AgentPlan) async throws -> PlanExecutionResult {
        for step in plan.steps {
            if safetyGate.requiresConfirmation(step.action) {
                return .confirmationRequired(step: step)
            }

            try await actionRunner.run(step.action)
        }

        return .completed
    }
}

