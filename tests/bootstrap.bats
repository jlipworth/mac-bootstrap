#!/usr/bin/env bats

load test_helper

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "accepts macOS on Apple silicon" {
  export MB_TEST_OS=Darwin MB_TEST_ARCH=arm64
  run validate_platform
  [ "$status" -eq 0 ]
}

@test "rejects the wrong OS" {
  export MB_TEST_OS=Linux MB_TEST_ARCH=arm64
  run validate_platform
  [ "$status" -ne 0 ]
  [[ "$output" == *"macOS only"* ]]
}

@test "rejects Intel architecture" {
  export MB_TEST_OS=Darwin MB_TEST_ARCH=x86_64
  run validate_platform
  [ "$status" -ne 0 ]
  [[ "$output" == *"Apple silicon"* ]]
}

@test "an existing Command Line Tools install is reused" {
  mock_command xcode-select '[[ "$1" == "-p" ]]'
  run require_clt
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed"* ]]
}

@test "a missing Command Line Tools install times out with a resumable error" {
  mock_command xcode-select 'exit 1'
  export MB_CLT_WAIT_SECONDS=0
  run require_clt
  [ "$status" -ne 0 ]
  [[ "$output" == *"continue automatically"* ]]
  [[ "$output" == *"were not installed"* ]]
  [[ "$output" == *"Re-run"* ]]
}

@test "a Command Line Tools install continues without rerunning bootstrap" {
  local marker="$TEST_ROOT/xcode-select-installed"
  export MB_TEST_CLT_MARKER="$marker"
  mock_command xcode-select '
    if [[ "$1" == "--install" ]]; then
      touch "$MB_TEST_CLT_MARKER"
      exit 0
    fi
    [[ "$1" == "-p" && -f "$MB_TEST_CLT_MARKER" ]]
  '
  run require_clt
  [ "$status" -eq 0 ]
  [[ "$output" == *"continue automatically"* ]]
  [[ "$output" == *"Command Line Tools are installed"* ]]
}

@test "existing Homebrew, gh, and Codex commands are reused" {
  mock_command brew 'exit 0'
  mock_command gh 'exit 0'
  mock_command codex 'exit 0'
  run install_homebrew
  [ "$status" -eq 0 ]
  run install_gh
  [ "$status" -eq 0 ]
  run install_codex
  [ "$status" -eq 0 ]
}

@test "fresh-host command paths are persisted idempotently for Zsh" {
  local profile="$HOME/.zprofile"
  export MB_ZPROFILE="$profile"

  run persist_shell_path
  [ "$status" -eq 0 ]
  run persist_shell_path
  [ "$status" -eq 0 ]

  [ "$(grep -Fxc 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$profile")" -eq 1 ]
  [ "$(grep -Fxc 'export PATH="$HOME/.local/bin:$PATH"' "$profile")" -eq 1 ]
}

@test "a clean Zsh login must resolve all bootstrap commands" {
  mock_command zsh '
    [[ "$1" == "-lic" ]]
    [[ "$2" == *"command -v brew"* ]]
    [[ "$2" == *"command -v gh"* ]]
    [[ "$2" == *"command -v codex"* ]]
  '
  export MB_ZSH_BINARY="$MOCK_BIN/zsh"
  run verify_login_shell_path
  [ "$status" -eq 0 ]
  [[ "$output" == *"clean Zsh login shell resolves"* ]]
}

@test "cached administrator access is reused without prompting" {
  mock_command sudo '[[ "$*" == "-n -v" ]]'
  run require_sudo
  [ "$status" -eq 0 ]
  [[ "$output" != *"may prompt"* ]]
}

@test "administrator access is requested before a noninteractive install" {
  mock_command sudo '
    if [[ "$*" == "-n -v" ]]; then exit 1; fi
    [[ "$*" == "-v" ]]
  '
  run require_sudo
  [ "$status" -eq 0 ]
  [[ "$output" == *"may prompt for your password"* ]]
}

@test "missing administrator access stops with a clear error" {
  mock_command sudo 'exit 1'
  run require_sudo
  [ "$status" -ne 0 ]
  [[ "$output" == *"Administrator access is required"* ]]
}

@test "failed GitHub authentication stops in noninteractive mode" {
  mock_command gh 'exit 1'
  run authenticate_gh
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires an interactive terminal"* ]]
}

@test "GitHub login uses a terminal-independent browser flow" {
  mock_command open 'printf "open args=%s\n" "$*"'
  mock_command gh 'printf "GH_PROMPT_DISABLED=%s args=%s\n" "${GH_PROMPT_DISABLED:-}" "$*"'
  run login_gh
  [ "$status" -eq 0 ]
  [[ "$output" == *"open args=https://github.com/login/device"* ]]
  [[ "$output" == *"GH_PROMPT_DISABLED=1"* ]]
  [[ "$output" == *"auth login --hostname github.com --git-protocol https --web --clipboard"* ]]
  [[ "$output" == *"auth setup-git --hostname github.com"* ]]
}

