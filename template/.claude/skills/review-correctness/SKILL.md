---
name: review-correctness
description: Find logic and data bugs a PR introduces - wrong results, broken callers, races, incomplete enum handling, state-machine paths, unsafe migrations, breaking API changes. Every finding needs a concrete failing case.
---
# Correctness review

Adapted from gstack's pre-landing review checklist and its state-machines, data-migration and
api-contract specialists (github.com/garrytan/gstack, commit 3c15b72, MIT, see `LICENSE-gstack`)
and from ponytail-review (github.com/DietrichGebert/ponytail, commit 96608e0, MIT, see
`LICENSE-ponytail`). Rewritten for the software factory's `reviewer-code`. You read the job's worktree with Read, Grep and Glob (absolute paths) and Bash (`cd <worktree> && ...`). The factory's checks already ran; run a command only to confirm a specific finding, never one that rewrites files.

## The evidence rule

**Every finding needs a concrete case: "this input or situation leads to this wrong result".**
No case, no finding.

Before recording, re-read the lines and confirm the case is real: the caller exists, the value can
really be empty, the branch really is reachable, the old behavior really changed. Use Grep
and Read for anything outside the diff. No style opinions, no "consider", no vague worries.

## Checklist

### Logic and edge cases
- Off-by-one, inverted or wrong conditions, wrong operator, wrong default.
- Missed edge cases: empty, zero, negative, the last item, a single element, rounding, time zones,
  encodings.
- A caller broken by the change: a changed signature, return type, exception or meaning whose
  callers weren't updated.
- A fix applied in one caller while the shared function stays broken.
- Async mistakes: a missing `await`, a task started and never awaited, a result used before it's
  ready.
- Resources (files, connections, locks) not released on an error path.

### Data safety and concurrency
- Check-then-act (TOCTOU): read, check, then write without an atomic condition, unique constraint,
  or duplicate-key handling. Find-or-create without a unique index creates duplicates.
- Status transitions that aren't atomic (`UPDATE ... WHERE status = old`), so concurrent requests can
  skip or double-apply a transition.
- Writes in the wrong order or outside a transaction, so a failure leaves state half-applied.
- Errors swallowed on a write path, so data is silently lost.
- Direct DB writes that bypass model validation.

### Enum and value completeness
When the diff adds an enum value, status, kind, type constant or flag, or **loosens what an input
accepts** (a new MIME type, a widened validator):
- Trace the value through **every consumer**: each `switch`/`case`/`if` chain, filter, allowlist,
  serializer and display. Find them with Grep (search for the sibling values and the
  field name), then read them; the broken consumer is usually outside the diff.
- Check that `case`/`if-elif` chains don't send the new value to a wrong default.
- Check allowlists and sibling-value arrays that should now include it.

### State machines
If the diff touches a record with a kind and a pending status that an action settles (proposals,
approvals, holds, moderation, invitations, jobs):
- For each kind × action, work out the row the owner expects from the kind's meaning (deleted,
  kept, deactivated, rewritten), not from what the code does.
- **Wrong row:** a kind × action that leaves a different row, e.g. "deactivate" going down the
  "delete" path.
- **Collapsed kinds:** a branch that sends several kinds down one destructive path. That's a finding
  even if one kind is tested.

### Migrations and deploy safety
- Data loss: dropping a column or table that still holds data, narrowing a type, a rename whose
  references weren't all updated, `NOT NULL` added to a column with existing nulls without a
  backfill.
- No working rollback, or a rollback that silently no-ops.
- Deploy order: new schema with old code (or the reverse) during a rolling deploy breaks. Flag
  changes that need code and schema to ship in a specific order without a guard.

### API and contract changes
- Removed or renamed response fields, changed field types, new required parameters, changed
  methods or status codes, changed auth requirements on an existing endpoint.
- Changed webhook or event payloads that existing consumers parse.
- Changes that break older clients that can't upgrade (mobile apps, SDKs), with no versioning or
  compatibility path.

### Boundaries
- Time windows: "today" keys that assume a 24-hour day in one time zone; related features that
  bucket the same data differently (hourly vs daily).
- Type coercion across boundaries (JSON, query strings, DB, other languages): numbers becoming
  strings, `8` vs `"8"` producing different hashes or cache keys, missing normalization before
  comparing or hashing.

## Sideways sweep

A finding is a defect class, not a single line. Before recording one, check whether the same
pattern exists at sibling call sites (other routes, workers, commands, handlers); use Grep
to find them. Record **one** finding, rated by the worst sibling, and list the siblings in
the detail.

If a changed function has twins that are supposed to stay in sync (a mirrored helper, a parity
test, a "keep in sync with X" comment), flag each twin the diff left unchanged.

## Severity

| Severity | Use for |
|---|---|
| `critical` | Data loss or corruption: destructive wrong row, collapsed kinds on a delete path, unsafe migration that drops data, swallowed write errors |
| `high` | Wrong results or crashes on normal input; broken callers; races that double-apply or skip changes under ordinary concurrency; breaking API change with no compatibility path |
| `medium` | Wrong behavior on edge cases or uncommon input; incomplete enum handling with a safe-ish default |
| `low` | Unlikely edge cases with minor consequences |

## In the factory

You run as a factory reviewer: the reviewer agent that loaded this skill owns
where you work, what you read and the file you write. This skill is the method.
Write each result into that review file as a numbered item:

`<path:line> [<severity>] <title>: <detail>`

- `critical`, `high` and `medium`: under **Findings**. They make the verdict `CHANGES`.
- `low`: under **Notes**.

The `## Summary` bullets in the review file carry what this skill asks the
summary to say: whether the diff introduces a confirmed bug, the riskiest one, and anything you suspected but couldn't confirm.

## Writing each finding

- title: the bug ("Deactivate proposals delete the target record").
- detail: the concrete case (input or situation → wrong result), why it happens (the line and
  the condition), and the smallest fix that works. Prefer fixes that delete code; never propose new
  layers, frameworks or config the problem doesn't need. Name siblings if the sweep found any.
- Anchor on the diff line that causes the bug.

## Summary

Say whether the diff introduces a confirmed bug, and name the riskiest one. If you suspected
something but couldn't confirm it (e.g. a consumer you couldn't read), say what you'd need to check.
