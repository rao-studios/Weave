#!/bin/bash
# WHAT: Assemble build/Weave.app from a release build. After Veil's and Craft's Scripts/build/make-app.sh.
# OUT:  build/Weave.app: the binary, Info.plist (stamped with WeaveBuildCommit, WeaveBuildDate and
#       WeaveDependencyCommits), the resource bundles, and the app icon (the layered macOS 26 icon
#       compiled from Support/AppIcon/AppIcon.icon, and the .icns fallback). build/app-metadata.json:
#       version, build, commit, date and the MD5 of the signed executable.
# PIN:  Weave ships no AIIServer and no Metal library: it runs the AII build installed in
#       ~/.rao/aii/bin, the one every Rao app shares. Sign inside-out; never --deep.
#       Package.swift and Support/Info.plist must agree on the minimum OS.
#
#   ./Scripts/build/make-app.sh [--install]
#   SIGN_IDENTITY="…" DEVELOPER_ID=1 ./Scripts/build/make-app.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="$REPO_ROOT"
APP_DIR="$REPO_ROOT/build/Weave.app"
CONFIG=release
INSTALL=0

while [ $# -gt 0 ]; do
    case "$1" in
        --install) INSTALL=1; shift ;;
        *) echo "make-app: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

# The plist and the manifest must agree on the OS floor.
PKG_OS="$(sed -nE 's/.*\.macOS\("([0-9.]+)"\).*/\1/p' "$PKG/Package.swift" | head -1)"
PLIST_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PKG/Support/Info.plist")"
if [ "$PKG_OS" != "$PLIST_OS" ]; then
    echo "make-app: Package.swift says macOS $PKG_OS but Support/Info.plist says $PLIST_OS" >&2
    exit 1
fi

echo "▸ swift build -c $CONFIG"
swift build -c $CONFIG --product Weave
BIN_DIR="$(swift build -c $CONFIG --show-bin-path)"

echo "▸ assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/Weave" "$APP_DIR/Contents/MacOS/Weave"
cp "$PKG/Support/Info.plist" "$APP_DIR/Contents/Info.plist"

commit="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
[ -z "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ] || commit="$commit-dirty"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
dependencies="$(python3 -I - "$PKG/Package.resolved" <<'PY'
import json, sys
pins = {p["identity"]: p["state"].get("revision", "") for p in json.load(open(sys.argv[1]))["pins"]}
print(" ".join(f"{name}={pins[name][:12]}" for name in ("aii", "granite", "hummingbird") if pins.get(name)))
PY
)"
/usr/libexec/PlistBuddy -c "Add :WeaveBuildCommit string $commit" \
    -c "Add :WeaveBuildDate string $built_at" \
    -c "Add :WeaveDependencyCommits string $dependencies" "$APP_DIR/Contents/Info.plist"
echo "▸ stamped WeaveBuildCommit $commit, WeaveBuildDate $built_at, WeaveDependencyCommits $dependencies"

for bundle in "$BIN_DIR/"*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

# Dock and Finder icon, before codesign: Resources is sealed. macOS 26+ reads the layered icon
# (AppIcon.icon compiled into Assets.car, named by CFBundleIconName); the ten-size .icns from the
# 1024 PNG is the CFBundleIconFile fallback.
echo "▸ app icon"
# ONE ICON COMPILE AT A TIME, across every Rao checkout: every catalog is AppIcon.icon, and two
# actool runs in flight once swapped Ambient's and Craft's renditions (2026-10-15).
ICON_LOCK="/tmp/rao-actool.lock"
for _ in $(seq 1 150); do
    mkdir "$ICON_LOCK" 2>/dev/null && break
    echo "▸ waiting for another icon compile to finish ($ICON_LOCK)"; sleep 2
