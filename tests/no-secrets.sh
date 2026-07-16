#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

files=()
while IFS= read -r -d '' file; do files+=("$file"); done < <(git ls-files -z)

if ((${#files[@]} == 0)); then
  echo "no tracked files to scan" >&2
  exit 1
fi

# Construct sensitive signatures in pieces so this scanner does not flag itself.
private_key_marker="BEGIN PRIVATE"$' '"KEY"
github_token_prefix="gh""p_"
openai_key_prefix="sk""-proj-"
recovery_assignment="RECOVERY""_KEY="

for signature in "$private_key_marker" "$github_token_prefix" "$openai_key_prefix" "$recovery_assignment"; do
  if rg --fixed-strings --line-number -- "$signature" "${files[@]}"; then
    echo "prohibited secret-shaped content found" >&2
    exit 1
  fi
done

echo "tracked content passed the repository secret-shape scan"
