"""Renders Weave's README hero in the Rao plate style (Braid's Docs/README_Assets/src/build.py hero,
Craft's plates.py shoot), from HTML, through the installed Google Chrome driven by Playwright.

    python3 -I Docs/README_Assets/src/plates.py Docs/README_Assets

Inputs:  this folder's rr-mark.png; Playfair Display Italic from ~/Library/Fonts.
Outputs: hero.png (1200x630 at 2x: 2400x1260) in argv[1].

What it draws follows the app: the spawned AIIs' Threads, each on its own slot's port, come in from
the left as three strands and pass through the eye of one needle, the host (the Sewn every woven
Thread registered with, as the app icon's needle), set just after the subtitle's last word; the
needle, angled, stitches them into a quilt on the right: your query's answer (Weave's port,
127.0.0.1:47600), one piece pieced from every partition, merged by score.
"""

import math
import os
import sys
import tempfile

from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.dirname(HERE)
PLAYFAIR = os.path.expanduser("~/Library/Fonts/PlayfairDisplay-Italic-VariableFont_wght.ttf")

# The plate palette (AII's, Braid's, Craft's), and Weave's vermilion for the host.
BLUE, GREEN, ORANGE, GOLD, LINE = "#5e8fda", "#28a883", "#d8773f", "#c7a659", "#cbc8c0"
VERMILION = "#d4613d"
MONO = "Menlo, 'SF Mono', monospace"


def shoot(browser, page_html, path, viewport=(1200, 630), scale=2, prepare=None):
    """Writes `page_html` beside the inputs (so relative URLs resolve) and screenshots it."""
    with tempfile.NamedTemporaryFile("w", suffix=".html", dir=HERE, delete=False, encoding="utf-8") as f:
        f.write(page_html)
        name = f.name
    try:
        page = browser.new_page(device_scale_factor=scale, viewport={"width": viewport[0], "height": viewport[1]})
        page.goto("file://" + name)
        if prepare:
            page.evaluate(prepare)
        page.wait_for_timeout(200)
        page.screenshot(path=path, full_page=True)
        page.close()
    finally:
        os.unlink(name)


# The mark's ink, the title's and subtitle's first ink, and the legend start at EDGE (Braid's ALIGN).
EDGE = 66
ALIGN = f"""document.fonts.ready.then(() => {{ const ctx = document.createElement('canvas').getContext('2d');
    for (const el of document.querySelectorAll('.title, .sub')) {{ const cs = getComputedStyle(el), text = el.textContent.trim();
        ctx.font = `italic ${{cs.fontWeight}} ${{cs.fontSize}} Playfair`;
        el.style.left = ({EDGE} - parseFloat(cs.paddingLeft) + ctx.measureText(text[0]).actualBoundingBoxLeft) + 'px'; }} }})"""

# The diagram's geometry: the strands start at the left edge, below the subtitle; the needle's eye sits
# level with the middle strand, starting where the subtitle's last word ends; the needle leans up to
# the right, its tip leading to the port.
EYE_X, EYE_Y = 826, 438
NEEDLE_ANGLE = 45           # degrees from horizontal, tip down and to the right
NEEDLE_BACK, NEEDLE_FRONT = 14, 150   # from the eye to the head, and to the tip, along the needle
# The quilt the needle writes on: 3 x 3 patches, laid down in perspective (CSS 3D: tilted away, turned a
# little) so it is seen side-on, like cloth on a table. The page measures where the stitch starts on the
# warped quilt and moves the quilt so that point sits under the needle's tip. QUILT_AT is the quilt's
# centre before that move: to the right, balancing the plate.
QUILT_CELL = 54
QUILT_TILT, QUILT_TURN, QUILT_DEPTH = 58, -26, 700
QUILT_AT = (1010, 520)
STITCH_FROM = (0.08, 0.56)      # where the stitch starts, as fractions of the flat quilt
STRAND_X = 78
ENDS = [(STRAND_X, 446, BLUE, "alpha", 47611), (STRAND_X, 484, GREEN, "beta", 47621), (STRAND_X, 522, ORANGE, "gamma", 47631)]


