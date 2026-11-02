# Change-aware CI contract for derived projects

Bootstrap implements this contract in the generated project harness. This template
keeps its own lightweight validation workflow; it has no application stack to test.
The local-first policy below applies to derived projects without adding a new Skill,
agent service, attestation system or mandatory client hook.

## Classification
Use one reusable classifier locally and in CI, with exactly `docs` and `full` results.
`docs` requires a nonempty change set containing only documentation Markdown (`.md`),
regardless of directory, provided every changed path passes the project's protected-path
policy. A Markdown extension alone is insufficient to override protection. Operational
Markdown (including agent instructions, Skills, methodology, or content consumed by an
application or build) always requires `full`. Non-Markdown files, mixed documentation/code,
unknown functional impact, invalid input, missing Git base, empty or incomplete change
lists and classification errors default to `full`.
Inspect the complete event comparison, including additions, deletions and both sides
of renames. Document PR and push comparison bases; never silently inspect only HEAD's
last commit. Parse filenames safely, including spaces and unusual characters.

## Adaptable Markdown documentation scope
Use a default documentation rule for `.md` files in any directory, rather than
maintaining a product-document allowlist. Ordinary Markdown documentation includes
root `README.md`, documentation under `docs/`, specifications, backlog files,
nested notes and investigations; no special filename convention is required.
Classify the complete Git comparison, not just the final commit.

Protected exclusions take precedence over every Markdown documentation candidate.
Define and test these boundaries in the derived project's shared classifier:

- Exclude operational basenames regardless of directory or case: `AGENTS.md`,
  `CLAUDE.md`, `SKILL.md`, `instructions.md`, and the project's agent bootstrap,
  handoff and backup prompts (for example `NEW_PROJECT_PROMPT.md` and
  `PROMPT_BACKUP*.md`).
- Exclude operational/harness path families such as `.agents/`, `.claude/`,
  `templates/`, `specs/methodology/`, `specs/guidelines/`, `scripts/` and
  `.github/`, and exact operational files such as `specs/README.md` when applicable.
- Exclude Markdown used by application, tests, fixtures, build or deployment,
  including relevant paths under `apps/`, `packages/`, `tests/`, `build/`,
  `dist/` and project-specific functional content directories.
- Review additional paths that affect agent instructions, automation, generated
  assets or application behavior; uncertain impact selects `full`. Extensions
  do not prove content is harmless.

