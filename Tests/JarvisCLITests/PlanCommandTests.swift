import Foundation
import Testing
import JarvisCore
@testable import JarvisCLI

@Test func planCommandParsesTranscriptArgument() throws {
    let command = try PlanCommand.parse(["plan", "Open Notes"])

    #expect(command.transcript == "Open Notes")
    #expect(command.execute == false)
}

@Test func planCommandParsesExecuteFlag() throws {
    let command = try PlanCommand.parse(["plan", "--execute", "Open Notes"])

    #expect(command.transcript == "Open Notes")
    #expect(command.execute == true)
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

@Test func planCommandRendersConfirmationRequired() throws {
    let step = AgentStep(
        id: "send",
        reason: "Send the message",
        action: .click(x: 10, y: 20, label: "Send")
    )

    let output = PlanCommand.renderExecutionResult(.confirmationRequired(step: step))

    #expect(output.contains("Confirmation required before step send"))
}
