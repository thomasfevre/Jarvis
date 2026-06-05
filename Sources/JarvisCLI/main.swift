import AppKit
import Foundation
import JarvisCore

struct JarvisCommand {
    static func run() async {
        do {
            let command = try JarvisCLICommand.parse(Array(CommandLine.arguments.dropFirst()))

            switch command {
            case .doctor:
                print(DoctorCommand.render(await Self.doctorReport()))
            case let .observe(command):
                print(try await Self.renderObservation(command))
            case let .plan(command):
                let observation = await Self.currentObservation()
                let resolvedPlan: AgentPlan

                if let directPlan = PlanCommand.directVisibleClickPlan(
                    transcript: command.transcript,
                    observation: observation
                ) {
                    resolvedPlan = directPlan
                } else {
                    let provider = CodexPlannerProvider(runner: CodexExecCommandRunner())
                    let plan = try await provider.plan(
                        for: PlanningRequest(
                            transcript: command.transcript,
                            observation: observation
                        )
                    )
                    resolvedPlan = PlanCommand.resolveElementActions(
                        in: plan,
                        using: observation,
                        transcript: command.transcript
                    )
                }

                print(try PlanCommand.render(resolvedPlan))

                if command.execute {
                    let executor = PlanExecutor(safetyGate: SafetyGate(), actionRunner: MacOSActionRunner())
                    let result = try await executor.run(resolvedPlan)
                    print(PlanCommand.renderExecutionResult(result))
                }
            }
        } catch CLIError.usage {
            fputs("Usage: jarvis doctor | jarvis observe [--save-screenshot <path>] | jarvis plan [--execute] <instruction>\n", stderr)
            Foundation.exit(64)
        } catch {
            fputs("jarvis: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func currentObservation() async -> ScreenObservation {
        await MacOSAccessibilityObserver(visibleTextSource: MacOSVisionTextObservationSource()).observe()
    }

    static func renderObservation(_ command: ObserveCLICommand) async throws -> String {
        guard let screenshotPath = command.saveScreenshotPath else {
            return ObserveCommand.render(await currentObservation())
        }

        let screenshots = await MacOSVisionTextObservationSource.captureDisplayScreenshots()
        guard let firstScreenshot = screenshots.first else {
            return ObserveCommand.render(await currentObservation())
        }

        try saveScreenshot(firstScreenshot, to: screenshotPath)
        let observation = await MacOSAccessibilityObserver(
            visibleTextSource: MacOSVisionTextObservationSource(captureScreenshots: { screenshots })
        ).observe()

        return """
        Saved screenshot: \(screenshotPath)
        \(ObserveCommand.render(observation))
        """
    }

    static func saveScreenshot(_ screenshot: MacOSVisionTextObservationSource.Screenshot, to path: String) throws {
        if let pngData = screenshot.pngData {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.removeItem(at: url)
            try pngData.write(to: url, options: .atomic)
            return
        }

        try savePNG(screenshot.image, to: path)
    }

    static func savePNG(_ image: CGImage, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CLIError.cannotWriteScreenshot(path)
        }

        try data.write(to: url, options: .atomic)
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
