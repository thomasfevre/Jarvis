import Foundation
import JarvisCore

struct JarvisCommand {
    static func run() async {
        do {
            let command = try JarvisCLICommand.parse(Array(CommandLine.arguments.dropFirst()))

            switch command {
            case .doctor:
                print(DoctorCommand.render(await Self.doctorReport()))
            case .observe:
                print(ObserveCommand.render(await Self.currentObservation()))
            case let .plan(command):
                let provider = CodexPlannerProvider(runner: CodexExecCommandRunner())
                let observation = await Self.currentObservation()
                let plan = try await provider.plan(
                    for: PlanningRequest(
                        transcript: command.transcript,
                        observation: observation
                    )
                )
                let resolvedPlan = PlanCommand.resolveElementActions(
                    in: plan,
                    using: observation,
                    transcript: command.transcript
                )

                print(try PlanCommand.render(resolvedPlan))

                if command.execute {
                    let executor = PlanExecutor(safetyGate: SafetyGate(), actionRunner: MacOSActionRunner())
                    let result = try await executor.run(resolvedPlan)
                    print(PlanCommand.renderExecutionResult(result))
                }
            }
        } catch CLIError.usage {
            fputs("Usage: jarvis doctor | jarvis observe | jarvis plan [--execute] <instruction>\n", stderr)
            Foundation.exit(64)
        } catch {
            fputs("jarvis: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func currentObservation() async -> ScreenObservation {
        await MacOSAccessibilityObserver(visibleTextSource: MacOSVisionTextObservationSource()).observe()
    }

    static func doctorReport() async -> DoctorReport {
        let observation = await currentObservation()
        return DoctorReport(
            codexExecutable: CodexExecCommandRunner.defaultCodexExecutable(),
            accessibilityTrusted: MacOSAccessibilitySource.isProcessTrusted(),
            screenCaptureTrusted: MacOSVisionTextObservationSource.isScreenCaptureTrusted(),
            focusedApplication: observation.focusedApplication,
            accessibilityTreeIsEmpty: observation.accessibilityTree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

await JarvisCommand.run()
