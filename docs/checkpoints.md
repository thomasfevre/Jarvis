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
