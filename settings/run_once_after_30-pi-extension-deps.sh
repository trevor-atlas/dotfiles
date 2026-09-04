#!/usr/bin/env bash
# Install runtime deps for the vendored pi extension packages that carry real
# npm dependencies (browser = playwright-core; web-fetch = readability, linkedom,
# turndown, unpdf). Their node_modules is chezmoi-ignored (never committed/symlinked),
# so it must be materialized on each machine that will load them.
#
# Idempotent: only runs `bun install` inside a package dir when it has a package.json
# but no node_modules yet (e.g. the very first apply on a fresh machine).
set -e

command -v bun >/dev/null 2>&1 || { \
  echo "run_once_after_30-pi-extension-deps: bun not found; skipping (extension deps not installed)" >&2; \
  exit 0; }

PACKAGES_ROOT="$HOME/.pi/agent/packages"

install_if_missing() {
  local dir="$1"
  [ -f "$PACKAGES_ROOT/$dir/package.json" ] || return 0
  if [ ! -d "$PACKAGES_ROOT/$dir/node_modules" ]; then
    echo "==> Installing pi extension deps in ~/.pi/agent/packages/$dir …"
    (cd "$PACKAGES_ROOT/$dir" && bun install --no-progress)
  else
    echo "pi extension deps already present in $dir; skipping."
  fi
}

install_if_missing browser
install_if_missing web-fetch
