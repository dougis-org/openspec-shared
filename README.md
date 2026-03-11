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
| `skills/` | Four OpenSpec agent skills for VS Code Copilot |
| `init-change.sh` | POSIX shell script to scaffold a new change |

---

## Prerequisites

- **`git`** with submodule support (git 2.13+)
- **`openspec` CLI** installed and available in `PATH`
- A project that already has an `openspec/` directory (or you will create one)

---

## Adding to a New Project

### 1. Add the submodule

Run this from your project root:

```sh
git submodule add https://github.com/dougis-org/openspec-shared .github/openspec-shared
git submodule update --init
```

This creates `.github/openspec-shared/` and adds a `.gitmodules` entry.

### 2. Create the `openspec/` directory (if it does not exist)

```sh
mkdir -p openspec/changes openspec/specs
```

### 3. Create skill symlinks

VS Code Copilot discovers skills in `.github/skills/`. Create one symlink per skill:

```sh
mkdir -p .github/skills
for s in openspec-propose openspec-apply-change openspec-archive-change openspec-explore; do
  ln -s ../openspec-shared/skills/$s .github/skills/$s
done
```

### 4. Create template and config symlinks

Point the `openspec/templates` directory and `openspec/config.yaml` at the shared copies:

```sh
ln -s ../.github/openspec-shared/templates openspec/templates
ln -s ../.github/openspec-shared/config.yaml openspec/config.yaml
```

### 5. Create the init script symlink

```sh
mkdir -p scripts
ln -s ../.github/openspec-shared/init-change.sh scripts/init-change.sh
```

### 6. Wire `package.json` (npm / Node.js projects only)

Add a convenience script so contributors can run the tool without remembering the path:

```json
{
  "scripts": {
    "opsx:init-change": "sh scripts/init-change.sh"
  }
}
```

### 7. Commit everything

```sh
git add .gitmodules .github/openspec-shared .github/skills openspec/templates openspec/config.yaml scripts/init-change.sh package.json
git commit -m "chore: add openspec-shared submodule and symlinks"
git push
```

---

## Usage

### Scaffold a new change

Positional arguments:

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

Before starting implementation for that change, check out the repository's default branch and pull the latest remote state so the feature branch starts from current history. The expected sequence is `git checkout <default-branch>`, `git pull --ff-only`, then create the feature branch.

The shared workflow expects local cleanup after merge and archive: archive the completed
change under `openspec/changes/archive/`, then prune merged local branches and stale
remote-tracking refs to keep the repository clean.

---

## Keeping the Submodule Up to Date

Pull the latest shared content and pin your project to the new commit:

```sh
git submodule update --remote .github/openspec-shared
git add .github/openspec-shared
git commit -m "chore: bump openspec-shared to latest"
git push
```

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

---

## Skill Reference

| Skill | When to use |
| ----- | ----------- |
| `openspec-propose` | Quickly describe what to build and get a full proposal |
| `openspec-explore` | Think through an idea before or during a change |
| `openspec-apply-change` | Implement tasks from an approved change |
| `openspec-archive-change` | Finalize and archive a completed change |
