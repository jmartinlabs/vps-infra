# Local Codex usage reports

Optional local accounting; no network calls, model invocations or package installation.
The manual reader needs Python 3.10+ only. An advisory Codex hook adapter is also
provided for macOS/Linux. Claude Code accounting is not implemented.

Run from the project directory, pointing at the script in your template checkout:

```sh
python3 scripts/report-agent-usage --session ROOT_SESSION_UUID --task "Harness update"
```

Use the root session UUID from the chat/session identifier or the root rollout's
`session_meta.id`. Local rollouts normally live under `~/.codex/sessions/` (or
`$CODEX_HOME/sessions/`). A child agent's UUID is not the root session UUID.
The script does not automatically guess the latest chat, read credentials or launch
agents. `--help` lists all options.

By default reports are written under `$CODEX_HOME/usage-reports/<current-folder>/`
(normally `~/.codex/usage-reports/`). Each invocation creates a private, unique
timestamped directory with `usage.md` and `usage.csv`; it never overwrites a report.
The current folder is only a grouping label, not a repository/session filter.
Select the correct root session explicitly. Read the Markdown directly or ask an
agent to analyze it; use CSV for comparisons. No generated reports are committed.

Optional selectors and destinations:

```sh
python3 scripts/report-agent-usage --session ROOT_SESSION_UUID \
  --turn ROOT_TURN_UUID --task "Single task" \
  --sessions-dir /path/to/exported/sessions --output-dir /path/to/private/reports
```

Rows group usage by `root_turn_id`, agent thread and recorded model. A root turn is
an execution boundary, not necessarily a complete feature: combine selected rows
when work spans user turns. `--task` is your label and does not infer scope from chat
text. Reports exclude prompts, tool output, code, credentials and conversation text;
they retain IDs, agent/model labels and token counts. Keep task labels non-sensitive.

## Accounting and limitations

- Supports observed Codex `token_usage_record` records with per-response `usage`.
  Internal rollout formats can change. Unsupported/empty selections fail visibly;
  legacy cumulative `token_count` events are not substituted.
- Deduplicates by thread and response ID, including copies inherited in forks.
  Conflicting duplicates fail rather than silently choosing a total. Aggregates
  per-response counters, never cumulative turn/thread totals.
- Cached input is included in input, not added again. Output is used as recorded;
  reasoning counters are not added again. Missing counts become `NA`, never zero.
- A running session is a snapshot; unrecorded requests are unknowable. Malformed
  lines are ignored with a warning and totals may then be incomplete. Unreadable
  files fail the report. Unknown metadata/model values remain unavailable.
- Counts describe processed tokens, including repeated context. They do not measure
  unique text, current context size, money or subscription quota. No cost estimate,
  budget enforcement, automatic termination or duration attribution is provided.
- The reader scans JSONL rollouts in the supplied directory. Use an exported subset
  for large histories. It does not modify source logs. Preserve separate reports to
  compare runs; do not sum overlapping snapshots.

Run `python3 scripts/test-agent-usage` for synthetic regression fixtures. Real model
behavior and billing are not tested by these fixtures.

Official event interfaces for future adapters: [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
and [App Server](https://learn.chatgpt.com/docs/app-server). This reader uses local
rollouts, not those APIs, and does not claim their formats are interchangeable.

## Automatic snapshots (Codex on macOS/Linux)

The project-local `.codex/hooks.json` invokes `scripts/auto-agent-usage` for `Stop`,
`SubagentStop` and `SessionEnd`. Each event updates a session snapshot containing all
recorded root turns and subagents. Turn completion is not semantic feature completion;
handoff benefits from the same Stop event, without calling another model or test suite.
An idle/archived session may emit SessionEnd later; abrupt termination may emit none.

**Activation is a client trust step, not a report-script permission.** In Codex CLI,
open this trusted project and use `/hooks` to review and trust these exact command
definitions. A changed definition requires review again. Reopen/resume the conversation
if the client has not loaded newly added project hooks. Do not edit trust databases,
use trust-bypass flags, or assume a prepared file proves the client executed it.
Desktop availability depends on the local client's hook/trust support. See
[official lifecycle and trust documentation](https://learn.chatgpt.com/docs/hooks).
This does not change global configuration or the Claude adapter.

Default location: `$CODEX_HOME/usage-reports/<event-cwd-name>/auto/<root-session-id>/`.
Each changed snapshot gets a private timestamped directory with Markdown and CSV.
`latest.json` points to the most recent successfully written pair; open its `markdown`
path to read the report. Preserve links to timestamped reports for comparisons.
For a workspace-accessible destination, an explicitly chosen `--output-dir` may point
to the ignored `artifacts/usage-reports/auto` directory; updating the hook command
requires trust review. Reports stay local and must remain excluded from version control.

The adapter reads only event IDs and cwd, not messages or transcript text. It hashes
the aggregated counts to avoid duplicate snapshots across repeated lifecycle events.
Per-session POSIX locks prevent concurrent updates and release automatically on exit.
`latest.json` is atomically replaced after the full report is written. A process killed
between report creation and pointer update may leave an unreferenced snapshot; it does
not replace the last good pointer. Concurrent busy events skip without waiting; a later
event/manual refresh captures subsequent data. Existing snapshots are not summed.

Hook output never requests continuation or changes task decisions. Success emits `{}`;
reporting errors emit an informational `systemMessage`, with no raw error or event
text. Empty/unsupported rollouts produce no success pointer. Each hook has a three-second
timeout: failure is advisory and must not block the user's work. On large histories,
use manual reporting over an exported subset rather than raising hook timeouts blindly.

Usage may reach disk after Stop/SubagentStop. Later events refresh the snapshot, but
neither event nor a stable hash proves all accounting arrived. A final manual refresh
can capture late records; a crash or timeout cannot guarantee a final complete report.
No polling daemon, scheduling service or mandatory agent instructions are installed.

Test with `python3 scripts/test-auto-agent-usage`. Synthetic stdin replay proves adapter
behavior, **not** real Codex dispatch/trust. After activation, complete a normal turn
and confirm that `latest.json` was generated without manually invoking the adapter.
