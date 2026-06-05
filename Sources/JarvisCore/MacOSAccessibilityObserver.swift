import AppKit
import ApplicationServices
import Foundation
import ScreenCaptureKit
import Vision

public protocol AccessibilityObservationSource: Sendable {
    func focusedApplicationSnapshot(maxDepth: Int, maxChildren: Int) -> AccessibilityApplicationSnapshot?
}

public protocol VisibleTextObservationSource: Sendable {
    func observeVisibleTexts() async -> [VisibleTextObservation]
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
    private let visibleTextSource: any VisibleTextObservationSource
    private let maxDepth: Int
    private let maxChildren: Int

    public init(
        source: any AccessibilityObservationSource = MacOSAccessibilitySource(),
        visibleTextSource: any VisibleTextObservationSource = EmptyVisibleTextObservationSource(),
        maxDepth: Int = 6,
        maxChildren: Int = 80
    ) {
        self.source = source
        self.visibleTextSource = visibleTextSource
        self.maxDepth = max(0, maxDepth)
        self.maxChildren = max(0, maxChildren)
    }

    public func observe() async -> ScreenObservation {
        let visibleTexts = await visibleTextSource.observeVisibleTexts()

        guard let snapshot = source.focusedApplicationSnapshot(maxDepth: maxDepth, maxChildren: maxChildren) else {
            return ScreenObservation(
                focusedApplication: nil,
                accessibilityTree: "",
                screenshotDescription: Self.screenshotDescription(for: visibleTexts),
                visibleTexts: visibleTexts
            )
        }

        return ScreenObservation(
            focusedApplication: snapshot.applicationName,
            accessibilityTree: snapshot.rootElement.map {
                Self.renderAccessibilityTree($0, maxDepth: maxDepth, maxChildren: maxChildren)
            } ?? "",
            screenshotDescription: Self.screenshotDescription(for: visibleTexts),
            visibleTexts: visibleTexts
        )
    }

    private static func screenshotDescription(for visibleTexts: [VisibleTextObservation]) -> String? {
        guard !visibleTexts.isEmpty else { return nil }
        if visibleTexts.count == 1 {
            return "1 visible text region detected"
        }
        return "\(visibleTexts.count) visible text regions detected"
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

public struct EmptyVisibleTextObservationSource: VisibleTextObservationSource {
    public init() {}

    public func observeVisibleTexts() async -> [VisibleTextObservation] {
        []
    }
}

public struct MacOSVisionTextObservationSource: VisibleTextObservationSource {
    public struct Screenshot: Sendable {
        public let image: CGImage
        public let originX: Int
        public let originY: Int

        public init(image: CGImage, originX: Int = 0, originY: Int = 0) {
            self.image = image
            self.originX = originX
            self.originY = originY
        }
    }

    private let captureScreenshots: @Sendable () async -> [Screenshot]

    public init(captureScreenshots: @escaping @Sendable () async -> [Screenshot] = {
        await Self.captureDisplayScreenshots()
    }) {
        self.captureScreenshots = captureScreenshots
    }

    public func observeVisibleTexts() async -> [VisibleTextObservation] {
        let screenshots = await captureScreenshots()
        guard !screenshots.isEmpty else { return [] }

        return screenshots.flatMap(Self.recognizeTexts(in:))
    }

    public static func recognizeTexts(in screenshot: Screenshot) -> [VisibleTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: screenshot.image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let width = CGFloat(screenshot.image.width)
        let height = CGFloat(screenshot.image.height)

        return (request.results ?? [])
            .compactMap { observation -> VisibleTextObservation? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let bounds = observation.boundingBox
                return VisibleTextObservation(
                    text: candidate.string,
                    x: screenshot.originX + Int((bounds.minX * width).rounded()),
                    y: screenshot.originY + Int(((1 - bounds.maxY) * height).rounded()),
                    width: Int((bounds.width * width).rounded()),
                    height: Int((bounds.height * height).rounded()),
                    confidence: Double(candidate.confidence)
                )
            }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public static func isScreenCaptureTrusted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func captureDisplayScreenshots() async -> [Screenshot] {
        guard isScreenCaptureTrusted() else { return [] }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = displayContainingFrontmostWindow(from: content.displays)
                ?? content.displays.first else {
                return []
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = true

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let bounds = CGDisplayBounds(display.displayID)
            return [
                Screenshot(
                    image: image,
                    originX: Int(bounds.origin.x.rounded()),
                    originY: Int(bounds.origin.y.rounded())
                ),
            ]
        } catch {
            return []
        }
    }

    private static func displayContainingFrontmostWindow(from displays: [SCDisplay]) -> SCDisplay? {
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windowBounds = frontmostWindowBounds(processIdentifier: frontmostPID)
        else {
            return nil
        }

        let center = CGPoint(x: windowBounds.midX, y: windowBounds.midY)
        return displays.first { display in
            CGDisplayBounds(display.displayID).contains(center)
        }
    }

    private static func frontmostWindowBounds(processIdentifier: pid_t) -> CGRect? {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return windowInfo
            .compactMap { info -> CGRect? in
                guard info[kCGWindowOwnerPID as String] as? pid_t == processIdentifier,
                      (info[kCGWindowLayer as String] as? Int) == 0,
                      let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any]
                else {
                    return nil
                }

                var rect = CGRect.zero
                guard CGRectMakeWithDictionaryRepresentation(boundsDictionary as CFDictionary, &rect),
                      rect.width > 0,
                      rect.height > 0
                else {
                    return nil
                }

                return rect
            }
            .max { $0.width * $0.height < $1.width * $1.height }
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

    public static func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public func focusedApplicationSnapshot(maxDepth: Int, maxChildren: Int) -> AccessibilityApplicationSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        guard Self.isProcessTrusted() else {
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
