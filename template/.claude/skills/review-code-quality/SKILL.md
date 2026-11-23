---
name: review-code-quality
description: Strict structural code-quality review of a PR diff - missed simplifications, spaghetti branching, file-size growth, thin abstractions, unclear type boundaries, logic in the wrong layer.
---
# Code quality review (strict, structural)

Adapted from the ideas in Cursor's "thermo-nuclear code quality review" skill
(github.com/cursor/plugins, cursor-team-kit). Rewritten for the software factory's `reviewer-code`. You read the job's worktree with Read, Grep and Glob (absolute paths) and Bash (`cd <worktree> && ...`). The factory's checks already ran; run a command only to confirm a specific finding, never one that rewrites files.

Your job is not to check that the code works. It's to decide whether the PR leaves the codebase
simpler or messier, and to push hard for the simpler version when one is visible.

## Mindset

- **Look for the "code judo" move first.** Before anything else, ask: is there a restructuring that
  keeps the behavior but makes whole branches, helpers, flags or layers disappear? A cleaner version
  of the same messy idea is not enough if a much simpler idea is available.
- **Delete, don't rearrange.** A refactor that moves complexity around without reducing the number of
  concepts a reader has to hold is not an improvement.
- **"It works" is not approval.** Correct behavior that leaves the code more tangled is still a
  finding.
- **Few, high-conviction findings.** One structural finding beats ten cosmetic ones. Skip naming and
  formatting nits entirely when there are structural problems.

## Rules

1. **File size.** For each changed file, compare its line count at the base
   (`git show <base>:<path> | wc -l`) with HEAD (`wc -l <path>`). A file this branch pushed past
   1000 lines: flag it and ask whether it should be decomposed first, unless the file is still clearly organised
   for a compelling structural reason. Anchor the finding on the first added line of that file.
2. **No spaghetti growth.** Be suspicious of new ad-hoc conditionals, one-off flags, nullable modes
   or special cases inserted into an existing, unrelated flow. That's a design problem, not style:
   the logic belongs behind its own helper, policy, state model or module.
3. **Earn every abstraction.** Flag thin wrappers, identity or pass-through helpers, and generic
   "magic" mechanisms that hide a simple data shape. Direct, boring code wins.
4. **Explicit boundaries.** Question unnecessary optionality, `any`/`unknown`, casts, and
   loosely-shaped dicts where a typed model would make the contract clear. A silent fallback that
   papers over an unclear invariant (`or {}`, bare `except`, default values that hide errors) is a
   boundary problem.
5. **Canonical layer and helpers.** Flag feature logic leaking into shared code, implementation
   details leaking through an API, and bespoke helpers that duplicate one the codebase already has.
   Use Grep to confirm a canonical helper exists before claiming duplication.
6. **Orchestration.** Flag independent work that's serialized for no reason, and related updates that
   can leave state half-applied, when the cleaner structure is obvious. Leave pure speed concerns to
   the performance reviewer.
7. **Duplication.** Copy-pasted logic should be one helper.

## Questions to ask of every meaningful change

- Could this be reframed so fewer concepts, branches or layers are needed?
- Did it add branching where a missing model or helper should exist? Do repeated conditionals hint
  at one?
- Is the logic in the right file and layer?
- Did a cohesive module become more coupled, stateful or harder to scan?
- Is each abstraction earning its keep?

## Severity

Rate each finding with these severities. In the factory they all go under Notes (see below), so
the severity tells the builder and the approver what matters most.

| Severity | Use for |
|---|---|
| `high` | Presumptive blockers: a clear code-judo simplification left on the table while lots of incidental complexity is preserved; a file pushed past 1000 lines; ad-hoc branching that tangles an existing flow; feature checks scattered through shared code; an unnecessary wrapper/cast-heavy contract; duplicating an existing helper or putting logic in a clearly wrong layer |
| `medium` | Structural issues that make the code harder to reason about but aren't blockers |
| `low` | Legibility issues. Only report these when there are no bigger problems |

Do not use `critical`; that's reserved for security and data-loss issues.

## In the factory

You run as a factory reviewer: the reviewer agent that loaded this skill owns
where you work, what you read and the file you write. This skill is the method.
Write each result into that review file as a numbered item:

`<path:line> [<severity>] <title>: <detail>`

- Every severity goes under **Notes**: structural and style issues, including a file pushed past
  1000 lines and spaghetti growth, never make the verdict `CHANGES` on their own.
- The exception is duplicating a helper the codebase already has, which breaks the repo's
  conventions: that goes under **Findings**.

The `## Summary` bullets in the review file carry what this skill asks the
summary to say: whether the branch clears the bar, and the one or two changes that would matter most.

## Writing each finding

- title: the structural problem, not a symptom ("Retry policy bolted into request handler").
- detail: what's wrong, why it hurts maintainability, and the concrete restructuring that fixes it.
  Name the move: delete the layer, extract the helper, introduce the model, move it to the module
  that owns the concept.
- Be direct and serious. Don't soften a structural regression into a suggestion. Don't be rude.

Examples of the right tone:

- "This pushes `service.py` from 940 to 1,120 lines. Can we split the parsing out first?"
- "This adds another special case to an already busy flow. Can it live behind its own abstraction?"
- "This wrapper only forwards its arguments. Can we call the underlying function directly?"
- "There's a simpler framing here: if the state model tracked X, these three branches disappear."
- "Why is this optional? Making the boundary explicit would remove the fallback below."

## Summary

State whether the PR clears the bar: no structural regression, no visible missed simplification, no
unjustified file-size growth, no spaghetti branching, no unnecessary abstraction, no boundary leak.
If it doesn't, name the one or two changes that would matter most.
