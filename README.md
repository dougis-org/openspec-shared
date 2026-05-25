# openspec-shared

Shared OpenSpec workflow templates, skills, config, and tooling.
Single source of truth for the spec-driven development workflow
used across all dougis-org projects.

---

## Contents

| Path | Purpose |
| ---- | ------- |
| `config.yaml` | OpenSpec workflow configuration |
| `templates/` | Proposal, design, spec, and tasks templates |
| `skills/` | Five OpenSpec agent skills (VS Code Copilot / GitHub Copilot) |
| `init-change.sh` | POSIX shell script to scaffold a new change |
| `bootstrap.sh` | Bootstrap script — wires shared assets into a downstream repo |

---

## Supported Agent Surfaces

This shared repo provides assets for the following agents out of the box:

| Surface | Agent | Contents |
| ------- | ----- | -------- |
| `.codex/` | OpenAI Codex | `skills/` |
| `.claude/` | Anthropic Claude | `skills/`, `commands/` |
| `.gemini/` | Google Gemini | `skills/`, `commands/` |
| `.github/` | GitHub Copilot / VS Code Copilot | `skills/`, `prompts/` |

> **Note:** `.agent/` exists in this repository as an experimental surface. It is not
> part of the default onboarding contract and is not wired by `bootstrap.sh`.

---

## Prerequisites

- **`git`** with submodule support (git 2.13+)
- **`openspec` CLI** installed and available in `PATH`
- A project that already has an `openspec/` directory (or you will create one)

---

## Adding to a New Project

Setup takes two steps: add the submodule manually, then run the bootstrap script.

### Step 1 — Add the submodule

Run this from your project root:

```sh
git submodule add https://github.com/dougis-org/openspec-shared .github/openspec-shared
```

This creates `.github/openspec-shared/` and adds a `.gitmodules` entry.

### Step 2 — Run the bootstrap script

```sh
sh .github/openspec-shared/bootstrap.sh
```

The script:
- initializes or updates the submodule
- creates the required directories
- creates symlinks for all supported agent surfaces (`.codex/`, `.claude/`, `.gemini/`, `.github/`)
- links `openspec/templates`, `openspec/config.yaml`, and `scripts/init-change.sh`

It is safe to re-run after bumping the submodule — existing symlinks are replaced.

#### Copy mode (optional)

If symlinks are unavailable or undesirable in your environment, use copy mode:

```sh
sh .github/openspec-shared/bootstrap.sh --copy
```

Copied assets do not update automatically. After bumping the submodule, re-run bootstrap
with `--copy` to refresh the copies.

### Step 3 — Commit

```sh
git add .gitmodules .github/openspec-shared \
    .codex .claude .gemini .github/skills .github/prompts \
    openspec/templates openspec/config.yaml scripts/init-change.sh
git commit -m "chore: add openspec-shared submodule and bootstrap assets"
git push
```

### Wire `package.json` (npm / Node.js projects only)

Add a convenience script so contributors can scaffold changes without remembering the path:

```json
{
  "scripts": {
    "opsx:init-change": "sh scripts/init-change.sh"
  }
}
```

---

## Usage

### Scaffold a new change

```sh
sh scripts/init-change.sh <change-name> [capability-name]
```

`change-name` and `capability-name` must be **kebab-case** (e.g. `add-login`, `auth`).

Examples:

```sh
# Minimal — capability defaults to "new-capability"
sh scripts/init-change.sh add-dark-mode

# With an explicit capability name
sh scripts/init-change.sh add-login auth

# Via npm (if package.json is wired)
npm run opsx:init-change -- add-dark-mode
```

This runs `openspec new change <change-name>` then copies all four templates into
`openspec/changes/<change-name>/specs/<capability-name>/`.

Before starting implementation for that change, check out the repository's default branch
and pull the latest remote state so the feature branch starts from current history. The
expected sequence is `git checkout <default-branch>`, `git pull --ff-only`, then create
the feature branch.

The shared workflow expects local cleanup after merge and archive: archive the completed
change under `openspec/changes/archive/`, then prune merged local branches and stale
remote-tracking refs to keep the repository clean.

---

## Refreshing After a Submodule Update

After bumping the submodule to a newer commit, re-run bootstrap to refresh all links:

```sh
git submodule update --remote .github/openspec-shared
git add .github/openspec-shared
git commit -m "chore: bump openspec-shared to latest"
git push

# Refresh symlinks in the downstream repo
sh .github/openspec-shared/bootstrap.sh
```

If you used copy mode, add `--copy` to the final command.

---

## Cloning a Project That Uses This Submodule

When cloning for the first time, recurse into submodules:

```sh
git clone --recurse-submodules <repo-url>
```

If you already cloned without `--recurse-submodules`, initialise manually:

```sh
git submodule update --init
```

After initialising, run bootstrap to ensure all links are in place:

```sh
sh .github/openspec-shared/bootstrap.sh
```

---

## Skill Reference

| Skill | When to use |
| ----- | ----------- |
| `openspec-propose` | Quickly describe what to build and get a full proposal |
| `openspec-explore` | Think through an idea before or during a change |
| `openspec-apply-change` | Implement tasks from an approved change |
| `openspec-review-code` | Pre-commit code review for duplication, complexity, and quality (spawned as sub-agent) |
| `openspec-archive-change` | Finalize and archive a completed change |
