# mac-bootstrap

Minimal, resumable bootstrap for a newly erased Apple-silicon Mac. It installs
only the public prerequisites needed to hand off to the private `mac-setup`
automation.

## Security boundary

This repository is public. It must never contain tokens, passwords, private
keys, FileVault recovery material, device identifiers, runner enrollment
secrets, Apple Account details, or private machine configuration. Authentication
is performed interactively and credentials remain in each tool's own secure
storage. The only private resource named here is the intended
`jlipworth/mac-setup` checkout.

## What it does

1. Requires macOS on Apple silicon.
2. Verifies Command Line Tools, or opens Apple's installer and asks you to
   re-run after it completes.
3. Installs Homebrew from a downloaded temporary installer.
4. Installs GitHub CLI and the official standalone Codex CLI.
5. Performs interactive `gh` and Codex login when needed.
6. Clones `mac-setup` to `~/Projects/mac-setup`, verifies its origin and branch,
   and runs `make doctor-bootstrap`.
7. Prints the private setup and Codex desktop-app handoff commands.

Every step verifies current state before acting, so an interrupted run can be
resumed by running the script again. It never removes an existing Homebrew or
Codex installation.

## First use

Do not pipe a network response directly into a shell. Download, inspect, verify,
and then run the released script:

```bash
curl --fail --location --proto '=https' --tlsv1.2 \
  --remote-name https://github.com/jlipworth/mac-bootstrap/releases/latest/download/bootstrap.sh
curl --fail --location --proto '=https' --tlsv1.2 \
  --remote-name https://github.com/jlipworth/mac-bootstrap/releases/latest/download/bootstrap.sh.sha256
shasum -a 256 --check bootstrap.sh.sha256
less bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh
```

Until the first release exists, clone the repository, inspect it, and run
`./bootstrap.sh` from the checkout.

### Optional installer pinning

The upstream Homebrew and Codex installer contents can change. To require an
expected installer digest during a controlled enrollment, set one or both
values before running:

```bash
export HOMEBREW_INSTALL_SHA256='<reviewed sha256>'
export CODEX_INSTALL_SHA256='<reviewed sha256>'
./bootstrap.sh
```

Without a supplied digest, the bootstrap emits a prominent warning. HTTPS is
still required and installers are downloaded to temporary files rather than
piped into a shell.

## Authentication and handoff

The bootstrap never accepts credentials as command-line arguments or from a
committed environment file. If a noninteractive invocation reaches a missing
login, it stops and prints the exact command that must be run interactively.

After successful bootstrap:

```bash
cd "$HOME/Projects/mac-setup"
make doctor-bootstrap
codex app
```

Continue only after reviewing the private repository's runbook.

## Development

Prerequisites: Bats, ShellCheck, and shfmt.

```bash
brew install bats-core shellcheck shfmt
make validate
```

The tests use disposable mock homes and do not install software or alter the
host.

## Releases

Pushing a tag matching `v*` builds a standalone script from the reviewed
library, runs validation, and creates a GitHub release with `bootstrap.sh` and
`bootstrap.sh.sha256`. Review and tag releases explicitly; the workflow does
not auto-increment versions.
