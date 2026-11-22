# <project name>

One or two lines: what this project is and who uses it.

The factory's agents read this file first. Keep it short and exact: every line
should save an agent from guessing.

## Layout

- `src/`: <what lives here>
- `tests/`: <how tests are organised>

## Setup

```bash
# what a fresh checkout needs before anything runs, e.g.
# npm ci     |     uv sync     |     bundle install
```

## Run locally

How to start the dev server or CLI, and on which port. The builder and the
UI/UX reviewers start it on a port the factory gives them, so say how to
override the port (for example `PORT=5100 npm run dev`). If there is no dev
server, say so.

## Validation

What `factory/checks.sh` runs, so everyone agrees on "passing":

```bash
# lint, type-check, tests, build
```

## Conventions

- Style and naming the neighbouring code already follows.
- Where docs live, and which changes must update them.
- Anything the agents must never do (files not to touch, commands not to run).
