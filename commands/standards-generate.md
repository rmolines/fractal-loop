---
description: "Inspect target repo and generate .claude/standards.md with detected values. Replaces scripts/generate-standards.sh."
argument-hint: "optional: path to target repo (defaults to current repo root)"
allowed-tools: AskUserQuestion, Bash, Read, Write, Glob
---

# /standards:generate

Inspect the target repo intelligently and generate `.claude/standards.md` following the schema in `references/standards-schema.md`.

Input: $ARGUMENTS — optional path to target repo. Defaults to repo root (`git rev-parse --show-toplevel`).

---

## Step 1: Resolve target path

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
TARGET="${ARGUMENTS:-$REPO_ROOT}"
```

## Step 2: Guard — check if standards.md already exists

If `.claude/standards.md` exists in TARGET:

Use `AskUserQuestion`:
- Question: "`.claude/standards.md` já existe. Deseja sobrescrever?"
- Options: "Sim, sobrescrever" / "Cancelar"

If "Cancelar" → print "Operação cancelada. Arquivo existente mantido." and STOP.
If "Sim, sobrescrever" → continue.

## Step 3: Inspect the repo

Read the following files if they exist (use Read tool):

**Primary config sources (read all that exist):**
- `$TARGET/CLAUDE.md`
- `$TARGET/.claude/project.md`
- `$TARGET/package.json`
- `$TARGET/Makefile`
- `$TARGET/pyproject.toml`
- `$TARGET/tsconfig.json`
- `$TARGET/Cargo.toml`
- `$TARGET/go.mod`

**Commit/lint config:**
- Any `$TARGET/commitlint.config.*` (use Glob: `commitlint.config.*`)
- Any `$TARGET/.commitlintrc*` (use Glob: `.commitlintrc*`)
- Any `$TARGET/.eslintrc*` (use Glob: `.eslintrc*`)
- `$TARGET/.eslintignore`

**Hooks:**
- `$TARGET/.husky/pre-commit`
- `$TARGET/.husky/pre-push`

**CI:**
- List `$TARGET/.github/workflows/` if it exists (use Glob: `.github/workflows/*.yml` and `.github/workflows/*.yaml`)

Also run:
```bash
git -C "$TARGET" branch -l main master 2>/dev/null | sed 's/^[* ]*//' | grep -v '^$'
```
to detect protected branches.

## Step 4: Synthesize detected values

Using your understanding of the files read, determine values for each field. Apply this detection logic:

### Gates section

**`build`** (required):
- `package.json` has `scripts.build` → `npm run build` (source: `package.json#scripts.build`)
- `Makefile` has `build:` target → `make build` (source: `Makefile#build`)
- `.claude/project.md` has `build:` field → use that value (source: `.claude/project.md#build`)
- `Cargo.toml` exists → `cargo build` (source: `Cargo.toml`)
- `go.mod` exists → `go build ./...` (source: `go.mod`)
- `pyproject.toml` exists with `[build-system]` → detect tool (hatch, poetry, flit) and emit appropriate command (source: `pyproject.toml#build-system`)
- Nothing → mark as `# not detected — fill manually`

**`test`** (required):
- `package.json` has `scripts.test` (non-placeholder) → `npm test` (source: `package.json#scripts.test`)
- `Makefile` has `test:` target → `make test` (source: `Makefile#test`)
- `.claude/project.md` has `test:` field → use that value (source: `.claude/project.md#test`)
- `pytest.ini` exists → `pytest` (source: `pytest.ini`)
- `pyproject.toml` has `[tool.pytest.ini_options]` → `pytest` (source: `pyproject.toml#tool.pytest`)
- `go.mod` exists → `go test ./...` (source: `go.mod`)
- `Cargo.toml` exists → `cargo test` (source: `Cargo.toml`)
- Nothing → mark as `# not detected — fill manually`

**`lint`** (optional):
- `.eslintrc*` or `.eslintignore` exists → `npx eslint .` (source: `.eslintrc`)
- `package.json` has `scripts.lint` → `npm run lint` (source: `package.json#scripts.lint`)
- `pyproject.toml` has `[tool.ruff]` → `ruff check .` (source: `pyproject.toml#tool.ruff`)
- `pyproject.toml` has `[tool.flake8]` → `flake8 .` (source: `pyproject.toml#tool.flake8`)
- Nothing → mark as `# optional`

**`type-check`** (optional):
- `tsconfig.json` exists → `npx tsc --noEmit` (source: `tsconfig.json`)
- Nothing → mark as `# optional`

**`smoke`** (optional):
- `.claude/project.md` has `smoke:` field → use that value (source: `.claude/project.md#smoke`)
- Nothing → mark as `# optional`

