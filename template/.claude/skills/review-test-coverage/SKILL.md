---
name: review-test-coverage
description: Find test gaps and weak tests in a PR - risky new logic without a test that would fail when it breaks, missing negative paths and edge cases, untested state transitions, flaky or low-value tests, regression tests without proof.
---
# Test coverage review

Adapted from gstack's testing and state-machines specialists and its review checklist
(github.com/garrytan/gstack, commit 3c15b72, MIT, see `LICENSE-gstack`) and from ponytail-review
(github.com/DietrichGebert/ponytail, commit 96608e0, MIT, see `LICENSE-ponytail`). Rewritten for
the software factory's `reviewer-code`. You read the job's worktree with Read, Grep and Glob (absolute paths) and Bash (`cd <worktree> && ...`). The factory's checks already ran; run a command only to confirm a specific finding, never one that rewrites files. Don't re-run the test suite.

## The rule

**Risky new logic needs one good test that fails when it breaks. Not coverage percentage.**

Risky means: a new branch, a parser, money, auth or permissions, data writes or deletes, state
transitions, or a bug fix. Trivial getters and pass-through code don't need their own tests.

## Procedure

1. List the behaviors the diff adds or changes, especially the risky ones.
2. For each, look for a test that exercises it: in the diff first, then with Grep for the
   function or behavior name in test files, then Read.
3. If you can't find a test, say what you searched for rather than just asserting none exists.
4. Anchor each gap on the **untested production line**, and say exactly which test to add: inputs,
   setup and the expected outcome.

## Checklist

### Missing tests for new behavior
- New public functions, endpoints or commands with no test.
- Changed functions whose existing tests only cover the old behavior, not the new branch.
- A bug fix with no regression test.
- A path whose only tests are weak (smoke, "doesn't crash", asserts nothing meaningful) is still a
  gap.

### Negative paths and edge cases
- Error branches, guard clauses and early returns with no failure-path test.
- Auth or permission checks never tested for the "denied" case; rate limits never shown to block;
  input sanitization never tested with malicious input.
- Boundary values: zero, negative, max, empty string or list, null, a single element, unicode.
- Concurrency-sensitive code with no test for the race.

### State machines
If the diff touches a record with a kind and a pending status that an action settles (proposals,
approvals, holds, jobs): every kind × action pair needs a test asserting the resulting row. A test of
a sibling kind that happens to share the code path does **not** cover it. Report each untested pair,
especially destructive ones (delete, deactivate, replace).

### Negative assertions
- A new assertion that something is absent (`not in`, `not.toContain`, `pytest.raises` on a call
  that used to succeed) records a behavior removal. Flag it unless the spec, build.md or diff
  explains why the removal is intended.
- When the diff renames or removes an identifier, string or flag, an existing test asserting the old
  value is absent now passes forever and guards nothing. Search the tests for the old value with Grep.

### Test quality
- **Low-value tests:** no meaningful assertion, asserting the test's own setup, mirroring the
  implementation, mocking away the code under test, or a production seam (export, flag, hook) that
  only tests use. A good test answers: what behavior does it protect, and what realistic regression
  would make it fail?
- **Isolation:** shared mutable state, order dependence, real network calls, reliance on the system
  clock, time zone or locale.
- **Flakiness:** sleeps or tight wall-clock bounds (`assert elapsed < 0.5`), assertions on the order
  of unordered results, unseeded random data, a timeout raised or a retry added just to make a flaky
  test pass.
- **Regression test without red proof:** a test described as a regression test with no sign
  (commit message, build.md) that it failed before the fix. Ask for that record.

## Severity

| Severity | Use for |
|---|---|
| `high` | Untested risky logic in money, auth, data deletion, state transitions, migrations or concurrency; an untested destructive kind × action pair |
| `medium` | Untested core logic, error handling or a bug fix; tests that can't fail; flaky tests |
| `low` | Weak or implementation-coupled tests; minor edge cases |

Do not use `critical`.

## In the factory

You run as a factory reviewer: the reviewer agent that loaded this skill owns
where you work, what you read and the file you write. This skill is the method.
Write each result into that review file as a numbered item:

`<path:line> [<severity>] <title>: <detail>`

- `high` and `medium`: under **Findings**. They make the verdict `CHANGES`.
- `low`: under **Notes**.

The `## Summary` bullets in the review file carry what this skill asks the
summary to say: whether the risky behavior is protected by tests, and the most important test to add.

## Writing each finding

- title: the gap ("Refund over-limit branch has no test").
- detail: which behavior is unprotected, the realistic regression that would slip through, and the
  test to add (name, setup, inputs, expected result). Mention the files you checked.
- Anchor on the untested production line (or, for a bad test, the test line).

## Summary

Say whether the risky behavior in this diff is protected by tests, and name the most important test
to add.
