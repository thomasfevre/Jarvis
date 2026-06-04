import Testing
@testable import JarvisCore

@Test func macOSActionRunnerOpensApplicationsByName() async throws {
    let openedApplications = OpenedApplications()
    let inputEvents = InputEvents()
    let runner = MacOSActionRunner { name in
        await openedApplications.record(name)
        return true
    } performInputCommand: { command in
        await inputEvents.record(command)
    }

    try await runner.run(.openApplication(name: "Notes"))

    #expect(await openedApplications.names == ["Notes"])
    #expect(await inputEvents.commands == [])
}

@Test func macOSActionRunnerReportsMissingApplications() async throws {
    let runner = MacOSActionRunner(
        openApplicationByName: { _ in false },
        performInputCommand: { _ in }
    )

    await #expect(throws: MacOSActionRunner.Error.applicationNotFound(name: "MissingApp")) {
        try await runner.run(.openApplication(name: "MissingApp"))
    }
}

@Test func macOSActionRunnerClicksUsingMouseDownAndMouseUpEvents() async throws {
    let inputEvents = InputEvents()
    let runner = MacOSActionRunner(
        openApplicationByName: { _ in true },
        performInputCommand: { command in
            await inputEvents.record(command)
        }
    )

    try await runner.run(.click(x: 120, y: 240, label: "Send"))

    #expect(await inputEvents.commands == [
        .mouseDown(x: 120, y: 240),
        .mouseUp(x: 120, y: 240),
    ])
}

@Test func macOSActionRunnerTypesTextUsingPasteboardThenCommandV() async throws {
    let inputEvents = InputEvents()
    let runner = MacOSActionRunner(
        openApplicationByName: { _ in true },
        performInputCommand: { command in
            await inputEvents.record(command)
        }
    )

    try await runner.run(.typeText("hello"))

    #expect(await inputEvents.commands == [
        .setPasteboardString("hello"),
        .keyDown(keyCode: 9, flags: MacOSInputFlags.command),
        .keyUp(keyCode: 9, flags: MacOSInputFlags.command),
    ])
}

@Test func macOSActionRunnerPressesKeysUsingKeyDownAndKeyUpEvents() async throws {
    let inputEvents = InputEvents()
    let runner = MacOSActionRunner(
        openApplicationByName: { _ in true },
        performInputCommand: { command in
            await inputEvents.record(command)
        }
    )

    try await runner.run(.keyPress(key: "return", modifiers: ["cmd", "shift"], label: "Submit"))

    #expect(await inputEvents.commands == [
        .keyDown(keyCode: 36, flags: [.command, .shift]),
        .keyUp(keyCode: 36, flags: [.command, .shift]),
    ])
}

@Test func macOSActionRunnerRejectsUnknownKeys() async throws {
    let runner = MacOSActionRunner(
        openApplicationByName: { _ in true },
        performInputCommand: { _ in }
    )

    await #expect(throws: MacOSActionRunner.Error.unsupportedKey("launch")) {
        try await runner.run(.keyPress(key: "launch", modifiers: [], label: nil))
    }
}

@Test func macOSActionRunnerRejectsShellActions() async throws {
    let runner = MacOSActionRunner(
        openApplicationByName: { _ in true },
        performInputCommand: { _ in }
    )

    await #expect(throws: MacOSActionRunner.Error.unsupportedAction(.shell(command: "date"))) {
        try await runner.run(.shell(command: "date"))
    }
}

private actor OpenedApplications {
    private(set) var names: [String] = []

    func record(_ name: String) {
        names.append(name)
    }
}

private actor InputEvents {
    private(set) var commands: [MacOSInputCommand] = []

    func record(_ command: MacOSInputCommand) {
        commands.append(command)
    }
}
