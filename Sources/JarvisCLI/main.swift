import Foundation
import JarvisCore

struct JarvisCommand {
    static func run() async {
        do {
            let command = try JarvisCLICommand.parse(Array(CommandLine.arguments.dropFirst()))

            switch command {
            case .observe:
                print(ObserveCommand.render(Self.currentObservation()))
            case let .plan(command):
                let provider = CodexPlannerProvider(runner: CodexExecCommandRunner())
                let plan = try await provider.plan(
                    for: PlanningRequest(
                        transcript: command.transcript,
                        observation: Self.currentObservation()
                    )
                )

                print(try PlanCommand.render(plan))

                if command.execute {
                    let executor = PlanExecutor(safetyGate: SafetyGate(), actionRunner: MacOSActionRunner())
                    let result = try await executor.run(plan)
                    print(PlanCommand.renderExecutionResult(result))
                }
            }
        } catch CLIError.usage {
            fputs("Usage: jarvis observe | jarvis plan [--execute] <instruction>\n", stderr)
            Foundation.exit(64)
        } catch {
            fputs("jarvis: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func currentObservation() -> ScreenObservation {
        MacOSAccessibilityObserver().observe()
    }
}

await JarvisCommand.run()
