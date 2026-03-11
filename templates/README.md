# OpenSpec Starter Pack

Reusable templates aligned with `openspec/config.yaml` rules.

## Files

- `proposal.template.md`
- `design.template.md`
- `tasks.template.md`
- `spec.template.md`

## How to use

Create and scaffold a new change with:

```bash
npm run opsx:init-change -- <change-name> [capability-name]
```

This runs `openspec new change` and copies all templates into the new change directory automatically.

## Notes

- Keep default OpenSpec flow: proposal -> design -> specs -> tasks -> apply -> archive.
- If scope changes after approval, update proposal, design, specs, and tasks before implementation.
