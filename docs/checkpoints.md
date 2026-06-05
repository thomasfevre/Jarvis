# Checkpoints

This file is the running project log. Update it after each meaningful step so
future work can restart from the current state without rediscovering context.

## 2026-06-04 - Bootstrap and Codex Planner

### Repository

- GitHub: <https://github.com/thomasfevre/Jarvis>
- Branch: `main`
- Current commits:
  - `3125dbc` - `Bootstrap Jarvis core`
  - `b6ea3f5` - `Add Codex planner provider`

### Decisions Locked

- Start Mac-first, then build a research/evaluation harness after the app works.
- Use push-to-talk first; add always-on listening later as an experimental mode.
- Use a multi-step `Planner + Executor` architecture.
- Use local Codex as the development planner provider because there is no
  external API key budget for now.
- Keep provider boundaries so OpenAI Realtime, local models, or other providers
  can replace Codex later.
- Confirm risky actions before execution.

### Implemented

- Swift package named `Jarvis`.
- `JarvisCore` library target.
- Core action and plan contracts:
  - `AgentAction`
  - `AgentPlan`
  - `AgentStep`
- Safety and execution:
  - `SafetyGate`
  - `ActionRunning`
  - `PlanExecutor`
- Planning provider boundary:
  - `PlanningProvider`
  - `PlanningRequest`
  - `ScreenObservation`
- Local Codex planning provider:
  - `CodexPlannerProvider`
  - `CodexExecCommandRunner`
  - strict JSON output schema for `codex exec`

### Verified

- `swift test` passes with 9 tests.
- Real smoke test confirmed local `codex exec` can return a valid `AgentPlan`
  through the local Codex login.

### Current Limitations

- No macOS app shell yet.
- No push-to-talk audio capture yet.
- No screen capture or Accessibility tree reader integrated into Jarvis yet.
- No native action runner for click/type/open-app execution yet.
- `CodexPlannerProvider` is suitable for local development, not realtime voice
  or production distribution.

### Next Recommended Step

Build the macOS observation/action layer before UI polish:

1. Add a native macOS `ActionRunning` implementation for open app, click,
   type text, and key press.
2. Add an Accessibility tree observation provider.
3. Add tests around action mapping and observation normalization.
4. Only then create the menu-bar app and push-to-talk loop around the core.

## 2026-06-04 - Minimal CLI Test Path

### Implemented

- Added executable product `jarvis`.
- Added `swift run jarvis plan "<instruction>"` to call local Codex and print an
  `AgentPlan`.
- Added `swift run jarvis plan --execute "Open Notes"` path.
- Added `MacOSActionRunner` with support for `AgentAction.openApplication`.
- Added CLI and macOS runner tests.
- Added [testing-now.md](testing-now.md) with current manual test commands.

### Verified

- `swift test` passes with 16 tests.
- `swift run jarvis plan "Open Notes"` returns a valid plan JSON.
- `swift run jarvis plan --execute "Open Notes"` returns `Execution completed.`

### Current Limitations

- Execution only supports opening macOS applications.
- Click, type text, key press, and shell actions are intentionally unsupported by
  the native runner for now.
- CLI still uses placeholder screen/accessibility observations.
- No voice input or menu-bar app shell yet.

### Next Recommended Step

Add the Accessibility tree observation provider, then pass real focused-app and
AX context into the CLI planner request.

## 2026-06-04 - Codex Executable Resolution Fix

### Fixed

- `swift run jarvis plan "Open Notes"` failed for the user with
  `env: codex: No such file or directory`.
- `CodexExecCommandRunner` now resolves Codex through `JARVIS_CODEX_EXECUTABLE`,
  Codex.app, Homebrew paths, then `/usr/bin/env`.

### Verified

- `swift test` passes with 18 tests.
- `swift run jarvis plan "Open Notes"` returns a valid plan JSON.

## 2026-06-05 - Accessibility Observation and Native Input

### Implemented

- Added `swift run jarvis observe`.
- `jarvis plan` now sends real frontmost-app Accessibility context to Codex
  instead of placeholder observation text.
