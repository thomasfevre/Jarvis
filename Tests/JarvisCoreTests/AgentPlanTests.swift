import Foundation
import Testing
@testable import JarvisCore

@Test func decodesPlannerJsonIntoOrderedSteps() throws {
    let data = Data("""
    {
      "summary": "Open Mail and draft a reply",
      "steps": [
        {
          "id": "focus-mail",
          "reason": "Bring Mail forward",
          "action": { "type": "openApplication", "name": "Mail" }
        },
        {
          "id": "click-compose",
          "reason": "Start a new email",
          "action": { "type": "click", "x": 42, "y": 84, "label": "Compose" }
        }
      ]
    }
    """.utf8)

    let plan = try JSONDecoder().decode(AgentPlan.self, from: data)

    #expect(plan.summary == "Open Mail and draft a reply")
    #expect(plan.steps.map(\.id) == ["focus-mail", "click-compose"])
    #expect(plan.steps[0].action == .openApplication(name: "Mail"))
    #expect(plan.steps[1].action == .click(x: 42, y: 84, label: "Compose"))
}

@Test func decodesClickElementPlannerAction() throws {
    let data = Data("""
    {
      "summary": "Click search",
      "steps": [
        {
          "id": "click-search",
          "reason": "Use the visible search field",
          "action": { "type": "clickElement", "label": "Search" }
        }
      ]
    }
    """.utf8)

    let plan = try JSONDecoder().decode(AgentPlan.self, from: data)

    #expect(plan.steps[0].action == .clickElement(label: "Search"))
}
