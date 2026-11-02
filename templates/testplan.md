# NN — FEATURE: Test plan
Specification: SPECIFICATION_PATH

Before implementation, map applicable acceptance criteria, negative/error and integration
cases to their environment and expected evidence. Draft specs allow provisional test
design only, never implementation or PASS claims.

| Acceptance ID | Preconditions and action | Expected result | Automated/manual method and command | Local / CI platform and owner | Expected evidence | Actual result / status | Candidate / run date / evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AC-01 | UNDECIDED | UNDECIDED | UNDECIDED | UNDECIDED | UNDECIDED | unrun | |

## Regression checks
Record relevant suites, counts, command exit status and failures separately.
Use focal checks per delta and required complete checks on a stable candidate. Reuse
evidence only while candidate inputs and environment remain valid; record why checks
repeat. QA independently assesses risks and may reproduce required checks. Do not run
a platform-specific full suite on an incompatible platform as a substitute for CI.
Concurrency, production without demo fixtures, restore and asynchronous responses belong
in the matrix when applicable, not in every project.
## Functional verification
Record actual API/CLI/integration outcomes; process startup alone does not pass.
## Browser verification (web only)
Use Playwright to operate every browser acceptance flow. Capture and inspect screenshots
at 390px and 1440px, recording evidence paths. Record accessibility/responsive findings.
## Visual improvements (visual apps only)
List the five most valuable improvements or justify fewer; record corrections and rechecks.
## Limitations and next action
No acceptance completion claim until every required check passes.
