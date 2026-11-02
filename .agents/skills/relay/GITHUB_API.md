# Agent Relay v1 — GitHub API client transport

This is a **transport adapter procedure**, not a second protocol. The canonical wire
format and behavioral rules remain in [SKILL.md](SKILL.md); `scripts/agent-relay`
is the canonical executable implementation. A GitHub API client must obey the same
rules and stop if its available tools cannot enforce them.

## Capability preflight (required, not assumed)

A connected client's tools must actually support all of:

- Read the **commit SHA** at `refs/heads/relay/<id>`, and fetch `relay.md` from
  that exact commit, returning the file's **blob SHA**.
- Update the existing `relay.md` on the **named branch** with its previous blob
  SHA as a conditional write (conflict/409 if stale), returning a commit SHA.
- Fetch the published file **by returned commit SHA** and read the current
  branch HEAD afterwards. When HEAD advanced, verify ancestry by comparing commits.
- Read Git commit history when needed for `in_reply_to`, gaps, historical
  read receipts and recovery. The tools must expose the required history; do
  not fabricate it.

On ChatGPT's GitHub connector, the available equivalents can be `fetch` (GET
Git refs/commit data), `fetch_file`, `update_file`, `compare_commits` and
`fetch_commit`. Discover **current tool capabilities and permissions** before
using them; a repository file cannot install or enable a ChatGPT tool.

`init` still requires an **orphan root commit**. If the connector cannot create
a commit with *zero parents* and an orphan ref, create the conversation from a
Git CLI-capable client instead. Never create `relay/<id>` from `main` as a
substitute: it would no longer be an orphan branch with one file. This limitation
does not prevent API clients from joining an existing conversation.

No additional GitHub token is needed when the already-connected GitHub tools
have sufficient permissions. If a tool is unavailable or its execution is blocked,
STOP and report the exact missing capability. A new repository script alone does
not make that capability available inside ChatGPT.

## Read-only preflight

1. Fetch remote `refs/heads/relay/<id>` and record its commit SHA `H`.
2. Fetch `relay.md` **pinned to H**; retain its blob SHA `B`.
3. Parse the single current document using the canonical format:
   `# Agent Relay`, one `key: value` per header, `## Message` followed by
   one blank separator line and the UTF-8 body. The complete message body must
   be preserved, including intentional leading blank lines.
4. Verify ID = branch ID; valid record type/state/sequence; exactly one or two
   distinct participants; message `from` and `to` must differ and belong
   to the participants. Validate `message_id`, `read_by`, `reply_expected`
   and `in_reply_to` per canonical Skill and CLI. Identify this client
   explicitly (`RELAY_AGENT` or user-provided identity); transport addressing
   is not authentication.
5. Never use `main` as the default `ref` or default `branch` during these calls.

A status request **displays** metadata only. The GitHub contents endpoint
returns the full file, but the client must discard and not process/expose its
message body for status. Processing message content is allowed on explicit
`Lee` / `read`, or when required to carry out another expressly requested
relay operation. Do not add polling or hooks.

## Write operations (same document, same CAS)

For each write: perform the preflight above; build **the entire replacement**
`relay.md` in canonical header order; submit a conditional `update_file`
using `branch=relay/<id>` and the captured **blob SHA B**; never force or
write the default branch. If GitHub rejects the write, STOP and report the
conflict: do not retry automatically and do not acknowledge a different message.

- **join**: only from an open `init` with one participant; append the caller
  as the second, `type: join`, `sequence: 0`, `joined: caller`. Existing
  joined participants are idempotent (no write). Never add a third participant.
- **send**: requires two participants and open state. New
  `sequence = current.sequence + 1`, new UUIDv4 `message_id`, `from=caller`,
  `to=the other participant`, explicit `reply_expected=true|false`,
  `read_by=none`, UTC `created_at`, UTF-8 nonempty body (at most 65536
  bytes, no evident credentials). A reply uses `in_reply_to` with an
  **existing earlier sequence addressed to caller**, verified from history.
  A reply is an implicit acknowledgement; do not write an additional `ack`.
- **ack**: caller must be the latest message's `to`; require the exact
  `message_id` observed on read. If already `read_by: caller`, do not
  write. Otherwise modify **only the `read_by` header**, preserving every
  other byte of the current file. Process before acknowledging; a pending
  `reply_expected=true` is not considered answered merely by `read_by`.
- **close**: only an existing participant in an open, two-participant
  conversation; terminal `type: close`, `state: closed`, and next sequence.
  This closes the conversation, not the underlying task or approval.
- **read**: validate recipient; wrong recipient => `No corresponde - XXXX`
  and no processing or write. Historical reads must not acknowledge.

## Publication verification and user receipt

After a successful conditional write:

1. Fetch `relay.md` pinned to the **returned commit SHA C**, validate the
   expected type, sequence, message/recipient or ack ID and exact content.
2. Re-fetch the remote branch HEAD. If it is C, success. If it has advanced,
   verify C is an ancestor of HEAD and the correct message/ack is preserved
   in the history. Otherwise report `No verificado`, never `Listo`.
3. Put the permanent link
   `https://github.com/<owner>/<repo>/blob/<C>/relay.md` before the final
   `Listo - XXXX` or `Leído y registrado - XXXX`. It is a constructed
   link, not an HTTP-verified page. Related documents use their **own**
   revision/URL, never the orphan relay's SHA.
4. If the update is rejected, stop without claiming publication. If remote
   verification is unavailable or a tool blocks the update, report that
   specifically; do not infer success. Lost responses may represent an
   already published commit: inspect history before any user-authorized retry.

On a blocked or failed write, classify from observed evidence only (platform policy,
provider/API error, conflict, network, unknown) and report: operation, UTC time, tool,
repository/branch, last verified HEAD, expected blob SHA, content length, sanitized
error, HTTP status/request ID if exposed, and the read-only post-check. Do not infer
the cause, record request bodies or credentials, retry automatically, or reword the
call to evade a safety control. A block does not prove GitHub received it; checking
HEAD and history reduces uncertainty but does not prove the original call never
executed.

The contents API's conditional **blob** SHA protects one-file relay updates
against ordinary competing writes. It is not a general branch-head transaction
or an identity/authentication mechanism. A read acknowledgement remains
best-effort and cannot be atomically committed with external work.

## Compatibility and acceptance

The API and CLI share the **wire format**, not a runtime validation library:
ChatGPT does not execute Python from a repository merely because the file
exists. Validate equivalent cases against `scripts/test-agent-relay` and
its fixtures, including two participants, wrong recipient, stale ack, same
sequence after ack, reply `in_reply_to`, byte-for-byte body preservation,
non-forced conflicts, idempotence, close, SHA-pinned link and lost-verification
reports. Demonstrate both directions on a **dedicated test conversation**
before claiming end-to-end interoperability; do not use an active work relay
as a test fixture. Client-tool policy blocks cannot be fixed by repository
changes.
