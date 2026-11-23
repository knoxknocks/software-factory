---
name: review-security
description: Source-first security review of a PR diff - find changes that violate a real trust boundary, with evidence, calibrated severity, and the smallest effective fix. Based on Cloudflare's security-audit skill (guidance mode).
---
# Security review

Based on Cloudflare's security-audit skill (github.com/cloudflare/security-audit-skill, commit
c1c8a8c, MIT license, see `references/LICENSE-cloudflare-security-audit`). This is the skill's
**guidance mode** applied to one pull request. The full six-phase audit workflow (coverage ledger,
hunter and verifier sub-agents, report files, validators) does not apply here and is not included.

## Goal

Find changes in this diff that **violate a real trust boundary**, then give the author the source
evidence, a calibrated severity, and the smallest effective fix. A candidate without a concrete
affected principal, resource, or security outcome is not a finding.

You review source only. You read the job's worktree with Read, Grep and Glob (absolute paths) and Bash (`cd <worktree> && ...`). The factory's checks already ran; run a command only to confirm a specific finding, never one that rewrites files. Never probe live endpoints or suggest doing so.

## Procedure

1. **Identify what the diff touches.** Entry points, parsers, auth checks, data access, external
   calls, config/IaC, CI, prompts or tool calls, client-side rendering.
2. **Run the built-in checklist below** against every changed line.
3. **Load the reference for every domain the diff touches** with Read, from `references/` next to this file. This is required,
   not optional: if a changed file falls in a row of the table below, read that row's document
   before recording findings, even if the checklist already covered it. A PR that touches CI and
   IaC loads both. Skip references only when the diff touches none of these domains.
   `ATTACK-CLASSES.md` is an optional general catalogue for diffs that don't fit a row:

   | Diff touches | Reference |
   |---|---|
   | HTTP handlers, APIs, sessions, JWT/OAuth/OIDC/SAML, API keys, mTLS | `WEB-PROTOCOL-AND-AUTH.md` |
   | LLM prompts, RAG, agent tools, MCP, model-controlled actions | `AI-AND-LLM.md` |
   | IAM, IaC (CDK/Terraform), containers, serverless, ingress, runtime config | `CLOUD-AND-DEPLOYMENT.md` |
   | Multi-tenant data, caches, search, exports, deletion, retention | `DATA-ISOLATION-AND-LIFECYCLE.md` |
   | Browser code, DOM rendering, CORS, postMessage, extensions | `CLIENT-SIDE.md` |
   | Dependencies, lockfiles, CI workflows, release/signing, plugins | `SUPPLY-CHAIN-AND-RELEASE.md` |
   | gRPC, GraphQL, queues, pub/sub, webhooks, custom protocols | `PROTOCOLS-RPC-AND-MESSAGING.md` |
   | Untrusted work consuming shared CPU, memory, quotas, or spend | `RESOURCE-EXHAUSTION-AND-AVAILABILITY.md` |
   | C/C++/unsafe Rust, FFI, binary parsers | `MEMORY-SAFETY-AND-BINARY.md` |
   | Desktop/mobile apps, deep links, local daemons, IPC | `DESKTOP-MOBILE-AND-LOCAL-IPC.md` |

   The references were written for the full audit. Ignore their mentions of phases, sub-agent
   types, ledgers and output files, and use them as lists of attack classes and checks.
4. **Trace each candidate** from the untrusted input to the sink or decision, using Grep and Read for
   code outside the diff (callers, auth middleware, validation helpers, config).
5. **Classify** each candidate as a boundary violation, a weakened control, or needs validation
   (below), then record it.

## Built-in checklist

`reviewer-infra` also reviews IAM, exposure and IaC settings for operational fit. You still own
the security outcome of those changes: report boundary violations there as usual.

Check every changed line for:

- **Injection:** SQL/NoSQL, shell (`shell=True`, `os.system`, string-built commands), templates,
  LDAP/XPath, log injection; untrusted data reaching a sink indirectly (stored, then reused).
- **Input handling:** path traversal, SSRF via user-controlled URLs, unsafe deserialization
  (`pickle`, `yaml.load`), missing validation at a trust boundary, regex DoS.
- **AuthN/AuthZ:** routes without auth, missing ownership or tenant checks (IDOR), ids or roles
  taken from the request instead of the session, JWTs not fully verified (signature, `exp`, `aud`).
- **Secrets:** hardcoded keys, tokens or passwords; secrets in logs, errors, URLs or responses.
- **Crypto and transport:** weak password hashing (MD5/SHA1, unsalted), weak ciphers or modes,
  disabled TLS verification, insecure cookie flags, permissive CORS.
- **Cloud and IaC:** wildcard IAM actions or resources, `iam:PassRole` on `*`, public principals,
  unauthenticated function URLs or endpoints, public buckets, security groups open to the world,
  encryption or logging turned off.
- **CI and supply chain:** `pull_request_target` or `workflow_run` running untrusted PR code with
  secrets or write tokens; `${{ github.event.* }}` interpolated into `run:`; third-party actions or
  dependencies pinned to a branch or tag instead of a commit SHA in privileged jobs; new
  install/build scripts with network access during release.
