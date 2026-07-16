#!/usr/bin/env bash

readonly MAC_SETUP_REMOTE="https://github.com/jlipworth/mac-setup.git"
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly CODEX_INSTALL_URL="https://chatgpt.com/codex/install.sh"

log() { printf '[mac-bootstrap] %s\n' "$*"; }
warn() { printf '[mac-bootstrap] WARNING: %s\n' "$*" >&2; }
die() {
  printf '[mac-bootstrap] ERROR: %s\n' "$*" >&2
  printf '[mac-bootstrap] Re-run %q to resume after correcting the problem.\n' "${MB_BOOTSTRAP_PATH:-./bootstrap.sh}" >&2
  exit 1
}

is_interactive() {
  [[ "${MB_NONINTERACTIVE:-0}" != 1 && -t 0 && -t 1 ]]
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

platform_os() { printf '%s\n' "${MB_TEST_OS:-$(uname -s)}"; }
platform_arch() { printf '%s\n' "${MB_TEST_ARCH:-$(uname -m)}"; }

validate_platform() {
  [[ "$(platform_os)" == Darwin ]] || die "This bootstrap supports macOS only."
  [[ "$(platform_arch)" == arm64 ]] || die "This bootstrap supports Apple silicon (arm64) only."
}

require_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Command Line Tools are installed."
    return
  fi

  log "Requesting the Command Line Tools installer."
  xcode-select --install >/dev/null 2>&1 || true
  die "Complete the Command Line Tools dialog, then re-run the bootstrap."
}

download_review_and_run() {
  local name="$1" url="$2" expected_sha="$3"
  local tmp actual_sha
  tmp="$(mktemp "${TMPDIR:-/tmp}/mac-bootstrap.XXXXXX")"
  trap 'rm -f "$tmp"' RETURN

  log "Downloading $name to a temporary file for verification."
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$url" --output "$tmp"

  if [[ -n "$expected_sha" ]]; then
    actual_sha="$(shasum -a 256 "$tmp" | awk '{print $1}')"
    [[ "$actual_sha" == "$expected_sha" ]] || die "$name checksum mismatch."
    log "$name checksum verified."
  else
    warn "$name checksum was not pinned; review the downloaded installer source before fleet use."
  fi

  /bin/bash "$tmp"
}

activate_homebrew() {
  if command_exists brew; then
    return
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

install_homebrew() {
  activate_homebrew
  if command_exists brew; then
    log "Homebrew is installed."
    return
  fi
  NONINTERACTIVE=1 download_review_and_run \
    "Homebrew installer" "$HOMEBREW_INSTALL_URL" "${HOMEBREW_INSTALL_SHA256:-}"
  activate_homebrew
  command_exists brew || die "Homebrew installer completed but brew is not available."
}

install_gh() {
  if command_exists gh; then
    log "GitHub CLI is installed."
    return
  fi
  brew install gh
  command_exists gh || die "GitHub CLI installation did not produce a gh command."
}

install_codex() {
  if command_exists codex; then
    log "Codex CLI is installed."
    return
  fi
  CODEX_NON_INTERACTIVE=1 download_review_and_run \
    "Codex installer" "$CODEX_INSTALL_URL" "${CODEX_INSTALL_SHA256:-}"
  export PATH="$HOME/.local/bin:$PATH"
  command_exists codex || die "Codex installer completed but codex is not available."
}

authenticate_gh() {
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    log "GitHub CLI is authenticated."
    return
  fi
  is_interactive || die "GitHub authentication requires an interactive terminal. Run: gh auth login --hostname github.com --git-protocol https --web"
  gh auth login --hostname github.com --git-protocol https --web
  gh auth status --hostname github.com >/dev/null 2>&1 || die "GitHub authentication was not completed."
}

authenticate_codex() {
  if codex login status >/dev/null 2>&1; then
    log "Codex CLI is authenticated."
    return
  fi
  is_interactive || die "Codex authentication requires an interactive terminal. Run: codex login"
  codex login
  codex login status >/dev/null 2>&1 || die "Codex authentication was not completed."
}

normalized_git_url() {
  local url="$1"
  printf '%s\n' "${url%.git}"
}

checkout_mac_setup() {
  local projects_dir="${MB_PROJECTS_DIR:-$HOME/Projects}"
  local checkout="$projects_dir/mac-setup"
  local expected_branch="${MAC_SETUP_BRANCH:-main}"
  local actual_remote actual_branch

  mkdir -p "$projects_dir"
  if [[ ! -e "$checkout" ]]; then
    gh repo clone jlipworth/mac-setup "$checkout" -- --branch "$expected_branch"
  elif [[ ! -d "$checkout/.git" ]]; then
    die "$checkout exists but is not a Git checkout; move it aside and resume."
  fi

  actual_remote="$(git -C "$checkout" remote get-url origin 2>/dev/null || true)"
  [[ "$(normalized_git_url "$actual_remote")" == "$(normalized_git_url "$MAC_SETUP_REMOTE")" ]] \
    || die "$checkout has unexpected origin: ${actual_remote:-<missing>}"

  actual_branch="$(git -C "$checkout" branch --show-current)"
  [[ "$actual_branch" == "$expected_branch" ]] \
    || die "$checkout is on branch ${actual_branch:-<detached>}; expected $expected_branch."

  make -C "$checkout" doctor-bootstrap
  MAC_SETUP_CHECKOUT="$checkout"
  export MAC_SETUP_CHECKOUT
}

print_handoff() {
  local checkout="${MAC_SETUP_CHECKOUT:-${MB_PROJECTS_DIR:-$HOME/Projects}/mac-setup}"
  cat <<EOF

Public bootstrap is complete.

Private setup checkout: $checkout
Resume or re-verify:     $(printf '%q' "${MB_BOOTSTRAP_PATH:-./bootstrap.sh}")
Private handoff:         cd $(printf '%q' "$checkout") && make doctor-bootstrap
Desktop Codex handoff:   codex app

Review the private mac-setup runbook before applying host configuration.
EOF
}

run_step() {
  local name="$1"
  shift
  log "STEP: $name"
  "$@"
}

bootstrap_main() {
  MB_BOOTSTRAP_PATH="${MB_BOOTSTRAP_PATH:-$0}"
  export MB_BOOTSTRAP_PATH
  run_step platform validate_platform
  run_step command-line-tools require_clt
  run_step homebrew install_homebrew
  run_step github-cli install_gh
  run_step codex-cli install_codex
  run_step github-auth authenticate_gh
  run_step codex-auth authenticate_codex
  run_step private-checkout checkout_mac_setup
  run_step handoff print_handoff
}
