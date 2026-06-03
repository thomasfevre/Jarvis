# Jarvis

Jarvis is a macOS-first, voice-controlled computer-use agent inspired by Clicky.
The first milestone is a usable native Mac assistant; the second milestone is a
research harness for evaluating and improving desktop agent reliability.

## Direction

- Build order: Mac-first product, then evaluation/research harness.
- Interaction model: push-to-talk first, experimental always-on later.
- Agent model: multi-step `Planner + Executor`.
- Safety: allow routine steps, require confirmation before risky actions.
- Model strategy: cloud-first for the MVP, provider interfaces so local models can replace cloud services later.

## ChatGPT Plus and API Access

ChatGPT Plus is not treated as an application backend. Jarvis needs provider
interfaces that can be backed by an OpenAI API key, another model provider, or
local models. The MVP can run core tests without model credentials.

## Current State

This repository currently contains the testable Swift core:

- `AgentPlan`: structured planner output.
- `AgentAction`: supported action contract.
- `SafetyGate`: confirms risky actions.
- `PlanExecutor`: sequential multi-step execution over an injected action runner.

The native macOS UI, screen observation, audio, and model providers will be added
after the core contracts are stable.

## Development

```sh
swift test
```

