#!/bin/zsh
# Rebuilds Weave's README hero: HTML rendered by Google Chrome through Playwright (pip install
# playwright; it drives the installed Chrome). No server, no GPU. Writes Docs/README_Assets/hero.png.
set -euo pipefail
repo=${0:A:h:h:h:h}
cd "$repo"
python3 -I Docs/README_Assets/src/plates.py Docs/README_Assets "$@"
