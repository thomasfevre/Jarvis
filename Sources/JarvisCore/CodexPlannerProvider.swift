import Foundation

public protocol CodexRunning: Sendable {
    func run(prompt: String) async throws -> String
}

public struct CodexPlannerProvider<Runner: CodexRunning>: PlanningProvider {
    private let runner: Runner
    private let decoder: JSONDecoder

    public init(runner: Runner, decoder: JSONDecoder = JSONDecoder()) {
        self.runner = runner
        self.decoder = decoder
    }

    public func plan(for request: PlanningRequest) async throws -> AgentPlan {
        let response = try await runner.run(prompt: Self.prompt(for: request))
        let json = Self.extractJSON(from: response)

        guard let data = json.data(using: .utf8) else {
            throw PlannerProviderError.invalidResponse(response)
        }

        do {
            return try decoder.decode(AgentPlan.self, from: data)
        } catch {
            throw PlannerProviderError.invalidResponse(response)
        }
    }

    static func prompt(for request: PlanningRequest) -> String {
        """
        You are the planner for Jarvis, a macOS computer-use agent.

        Convert the user's request and current screen observation into one ordered AgentPlan.
        Return only JSON matching this shape:
        {
          "summary": "short task summary",
          "steps": [
            {
              "id": "stable-kebab-case-id",
              "reason": "why this step is needed",
              "action": { "type": "openApplication", "name": "Notes" }
            }
          ]
        }

        Supported action objects:
        - { "type": "click", "x": 100, "y": 200, "label": "Button label" }
        - { "type": "typeText", "text": "text to type" }
        - { "type": "keyPress", "key": "return", "modifiers": ["cmd"], "label": "Submit" }
        - { "type": "openApplication", "name": "Application Name" }
        - { "type": "shell", "command": "command" }

        Prefer macOS UI actions over shell commands. Use shell only when the user explicitly asks
        for a command-line action. Jarvis will require confirmation before risky actions.

        User transcript:
        \(request.transcript)

        Focused application:
        \(request.observation.focusedApplication ?? "unknown")

        Screenshot description:
        \(request.observation.screenshotDescription ?? "not provided")

        Accessibility tree:
        \(request.observation.accessibilityTree)
        """
    }

    static func extractJSON(from response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
                lines.removeFirst()
            }
            if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
                lines.removeLast()
            }
            return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }
}

public struct CodexExecCommandRunner: CodexRunning {
    public static let outputSchema = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["summary", "steps"],
      "properties": {
        "summary": { "type": "string" },
        "steps": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "reason", "action"],
            "properties": {
              "id": { "type": "string" },
              "reason": { "type": "string" },
              "action": {
                "anyOf": [
                  {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "x", "y", "label"],
                    "properties": {
                      "type": { "type": "string", "const": "click" },
                      "x": { "type": "integer" },
                      "y": { "type": "integer" },
                      "label": { "type": ["string", "null"] }
                    }
                  },
                  {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "text"],
                    "properties": {
                      "type": { "type": "string", "const": "typeText" },
                      "text": { "type": "string" }
                    }
                  },
                  {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "key", "modifiers", "label"],
                    "properties": {
                      "type": { "type": "string", "const": "keyPress" },
                      "key": { "type": "string" },
                      "modifiers": {
                        "type": "array",
                        "items": { "type": "string" }
                      },
                      "label": { "type": ["string", "null"] }
                    }
                  },
                  {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "name"],
                    "properties": {
                      "type": { "type": "string", "const": "openApplication" },
                      "name": { "type": "string" }
                    }
                  },
                  {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "command"],
                    "properties": {
                      "type": { "type": "string", "const": "shell" },
                      "command": { "type": "string" }
                    }
                  }
                ]
              }
            }
          }
        }
      }
    }
    """

    private let codexExecutable: String

    public init(codexExecutable: String = "/usr/bin/env") {
        self.codexExecutable = codexExecutable
    }

    public func arguments(outputPath: String, schemaPath: String) -> [String] {
        [
            "exec",
            "--sandbox", "read-only",
            "--ephemeral",
            "--output-schema", schemaPath,
            "--output-last-message", outputPath,
            "-",
        ]
    }

    public func run(prompt: String) async throws -> String {
        let fileManager = FileManager.default
        let outputURL = fileManager.temporaryDirectory
            .appendingPathComponent("jarvis-codex-plan-\(UUID().uuidString).json")
        let schemaURL = fileManager.temporaryDirectory
            .appendingPathComponent("jarvis-codex-plan-schema-\(UUID().uuidString).json")
        defer { try? fileManager.removeItem(at: outputURL) }
        defer { try? fileManager.removeItem(at: schemaURL) }

        try Self.outputSchema.write(to: schemaURL, atomically: true, encoding: .utf8)

        let process = Process()
        if codexExecutable == "/usr/bin/env" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["codex"] + arguments(outputPath: outputURL.path, schemaPath: schemaURL.path)
        } else {
            process.executableURL = URL(fileURLWithPath: codexExecutable)
            process.arguments = arguments(outputPath: outputURL.path, schemaPath: schemaURL.path)
        }

        let stdin = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardError = stderr

        try process.run()
        if let data = prompt.data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
        }
        stdin.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "codex exec failed"
            throw PlannerProviderError.commandFailed(errorMessage)
        }

        return try String(contentsOf: outputURL, encoding: .utf8)
    }
}
