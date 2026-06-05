import Testing
@testable import JarvisCore

@Test func accessibilityObserverUsesInjectedSource() async {
    let observer = MacOSAccessibilityObserver(
        source: StubAccessibilitySource(
            snapshot: AccessibilityApplicationSnapshot(
                applicationName: "Notes",
                rootElement: AccessibilityElementSnapshot(
                    role: "AXWindow",
                    title: "Meeting Notes",
                    children: [
                        AccessibilityElementSnapshot(role: "AXTextArea", value: "Agenda"),
                    ]
                )
            )
        ),
        visibleTextSource: StubVisibleTextSource(
            visibleTexts: [
                VisibleTextObservation(text: "Obsidian", x: 47, y: 236, width: 72, height: 20, confidence: 0.94),
            ]
        )
    )

    let observation = await observer.observe()

    #expect(observation.focusedApplication == "Notes")
    #expect(observation.accessibilityTree == """
    AXWindow "Meeting Notes"
      AXTextArea value="Agenda"
    """)
    #expect(observation.screenshotDescription == "1 visible text region detected")
    #expect(observation.visibleTexts == [
        VisibleTextObservation(text: "Obsidian", x: 47, y: 236, width: 72, height: 20, confidence: 0.94),
    ])
}

@Test func accessibilityTreeRendererLimitsDepth() {
    let root = AccessibilityElementSnapshot(
        role: "AXWindow",
        title: "Root",
        children: [
            AccessibilityElementSnapshot(
                role: "AXGroup",
                title: "First",
                children: [
                    AccessibilityElementSnapshot(role: "AXButton", title: "Too Deep"),
                ]
            ),
        ]
    )

    #expect(MacOSAccessibilityObserver.renderAccessibilityTree(root, maxDepth: 1) == """
    AXWindow "Root"
      AXGroup "First"
    """)
}

@Test func accessibilityTreeRendererLimitsChildrenAndReportsOmittedCount() {
    let root = AccessibilityElementSnapshot(
        role: "AXWindow",
        children: [
            AccessibilityElementSnapshot(role: "AXButton", title: "One"),
            AccessibilityElementSnapshot(role: "AXButton", title: "Two"),
            AccessibilityElementSnapshot(role: "AXButton", title: "Three"),
        ]
    )

    #expect(MacOSAccessibilityObserver.renderAccessibilityTree(root, maxChildren: 2) == """
    AXWindow
      AXButton "One"
      AXButton "Two"
      ... 1 more children
    """)
}

@Test func accessibilityObserverReportsEmptyTreeWhenSourceCannotReadElements() async {
    let observer = MacOSAccessibilityObserver(
        source: StubAccessibilitySource(
            snapshot: AccessibilityApplicationSnapshot(applicationName: "Finder", rootElement: nil)
        )
    )

    let observation = await observer.observe()

    #expect(observation.focusedApplication == "Finder")
    #expect(observation.accessibilityTree == "")
}

private struct StubAccessibilitySource: AccessibilityObservationSource {
    let snapshot: AccessibilityApplicationSnapshot?

    func focusedApplicationSnapshot(maxDepth: Int, maxChildren: Int) -> AccessibilityApplicationSnapshot? {
        snapshot
    }
}

private struct StubVisibleTextSource: VisibleTextObservationSource {
    let visibleTexts: [VisibleTextObservation]

    func observeVisibleTexts() async -> [VisibleTextObservation] {
        visibleTexts
    }
}
