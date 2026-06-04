# Jarvis Architecture

## MVP Loop

1. User invokes push-to-talk.
2. Voice input produces a transcript.
3. Screen observer captures screenshot plus macOS Accessibility tree.
4. Planner converts intent and observation into an `AgentPlan`.
5. `PlanExecutor` runs steps through an `ActionRunning` implementation.
6. `SafetyGate` pauses before risky actions and asks for confirmation.
7. Session log records transcript, observation metadata, plan, actions, and results.

## Core Contracts

- `AgentAction`: stable action vocabulary shared by planner, executor, UI, and logs.
- `AgentPlan`: ordered planner output with reasons per step.
- `SafetyGate`: conservative policy for confirmation-required actions.
- `ActionRunning`: adapter protocol for native macOS input, mocks, or future harness runners.
- `PlanExecutor`: sequential runner that enforces safety before dispatching actions.
- `PlanningProvider`: adapter protocol for planner implementations.
- `CodexPlannerProvider`: local development planner that calls `codex exec`.

## Provider Boundaries

The app should use provider protocols for speech-to-text, realtime voice, LLM
planning, text-to-speech, observation, and action execution. The first planner
provider uses local Codex authentication through the Codex CLI, so Jarvis can be
developed without an external API key. The core must not depend directly on any
single model vendor or runtime.

The Codex planner is intentionally non-realtime: it is good for structured
planning and dev iteration, while realtime voice should remain a separate
provider later.

## Phase Two Harness

After the Mac app works, reuse the same contracts for a harness that can replay
tasks, compare observations, record trajectories, and evaluate planner/executor
success rates.
