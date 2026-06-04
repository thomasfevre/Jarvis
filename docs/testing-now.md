# Testing Now

Jarvis is currently a Swift package with a planning core, a minimal CLI, a
macOS Accessibility observer, and a native macOS action runner. The fastest
useful MVP test is:

```sh
swift run jarvis plan "Open Notes and create a quick note"
```

That path sends a text transcript to the local Codex planner provider and should
print an `AgentPlan` JSON object. This validates the current planning loop:

```text
text transcript -> CodexPlannerProvider -> AgentPlan JSON
```

You can inspect the current Accessibility context with:

```sh
swift run jarvis observe
```

That path validates:

```text
frontmost app -> macOS Accessibility APIs -> ScreenObservation
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
Usage: jarvis plan [--execute] <instruction>
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

## What Can Be Tested

- `AgentPlan` JSON decoding and rendering.
- Planner prompt and output-schema behavior through the local Codex provider.
- Real frontmost-app observation through macOS Accessibility APIs.
- Safety classification for planned actions through unit tests.
- Sequential plan execution over injected test runners through unit tests.
- CLI parsing for `jarvis plan`, including `--execute`.
- Native app-open/click/type/key execution through `MacOSActionRunner`.

## Known Limitations

- No native macOS app shell yet.
- No speech capture, push-to-talk, or realtime voice path yet.
- No screen capture or vision fallback is wired into Jarvis yet.
- Accessibility output can be partial depending on the target app and macOS
  permissions.
- Native click/type/key execution is coordinate/focus based and does not yet
  validate post-action state.
- The local Codex provider is intended for development and prototyping, not
  production realtime voice.
- Planner output can vary between runs.

## Next Steps

1. Improve Accessibility targeting by mapping planned element labels to bounds.
2. Add post-action observation/retry after each executed step.
3. Add confirmation UI for risky actions.
4. Add push-to-talk transcript capture.
5. Keep the provider boundary so Codex-local, API-backed, and local model
   providers can be swapped without changing planner contracts.