- **LLM and agents:** untrusted content reaching prompts that can trigger tools, model output used
  as code, shell or SQL, tools with broader authority than the caller.

## Weakened controls

A PR that **removes or weakens an existing control, or adds an over-broad permission**, is a finding
even without a proven end-to-end exploit. That's the point of reviewing a diff. This includes
everything in the checklist above: wildcard IAM, public principals, unauthenticated endpoints,
disabled verification, weaker hashing, privileged workflows running PR code, unpinned privileged
actions. Rate it by the anchors below if the source shows a full exploit path, otherwise:

- `medium` when it widens access or authority (over-broad IAM, public principal, unauthenticated
  endpoint, unpinned action in a privileged workflow);
- `low` when it only weakens defense in depth (cookie flags, a less safe default with another
  control still in place).

"Needs validation" is only for claims that depend on a fact outside the repository. If the diff
itself introduces the weakening, record it; mention the outside fact (e.g. "S3 Block Public Access
may block this policy at deploy time") in the detail instead.

## Require a boundary and a result

For every candidate, name:

- the lower-trust principal (who controls the input or action);
- the accepted input or action;
- the intended control;
- the boundary that is crossed;
- the affected principal or resource;
- the concrete result.

Do not elevate a missing best practice, guessed deployment behavior, generic parser crash, or
self-impact into a security finding.

## Confirmed vs needs validation

- **Confirmed:** the source alone establishes the full path from input to boundary violation. Record
  it with a severity.
- **Needs validation:** a specific, source-grounded boundary hypothesis is blocked on a fact the
  repository doesn't contain, e.g. proxy or gateway behavior, identity-provider policy, IAM outside
  this repo, or a deployment setting. Do **not** record these as findings, and do not give them a
  severity. List them under Notes, each starting `NEEDS-VALIDATION:`, each with the exact
  missing fact and a safe way for the owner to check it.

If the deciding control lives outside the repository, don't assume it's present or absent.

## Severity

Only confirmed findings get a severity. It cannot exceed the demonstrated impact.

| Severity | Anchor |
|---|---|
| `critical` | An unauthenticated actor gains code execution, full data-store access, or takeover of arbitrary accounts |
| `high` | An actor fully defeats an explicit security control with real consequences: auth bypass, cross-tenant read or write, stored script execution affecting other users, authenticated code execution, unauthenticated remote stop of a shared service |
| `medium` | A real boundary violation with limited blast radius, uncommon preconditions, or consequences confined to a narrow resource set |
| `low` | Disclosure of non-secret internals, or an effect needing sustained effort for minimal gain |

The high/medium test: does the result *fully defeat* an explicit control for an action with real
consequences, or only *weaken* it? If you can't state the concrete damage, the severity is lower than
it feels. Confirmed observations below `low` (informational) are not worth a finding; mention
them in the summary only if they matter as a step in a larger issue.

Committed live secrets (real API keys, tokens, private keys, passwords) are always a finding. Rate
them by what the secret unlocks.

A CI workflow that runs code from an untrusted PR with secrets, cloud credentials or a write token
lets anyone who can open a PR run code with that authority: that's unauthenticated code execution,
so `critical`.

## In the factory

You run as a factory reviewer: the reviewer agent that loaded this skill owns
where you work, what you read and the file you write. This skill is the method.
Write each result into that review file as a numbered item:

`<path:line> [<severity>] <title>: <detail>`

- Confirmed `critical`, `high` and `medium`: under **Findings**. They make the verdict `CHANGES`.
- Confirmed `low`: under **Notes**.
- Needs validation: under **Notes**, each starting `NEEDS-VALIDATION:` with the missing fact and the
  owner-side check. They don't block, but the approver reads them.

The `## Summary` bullets in the review file carry what this skill asks the
summary to say: whether the diff introduces a confirmed boundary violation, and how many needs-validation items there are.

## Writing each finding

- title: the violation, not the category ("Tenant id from request body bypasses org scoping").
- detail, in this order:
  1. The path: principal → input → missing or wrong control → affected resource → result.
  2. The invariant the code must enforce.
  3. The smallest effective fix at the last trusted decision point, plus a regression test to add.
     Prefer a specific change over generic hardening advice.
- Anchor the finding on the diff line where the control is missing or wrong.

## Anti-patterns

Do not report:

1. Checklist deviations presented as vulnerabilities.
2. Generic defense-in-depth advice about code the diff didn't change. (A control the diff
   weakens is a finding; see "Weakened controls".)
3. Guesses about provider, proxy, browser, identity, or deployment behavior not present in source
   (use "Needs validation" instead).
4. Intended same-principal authority or self-impact presented as a cross-boundary result.
5. A parser or runtime effect stronger than the source supports.
6. A severity on anything that isn't confirmed.

## Summary

Say whether the diff introduces a confirmed boundary violation. Then list any "Needs validation"
items, each with its missing fact and the owner-side check. If the diff doesn't touch a trust
boundary, say so in one sentence.
