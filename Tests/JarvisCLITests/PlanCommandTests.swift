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

@Test func doctorCommandParses() throws {
    let command = try JarvisCLICommand.parse(["doctor"])

    #expect(command == .doctor)
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

@Test func observeCommandRendersHelpWhenAccessibilityTreeIsEmpty() {
    let output = ObserveCommand.render(
        ScreenObservation(
            focusedApplication: "Terminal",
            accessibilityTree: "",
            screenshotDescription: nil
        )
    )

    #expect(output.contains("No Accessibility elements were returned."))
    #expect(output.contains("System Settings > Privacy & Security > Accessibility"))
}

@Test func doctorCommandRendersDiagnostics() {
    let report = DoctorReport(
        codexExecutable: "/Applications/Codex.app/Contents/Resources/codex",
        accessibilityTrusted: false,
        focusedApplication: "cmux",
        accessibilityTreeIsEmpty: true
    )

    let output = DoctorCommand.render(report)

    #expect(output.contains("Codex executable: /Applications/Codex.app/Contents/Resources/codex"))
    #expect(output.contains("Accessibility trusted: no"))
    #expect(output.contains("Focused application: cmux"))
    #expect(output.contains("System Settings > Privacy & Security > Accessibility"))
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

@Test func planCommandResolvesClickElementFromAccessibilityBounds() throws {
    let plan = AgentPlan(
        summary: "Click search",
        steps: [
            AgentStep(id: "click-search", reason: "Use search", action: .clickElement(label: "Search")),
        ]
    )
    let observation = ScreenObservation(
        focusedApplication: "Browser",
        accessibilityTree: #"AXTextField "Search" bounds=(10,20,200,40)"#,
        screenshotDescription: nil
    )

    let resolved = PlanCommand.resolveElementActions(in: plan, using: observation)

    #expect(resolved.steps[0].action == .click(x: 110, y: 40, label: "Search"))
}

@Test func planCommandLeavesUnresolvedClickElementInPlace() throws {
    let plan = AgentPlan(
        summary: "Click search",
        steps: [
            AgentStep(id: "click-search", reason: "Use search", action: .clickElement(label: "Search")),
        ]
    )
    let observation = ScreenObservation(focusedApplication: "Browser", accessibilityTree: "AXButton \"Other\"", screenshotDescription: nil)

    let resolved = PlanCommand.resolveElementActions(in: plan, using: observation)

    #expect(resolved.steps[0].action == .clickElement(label: "Search"))
}
