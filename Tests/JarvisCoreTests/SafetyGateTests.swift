import Testing
@testable import JarvisCore

@Test func riskyActionsRequireConfirmation() {
    let gate = SafetyGate()

    #expect(gate.requiresConfirmation(.click(x: 100, y: 200, label: "Send")) == true)
    #expect(gate.requiresConfirmation(.keyPress(key: "return", modifiers: [], label: "Submit")) == true)
    #expect(gate.requiresConfirmation(.shell(command: "rm -rf ~/Downloads")) == true)
}

@Test func routineNavigationDoesNotRequireConfirmation() {
    let gate = SafetyGate()

    #expect(gate.requiresConfirmation(.click(x: 10, y: 20, label: "Search field")) == false)
    #expect(gate.requiresConfirmation(.typeText("hello")) == false)
    #expect(gate.requiresConfirmation(.keyPress(key: "tab", modifiers: [], label: nil)) == false)
}