@test "GitHub login continues when the device page cannot be opened" {
  mock_command open 'exit 1'
  mock_command gh 'printf "gh args=%s\n" "$*"'
  run login_gh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not open the GitHub device page automatically"* ]]
  [[ "$output" == *"auth login --hostname github.com"* ]]
  [[ "$output" == *"auth setup-git --hostname github.com"* ]]
}

@test "existing GitHub authentication repairs the Git credential helper" {
  mock_command gh '
    if [[ "$*" == "auth status --hostname github.com" ]]; then exit 0; fi
    printf "gh args=%s\n" "$*"
  '
  run authenticate_gh
  [ "$status" -eq 0 ]
  [[ "$output" == *"auth setup-git --hostname github.com"* ]]
}

@test "failed Codex authentication stops in noninteractive mode" {
  mock_command codex 'exit 1'
  run authenticate_codex
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires an interactive terminal"* ]]
}

@test "download refuses a checksum mismatch before execution" {
  export TMPDIR="$TEST_ROOT/tmp"
  mkdir -p "$TMPDIR"
  mock_command curl 'printf "echo should-not-run" > "${@: -1}"'
  # Exercise the macOS system Bash explicitly; its 3.2 EXIT-trap scoping
  # differs from newer Homebrew Bash releases.
  run /bin/bash -u -c '
    source "$1"
    download_review_and_run test-installer https://example.invalid/install.sh deadbeef
  ' _ "$BATS_TEST_DIRNAME/../lib/bootstrap.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* ]]
  [[ "$output" != *"should-not-run"* ]]
  [ -z "$(find "$TMPDIR" -type f -name 'mac-bootstrap.*' -print -quit)" ]
}

@test "download cleanup does not leak a RETURN trap into its caller" {
  export TMPDIR="$TEST_ROOT/tmp"
  mkdir -p "$TMPDIR"
  mock_command curl 'printf "exit 0\n" > "${@: -1}"'
  run bash -u -c '
    source "$1"
    download_review_and_run test-installer https://example.invalid/install.sh ""
    later_function() { :; }
    later_function
  ' _ "$BATS_TEST_DIRNAME/../lib/bootstrap.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unbound variable"* ]]
  [ -z "$(find "$TMPDIR" -type f -name 'mac-bootstrap.*' -print -quit)" ]
}

@test "download cleanup removes the temporary file after curl failure" {
  export TMPDIR="$TEST_ROOT/tmp"
  mkdir -p "$TMPDIR"
  mock_command curl 'printf "partial" > "${@: -1}"; exit 22'
  run /bin/bash -u -c '
    source "$1"
    download_review_and_run test-installer https://example.invalid/install.sh ""
  ' _ "$BATS_TEST_DIRNAME/../lib/bootstrap.sh"
  [ "$status" -ne 0 ]
  [ -z "$(find "$TMPDIR" -type f -name 'mac-bootstrap.*' -print -quit)" ]
}

@test "download cleanup removes the temporary file after installer failure" {
  export TMPDIR="$TEST_ROOT/tmp"
  mkdir -p "$TMPDIR"
  mock_command curl 'printf "exit 42\n" > "${@: -1}"'
  run download_review_and_run test-installer https://example.invalid/install.sh ""
  [ "$status" -eq 42 ]
  [ -z "$(find "$TMPDIR" -type f -name 'mac-bootstrap.*' -print -quit)" ]
}

@test "existing checkout with wrong origin is rejected" {
  local checkout="$MB_PROJECTS_DIR/mac-setup"
  mkdir -p "$checkout"
  git -C "$checkout" init -q -b main
  git -C "$checkout" remote add origin https://example.invalid/wrong.git
  run checkout_mac_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"unexpected origin"* ]]
}

@test "existing checkout with wrong branch is rejected" {
  local checkout="$MB_PROJECTS_DIR/mac-setup"
  mkdir -p "$checkout"
  git -C "$checkout" init -q -b other
  git -C "$checkout" remote add origin "$MAC_SETUP_REMOTE"
  run checkout_mac_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected main"* ]]
}

@test "a valid existing checkout resumes at doctor-bootstrap" {
  local checkout="$MB_PROJECTS_DIR/mac-setup"
  mkdir -p "$checkout"
  git -C "$checkout" init -q -b main
  git -C "$checkout" remote add origin "$MAC_SETUP_REMOTE"
  printf 'doctor-bootstrap:\n\t@echo doctor-ok\n' > "$checkout/Makefile"
  run checkout_mac_setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"doctor-ok"* ]]
}

@test "handoff directs fresh hosts to the plan and away from make all" {
  export MAC_SETUP_CHECKOUT="$TEST_ROOT/Projects/mac-setup"
  run print_handoff
  [ "$status" -eq 0 ]
  [[ "$output" == *"make plan HOST=<host-id>"* ]]
  [[ "$output" == *"Do not run 'make all'"* ]]
  [[ "$output" == *"WORKFLOW: fresh"* ]]
}
