---
name: karpathy-guidelines
description: Use when writing, reviewing, or refactoring code to reduce LLM coding mistakes by surfacing assumptions, keeping implementations simple, making surgical changes, and defining verifiable success criteria.
license: MIT
---

# Karpathy Guidelines

Behavioral guidelines adapted from `/home/perry/andrej-karpathy-skills`. Apply them to non-trivial engineering work; keep trivial one-line fixes lightweight.

## 1. Think Before Coding

- State task-local assumptions before implementation.
- Identify the directly relevant files, modules, dependencies, entry points, and execution flow.
- If multiple interpretations would materially change the implementation, surface the trade-offs or ask before editing.
- If the request conflicts with the codebase shape, point out the mismatch and propose the simpler coherent path.

## 2. Simplicity First

- Implement the minimum design that solves the requested problem.
- Do not add speculative features, unused abstractions, or unrequested configurability.
- Prefer existing local patterns and helper APIs over new architecture.
- If the solution is becoming much larger than the problem, simplify before continuing.

## 3. Surgical Changes

- Every changed line should trace directly to the request or to cleanup caused by your own edit.
- Do not rewrite unrelated code, comments, formatting, or neighboring logic.
- Match the existing style even when another style would be personally preferred.
- Remove imports, variables, and helpers made unused by your change; mention unrelated dead code instead of deleting it.

## 4. Goal-Driven Execution

- Convert bug fixes, features, and refactors into explicit success criteria.
- Prefer a failing test or reproducible command before fixing a bug when practical.
- Verify with the narrowest meaningful check first, then broader checks when the blast radius requires it.
- Report what was verified and what remains unverified.