def strand(x0, y0, x1, y1):
    """A Thread from its node on the left into the eye: it runs level, then rises late, clear of the words."""
    return f"M{x0},{y0} C{x1 - 330},{y0} {x1 - 120},{y1} {x1},{y1}"


def along(distance):
    """A point on the needle's axis, `distance` from the eye (positive toward the tip)."""
    a = math.radians(NEEDLE_ANGLE)
    return EYE_X + distance * math.cos(a), EYE_Y + distance * math.sin(a)


def hero(browser):
    strands = "".join(
        f'<path d="{strand(x + 11, y, EYE_X + 1, EYE_Y)}" fill="none" stroke="{colour}" stroke-width="3.4" stroke-linecap="round"/>'
        f'<circle cx="{x}" cy="{y}" r="9.5" fill="none" stroke="{colour}" stroke-width="2.4"/>'
        f'<circle cx="{x}" cy="{y}" r="3.6" fill="{colour}"/>'
        for x, y, colour, _, _ in ENDS)
    labels = "".join(
        f'<div class="node" style="left:{x + 18}px; top:{y - 35}px"><b>{name}</b> <span>:{port}</span></div>'
        for x, y, _, name, port in ENDS)

    # The needle, drawn on its own axis (the eye at 0, the head at -BACK, the tip at +FRONT), then
    # rotated into place about the eye.
    back, front, w = NEEDLE_BACK, NEEDLE_FRONT, 5.4
    body = (f'M{-back - 6},0 Q{-back - 6},{-w} {-back + 2},{-w} L{front - 34},{-w * 0.75} L{front},0 '
            f'L{front - 34},{w * 0.75} L{-back + 2},{w} Q{-back - 6},{w} {-back - 6},0 Z')
    needle = (f'<g transform="translate({EYE_X} {EYE_Y}) rotate({NEEDLE_ANGLE})">'
              f'<path d="{body}" fill="#000" fill-opacity=".38" transform="translate(2 4)"/>'
              f'<path d="{body}" fill="url(#steel)"/>'
              f'<path d="M{-back + 2},{-w * 0.45} L{front - 40},{-w * 0.35}" stroke="#fff" stroke-opacity=".75" stroke-width="1.2" stroke-linecap="round"/>'
              # The eye, with the three threads showing through it.
              f'<rect x="-8" y="-1.9" width="16" height="3.8" rx="1.9" fill="#121211"/>'
              f'<rect x="-3" y="-1.9" width="6" height="3.8" fill="{VERMILION}"/>'
              '</g>')

    # The quilt, flat: nine patches in the Threads' colours and cream, each quilted with a stitched inset
    # and a diagonal, bound in cream; then the running stitch the needle is writing, in the quilting's own
    # hand, from under the tip across the middle row and away.
    cell = QUILT_CELL
    side = 3 * cell
    palette = [("#e7dfcd", 1), (BLUE, .55), ("#e7dfcd", 1),
               (GREEN, .5), ("#efe8d9", 1), (ORANGE, .55),
               ("#e7dfcd", 1), (GOLD, .6), ("#e7dfcd", 1)]
    patches = f'<rect x="0" y="0" width="{side}" height="{side}" fill="#efe8d9"/>'
    for i, (colour, opacity) in enumerate(palette):
        x, y = (i % 3) * cell, (i // 3) * cell
        patches += (f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" fill="{colour}" fill-opacity="{opacity}"/>'
                    f'<rect x="{x + 6}" y="{y + 6}" width="{cell - 12}" height="{cell - 12}" fill="none" stroke="#fffaf0" '
                    f'stroke-opacity=".75" stroke-width="1.3" stroke-dasharray="4 3"/>'
                    f'<path d="M{x + 11},{y + cell - 11} L{x + cell - 11},{y + 11}" stroke="#fffaf0" stroke-opacity=".5" '
                    f'stroke-width="1.2" stroke-dasharray="4 3"/>')
    seams = "".join(f'<line x1="{k * cell}" y1="0" x2="{k * cell}" y2="{side}" stroke="#2a2a26" stroke-opacity=".3" stroke-width="1.2"/>'
                    f'<line x1="0" y1="{k * cell}" x2="{side}" y2="{k * cell}" stroke="#2a2a26" stroke-opacity=".3" stroke-width="1.2"/>'
                    for k in (1, 2))
    sx, sy = STITCH_FROM[0] * side, STITCH_FROM[1] * side
    run = (f'<line x1="{sx}" y1="{sy}" x2="{side - 12}" y2="{sy}" stroke="{VERMILION}" stroke-opacity=".85" '
           f'stroke-width="2.4" stroke-linecap="round" stroke-dasharray="7 5"/>'
           f'<circle id="stitch-start" cx="{sx}" cy="{sy}" r="0.5" fill="none"/>')
    flat = (f'<svg width="{side}" height="{side}" viewBox="0 0 {side} {side}">{patches}{seams}{run}'
            f'<rect x="1.5" y="1.5" width="{side - 3}" height="{side - 3}" rx="3" fill="none" stroke="#efe8d9" stroke-width="3"/></svg>')
    warp = f"perspective({QUILT_DEPTH}px) rotateX({QUILT_TILT}deg) rotateZ({QUILT_TURN}deg)"
    quilt = (f'<div id="quilt" class="quilt" style="left:{QUILT_AT[0] - side / 2}px; top:{QUILT_AT[1] - side / 2}px; width:{side}px; height:{side}px">'
             # The cloth's thickness: the same quilt, darker, a little lower, under the top.
             f'<div class="ply edge" style="transform:{warp}"></div>'
             f'<div class="ply" style="transform:{warp}">{flat}</div>'
             '</div>')
    tip_x, tip_y = along(NEEDLE_FRONT)
    place = f"""<script>
(() => {{
  const quilt = document.getElementById("quilt"), mark = document.getElementById("stitch-start").getBoundingClientRect();
  const dx = {tip_x:.1f} - (mark.left + mark.width / 2), dy = {tip_y:.1f} - (mark.top + mark.height / 2);
  quilt.style.left = (parseFloat(quilt.style.left) + dx) + "px";
  quilt.style.top = (parseFloat(quilt.style.top) + dy) + "px";
  const box = quilt.querySelector(".ply:last-child").getBoundingClientRect();
  const label = document.getElementById("quilt-label");
  label.style.left = (box.right - label.offsetWidth) + "px";
  label.style.top = (box.top - 92) + "px";
}})();
</script>"""

    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: "Playfair"; font-style: italic; font-weight: 400 900; src: url("file://{PLAYFAIR}") format("truetype"), local("Playfair Display Italic"); }}
