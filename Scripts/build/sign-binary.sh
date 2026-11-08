#!/bin/bash
# WHAT: Stable-sign one built Weave binary, so what macOS grants it survives rebuilds.
# IN:   path to binary — Scripts/dev/dev.sh.
# PIN:  Designated requirement = identifier + certificate, not the per-build cdhash an ad-hoc
#       signature is; a Keychain item or a privacy prompt answered for one build then holds for
#       the next. As Ambient's Scripts/sign-binary.sh.
#
#   ./Scripts/build/sign-binary.sh /path/to/Weave
#
BIN="$1"

if [ ! -f "$BIN" ]; then
    echo "sign-binary: nothing at $BIN — skipping"
    exit 0
fi

# An Apple Development identity, as Ambient picks it.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ {print $2; exit}')"

if [ -z "$IDENTITY" ]; then
    echo "sign-binary: no Apple Development identity; leaving it ad-hoc (grants will not survive the next build)."
    exit 0
fi

# --preserve-metadata keeps get-task-allow so the debugger still attaches.
codesign --force --sign "$IDENTITY" --preserve-metadata=entitlements "$BIN"
echo "sign-binary: signed $BIN with '$IDENTITY'"
