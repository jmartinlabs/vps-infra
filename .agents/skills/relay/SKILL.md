---
name: relay
description: Exchange substantive messages between two agents through one Git branch, with explicit reads and verified publication.
---

# relay

Optional, user-triggered transport for a two-participant conversation. It is not a work
queue, a controller, an approval channel or a second source of truth. The canonical packet
and return contracts remain in [the work packet](../../../templates/agent-work-packet.md)
and [coordinator communication](../../../specs/methodology/coordinator-communication.md).

Clients without Git/Python can use the [GitHub API transport procedure](GITHUB_API.md)
with an already-connected GitHub tool. This is the same relay format and semantics,
not another protocol. A repository Skill does not enable tools in ChatGPT automatically.

## Inputs
- An explicit user request to use the relay: `Lee`, `$relay read` or another named relay
  command. Never read relay messages proactively, on a timer or through a hook.
- The active conversation ID, or the ID supplied by the user. If the context is lost, ask
  for the ID; never invent one.
- The agent identity from `RELAY_AGENT` or the client's configured identity. If it is
  missing, ask once and keep it in the current conversation context. This is transport
  addressing, not authentication of the pusher.
- An open conversation with exactly two participants. Use `join` before sending or
  acknowledging messages.

## Outputs
- A validated message read, a verified response, a verified read acknowledgement or a
  verified conversation close.
- A short user-facing receipt: `Listo - XXXX` after verified publication,
  `Leído y registrado - XXXX` after a verified read acknowledgement, or an explicit error.
- A partial receipt when publication succeeded but remote verification did not:
  `Publicado, no verificado` for init/join/close, `No verificado - XXXX` for a sent
  message and `Leído, no verificado - XXXX` for a read acknowledgement. Never use
  `Listo` or `Leído y registrado` in that state.
- A clickable GitHub link pinned to the published commit after verified publication:
  `[XXXX](https://github.com/<owner>/<repo>/blob/<sha>/relay.md)`. If the remote is not
  GitHub or cannot be derived reliably, print `commit <sha>` and do not invent a URL.
  Related tracker, SPEC, PR or evidence links only when relevant and already known or
  verified; use their own reference/SHA, never the orphan relay SHA. Do not claim a link
  is verified without checking its destination.
- No commit, push or file change for a read that needs no response and has already been
  acknowledged.

## Procedure
1. **Initialize.** `relay init "<description>"` generates a unique ID and creates an
   orphan branch `relay/<id>` with one `relay.md` file. The initiator is the first
   participant. Tell the user the ID so the second participant can join.
2. **Join.** `relay join <id>` identifies the current agent and adds it as the second
   participant. Only two participants are allowed. A closed or full conversation rejects a
   new participant; an existing participant in an open conversation is idempotent. The
   first non-initiator to join occupies the second slot; the ID is an address, not a secret.
3. **Read.** On `Lee` or `$relay read`, fetch the branch and inspect the latest record.
   Validate the conversation, state, recipient, sequence and commit. If the latest record
   is addressed to another participant, report `No corresponde - XXXX` and do not process
   it. If it is already marked `read_by` for this agent, report
   `Leído y registrado - XXXX` without writing and include the pinned message or
   acknowledgement link when available. If context was lost, read the body from history
   for understanding without re-marking it or repeating effects.
4. **Respond or acknowledge.** If the message requires a response, publish it with
   `relay send <id> --body-file <path> --reply-expected true --in-reply-to <sequence>`;
   the response is the implicit read acknowledgement, so do not create a separate read
   commit. If no response is required, run `relay read --ack --message-id <id>` with the
   ID returned by the read to add `read_by` to that same current message. Never mark a
   message read before processing it. A read acknowledgement keeps the message sequence
   unchanged. A read flag never answers a question: if `reply_expected=true` and no response
   with `in_reply_to` exists, answer or report the blocker even when `read_by` is already
   present. The message ID prevents acknowledging a superseded record; it is not proof that
   the body was displayed.
5. **Content of a published response.** Include the recipient (the `to` header), a brief
   summary, and relevant blockers or authorizations, or state `ninguno`/`ninguna nueva`.
   Add related tracker/SPEC/PR/evidence links only when relevant and known or verified; use
   their own reference/SHA, never the orphan relay SHA. Reuse the existing return/packet
   fields; do not invent a parallel format. Authorizations are only pending or required;
   the relay never grants an approval.
6. **Verify.** After every publish or acknowledgement, fetch the branch again and verify
   the remote result. Confirm the commit, message identity, sequence, recipient and
   `read_by` where applicable. A read acknowledgement may be verified in history even if a
   newer message is now the head. Never declare success from a local commit alone.
7. **Status.** `relay status <id>` shows conversation metadata only: state, participants,
   head, sequence and the last sender/recipient/read flag. It never prints the body and is
   not a substitute for `read`.
8. **Receipts.** Use `Listo - XXXX` only for a published and remotely verified message
   (qualify with `superado por YYYY` when it is no longer the head). Use
   `Leído y registrado - XXXX` only for a verified read acknowledgement. On a failed push,
   failed verification or unavailable remote, report the error and do not use a success
   receipt: use `Leído, no registrado` only when the current message no longer matches the
   read message ID, and `Leído, no verificado` when publication succeeded but remote
   verification did not. For init/join/close use `Publicado, no verificado`; for a sent
   message use `No verificado - XXXX`. After an unverified init, reuse the printed ID; do
   not create a second conversation. After an unverified send, the message may already be
   published; inspect remote history before retrying. After a verified publication, put
   the pinned relay link before the final receipt; the final line is `Listo - XXXX`. No
   HTTP check of the link is required, so do not call it verified. For a read-only receipt,
   put the pinned message or acknowledgement link before `Leído y registrado - XXXX`.
9. **Close.** `relay close <id>` publishes a terminal control record. It closes the
   conversation only; it does not complete the task, approve anything or authorize a merge.
   After closing, read and status remain possible; join and send are rejected.
10. **Recover context only when needed.** `relay read --seq`, `--last` and `--after` are
   internal context queries, not ordinary user commands. They never acknowledge a message.
   If the latest sequence suggests a gap, or the agent lost context, inspect the relevant
   Git history before acting. Do not create a local cursor or read receipt file.

## Stop conditions
- Stop and report on a Git conflict or rejected push. Do not force, rebase, retry
  automatically or mark a newer message.
- Stop if the recipient does not match, the conversation is closed, the agent is not a
  participant, a join would create a third participant, the ID is missing or the remote
  cannot be verified.
- Stop if neither Git CLI nor verified GitHub API operations can access the relay
  branch; report the missing capability. Do not create a parallel manual relay.
  This Skill does not automatically install or enable client tools.
- Stop if the body is empty, exceeds the size limit, is not UTF-8 text or contains an
  evident credential. The relay is repository-visible; never publish secrets or private
  personal data.
- Stop if a read acknowledgement would have to be applied to a message that is no longer
  the latest. The message ID check must fail closed; report `Leído, no registrado - XXXX`
  and leave the new message unread.
- A read acknowledgement, a response or a conversation close is never an approval,
  completion, QA pass or merge authorization. Only the user can grant those.
