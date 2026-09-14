---
applyTo: "**/*.ts,**/*.html,**/*.scss,**/angular.json,**/package.json"
---
# Angular / TypeScript

- Follow the repository's Angular version, architecture, component style, state-management, routing, forms, and testing conventions before introducing alternatives.
- Keep TypeScript strictness intact; avoid `any` unless an external boundary genuinely requires it and the reason is documented.
- Prefer small components with explicit inputs/outputs and keep business/data-access concerns in the existing service or state layer.
- Preserve accessibility, keyboard behavior, loading/empty/error states, and responsive behavior for UI changes.
- Treat API data as an external contract; validate assumptions and preserve backwards compatibility.
- Avoid unnecessary subscriptions and leaks; follow the project's established signals/RxJS lifecycle pattern.
- Reuse existing design-system components and utilities rather than duplicating UI abstractions.
- Detect the repository's test runner and conventions before generating tests.
- Run the narrowest relevant lint/test/build command first, then expand verification according to risk.
- Never claim lint, test, or build success unless the command actually ran successfully.