done
[ -d "$ICON_LOCK" ] || { echo "error: could not take $ICON_LOCK" >&2; exit 1; }
trap 'rmdir "$ICON_LOCK" 2>/dev/null' EXIT
ACTOOL_OUT="$(xcrun actool "$PKG/Support/AppIcon/AppIcon.icon" --compile "$APP_DIR/Contents/Resources" \
    --platform macosx --minimum-deployment-target "$PLIST_OS" --app-icon AppIcon \
    --include-all-app-icons --output-partial-info-plist "$REPO_ROOT/build/AppIcon-partial.plist" \
    --output-format human-readable-text 2>&1)"
if echo "$ACTOOL_OUT" | grep -q -i "error" || [ ! -f "$APP_DIR/Contents/Resources/Assets.car" ]; then
    echo "make-app: actool failed to compile Support/AppIcon/AppIcon.icon" >&2
    echo "$ACTOOL_OUT" >&2
    exit 1
fi
rmdir "$ICON_LOCK"; trap - EXIT
ICONSET="$REPO_ROOT/build/AppIcon.iconset"
"$REPO_ROOT/Scripts/art/make-iconset.sh" "$PKG/Support/AppIcon/icon_1024.png" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

ENTITLEMENTS="$PKG/Support/Weave.entitlements"
SIGN_FLAGS=()
if [ "${DEVELOPER_ID:-0}" = 1 ]; then
    IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
    SIGN_FLAGS=(--options runtime --timestamp)
else
    IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')}"
fi
if [ -n "$IDENTITY" ]; then echo "▸ codesign ($IDENTITY)"; else IDENTITY="-"; echo "▸ codesign (ad-hoc)"; fi

# SwiftPM resource bundles are nested code to codesign: a flat one gets a root Info.plist, one
# with a Resources/ directory is moved to the deep layout (Veil's make-app.sh says why).
find "$APP_DIR/Contents" -maxdepth 3 -name '*.bundle' -type d | while read -r bundle; do
    name="$(basename "$bundle" .bundle)"
    plist="$bundle/Info.plist"
    if [ ! -f "$bundle/Contents/Info.plist" ]; then
        if [ -d "$bundle/Resources" ]; then
            mkdir -p "$bundle/Contents"
            rm -f "$bundle/Info.plist"
            for entry in "$bundle"/*; do
                case "$(basename "$entry")" in
                    Contents) ;;
                    Resources) mv "$entry" "$bundle/Contents/" ;;
                    *) mkdir -p "$bundle/Contents/Resources"; mv "$entry" "$bundle/Contents/Resources/" ;;
                esac
            done
            plist="$bundle/Contents/Info.plist"
        fi
        [ -f "$plist" ] || /usr/libexec/PlistBuddy \
            -c "Add :CFBundleIdentifier string nyc.rao.weave.res.$(echo "$name" | tr '_' '-')" \
            -c "Add :CFBundleName string $name" \
            -c "Add :CFBundlePackageType string BNDL" \
            -c "Add :CFBundleInfoDictionaryVersion string 6.0" \
            "$plist" >/dev/null
    fi
    xattr -cr "$bundle" 2>/dev/null || true
    codesign --force --sign "$IDENTITY" ${SIGN_FLAGS[@]+"${SIGN_FLAGS[@]}"} "$bundle" || exit 1
done
codesign --force --sign "$IDENTITY" ${SIGN_FLAGS[@]+"${SIGN_FLAGS[@]}"} --entitlements "$ENTITLEMENTS" "$APP_DIR"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist")"
md5="$(md5 -q "$APP_DIR/Contents/MacOS/Weave")"
METADATA="$REPO_ROOT/build/app-metadata.json"
cat > "$METADATA" <<JSON
{
  "version": "$version",
  "build": "$build_number",
  "commit": "$commit",
  "builtAt": "$built_at",
  "dependencies": "$dependencies",
  "signedBy": "$IDENTITY",
  "executable": "Weave.app/Contents/MacOS/Weave",
  "md5": "$md5"
}
JSON
echo "▸ wrote $METADATA (md5 $md5)"

if [ "$INSTALL" = 1 ]; then
    echo "▸ installing /Applications/Weave.app"
    rm -rf /Applications/Weave.app
    ditto "$APP_DIR" /Applications/Weave.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Weave.app
fi

echo "Done: $APP_DIR"