Documentation Markdown outside protected boundaries uses `docs`; Markdown inside
those boundaries, non-Markdown changes and mixed changes use `full` delivery coverage
(with CI checks selected by the event's documented profile). Both endpoints of renames
and copies must be classified; additions, modifications and deletions are included.
Changes to the protected-path policy or classifier themselves require `full`.
The exceptions are configurable to each stack; do not hardcode every template-specific
path into an unrelated project.

Adapt existing projects without init-project, replacing functional decisions or
reinitializing their harness. Do not silently replace an existing project's CI policy:
review its protected files, generated content and integration requirements first.
This is a CI scope policy, not product approval.
Reference: [MyFinanzas PR #108](https://github.com/jmartinlabs/myfinanzas-app/pull/108)
implements this default with project-specific exclusions; its paths are examples,
not universal defaults.

## Required checks and workflow enforcement
Documentation and security controls are mandatory for both classes. `full` defines
required delivery coverage: all applicable type, build, API/integration and E2E checks.
It does not require running every suite on every GitHub event. Record exact commands,
execution profiles, critical paths and platform requirements in project quality guidelines;
do not invent a browser, API or database requirement for stacks that do not use them.

Use local-first QA with a minimal CI gate:

- Local development and independent QA run E2E and complete regressions for each stable
  candidate. Platform-dependent checks require a compatible isolated environment;
  a host OS that cannot exercise them is not equivalent evidence.
- Every PR has one unconditional `required` job: baseline documentation/security controls,
  the shared conservative classifier and the project's fast type/build checks.
  Critical persistence, migration, financial, security and dependency changes also run
  independent checks in CI on the required platform. Keep their commands and path map
  in the project, including indirect consumers; unknown paths or uncertain impact select
  critical verification or fail visibly, never a successful omission.
- Automatic push runs target only `main`, providing a fast post-merge gate. PR runs
  compare the complete base/head change; working-branch pushes must not duplicate them.
  Include `ready_for_review` so a draft that becomes ready is validated, and keep the
  fast gate active on drafts unless the project explicitly decides otherwise. Keep
  manual full verification available. Cancel superseded PR runs using a PR-specific
  concurrency group; never let a push cancel the PR check or silently pass a cancellation.
- Keep a single habitual job rather than separate baseline/full/aggregator runners.
  Preserve the check identity through migration or explicitly coordinate protection
  updates with user approval. A job named `required` alone does not enforce branch
  protection; inspect actual required checks and bypass settings before claiming enforcement.

The project harness (for example `scripts/check-project`) must validate workflow
structure and execution conditions, not merely command text. Require unconditional
baseline controls, conservative profile selection and a required result that rejects
failures and unexpected skipped checks. Missing or invalid classifier output must
select critical/full verification or fail visibly. Reject disabled controls (`if: false`),
commented-only commands, `continue-on-error` on required checks and event/path filters
that omit the PR gate. Preserve approved security controls, including permissions,
action pins, checkout credentials and history requirements; classification never relaxes them.

Use an execution-profile matrix that keeps delivery coverage separate from the checks
selected for an event. The names below are semantic categories; projects map them to
their own commands and may omit a category only with a documented reason.

| Profile | Minimum check coverage |
| --- | --- |
| `docs` | Baseline documentation and security controls. |
| `fast` | Baseline plus the project's fast type, lint and build checks. |
| `critical` | Fast plus independent persistence, migration, security, dependency and API/integration checks on the required platform. |
| `full` | Every applicable check, including end-to-end and acceptance coverage. |

Within `docs`, omitting a regression suite is permitted only after a tested
evaluation of that suite's real dependency boundary, including the files,
fixtures or configuration it reads, copies, generates or otherwise consumes. A
documentation-only comparison does not by itself prove those inputs are unchanged:
if any dependency can change, or the boundary is uncertain, the suite remains
required or the project fails visibly. The project's real validators and its
documentation, security and whitespace controls remain mandatory. Report the
omission as intentionally skipped, never as passed; a missing or invalid
comparison, dirty tree, unknown path or uncertain impact selects `full` or fails
visibly. Record the suite set and dependency boundary per project, and measure the
CI effect before claiming a reduction.

Each profile must have a bounded timeout. A timeout, cancellation or unexpected skip
is a failure, never a successful omission. Profiles are check categories, not
universal commands: a project without a database, API or browser records the
justified omission instead of inventing checks.

Reducing automatic `push` coverage on the integration branch to `docs` or `fast` is
conditional. It is permitted only when the project has verified and recorded all of
these guarantees:

- The PR gate validated the exact integration tree against the current base.
- Branch protection requires that gate and prevents stale, bypassed or force-pushed
  merges.
- Tree equivalence between the tested PR integration and the merged commit is
  demonstrated, not assumed from the merge method.

If any guarantee is absent, stale or unverified, retain the project's existing
post-merge coverage; do not automatically reduce critical or full checks from change
classification alone. If the base or tested tree changes, rerun the affected critical checks.
Validate a high-risk merge with a manual `full` run rather than duplicating the critical
suite automatically. A fast post-merge run does not attest local QA or replace the PR gate.

A PR can modify its own workflow, classifier or workflow validator. No in-repository
check can prove that this did not weaken the gate. Require explicit review of CI,
classifier and validator changes, and do not claim that branch protection alone
resolves this risk.

## Evidence validity and independent QA
Reuse the existing testplan/checkpoint, not a second evidence registry. Before integration,
the coordinator and independent QA verify the clean candidate commit, current base commit,
complete comparison and tested environment against reachable raw logs and artifacts.
Record exact commands, tool/runtime versions, platform/architecture, run time, test counts,
exit statuses and expected coverage. Dirty/untracked inputs must be identified and cannot
be represented as evidence for a clean commit. A PASS declared by an agent or a self-authored
manifest is not sufficient evidence. QA inspects raw output and candidate diff and reruns
checks that resolve material risks; it does not merely repeat the author's conclusion.

After a candidate, base, dependency, toolchain, filesystem or environment change, reassess
impact and rerun affected checks; uncertain impact requires complete verification. Reuse
unchanged evidence only with an explicit equivalence rationale verified independently.
Missing, stale, inaccessible or incompatible evidence blocks integration even if CI is green.
The fast CI gate does not attest that local QA ran. Keep explicit merge approval; no
repository-controlled PASS file, client hook or successful check substitutes for it.
Codex and Claude Code follow this same canonical policy through their existing adapters;
do not make correctness depend on optional lifecycle hooks or a particular client.

## Canonical verification entry point
Bootstrap establishes one canonical verification command for local use and CI.
Reuse an existing command when it already covers this contract; do not add a wrapper
or rename commands merely for uniformity. The command name and implementation belong
to the approved project stack (for example a script, task runner or package command).
Record its working directory, prerequisites, comparison inputs and a way to force
`full` verification in AGENTS.md and project quality guidelines.

The entry point coordinates the shared classifier and required checks; keep their
logic in existing tools rather than copying it. Use explicit local-full, fast-CI and critical-CI profiles in the existing entry point.
Apply the same check selection and failure semantics for equivalent inputs within each
profile; profile differences are intentional and documented, not silent skips.
Environment preparation may differ and must be documented. The required CI result
verifies its profile coverage; the independent integration review verifies local-full
evidence. Keep conservative docs/full coverage classification separate from execution venue.
Within one verification run, execute each required suite once unless a documented
repeat is needed for an acceptance criterion or flakiness investigation. This does
not remove independent QA or require reusing stale evidence between candidates.

Propagate a nonzero exit status for any required failure or missing prerequisite.
An invalid mode must fail visibly. Report passed, failed, intentionally skipped and
unrun checks separately; unexpected skips and unexpectedly zero discovered tests
must not count as success. Classification uncertainty retains the conservative
`full` or visible failure behavior specified above. Successful `docs` verification
must say that application checks were intentionally omitted, not claim they passed.
Verification must not install dependencies, change task state, commit, deploy or
reinitialize a project implicitly; provision the documented environment separately.

Derived-project regression tests must invoke the real entry point and demonstrate:
valid docs/full paths, forced full mode, each required check failing, missing tooling,
invalid modes, unexpected zero tests/skips, local/CI selection parity within profiles, and each suite
executing once per run. Prove reuse of an adequate existing command without a second
verification layer. These are generated-harness behavioral tests; this template's
validator only protects preservation of the contract.

## Local regression evidence
The harness regression suite (for example `scripts/test-checks`) must exercise the
same classifier used by CI and valid/invalid workflow fixtures. Cover at least:

| Input or mutation | Expected result |
| --- | --- |
| Ordinary Markdown documentation at root, `docs/`, `specs/`, nested directories and investigations | `docs`, baseline controls required |
| Representative documentation paths: additions, modifications and deletions | `docs`, baseline controls required |
| Renames between two ordinary documentation Markdown paths | `docs`, both rename directions checked |
| Protected or functional Markdown renamed to documentation, and reverse | `full`, both rename directions checked |
| Protected Markdown basenames, operational prefixes and functional Markdown: additions, modifications and deletions, alone and mixed with documentation Markdown | `full` |
| Markdown lookalikes: non-Markdown suffixes, protected names, unsafe directories or excluded functional content | `full` |
| Documentation plus code | `full` delivery coverage; CI follows the explicit execution profile |
| SQL, dependencies, lockfiles, workflows, harness, configuration, instructions or Skills | `full` |
| Unknown non-Markdown path, uncertain functional Markdown, empty input, invalid output, missing comparison base or classifier failure | `full` or visible CI failure; never successful omission |
| Rename from code to documentation, or deleted protected file | `full` |
| Paths containing spaces or unusual characters | Parsed without losing changes |
| Missing classifier, disabled required check, broken dependency or unexpected skip | Workflow rejected |
| Commented command, allowed failure or filter skipping all validation | Workflow rejected |
| Valid docs and full workflow execution paths | Accepted with their required checks |

Prove the contract with local tests before changing Actions execution. Regressions
must check behavior, not repeat the implementation's string-presence assertions.
Also exercise working-branch push exclusion, PR/main/manual admission, PR cancellation,
failed/cancelled/timed-out checks, invalid profile selection and unknown critical paths.
Evidence validity tests cover stale candidate/base, dirty inputs, incompatible environment,
missing/raw-log mismatch and a forged PASS claim. Keep environment caching optional and
review its trust boundary separately.

For document Markdown in different directories, use real Git comparisons for additions,
modifications, deletions and renames. Exercise both rename endpoints even if the old
file no longer exists. Include protected files mixed with documentation Markdown;
one protected or uncertain functional path makes the whole comparison `full`. Test
policy adaptations with representative documentation and excluded operational paths.

## Template repository workflow

This repository's one `required` job keeps its complete lightweight template checks,
including the real Mermaid parser and a malformed-diagram rejection. It runs on PRs
to main —including `ready_for_review`, with drafts still gated—, pushes to main and
manual dispatch, with no working-branch push runs. This
repository has no API, database or E2E application suite; do not manufacture one.
Validator fixtures check the parsed workflow, unconditional execution and safe event
selection. They do not prove live GitHub cancellation or branch protection enforcement.
