# Representative Project Validation

v1.0 stabilization requires the harness to prove its contracts on repositories that look like supported application projects, not only on the harness repository itself.

## CI scenarios

`tests/representative-projects-smoke.ps1` creates disposable repositories and validates the installed harness from inside each target.

### .NET representative

The fixture contains a real SDK-style `net8.0` project. CI performs a local restore, then verifies that the harness:

- detects `DotNet`;
- installs the stack-specific Copilot instructions and complete runtime;
- generates `V1-DOTNET-BUILD` and `V2-DOTNET-TEST`;
- passes installed Doctor readiness;
- executes the generated verification profile;
- reaches maker/checker `ACCEPT`;
- reaches lifecycle `COMPLETE`;
- persists context, verification, lifecycle, maker/checker, manifest, and summary evidence.

The fixture uses a dependency-free local `VSTest` MSBuild target. This validates the harness test-command contract without introducing a network dependency on a unit-test framework package. It is not a substitute for repository-specific unit or integration tests.

### Angular representative

The fixture contains `angular.json` plus repository-local `lint` and `test:ci` npm scripts. CI does not run `npm install`; the scripts use the Node runtime already present on the Windows runner.

The scenario verifies that the harness:

- detects `Angular`;
- installs Angular-specific instructions;
- generates `V1-ANGULAR-LINT` and `V2-ANGULAR-TEST`;
- passes installed Doctor readiness;
- executes both deterministic local scripts;
- reaches maker/checker `ACCEPT` and lifecycle `COMPLETE`;
- persists the complete evidence set.

## End-to-end acceptance

For each representative project, the validation path is:

```text
project fixture
  -> installer
  -> stack detection
  -> generated verification profile
  -> installed Doctor
  -> run-harness
  -> deterministic verification
  -> maker/checker
  -> lifecycle COMPLETE
  -> durable evidence
```

A representative scenario fails if any required stage is missing, blocked, not run, rejected, or incomplete.

## Scope boundary

These fixtures validate harness integration contracts with supported stacks. They deliberately avoid credentials, remote services, package registries beyond the local SDK restore path, production environments, and application-specific infrastructure.

Real repositories must still provide their own deterministic tests, integration checks, security checks, and release evidence.

Copilot proposes; the harness verifies.
