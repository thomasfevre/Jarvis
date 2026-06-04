import Foundation
import Testing
import JarvisCore
@testable import JarvisCLI

@Test func planCommandParsesTranscriptArgument() throws {
    let command = try JarvisCLICommand.parse(["plan", "Open Notes"])

    #expect(command == .plan(PlanCommand(transcript: "Open Notes", execute: false)))
}

@Test func planCommandParsesExecuteFlag() throws {
    let command = try JarvisCLICommand.parse(["plan", "--execute", "Open Notes"])

    #expect(command == .plan(PlanCommand(transcript: "Open Notes", execute: true)))
}

@Test func observeCommandParses() throws {
    let command = try JarvisCLICommand.parse(["observe"])

    #expect(command == .observe)
}

@Test func planCommandRendersAgentPlanAsPrettyJSON() throws {
    let plan = AgentPlan(
        summary: "Open Notes",
        steps: [
            AgentStep(id: "open-notes", reason: "User asked for Notes", action: .openApplication(name: "Notes")),
        ]
    )

    let output = try PlanCommand.render(plan)

    #expect(output.contains("\"summary\" : \"Open Notes\""))
    #expect(output.contains("\"openApplication\""))
}

@Test func observeCommandRendersScreenObservation() {
    let output = ObserveCommand.render(
        ScreenObservation(
            focusedApplication: "Notes",
            accessibilityTree: "[button] New note",
            screenshotDescription: nil
        )
    )

    #expect(output.contains("Focused application: Notes"))
    #expect(output.contains("[button] New note"))
}

@Test func planCommandRendersConfirmationRequired() throws {
    let step = AgentStep(
        id: "send",
        reason: "Send the message",
        action: .click(x: 10, y: 20, label: "Send")
    )

    let output = PlanCommand.renderExecutionResult(.confirmationRequired(step: step))

    #expect(output.contains("Confirmation required before step send"))
}
