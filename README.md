# Jarvis

Jarvis is a macOS-first, voice-controlled computer-use agent inspired by Clicky.
The first milestone is a usable native Mac assistant; the second milestone is a
research harness for evaluating and improving desktop agent reliability.

## Direction

- Build order: Mac-first product, then evaluation/research harness.
- Interaction model: push-to-talk first, experimental always-on later.
- Agent model: multi-step `Planner + Executor`.
- Safety: allow routine steps, require confirmation before risky actions.
- Model strategy: Codex-local for development, provider interfaces so API or local models can replace it later.

## ChatGPT Plus and API Access

ChatGPT Plus is not treated as a general OpenAI API backend. For development,
Jarvis can use the local Codex CLI session through `CodexPlannerProvider`, which
invokes `codex exec` with a strict output schema. This lets the planner run from
the local Codex login without storing an `OPENAI_API_KEY` in Jarvis.

This Codex provider is intended for local development and planner prototyping.
Realtime voice and production distribution should still use dedicated provider
implementations.

## Current State

This repository currently contains the testable Swift core:

- `AgentPlan`: structured planner output.
- `AgentAction`: supported action contract.
- `SafetyGate`: confirms risky actions.
- `PlanExecutor`: sequential multi-step execution over an injected action runner.
- `CodexPlannerProvider`: development planner backed by local `codex exec`.

The native macOS UI, screen observation, audio, and model providers will be added
after the core contracts are stable.

See [docs/checkpoints.md](docs/checkpoints.md) for the running project log and
current next steps.
See [docs/testing-now.md](docs/testing-now.md) for the commands that work today.

## Development

```sh
swift test
```
