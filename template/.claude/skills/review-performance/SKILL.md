---
name: review-performance
description: Find performance and scalability regressions a PR introduces - N+1 queries, missing indexes, quadratic work, unbounded results, blocking calls in async code, risky migrations, uncapped spend.
---
# Performance and scalability review

Adapted from gstack's performance and data-migration specialists and its review checklist
(github.com/garrytan/gstack, commit 3c15b72, MIT, see `LICENSE-gstack`) and from ponytail-review
(github.com/DietrichGebert/ponytail, commit 96608e0, MIT, see `LICENSE-ponytail`). Rewritten for
the software factory's `reviewer-performance`. You read the job's worktree with Read, Grep and Glob (absolute paths) and Bash (`cd <worktree> && ...`). The factory's checks already ran; run a command only to confirm a specific finding, never one that rewrites files. Don't profile or load-test.

## The scale rule

Look for code that is **fine for one user and wrong for many**. Only report an issue when the input
size or call frequency on that path makes it matter. Say what realistic growth triggers it ("one
query per order; a 500-order export makes 500 queries").

- Big slowdowns, unbounded growth and outages are findings.
- Small wins (work repeated in a hot loop) are `low` at most.
- No micro-optimizations, no "consider caching" without a measured or obvious cost.

## Checklist

### Queries and data access
- **N+1:** queries or API calls inside loops, ORM associations traversed in a loop without eager
  loading, nested serializers that lazy-load, GraphQL resolvers that query per field instead of
  batching.
- **Missing indexes:** new `WHERE` or `ORDER BY` on unindexed columns, multi-column filters without a
  composite index, new foreign keys without an index. Find the schema or migration with
  Grep (e.g. pattern `CREATE INDEX`, or Glob `**/*.sql`).
- **Unbounded results:** list endpoints or queries without a limit or pagination; responses that
  embed full nested objects that grow with data.

### Algorithms and memory
- Quadratic or worse work on inputs that can be large: nested loops over collections, a linear
  `find`/`in` inside a loop, re-sorting or re-filtering the same collection repeatedly.
- String concatenation in loops.
- Memory or collections that only grow (caches without eviction, per-process lists, listeners never
  removed).

### Concurrency and I/O
- **Blocking in async code:** synchronous HTTP, file, subprocess or DB calls inside `async`
  functions; `time.sleep` in an event loop.
- Independent calls made one after another where they could run together (sequential awaits,
  fetch waterfalls).
- The same work done by every process or replica that should happen once; per-process state that
  must be shared.
- Network calls without timeouts; retries without backoff or a limit.

### Migrations
`reviewer-data` owns whether a migration is safe and whether a lookup has an index at all. Report
these only for their performance effect (lock time, scan cost), and say so.
- `ALTER TABLE` or index creation on large tables that takes long exclusive locks (e.g. Postgres
  without `CONCURRENTLY`).
- Backfills that update every row in one statement instead of batches.

### Frontend (when the diff touches it)
- Heavy new dependencies or whole-library imports, large unoptimized assets, missing route-level
  code splitting.
- Re-renders from unstable references, expensive computation in render, layout thrashing, missing
  lazy loading below the fold.

### Spend
- **Uncapped spend:** a paid API or LLM call, retry or loop with no cap on count, tokens or cost.
  This is always `critical`.

## Severity

| Severity | Use for |
|---|---|
| `critical` | Uncapped spend; a change likely to take the service down or exhaust a shared resource under normal load |
| `high` | Likely timeouts or severe slowdown under normal load (N+1 on a main path, unbounded endpoint, blocking call in a shared event loop, long table lock in a migration) |
| `medium` | Noticeable latency or cost at realistic scale |
| `low` | Minor inefficiency |

## In the factory

You run as a factory reviewer: the reviewer agent that loaded this skill owns
where you work, what you read and the file you write. This skill is the method.
Write each result into that review file as a numbered item:

`<path:line> [<severity>] <title>: <detail>`

- `critical` and `high`: under **Findings**. They make the verdict `CHANGES`.
- `medium` and `low`: under **Notes**.

The `## Summary` bullets in the review file carry what this skill asks the
summary to say: whether the diff introduces a regression that matters at realistic scale, and the worst one.

## Writing each finding

- title: the regression ("Export runs one query per order").
- detail: the path, what grows (rows, users, items) and the realistic effect, then the smallest fix
  (eager load, batch, index, limit, `asyncio.to_thread`, a cap).
- Anchor on the diff line that introduces it.

## Summary

Say whether the diff introduces a regression that matters at realistic scale, and name the worst one.
