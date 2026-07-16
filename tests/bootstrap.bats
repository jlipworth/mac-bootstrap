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

@test "a missing Command Line Tools install requests GUI completion" {
  mock_command xcode-select 'exit 1'
  run require_clt
  [ "$status" -ne 0 ]
  [[ "$output" == *"Complete the Command Line Tools dialog"* ]]
  [[ "$output" == *"re-run"* ]]
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

@test "failed GitHub authentication stops in noninteractive mode" {
  mock_command gh 'exit 1'
  run authenticate_gh
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires an interactive terminal"* ]]
}

@test "failed Codex authentication stops in noninteractive mode" {
  mock_command codex 'exit 1'
  run authenticate_codex
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires an interactive terminal"* ]]
}

@test "download refuses a checksum mismatch before execution" {
  mock_command curl 'printf "echo should-not-run" > "${@: -1}"'
  run download_review_and_run test-installer https://example.invalid/install.sh deadbeef
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* ]]
  [[ "$output" != *"should-not-run"* ]]
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
