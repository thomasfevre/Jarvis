# Testing Now

Jarvis is currently a Swift package with a planning core, a minimal CLI, a
macOS Accessibility observer, screenshot OCR through Apple Vision, and a native
macOS action runner. The fastest useful MVP test is:

```sh
swift run jarvis plan "Open Notes and create a quick note"
```

That path sends a text transcript to the local Codex planner provider and should
print an `AgentPlan` JSON object. This validates the current planning loop:

```text
text transcript -> CodexPlannerProvider -> AgentPlan JSON
```

You can inspect the current Accessibility and visible-text context with:

```sh
swift run jarvis observe
```

That path validates:

```text
frontmost app -> macOS Accessibility APIs + ScreenCaptureKit OCR -> ScreenObservation
```

The fastest execution test is:

```sh
swift run jarvis plan --execute "Open Notes"
```

That path validates:

```text
real Accessibility observation -> CodexPlannerProvider -> AgentPlan JSON -> PlanExecutor -> MacOSActionRunner
```

## Prerequisites

- macOS 14 or newer.
- Swift 6 toolchain available through `swift`.
- Codex CLI installed and already logged in locally.
- Accessibility permission granted to the terminal/cmux app running Jarvis.
- Screen Recording permission granted to the terminal/cmux app running Jarvis.
- Run commands from the repository root.

The local Codex provider uses the existing Codex CLI session through `codex exec`.
It does not require an `OPENAI_API_KEY` for this development path.

Jarvis resolves the Codex executable in this order:

1. `JARVIS_CODEX_EXECUTABLE`
2. `/Applications/Codex.app/Contents/Resources/codex`
3. `/opt/homebrew/bin/codex`
4. `/usr/local/bin/codex`
5. `codex` through `/usr/bin/env`

If Codex is installed somewhere else, run:

```sh
JARVIS_CODEX_EXECUTABLE=/absolute/path/to/codex swift run jarvis plan "Open Notes"
```

## Commands

Run the full package tests:

```sh
swift test
```

Expected result:

```text
Build complete!
Test Suite ... passed
```

Run the current smoke test:

```sh
swift run jarvis plan "Open Notes"
```

Expected result is pretty-printed JSON with this shape:

```json
{
  "steps" : [
    {
      "action" : {
        "name" : "Notes",
        "type" : "openApplication"
      },
      "id" : "open-notes",
      "reason" : "..."
    }
  ],
  "summary" : "..."
}
```

Exact wording, step IDs, and action choices may vary because the planner is a
model-backed provider. The important check is that the command exits
successfully and returns valid `AgentPlan` JSON.

Check CLI usage handling:

```sh
swift run jarvis
```

Expected result:

```text
Usage: jarvis doctor | jarvis observe | jarvis plan [--execute] <instruction>
```

The command exits with usage status because an instruction is required.

Check the current execution path:

```sh
swift run jarvis plan --execute "Open Notes"
```

Expected result:

```text
Execution completed.
```

Notes should open if macOS can resolve the application name. Currently only
`openApplication`, `click`, `typeText`, and `keyPress` are supported by the
native runner. `shell` actions fail clearly instead of silently doing nothing.

Be careful with click/type/key commands: they operate on the currently focused
macOS UI. Prefer starting with app-opening commands until the Accessibility
targeting loop is more mature.

Run environment diagnostics:

```sh
swift run jarvis doctor
```

Expected output includes the resolved Codex executable, whether Accessibility is
trusted, whether Screen Recording is trusted, the focused app, and whether the
Accessibility tree is empty.

Test Accessibility-based click planning:

```sh
swift run jarvis plan "Click the focused text area"
```

If the focused app exposes bounds in its Accessibility tree, Codex can emit
`clickElement` and Jarvis resolves it into a coordinate `click`.

Test screenshot-OCR-based click planning:

```sh
swift run jarvis plan "Click Obsidian"
```

If the visible screen contains the text `Obsidian`, Codex can emit
`clickElement` and Jarvis resolves it using Apple Vision OCR coordinates. This
works even when the Accessibility tree only exposes a broad terminal text area.

## What Can Be Tested

- `AgentPlan` JSON decoding and rendering.
- Planner prompt and output-schema behavior through the local Codex provider.
- Real frontmost-app observation through macOS Accessibility APIs.
- Visible text observation through ScreenCaptureKit and Apple Vision OCR.
- Environment diagnostics through `jarvis doctor`.
- Accessibility label targeting through `clickElement` resolution.
- Screenshot text targeting through `clickElement` resolution.
- Safety classification for planned actions through unit tests.
- Sequential plan execution over injected test runners through unit tests.
- CLI parsing for `jarvis plan`, including `--execute`.
- Native app-open/click/type/key execution through `MacOSActionRunner`.

## Known Limitations

- No native macOS app shell yet.
- No speech capture, push-to-talk, or realtime voice path yet.
- Accessibility output can be partial depending on the target app and macOS
  permissions.
- OCR can miss icon-only controls and can merge or split nearby text depending
  on the app rendering.
- Native click/type/key execution is coordinate/focus based. `clickElement`
  improves planning by resolving labels from Accessibility bounds or visible OCR
  text, but does not yet validate post-action state.
- The local Codex provider is intended for development and prototyping, not
  production realtime voice.
- Planner output can vary between runs.

## Next Steps

1. Add post-action observation/retry after each executed step.
2. Improve element matching with roles, exact label/title/value fields, and OCR
   grouping heuristics.
3. Add confirmation UI for risky actions.
4. Add push-to-talk transcript capture.
5. Keep the provider boundary so Codex-local, API-backed, and local model
   providers can be swapped without changing planner contracts.
