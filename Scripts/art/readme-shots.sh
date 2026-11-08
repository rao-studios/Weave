#!/bin/bash
# WHAT: Rebuild the README's screenshots of Weave at work: Docs/README_Assets/{fabric,search,explorer,connect}.png.
# HOW:  Seeds a demo fabric (three AIIs in Weave's folder, woven into the main AII, a few related notes
#       in each: Weave --demo seed), opens the app on each page at a fixed size, captures its window
#       (no shadow), and removes the demo AIIs (Weave --demo clear) unless KEEP=1.
# NEEDS: the main AII installed and running, the AII build that grants POST /v1/search, and Screen
#        Recording for the terminal (screencapture -l).
#
#   ./Scripts/art/readme-shots.sh
#   KEEP=1 ./Scripts/art/readme-shots.sh       # leave the demo AIIs running afterwards
#   SEED=0 ./Scripts/art/readme-shots.sh       # capture a demo fabric already seeded (after KEEP=1)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$REPO_ROOT/build/Weave.app"
BIN="$APP/Contents/MacOS/Weave"
OUT="$REPO_ROOT/Docs/README_Assets"
SIZE="${SIZE:-1240x860}"
# The Fabric page holds every AII's card: a taller window, inside a 1080-point display.
FABRIC_SIZE="${FABRIC_SIZE:-1240x1000}"
WINID="$(mktemp -t weave-winid).swift"
trap 'rm -f "$WINID"' EXIT
cat > "$WINID" <<'SWIFT'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Weave" && (w[kCGWindowLayer as String] as? Int) == 0 {
    print(w[kCGWindowNumber as String] as! Int); break
}
SWIFT

# Always from the source in front of you: a stale app would photograph an old window.
"$REPO_ROOT/Scripts/build/make-app.sh" | grep -E "Done|error"
osascript -e 'tell application "Weave" to quit' >/dev/null 2>&1 || true

if [ "${SEED:-1}" != 0 ]; then
    echo "▸ seeding the demo fabric"
    "$BIN" --demo seed 2>&1 | grep -v '^20[0-9][0-9]-'
fi

shoot() {   # shoot <name> <seconds> <size> <args…>
    local name="$1" wait="$2" size="$3"; shift 3
    open -n "$APP" --args --window="$size" "$@"
    sleep "$wait"
    local id; id="$(swift "$WINID" 2>/dev/null | head -1)"
    [ -n "$id" ] || { echo "readme-shots: no Weave window for $name" >&2; exit 1; }
    screencapture -l "$id" -o -x "$OUT/$name.png"
    osascript -e 'tell application "Weave" to quit' >/dev/null
    sleep 3
    echo "▸ $OUT/$name.png ($(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/ {printf "%s ", $2}'))"
}

shoot fabric 12 "$FABRIC_SIZE" --mode=fabric
shoot search 20 "$SIZE" --mode=search "--query=How did the Jacquard loom's punched cards lead to computing?"
shoot explorer 14 "$SIZE" --mode=explorer --explore=alpha
shoot connect 12 "$FABRIC_SIZE" --mode=connect

if [ "${KEEP:-0}" != 1 ]; then
    echo "▸ removing the demo fabric"
    "$BIN" --demo clear 2>&1 | grep -v '^20[0-9][0-9]-'
fi
