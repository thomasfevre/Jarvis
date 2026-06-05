import Foundation
import Testing
@testable import JarvisCore

@Test func codexPlannerBuildsPromptAndDecodesPlan() async throws {
    let runner = StubCodexRunner(response: """
    ```json
    {
      "summary": "Open Notes",
      "steps": [
        {
          "id": "open-notes",
          "reason": "The user asked to use Notes",
          "action": { "type": "openApplication", "name": "Notes" }
        }
      ]
    }
    ```
    """)
    let provider = CodexPlannerProvider(runner: runner)

    let plan = try await provider.plan(
        for: PlanningRequest(
            transcript: "Open Notes",
            observation: ScreenObservation(
                focusedApplication: "Finder",
                accessibilityTree: "[button] Notes",
                screenshotDescription: "Desktop with Finder open",
                visibleTexts: [
                    VisibleTextObservation(text: "Obsidian", x: 47, y: 236, width: 72, height: 20, confidence: 0.94),
                ]
            )
        )
    )

    #expect(plan == AgentPlan(
        summary: "Open Notes",
        steps: [
            AgentStep(
                id: "open-notes",
                reason: "The user asked to use Notes",
                action: .openApplication(name: "Notes")
            ),
        ]
    ))
    #expect(await runner.lastPrompt?.contains("Open Notes") == true)
    #expect(await runner.lastPrompt?.contains("Finder") == true)
    #expect(await runner.lastPrompt?.contains(#""Obsidian" bounds=(47,236,72,20)"#) == true)
    #expect(await runner.lastPrompt?.contains("Return only JSON") == true)
}

@Test func codexExecRunnerUsesSafeNonInteractiveArguments() {
    let runner = CodexExecCommandRunner(codexExecutable: "/usr/local/bin/codex")

    #expect(runner.arguments(outputPath: "/tmp/plan.json", schemaPath: "/tmp/schema.json") == [
        "exec",
        "--sandbox", "read-only",
        "--ephemeral",
        "--output-schema", "/tmp/schema.json",
        "--output-last-message", "/tmp/plan.json",
        "-",
    ])
}

@Test func codexExecRunnerUsesExplicitExecutableWithoutEnvWrapper() throws {
    let launch = try CodexExecCommandRunner.launchConfiguration(
        codexExecutable: "/Applications/Codex.app/Contents/Resources/codex",
        outputPath: "/tmp/plan.json",
        schemaPath: "/tmp/schema.json"
    )

    #expect(launch.executablePath == "/Applications/Codex.app/Contents/Resources/codex")
    #expect(launch.arguments.first == "exec")
}

@Test func codexExecRunnerFallsBackToEnvWhenExecutableIsNotAbsolute() throws {
    let launch = try CodexExecCommandRunner.launchConfiguration(
        codexExecutable: "codex",
        outputPath: "/tmp/plan.json",
        schemaPath: "/tmp/schema.json"
    )

    #expect(launch.executablePath == "/usr/bin/env")
    #expect(launch.arguments.prefix(2) == ["codex", "exec"])
}

@Test func codexExecRunnerSchemaDescribesAgentPlan() throws {
    let schema = try JSONSerialization.jsonObject(with: Data(CodexExecCommandRunner.outputSchema.utf8)) as? [String: Any]

    #expect(schema?["type"] as? String == "object")
    #expect((schema?["required"] as? [String]) == ["summary", "steps"])

    let properties = try #require(schema?["properties"] as? [String: Any])
    let steps = try #require(properties["steps"] as? [String: Any])
    let items = try #require(steps["items"] as? [String: Any])
    let stepProperties = try #require(items["properties"] as? [String: Any])
    let action = try #require(stepProperties["action"] as? [String: Any])
    let actionVariants = try #require(action["anyOf"] as? [[String: Any]])
    #expect(actionVariants.count == 6)
    #expect(actionVariants.allSatisfy { $0["additionalProperties"] as? Bool == false })
}

@Test func codexPlannerReportsInvalidPlannerOutput() async {
    let provider = CodexPlannerProvider(runner: StubCodexRunner(response: "not json"))

    await #expect(throws: PlannerProviderError.self) {
        _ = try await provider.plan(
            for: PlanningRequest(
                transcript: "Open Notes",
                observation: ScreenObservation(focusedApplication: nil, accessibilityTree: "", screenshotDescription: nil)
            )
        )
    }
}

private actor StubCodexRunner: CodexRunning {
    private let response: String
    private(set) var lastPrompt: String?

    init(response: String) {
        self.response = response
    }

    func run(prompt: String) async throws -> String {
        lastPrompt = prompt
        return response
    }
}