html, body {{ margin: 0; width: 1200px; height: 630px; overflow: hidden; }}
body {{ position: relative; font-family: "Playfair", Georgia, serif; font-style: italic; font-variant-numeric: lining-nums;
       background: radial-gradient(ellipse 90% 100% at 22% 20%, #20201c 0%, #191917 45%, #121211 100%); }}
.mark {{ position: absolute; left: 57.5px; top: 52px; width: 72px; }}
.caption {{ position: absolute; left: 143.5px; top: 72px; letter-spacing: .3em; font-size: 16.5px; color: #8b8a84; }}
.title {{ position: absolute; left: 34px; top: 112px; padding-left: 40px; font-size: 220px; line-height: 1; font-weight: 500; letter-spacing: -.005em;
         background: linear-gradient(100deg, #8d9097 0%, #c8cad0 35%, #f2f3f6 58%, #b6b9c1 100%);
         -webkit-background-clip: text; background-clip: text; color: transparent; padding-right: 30px; }}
.sub {{ position: absolute; left: 65.5px; top: 334px; font-size: 40px; color: #9b9991; }}
svg {{ position: absolute; left: 0; top: 0; }}
.lab {{ position: absolute; font-size: 19px; color: #8b8a84; white-space: nowrap; }}
.lab b {{ font-weight: 400; color: #e9e7e0; }}
.quilted {{ line-height: 1.3; text-align: right; }}
.quilt {{ position: absolute; filter: drop-shadow(0 10px 12px rgba(0,0,0,.55)); }}
.ply {{ position: absolute; inset: 0; transform-origin: 50% 50%; }}
.ply.edge {{ top: 7px; bottom: -7px; background: #b9ad94; border-radius: 4px; }}
svg.over {{ position: absolute; left: 0; top: 0; pointer-events: none; }}
.small {{ font-size: 15.5px; color: #8b8a84; }}
.code {{ font-family: {MONO}; font-style: normal; font-size: 13px; color: #8b8a84; letter-spacing: .02em; }}
.node {{ position: absolute; white-space: nowrap; font-size: 19px; color: #8b8a84; }}
.node b {{ font-weight: 400; color: #e9e7e0; }}
.node span {{ font-family: {MONO}; font-style: normal; font-size: 12.5px; }}
.legend {{ position: absolute; left: 66px; top: 556px; width: 1068px; display: flex; gap: 30px; align-items: baseline; font-size: 23px; color: #8b8a84; }}
.legend b {{ font-weight: 400; color: #e9e7e0; }}
.dot {{ display: inline-block; width: 13px; height: 13px; border-radius: 50%; margin-right: 10px; transform: translateY(-1px); }}
.needle {{ display: inline-block; width: 26px; height: 4px; margin: 0 10px 0 2px; transform: translateY(-6px) rotate({NEEDLE_ANGLE}deg);
           background: linear-gradient(180deg, #f4f5f7, #c3c8cf 45%, #7f858e); clip-path: polygon(0 0, 80% 0, 100% 50%, 80% 100%, 0 100%); border-radius: 2px 0 0 2px; }}
.tag {{ margin-left: auto; }}
</style></head><body>
<img class="mark" src="rr-mark.png">
<div class="caption">RAO STUDIOS · WEAVE · THREADS, WOVEN INTO ONE SEARCH</div>
<div class="title">Weave</div>
<div class="sub">spawn AIIs, and search every Thread as one</div>
<svg width="1200" height="630"><defs><linearGradient id="steel" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#f4f5f7"/><stop offset=".45" stop-color="#c3c8cf"/><stop offset="1" stop-color="#7f858e"/></linearGradient></defs>
{strands}</svg>
{quilt}
<svg class="over" width="1200" height="630"><defs><linearGradient id="steel2" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#f4f5f7"/><stop offset=".45" stop-color="#c3c8cf"/><stop offset="1" stop-color="#7f858e"/></linearGradient></defs>
{needle.replace("url(#steel)", "url(#steel2)")}</svg>
{labels}
<div class="lab" style="left:{EYE_X - 28}px; top:{EYE_Y - 52}px"><b>the host</b></div>
<div id="quilt-label" class="lab quilted"><b>your query</b> <span class="code">:47600</span><br><span class="small">every partition, merged by score</span></div>
<div class="legend">
  <span><i class="needle"></i><b>host</b> · a Sewn</span>
  <span><i class="dot" style="background:{BLUE}"></i><b>alpha</b></span>
  <span><i class="dot" style="background:{GREEN}"></i><b>beta</b></span>
  <span><i class="dot" style="background:{ORANGE}"></i><b>gamma</b> · Threads</span>
</div>
{place}
</body></html>"""
    shoot(browser, page, os.path.join(OUT, "hero.png"), prepare=ALIGN)


def main():
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome")
        hero(browser)
        browser.close()
    print("wrote", os.path.join(OUT, "hero.png"))


if __name__ == "__main__":
    main()
