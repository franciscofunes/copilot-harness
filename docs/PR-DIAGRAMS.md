# Pull Request Diagram Convention

Every harness PR includes two complementary Mermaid diagrams.

1. **Change diagram** — explains the architecture, data flow, lifecycle, or behavior changed by the PR. This is the technical-review view.
2. **Git Flow position** — shows where the branch sits in the repository workflow and where it is expected to merge. This is the delivery/release view.

The diagrams answer different questions, so both are useful. Keep them small. A feature PR should normally show `develop -> feature/* -> develop`; a release PR should show `develop -> release/* -> main -> develop`; a hotfix should show `main -> hotfix/* -> main` plus synchronization back to `develop`.

Do not fabricate history. The Git Flow diagram is a concise representation of the PR's actual branch path, not a full repository commit graph.
