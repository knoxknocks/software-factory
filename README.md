# Software factory

A template that turns GitHub issues into reviewed pull requests, using Claude
Code agents. You label an issue `factory`; the factory scopes it, writes a spec,
builds it on a branch, runs your checks, has specialist reviewers look at it,
and hands you a PR. **A person merges** (by default).

```
issue labeled `factory`
  → intake     accept / ask the author / reject; rate risk and surfaces
  → route      pick reviewers from risk and surfaces (script)
  → spec       testable acceptance criteria
  → build      one branch, one draft PR "Closes #n"
  → gate       your factory/checks.sh; a failure goes back to the builder, no reviewers run
  → review     code, security, infra, data, ux, ui: only the ones the change needs, in parallel
  → approve    APPROVE → PR ready for you · ESCALATE → PR ready with the decision you must make
```

Each job gets its own git worktree. State lives in files (`factory/jobs/`), so
a session that dies can be resumed. Every state change goes through
`factory/bin/job`, which refuses illegal moves; the orchestrating Claude session
never edits state by hand.

## Requirements

- [Claude Code](https://claude.com/claude-code), signed in
- `git` and `python3`
- [`gh`](https://cli.github.com), signed in with access to the target repo
- Optional: the `agent-browser` CLI, which the builder and the ux/ui reviewers use to look
  at pages when a change has a UI. Without it they review by reading code.

## Install into a repo

```bash
git clone https://github.com/knoxknocks/software-factory
cd software-factory
./install.sh /path/to/your-repo
```

This copies `template/` into your repo, adds `/factory/jobs/` and `/.worktrees/`
to `.gitignore`, starts an `AGENTS.md` if you have none, and creates the GitHub
labels (`--no-labels` to skip). It never overwrites a file that differs. Then:

1. **Edit `factory/checks.sh`.** It ships unconfigured and *fails on purpose*: a gate
   that always passes lets every branch through. Make it run your lint, tests and
   build, with read-only forms (no `--fix`), fast and non-interactive.
2. **Review `factory/config.json`** (table below).
3. **Fill in `AGENTS.md`.** Every agent reads it first: layout, setup, how to run
   the app on a given port, validation, conventions. See `templates/AGENTS.example.md`.
4. **Optional: add lenses** in `factory/lenses/` (see below).
5. **Commit the factory files to your base branch and push.** Jobs branch from
   `origin/<base_branch>`, so the factory must be there first.

## Use it

In Claude Code, from the repo root:

```
/factory run          every open `factory` issue, `concurrency` at a time; also resumes
/factory run 12       one issue
/factory <anything>   ask about a job, give feedback, file a feature, reject one
```

When a job needs you, `/factory run` ends by listing what waits on a human: PRs to
review (merge to approve, or reply with feedback) and questions waiting on authors.
Feedback on a `needs-human` job starts a fresh round budget:
`/factory feedback on #12: <what to change>`.

Watch progress: `cd factory && python3 -m http.server`, then open
<http://localhost:8000/dashboard.html>.

## Configuration: `factory/config.json`

| Key | Meaning |
|-----|---------|
| `concurrency` | Jobs in running stages at once. Each uses several agents, so start at 2 to 3 if you hit usage limits. |
| `max_rounds` | Build rounds per job (build → gate → review). When the last one fails the job goes to `needs-human`. |
| `base_branch` | Branch jobs start from and PRs target. |
| `auto_merge` | `false` (default): approved PRs wait for a human. `true`: the factory merges (using `merge_method`) after syncing with the base and re-running the gate. Think hard before enabling. |
| `labels` | Names of the queue, needs-info and needs-human labels. |
| `routing` | Risk (`low` / `medium` / `high`) → reviewers and models that always run. |
| `surface_reviewers` | Surface (`ui`, `security`, `infra`, `data`) → extra reviewers and models. |
| `protected_paths` | Globs a branch may not modify or delete (the gate fails it). Keeps the checks, the config and the lenses out of a builder's reach. |
| `ports` | Dev-server ports for builders and ux/ui reviewers: `base + step × job number`. |
| `prices_usd_per_mtok` | Per-model rates for the cost column. A model missing here makes cost lookup stop, so add new models. The `claude-fable-5-2` entry is an estimate copied from 5-1. |

The agents run on Opus, Sonnet or Haiku. To change a model, edit the `model:` line in
`.claude/agents/<name>.md` (agents) or `routing` / `surface_reviewers` (reviewers).

## Lenses: teach the reviewers your repo

The agents are generic. Each also reads an optional file in `factory/lenses/`
(`intake.md`, `approver.md`, `security.md`, `infra.md`, `data.md`, `code.md`,
`ui.md`, `ux.md`) from the **main checkout**, so a branch can't weaken the
guidance it is judged by. Keep them to short, checkable bullets: the real hot
spots of *your* project. See `factory/lenses/README.md` and a full real set in
[`examples/yh-better-auth/`](examples/yh-better-auth/).

## Upgrade

```bash
cd software-factory && git pull
./install.sh /path/to/your-repo --upgrade
```

`--upgrade` refreshes the engine (`factory/bin/`, `.claude/agents/`, the skill, the
dashboard) and never touches `config.json`, `checks.sh`, `factory/lenses/` or
`AGENTS.md`. Review the diff before committing.

## Safety model

- **The `factory` label is the trust boundary.** Only people who can label issues can start
  a build. Issue text reaches agents only as quoted data in `issue.md`, never in a prompt.
- Agents push only their `factory/<job-id>` branch. They never force-push, rebase or
  deploy, and never merge unless you set `auto_merge: true`.
- The gate runs the **main checkout's** `checks.sh`, so a branch can't change the checks it
  is judged by, and it fails any branch that touches `protected_paths`.
- The approver escalates anything touching auth, access, money, deploy config, schema
  migrations or new dependencies, plus whatever your `approver.md` lens lists.

## Limits

- Needs a repo whose checks you can run headlessly. A gate that needs a database or other
  services must start them itself, or the tests that need them get skipped (and still pass).
- The browser-based UI review needs `agent-browser` and a dev server started from
  `AGENTS.md`; without them, UI behaviour is reviewed by reading code only.
- One PR per issue: if an issue is too big, intake accepts a smaller first slice and says
  what it left out.

## Tests

```bash
bash tests/test_install.sh                                   # installs into a temp repo and checks it
python3 -m unittest discover -s template/factory/tests -v    # the factory's own tests
```

## Layout

```
template/               copied into your repo by install.sh
  .claude/agents/       intake, spec-writer, builder, approver, reviewer-{code,security,infra,data,ux,ui}
  .claude/skills/factory/SKILL.md   the /factory command
  factory/bin/          job (state machine), gate, route
  factory/config.json  factory/checks.sh  factory/dashboard.html  factory/lenses/
  factory/tests/        tests for the scripts
templates/AGENTS.example.md   a starter AGENTS.md
examples/               a real repo's lenses and checks.sh
install.sh              install and upgrade
tests/test_install.sh   smoke test
```
