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

## Provider Boundaries

The app should use provider protocols for speech-to-text, realtime voice, LLM
planning, text-to-speech, observation, and action execution. Cloud providers are
allowed in the MVP, but the core must not depend directly on any vendor SDK.

## Phase Two Harness

After the Mac app works, reuse the same contracts for a harness that can replay
tasks, compare observations, record trajectories, and evaluate planner/executor
success rates.

