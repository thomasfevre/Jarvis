import Testing
@testable import JarvisCore

@Test func executorStopsBeforeRiskyStepAndPreservesProgress() async throws {
    let plan = AgentPlan(
        summary: "Search and send",
        steps: [
            AgentStep(id: "open", reason: "Open app", action: .openApplication(name: "Mail")),
            AgentStep(id: "send", reason: "Send message", action: .click(x: 400, y: 40, label: "Send")),
        ]
    )
    let actionRunner = RecordingActionRunner()
    let executor = PlanExecutor(safetyGate: SafetyGate(), actionRunner: actionRunner)

    let result = try await executor.run(plan)

    #expect(result == .confirmationRequired(step: plan.steps[1]))
    #expect(await actionRunner.actions == [.openApplication(name: "Mail")])
}

@Test func executorCompletesPlanWhenAllStepsAreSafe() async throws {
    let plan = AgentPlan(
        summary: "Open and type",
        steps: [
            AgentStep(id: "open", reason: "Open app", action: .openApplication(name: "Notes")),
            AgentStep(id: "type", reason: "Enter text", action: .typeText("hello")),
        ]
    )
    let actionRunner = RecordingActionRunner()
    let executor = PlanExecutor(safetyGate: SafetyGate(), actionRunner: actionRunner)

    let result = try await executor.run(plan)

    #expect(result == .completed)
    #expect(await actionRunner.actions == [.openApplication(name: "Notes"), .typeText("hello")])
}

private actor RecordingActionRunner: ActionRunning {
    private(set) var actions: [AgentAction] = []

    func run(_ action: AgentAction) async throws {
        actions.append(action)
    }
}

