# Existing Project Comparison

## OpenClicky

Repository: <https://github.com/jasonkneen/openclicky>

OpenClicky is the closest product reference. It is a native macOS menu-bar app
with push-to-talk, screen-aware responses, visual pointing, local configuration,
agent work, and a cursor companion UX.

Use it as the main reference for:

- Native macOS app shape.
- Menu-bar companion UX.
- Cursor and overlay patterns.
- Screen-aware response flow.

Do not copy it wholesale at the start. The project is large, Xcode-project based,
and already includes many product surfaces. Jarvis should first stabilize its own
small core contracts.

## screen-voice-agent

Repository: <https://github.com/sambuild04/screen-voice-agent>

This project is the strongest realtime voice reference. It combines an
Electron/React app with OpenAI Realtime API, screen/audio helpers, Playwright,
and Swift helper binaries for macOS accessibility and input.

Use it as the main reference for:

- Realtime voice architecture.
- Wake/ambient mode tradeoffs.
- macOS helper binaries for AX tree and desktop actions.
- Cost-aware realtime design.

Do not make Jarvis Electron-first unless the native Mac direction fails. The MVP
should stay Mac-native.

## open-computer-use

Repository: <https://github.com/coasty-ai/open-computer-use>

Open Computer Use is broader agent infrastructure: browser, terminal, desktop,
planner, orchestration, and a desktop overlay.

Use it as the main reference for:

- Planner/Desktop/Browser/Terminal separation.
- Multi-step agent orchestration.
- Later harness and benchmark thinking.

Do not make this the MVP base. It is closer to the phase-two research platform
than the first Mac companion.

## Browser-use

Repository: <https://github.com/browser-use/browser-use>

Browser-use is a strong browser automation framework. It is useful as a future
specialized tool for web tasks, but it is not a desktop-wide assistant core.

## OmniParser

Repository: <https://github.com/microsoft/OmniParser>

OmniParser is a screen parsing component for vision-based GUI agents. Jarvis
should use macOS Accessibility first, then add OmniParser-style perception as a
fallback for inaccessible or visually complex screens.

## Decision

Jarvis starts as a small Swift core plus a native macOS shell. The first reusable
contracts are independent from UI and model providers, so we can borrow the best
ideas from these projects without inheriting their full architecture too early.

