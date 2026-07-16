# Agent guidance

This repository is intentionally public and must remain free of secrets and
machine-specific private data.

- Never commit tokens, passwords, private keys, recovery keys, device IDs, or
  personal configuration.
- Keep `bootstrap.sh` resumable and safe to re-run.
- Prefer explicit, reviewable downloads to `curl | sh`.
- Run `make validate` before committing.
- Do not weaken the macOS and Apple-silicon guards.
