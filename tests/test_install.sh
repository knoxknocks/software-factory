#!/usr/bin/env bash
# Smoke test: install into a throwaway git repo and check the result.
#   bash tests/test_install.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1" >&2; exit 1; }

# 1. no project-specific text leaked into the template
if grep -rniE "yh-better-auth|aurora|dynamodb|argon|knoxknocks|seahyh|whentimestoodstill|identity provider|\bbe/|\bfe/" "$HERE/template" --include='*' -l | grep -v __pycache__ | grep .; then
  fail "project-specific text found in template/ (files above)"
fi
pass "template has no project-specific text"
! grep -rn "^model: fable" "$HERE/template/.claude/agents" || fail "an agent still uses fable"
pass "no agent uses fable"

# 2. install into a fresh repo
R="$T/repo"; mkdir "$R"; git -C "$R" init -q; git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
"$HERE/install.sh" "$R" --no-labels >/dev/null
for f in factory/bin/job factory/bin/gate factory/bin/route factory/checks.sh factory/config.json \
         factory/dashboard.html factory/lenses/README.md .claude/skills/factory/SKILL.md AGENTS.md \
         .claude/agents/intake.md .claude/agents/builder.md .claude/agents/approver.md \
         .claude/agents/spec-writer.md .claude/agents/reviewer-code.md .claude/agents/reviewer-security.md; do
  [ -e "$R/$f" ] || fail "missing $f"
done
[ -x "$R/factory/bin/job" ] && [ -x "$R/factory/checks.sh" ] || fail "scripts not executable"
grep -qxF "/factory/jobs/" "$R/.gitignore" && grep -qxF "/.worktrees/" "$R/.gitignore" || fail ".gitignore entries"
pass "install copies everything and ignores runtime state"

# 3. idempotent
out="$("$HERE/install.sh" "$R" --no-labels)"
echo "$out" | grep -q "0 written" || fail "second install wrote files: $out"
pass "install is idempotent"

# 4. upgrade keeps your files, refreshes the engine
python3 - "$R" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]) / "factory/config.json"
c = json.loads(p.read_text()); c["concurrency"] = 2; p.write_text(json.dumps(c))
PY
echo "# mine" >> "$R/factory/checks.sh"
echo "# stale" >> "$R/.claude/agents/intake.md"
"$HERE/install.sh" "$R" --upgrade --no-labels >/dev/null
python3 -c "import json,sys;assert json.load(open('$R/factory/config.json'))['concurrency']==2" || fail "upgrade overwrote config.json"
grep -q "# mine" "$R/factory/checks.sh" || fail "upgrade overwrote checks.sh"
! grep -q "# stale" "$R/.claude/agents/intake.md" || fail "upgrade did not refresh the agent"
pass "upgrade keeps config/checks/lenses and refreshes the engine"

# 5. unconfigured gate fails loudly
if (cd "$R" && bash factory/checks.sh) 2>/dev/null; then fail "unconfigured checks.sh passed"; fi
pass "unconfigured checks.sh fails"

# 6. the factory's own tests run in the installed repo
(cd "$R" && python3 -m unittest discover -s factory/tests -q) >/dev/null 2>&1 || fail "installed factory tests failed"
pass "installed factory tests pass"

# 7. scripts at least start
for s in job gate route; do
  python3 -m py_compile "$R/factory/bin/$s" || fail "$s does not compile"
done
pass "scripts compile"
echo "all good"
