---
applyTo: "**/*.cs,**/*.csproj,**/*.sln,**/*.props,**/*.targets"
---
# .NET / ASP.NET Core

- Follow the solution's existing architecture, naming, dependency-injection, configuration, logging, validation, and error-handling conventions.
- Keep nullable reference types correct; do not silence warnings without understanding the cause.
- Use async end-to-end for I/O. Avoid `.Result`, `.Wait()`, fire-and-forget tasks, and unnecessary `Task.Run` in server code.
- Pass `CancellationToken` through cancellable I/O and request flows when the existing API supports it.
- Prefer framework and existing solution abstractions over new dependencies.
- For ASP.NET Core endpoints, consider validation, authorization, status/error contracts, cancellation, observability, API compatibility, and OpenAPI behavior.
- For persistence changes, identify transaction boundaries, concurrency behavior, query shape/performance, migrations, compatibility, and rollback.
- Detect the repository's test framework and existing patterns before generating tests. Do not introduce a second test framework without an explicit requirement.
- Run the narrowest relevant `dotnet build` / `dotnet test` commands first; expand verification when risk or repository policy requires it.
- Never claim build or test success unless the command actually ran successfully.