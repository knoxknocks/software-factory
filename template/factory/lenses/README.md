# Lenses: this repository's own review guidance

The factory's agents are generic. Each one also reads an optional file here,
from the **main checkout** (so a job branch can't change the guidance it is
judged by; `factory/lenses/*` is in `protected_paths`):

| File | Read by | Put in it |
|------|---------|-----------|
| `intake.md` | intake | What the project is, and which changes count as high risk or as each surface (`ui`, `security`, `infra`, `data`, `performance`) |
| `approver.md` | approver | Changes that must always go to a person, even when every review passed |
| `security.md` | reviewer-security | Hot spots: auth, tokens, input handling, secrets, whatever matters here |
| `infra.md` | reviewer-infra | Naming rules, required settings, what must never become public |
| `data.md` | reviewer-data | Migration rules, query conventions, key design |
| `performance.md` | reviewer-performance | Hot paths, expected data sizes and traffic, spend limits |
| `code.md` | reviewer-code | Conventions the code must follow beyond AGENTS.md |
| `ui.md` | reviewer-ui | Design tokens, components to reuse |
| `ux.md` | reviewer-ux | Flows, roles and copy rules |

Every file is optional. Write each as short bullets an agent can check against
a diff. Keep project facts (setup, commands, layout) in `AGENTS.md`, not here:
lenses are for what a reviewer should *look for*.

See `examples/` in the software-factory repo for a full set.
