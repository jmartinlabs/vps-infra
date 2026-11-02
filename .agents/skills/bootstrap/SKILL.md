---
name: bootstrap
description: Build and verify the smallest end-to-end walking skeleton from approved project decisions.
---

# bootstrap

## Inputs
Read `AGENTS.md`, `specs/README.md`, existing state and applicable guidelines before acting.
## Outputs
Minimal working infrastructure, basic automated tests, reproducible commands, guideline
updates, evidence in setup progress and a working local commit.
## Procedure
1. Read approved identity/architecture decisions and inspect existing code and Git status.
   Resolve missing approvals or conflicts before implementation.
2. Propose the smallest end-to-end flow using essential components only. Web may use
   frontend → API → database; CLI/library/service projects need their own equivalent.
   Do not force a database, browser, framework or extra abstraction into the flow.
3. Implement infrastructure only, with deterministic fictional data where needed.
   Avoid unrelated business functionality and unnecessary packages.
4. Add basic automated tests that would fail if the essential flow broke. Run actual
   build/type checks required by the chosen tooling, then tests; record commands/results.
   Implement the [change-aware CI contract](../../../specs/methodology/ci-policy.md):
   a shared conservative `docs`/`full` classifier, mandatory baseline controls,
   local-full delivery coverage, fast-CI and independent critical-CI profiles,
   and behavioral harness/workflow regression fixtures.
   Prove the contract locally before changing Actions execution; record commands
   and justified inapplicable checks in project quality guidelines.
5. Start and inspect the application/service and exercise representative behavior.
   For a library, invoke its public API; for CLI, assert output/exit status; for web,
   send actual requests and inspect responses. Diagnose failures and retry corrections.
6. Establish one canonical verification command shared by local use and CI, following
   the CI contract's entry point requirements. Reuse an adequate existing command;
   do not create a redundant wrapper. Document its working directory, prerequisites,
   comparison inputs and forced full mode in AGENTS.md and quality guidelines.
   Verify failure propagation, coverage, local/CI parity within profiles, evidence
   validity and absence of duplicate suites; use the CI contract as the single policy.
   Document exact working directories, install/run/check commands and prerequisites.
   Update architecture to implemented reality; record test evidence and next action.
7. Review diff, stage only own files, check for secrets, then commit the working state.
   Do not push or deploy without authorization.
## Stop conditions
Pause for unresolved material decisions, conflicting requirements, permissions or secrets.
Do not declare done while the end-to-end flow or tests fail or are unverified. Report the
blocker, preserve state and resume after resolution. Done means working, tested, reproducible.