- Added `MacOSAccessibilityObserver` and renderer with bounded depth/children.
- Extended `MacOSActionRunner` to support:
  - `openApplication`
  - `click`
  - `typeText`
  - `keyPress`
- Kept `shell` unsupported.
- Added tests for observer rendering, CLI observe parsing, click/type/key
  command generation, and unsupported shell/key behavior.

### Verified

- `swift test` passes with 28 tests.
- `swift run jarvis observe` returns the focused app and an Accessibility tree.
- `swift run jarvis plan "Open Notes"` returns a valid plan JSON.
- `swift run jarvis plan --execute "Open Notes"` returns `Execution completed.`

### Current Limitations

- Accessibility trees can be partial depending on the app and macOS permissions.
- Click/type/key execution is still low-level and focus/coordinate based.
- No post-action observation/retry loop yet.
- No voice input or menu-bar app shell yet.

### Next Recommended Step

Add a post-step observe/verify loop in `PlanExecutor`, then map AX element labels
to click coordinates before executing click plans.

## 2026-06-06 - Doctor and clickElement Targeting

### Implemented

- Added `swift run jarvis doctor`.
- Doctor reports:
  - resolved Codex executable
  - Accessibility trust status
  - focused application
  - whether the Accessibility tree is empty
- Added `AgentAction.clickElement(label:)`.
- Codex planner prompt/schema now supports `clickElement`.
- CLI resolves `clickElement` into coordinate `click` using rendered
  Accessibility `bounds=(x,y,w,h)`.

### Verified

- `swift test` passes with 34 tests.
- `swift run jarvis doctor` reports Codex path and Accessibility status.
- `swift run jarvis observe` returns focused app and Accessibility tree.
- `swift run jarvis plan "Click the focused text area"` produces `clickElement`
  from Codex and renders a resolved coordinate `click`.

### Current Limitations

- Element matching is currently string-based over the rendered Accessibility tree.
- No post-action observe/retry loop yet.
- No menu-bar, push-to-talk, or audio path yet.

### Next Recommended Step

Add post-action observation after each executed step, then make element matching
structured instead of line/string based.

## 2026-06-06 - Visual Observation v1

### Implemented

- Added `VisibleTextObservation` to `ScreenObservation`.
- Added a `VisibleTextObservationSource` boundary so screenshot OCR is injectable
  in tests.
- Added `MacOSVisionTextObservationSource` using ScreenCaptureKit screenshot
  capture and Apple Vision text recognition.
- `swift run jarvis observe` now prints a `Visible text:` section with OCR text,
  bounds, and confidence.
- `swift run jarvis doctor` now reports Screen Recording permission status.
- Codex planner prompts now include visible screenshot text and OCR bounds.
- `clickElement` resolution now tries Accessibility bounds first, then visible
  screenshot text bounds.

### Verified

- `swift test` passes with 35 tests.
- `swift run jarvis doctor` reports:
  - Codex executable found
  - Accessibility trusted
  - Screen Recording trusted
- `swift run jarvis observe` detects visible cmux sidebar text, including
  `Obsidian`, `Needs input`, `Jarvis`, and other sessions.
- `swift run jarvis plan "Click Obsidian"` produces `clickElement("Obsidian")`
  and resolves it to an OCR-based coordinate click in the sidebar.

### Current Limitations

- OCR can miss icon-only controls.
- OCR can merge or split nearby labels depending on rendering.
- The click target is currently the center of the matched text bounds, not the
  center of a surrounding row/control.
- No post-action observe/retry loop yet.

### Next Recommended Step

Add post-action observation and retry, then improve OCR grouping so text matches
can target the containing row/control instead of only the text glyph bounds.

### Follow-up Fix

- If the transcript asks to click/select/tap and Codex returns
  `openApplication(name:)`, Jarvis now rewrites that step to a visible OCR click
  when matching text is present.
- Planner instructions now explicitly say not to use `openApplication` for click
  requests when matching visible screenshot text is present.
- Simple visible-text click requests now short-circuit before Codex: `Click X`
  first tries to resolve `X` directly from screenshot OCR and returns a one-step
  click plan when found.
- Screenshot capture now targets the display containing the frontmost window
  instead of assuming the first ScreenCaptureKit display is the useful one.
