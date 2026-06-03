import Foundation

public enum AgentAction: Equatable, Sendable {
    case click(x: Int, y: Int, label: String?)
    case typeText(String)
    case keyPress(key: String, modifiers: [String], label: String?)
    case openApplication(name: String)
    case shell(command: String)
}

extension AgentAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case x
        case y
        case label
        case text
        case key
        case modifiers
        case name
        case command
    }

    private enum ActionType: String, Codable {
        case click
        case typeText
        case keyPress
        case openApplication
        case shell
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)

        switch type {
        case .click:
            self = .click(
                x: try container.decode(Int.self, forKey: .x),
                y: try container.decode(Int.self, forKey: .y),
                label: try container.decodeIfPresent(String.self, forKey: .label)
            )
        case .typeText:
            self = .typeText(try container.decode(String.self, forKey: .text))
        case .keyPress:
            self = .keyPress(
                key: try container.decode(String.self, forKey: .key),
                modifiers: try container.decodeIfPresent([String].self, forKey: .modifiers) ?? [],
                label: try container.decodeIfPresent(String.self, forKey: .label)
            )
        case .openApplication:
            self = .openApplication(name: try container.decode(String.self, forKey: .name))
        case .shell:
            self = .shell(command: try container.decode(String.self, forKey: .command))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .click(x, y, label):
            try container.encode(ActionType.click, forKey: .type)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encodeIfPresent(label, forKey: .label)
        case let .typeText(text):
            try container.encode(ActionType.typeText, forKey: .type)
            try container.encode(text, forKey: .text)
        case let .keyPress(key, modifiers, label):
            try container.encode(ActionType.keyPress, forKey: .type)
            try container.encode(key, forKey: .key)
            try container.encode(modifiers, forKey: .modifiers)
            try container.encodeIfPresent(label, forKey: .label)
        case let .openApplication(name):
            try container.encode(ActionType.openApplication, forKey: .type)
            try container.encode(name, forKey: .name)
        case let .shell(command):
            try container.encode(ActionType.shell, forKey: .type)
            try container.encode(command, forKey: .command)
        }
    }
}

