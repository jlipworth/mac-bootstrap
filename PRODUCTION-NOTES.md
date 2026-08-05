# Production bootstrap notes

This file records generalized findings from real-machine runs. Keep it public:
never include usernames, device identifiers, authentication codes, tokens,
recovery material, or private repository contents.

## 2026-08-05 — first production run

- Platform, Command Line Tools, and existing Homebrew/Codex detection worked.
- Installer cleanup used a `RETURN` trap that outlived its function while
  referring to the function-local `tmp`. Later function returns could fail
  with `tmp: unbound variable`, observed after the first Homebrew and Codex
  installs. The installer now runs in a subshell with an `EXIT` cleanup trap.
- GitHub CLI's interactive terminal UI stalled while querying cursor position
  in a remote terminal. The browser/device login now uses
  `GH_PROMPT_DISABLED=1`, explicitly opens GitHub's device page, and copies its
  short-lived code to the local clipboard. The CLI's `--web` flag alone did not
  open the browser during this run.
- After GitHub authorization, the bootstrap resumed safely, cloned the private
  setup repository, and passed all bootstrap doctor checks.