### Commit section

**`format`** (optional with default):
- `commitlint.config.*` or `.commitlintrc*` exists → `conventional` (source: `commitlint.config.*` or `.commitlintrc*`)
- `.github/workflows/` contains a file referencing conventional commits → `conventional` (source: `.github/workflows/...`)
- Nothing → `free` (source: `default`)

**`branch-prefix`** (optional):
- `.claude/project.md` has `branch-prefix:` → use that value (source: `.claude/project.md#branch-prefix`)
- CLAUDE.md mentions a branch prefix convention → extract it (source: `CLAUDE.md`)
- Nothing → mark as `# optional`

**`co-author`** (optional):
- CLAUDE.md mentions a co-author line pattern → extract it
- Nothing → mark as `# optional`

**`protected-branches`** (optional):
- Use the git branch output from Step 3
- If `main` or `master` detected → list them (source: `git branch`)
- Nothing → mark as `# optional`

### Code section

**`simplify-after-delivery`**: default `false` (source: `default`)
**`hot-file-preflight`**: default `false` (source: `default`)
**`staleness-check`**: default `false` (source: `default`)
**`max-lines-per-file`**: mark as `# optional`

### Deploy section

**`platform`** (optional):
- `.claude/project.md` has `platform:` → use that value (source: `.claude/project.md#platform`)
- `.github/workflows/` contains railway, vercel, fly, render, heroku references → detect platform
- `railway.toml` or `railway.json` exists → `railway`
- `vercel.json` or `.vercel/` exists → `vercel`
- `Dockerfile` or `docker-compose.yml` exists → `docker-compose`
- Nothing → mark as `# optional`

**`verify`** (optional):
- `.claude/project.md` has `verify:` → use that value (source: `.claude/project.md#verify`)
- Nothing → mark as `# optional`

**`ci-required`**: default `false` (source: `default`)

### Hooks note

If `.husky/pre-commit` or `.husky/pre-push` exist, note them as comments in the Gates section so the user knows they exist.

### Review section

Leave empty (no criteria to detect automatically — project-specific).

## Step 5: Compose the standards.md content

Build the file content following this exact format. Use `# detected from <source>` comment on the line BEFORE each detected field. Use `# <field>: <placeholder>   # not detected — fill manually` for undetected required fields. Use `# <field>: <placeholder>   # optional` for undetected optional fields.

```
## Gates
# Commands run before any commit or merge. All must exit 0.
# detected from <source>
build: <value>
# detected from <source>
test: <value>
# lint: <command>   # optional
# type-check: <command>   # optional
# smoke: <command>   # optional

## Commit
# detected from <source>
format: <value>
# branch-prefix: <prefix>   # optional
# co-author: <name <email>>   # optional
# detected from git branch
protected-branches:
- main

## Code
# detected from default
simplify-after-delivery: false
# detected from default
hot-file-preflight: false
# detected from default
staleness-check: false
# max-lines-per-file: <int>   # optional

## Deploy
# platform: <platform>   # optional
# verify: <command>   # optional
# detected from default
ci-required: false

## Review
# Add project-specific review criteria below
```

For undetected required fields, format as:
```
# build: <command>   # not detected — fill manually
```

For optional fields not detected, format as:
```
# lint: <command>   # optional
```

## Step 6: Confirm with user before writing

Show the user a summary of what was detected:
- List which fields were detected and from which source
- List which required fields need manual filling
- Mention the output path: `<TARGET>/.claude/standards.md`

Use `AskUserQuestion`:
- Question: "Gerar `.claude/standards.md` com os valores acima?"
- Options: "Confirmar" / "Cancelar"

If "Cancelar" → print "Operação cancelada." and STOP.

## Step 7: Write the file

```bash
mkdir -p "$TARGET/.claude"
```

Then use the Write tool to write the composed content to `$TARGET/.claude/standards.md`.

Print: "Escrito em $TARGET/.claude/standards.md"

---

## Rules

- Never overwrite `.claude/standards.md` without explicit user confirmation (Step 2 guard).
- Always use `AskUserQuestion` for confirmation before writing (Step 6).
- Use `# detected from <source>` comments for traceability.
- Mark undetected required fields with `# not detected — fill manually`.
- Mark undetected optional fields with `# optional`.
- Understand project type from context, not just pattern matching: if no config files exist but the repo contains only shell scripts and markdown, note "pure shell project, no build step" and mark build/test accordingly.
- When called from `/fractal:init`, skip the final confirmation if init already asked the user — use the confirmation from init as authorization to write.
- This skill is safe to invoke from other skills. It always ends with either the file written or a clear cancellation message.
