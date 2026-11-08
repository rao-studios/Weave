#!/bin/bash
# WHAT: Build, stable-sign and run Weave: the one command for working on the app.
# PIN:  Not `swift run`. SwiftPM ad-hoc-signs, so the app's identity changes with every build;
#       sign-binary.sh signs it with a stable identity instead (Veil's dev.sh).
# OUT:  exec <bin path>/Weave "$@" in the foreground (Ctrl-C quits it).
#
#   ./Scripts/dev/dev.sh
#   CONFIG=release ./Scripts/dev/dev.sh
#   ./Scripts/dev/dev.sh --mode=search        # open on a page (fabric, explorer, search, settings)
#   ./Scripts/dev/dev.sh --self-test          # the headless exercise against a scratch AII home, then exit
#
set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="${CONFIG:-debug}"
cd "$REPO_ROOT"

echo "▸ build ($CONFIG)"
swift build -c "$CONFIG" --product Weave
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Weave"
"$REPO_ROOT/Scripts/build/sign-binary.sh" "$BIN"
exec "$BIN" "$@"
