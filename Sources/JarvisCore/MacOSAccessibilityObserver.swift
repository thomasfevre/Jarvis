import AppKit
import ApplicationServices
import Foundation

public protocol AccessibilityObservationSource: Sendable {
    func focusedApplicationSnapshot(maxDepth: Int, maxChildren: Int) -> AccessibilityApplicationSnapshot?
}

public struct AccessibilityApplicationSnapshot: Equatable, Sendable {
    public let applicationName: String?
    public let rootElement: AccessibilityElementSnapshot?

    public init(applicationName: String?, rootElement: AccessibilityElementSnapshot?) {
        self.applicationName = applicationName
        self.rootElement = rootElement
    }
}

public struct AccessibilityElementSnapshot: Equatable, Sendable {
    public let role: String
    public let title: String?
    public let value: String?
    public let label: String?
    public let x: Double?
    public let y: Double?
    public let width: Double?
    public let height: Double?
    public let children: [AccessibilityElementSnapshot]

    public init(
        role: String,
        title: String? = nil,
        value: String? = nil,
        label: String? = nil,
        x: Double? = nil,
        y: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        children: [AccessibilityElementSnapshot] = []
    ) {
        self.role = role
        self.title = title
        self.value = value
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.children = children
    }
}

public struct MacOSAccessibilityObserver: Sendable {
    private let source: any AccessibilityObservationSource
    private let maxDepth: Int
    private let maxChildren: Int

    public init(
        source: any AccessibilityObservationSource = MacOSAccessibilitySource(),
        maxDepth: Int = 6,
        maxChildren: Int = 80
    ) {
        self.source = source
        self.maxDepth = max(0, maxDepth)
        self.maxChildren = max(0, maxChildren)
    }

    public func observe() -> ScreenObservation {
        guard let snapshot = source.focusedApplicationSnapshot(maxDepth: maxDepth, maxChildren: maxChildren) else {
            return ScreenObservation(
                focusedApplication: nil,
                accessibilityTree: "",
                screenshotDescription: nil
            )
        }

        return ScreenObservation(
            focusedApplication: snapshot.applicationName,
            accessibilityTree: snapshot.rootElement.map {
                Self.renderAccessibilityTree($0, maxDepth: maxDepth, maxChildren: maxChildren)
            } ?? "",
            screenshotDescription: nil
        )
    }

    public static func renderAccessibilityTree(
        _ root: AccessibilityElementSnapshot,
        maxDepth: Int = 6,
        maxChildren: Int = 80
    ) -> String {
        var lines: [String] = []
        render(root, depth: 0, maxDepth: max(0, maxDepth), maxChildren: max(0, maxChildren), lines: &lines)
        return lines.joined(separator: "\n")
    }

    private static func render(
        _ element: AccessibilityElementSnapshot,
        depth: Int,
        maxDepth: Int,
        maxChildren: Int,
        lines: inout [String]
    ) {
        let indent = String(repeating: "  ", count: depth)
        lines.append("\(indent)\(element.renderedLine)")

        guard depth < maxDepth else { return }

        let visibleChildren = element.children.prefix(maxChildren)
        for child in visibleChildren {
            render(child, depth: depth + 1, maxDepth: maxDepth, maxChildren: maxChildren, lines: &lines)
        }

        let omitted = element.children.count - visibleChildren.count
        if omitted > 0 {
            lines.append("\(indent)  ... \(omitted) more children")
        }
    }
}

private extension AccessibilityElementSnapshot {
    var renderedLine: String {
        var parts = [role]

        if let title, !title.isEmpty {
            parts.append("\"\(title)\"")
        }
        if let label, !label.isEmpty, label != title {
            parts.append("label=\"\(label)\"")
        }
        if let value, !value.isEmpty {
            parts.append("value=\"\(value)\"")
        }
        if let x, let y, let width, let height {
            parts.append("bounds=(\(Int(x)),\(Int(y)),\(Int(width)),\(Int(height)))")
        }

        return parts.joined(separator: " ")
    }
}

public struct MacOSAccessibilitySource: AccessibilityObservationSource {
    public init() {}

    public func focusedApplicationSnapshot(maxDepth: Int, maxChildren: Int) -> AccessibilityApplicationSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        guard AXIsProcessTrusted() else {
            return AccessibilityApplicationSnapshot(
                applicationName: app.localizedName,
                rootElement: AccessibilityElementSnapshot(
                    role: "AccessibilityPermissionRequired",
                    value: "Grant Accessibility permission to the terminal app running Jarvis, then rerun jarvis observe."
                )
            )
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedElement: AnyObject?
        let focusedElementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        var focusedWindow: AnyObject?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        let rootAXElement: AXUIElement
        if focusedElementResult == .success, let focusedElement {
            rootAXElement = focusedElement as! AXUIElement
        } else if focusedWindowResult == .success, let focusedWindow {
            rootAXElement = focusedWindow as! AXUIElement
        } else {
            rootAXElement = appElement
        }

        let rootElement = Self.snapshot(rootAXElement, depth: 0, maxDepth: maxDepth, maxChildren: maxChildren)
        let fallbackRootElement = rootElement?.isUsefulForPlanning == true
            ? rootElement
            : Self.snapshot(appElement, depth: 0, maxDepth: maxDepth, maxChildren: maxChildren)

        return AccessibilityApplicationSnapshot(
            applicationName: app.localizedName,
            rootElement: fallbackRootElement
        )
    }

    private static func snapshot(
        _ element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        maxChildren: Int
    ) -> AccessibilityElementSnapshot? {
        guard depth <= maxDepth else { return nil }

        let role = stringAttribute(element, kAXRoleAttribute) ?? "AXUnknown"
        let title = stringAttribute(element, kAXTitleAttribute)
        let value = stringAttribute(element, kAXValueAttribute)
        let label = stringAttribute(element, kAXDescriptionAttribute)
        let bounds = bounds(of: element)

        let children = depth < maxDepth
            ? childElements(of: element)
                .prefix(maxChildren)
                .compactMap { snapshot($0, depth: depth + 1, maxDepth: maxDepth, maxChildren: maxChildren) }
            : []

        return AccessibilityElementSnapshot(
            role: role,
            title: title,
            value: value,
            label: label,
            x: bounds.map { Double($0.origin.x) },
            y: bounds.map { Double($0.origin.y) },
            width: bounds.map { Double($0.size.width) },
            height: bounds.map { Double($0.size.height) },
            children: children
        )
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private static func childElements(of element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
           let children = value as? [AXUIElement],
           !children.isEmpty {
            return children
        }

        if AXUIElementCopyAttributeValue(element, kAXContentsAttribute as CFString, &value) == .success,
           let contents = value as? [AXUIElement] {
            return contents
        }

        return []
    }

    private static func bounds(of element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              positionValue != nil,
              sizeValue != nil
        else {
            return nil
        }

        let positionAX = positionValue as! AXValue
        let sizeAX = sizeValue as! AXValue
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAX, .cgPoint, &point),
              AXValueGetValue(sizeAX, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }
}

private extension AccessibilityElementSnapshot {
    var isUsefulForPlanning: Bool {
        role != "AXUnknown" || title != nil || value != nil || label != nil || !children.isEmpty
    }
}
