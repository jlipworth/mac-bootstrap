setup_test_env() {
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/mac-bootstrap.XXXXXX")"
  MOCK_BIN="$TEST_ROOT/bin"
  mkdir -p "$MOCK_BIN" "$TEST_ROOT/home" "$TEST_ROOT/projects"
  export TEST_ROOT MOCK_BIN
  export HOME="$TEST_ROOT/home"
  export MB_PROJECTS_DIR="$TEST_ROOT/projects"
  export MB_NONINTERACTIVE=1
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
  # shellcheck source=lib/bootstrap.sh
  source "$BATS_TEST_DIRNAME/../lib/bootstrap.sh"
}

teardown_test_env() {
  rm -rf "$TEST_ROOT"
}

mock_command() {
  local name="$1"
  shift
  cat >"$MOCK_BIN/$name" <<EOF
#!/bin/bash
$*
EOF
  chmod +x "$MOCK_BIN/$name"
}
