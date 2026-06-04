import Testing
@testable import JarvisCore

@Test func macOSActionRunnerOpensApplicationsByName() async throws {
    let openedApplications = OpenedApplications()
    let runner = MacOSActionRunner { name in
        await openedApplications.record(name)
        return true
    }

    try await runner.run(.openApplication(name: "Notes"))

    #expect(await openedApplications.names == ["Notes"])
}

@Test func macOSActionRunnerReportsMissingApplications() async throws {
    let runner = MacOSActionRunner { _ in false }

    await #expect(throws: MacOSActionRunner.Error.applicationNotFound(name: "MissingApp")) {
        try await runner.run(.openApplication(name: "MissingApp"))
    }
}

@Test func macOSActionRunnerRejectsUnsupportedActions() async throws {
    let runner = MacOSActionRunner { _ in true }

    await #expect(throws: MacOSActionRunner.Error.unsupportedAction(.typeText("hello"))) {
        try await runner.run(.typeText("hello"))
    }
}

private actor OpenedApplications {
    private(set) var names: [String] = []

    func record(_ name: String) {
        names.append(name)
    }
}
