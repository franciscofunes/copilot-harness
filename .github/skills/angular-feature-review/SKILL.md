---
name: angular-feature-review
description: "Optional Angular feature, component and state management review."
---
# Angular Feature Review

Use for explicit Angular component, signal, reactive forms, routing or performance review. Check the project's Angular version and established conventions first.

## Review checklist
1. Verify feature scope, component boundaries, accessibility, responsive layout and loading/error/empty states.
2. Check typed forms, validation, RxJS subscriptions, cancellation and cleanup.
3. Assess signals, change detection, state ownership and unnecessary recomputation without assuming a specific Angular version.
4. Review routing, guards, HTTP interceptors and authorization; client guards are not server security.
5. Examine testing strategy and observable regressions, including keyboard and screen-reader paths.
6. Document findings with repository paths and propose testable acceptance criteria.

## Boundaries
Advisory, opt-in and no MCP or scripts. Never overwrite project conventions. Spec Kit owns planning; policy gates authorize; deterministic harness verification proves completion.
