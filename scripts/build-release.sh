#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="$repo_root/dist/bootstrap.sh"

mkdir -p "$repo_root/dist"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
  tail -n +2 "$repo_root/lib/bootstrap.sh"
  printf '\nbootstrap_main "$@"\n'
} >"$destination"
chmod +x "$destination"

echo "wrote $destination"
