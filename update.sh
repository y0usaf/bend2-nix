#!/bin/sh
# Bump the pin in flake.nix from the published release manifest. Reads the
# version and sha256 the launcher's installer would, and rewrites both.
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
json=$(curl -fsSL --max-time 30 https://bend-lang.com/dl/latest.json)
ver=$(printf %s "$json" | sed -n 's/.*"ver":"\([^"]*\)".*/\1/p')
sha=$(printf %s "$json" | sed -n 's/.*"sha256":"\([^"]*\)".*/\1/p')
[ -n "$ver" ] && [ ${#sha} -eq 64 ] || { echo "update.sh: bad manifest: $json" >&2; exit 1; }
sed -i \
  -e 's/^      version = ".*";$/      version = "'"$ver"'";/' \
  -e 's/^      sha256 = ".*";$/      sha256 = "'"$sha"'";/' \
  "$dir/flake.nix"
echo "pinned bend $ver $sha" >&2
