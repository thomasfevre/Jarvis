import Foundation
import JarvisCore

struct JarvisCommand {
    static func run() async {
        do {
            let command = try PlanCommand.parse(Array(CommandLine.arguments.dropFirst()))
            let provider = CodexPlannerProvider(runner: CodexExecCommandRunner())
            let plan = try await provider.plan(
                for: PlanningRequest(
                    transcript: command.transcript,
                    observation: ScreenObservation(
                        focusedApplication: nil,
                        accessibilityTree: "No accessibility observation is wired yet.",
                        screenshotDescription: "No screenshot observation is wired yet."
                    )
                )
            )

            print(try PlanCommand.render(plan))

            if command.execute {
                let executor = PlanExecutor(safetyGate: SafetyGate(), actionRunner: MacOSActionRunner())
                let result = try await executor.run(plan)
                print(PlanCommand.renderExecutionResult(result))
            }
        } catch CLIError.usage {
            fputs("Usage: jarvis plan [--execute] <instruction>\n", stderr)
            Foundation.exit(64)
        } catch {
            fputs("jarvis: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }
}

await JarvisCommand.run()
