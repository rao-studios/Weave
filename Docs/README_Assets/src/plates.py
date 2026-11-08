"""Renders Weave's README hero in the Rao plate style (Braid's Docs/README_Assets/src/build.py hero,
Craft's plates.py shoot), from HTML, through the installed Google Chrome driven by Playwright.

    python3 -I Docs/README_Assets/src/plates.py Docs/README_Assets

Inputs:  this folder's rr-mark.png; Playfair Display Italic from ~/Library/Fonts.
Outputs: hero.png (1200x630 at 2x: 2400x1260) in argv[1].

What it draws follows the app: a query enters Weave's port (127.0.0.1:47600), goes to the host
(the Sewn every woven Thread registered with, ringed in Weave's vermilion), and fans out to the
spawned AIIs' Threads, each on its own slot's port; their partitions come back merged by score.
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

# The diagram's geometry.
PORT_X, LANE_Y = 68, 462
HOST_X = 560
ENDS = [(1068, 404, BLUE, "alpha", 47611), (1068, 462, GREEN, "beta", 47621), (1068, 520, ORANGE, "gamma", 47631)]


def strand(x0, y0, x1, y1):
    """A thread from the host to a Thread: leaves level, bends, arrives level."""
    mid = (x0 + x1) / 2
    return f"M{x0},{y0} C{mid},{y0} {mid},{y1} {x1},{y1}"


def weave_marks(y, x0, x1, colour, step=26):
    """Small over-under ticks across a strand, so the lane reads as cloth."""
    marks = []
    x = x0 + step
    i = 0
    while x < x1 - step / 2:
        dy = 7 if i % 2 == 0 else -7
        marks.append(f'<line x1="{x}" y1="{y - dy}" x2="{x}" y2="{y + dy}" stroke="{colour}" stroke-opacity=".28" stroke-width="2" stroke-linecap="round"/>')
        x += step
        i += 1
    return "".join(marks)


def hero(browser):
    strands = "".join(
        f'<path d="{strand(HOST_X + 14, LANE_Y, x - 11, y)}" fill="none" stroke="{colour}" stroke-width="3.4" stroke-linecap="round"/>'
        f'<circle cx="{x}" cy="{y}" r="9.5" fill="none" stroke="{colour}" stroke-width="2.4"/>'
        f'<circle cx="{x}" cy="{y}" r="3.6" fill="{colour}"/>'
        for x, y, colour, _, _ in ENDS)
    labels = "".join(
        f'<div class="node" style="left:{x - 168}px; top:{y - 33}px"><b>{name}</b> <span>:{port}</span></div>'
        for x, y, _, name, port in ENDS)
    query = (f'<line x1="{PORT_X + 8}" y1="{LANE_Y}" x2="{HOST_X - 14}" y2="{LANE_Y}" stroke="{LINE}" stroke-width="3" stroke-linecap="round"/>'
             + weave_marks(LANE_Y, PORT_X + 8, HOST_X - 14, LINE)
             + f'<path d="M{HOST_X - 26},{LANE_Y - 7} L{HOST_X - 18},{LANE_Y} L{HOST_X - 26},{LANE_Y + 7}" fill="none" stroke="{LINE}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>'
             + f'<rect x="{PORT_X - 6}" y="{LANE_Y - 8}" width="14" height="16" rx="3" fill="none" stroke="{LINE}" stroke-width="2.2"/>')
    host = (f'<circle cx="{HOST_X}" cy="{LANE_Y}" r="14" fill="none" stroke="{VERMILION}" stroke-width="2.8"/>'
            f'<circle cx="{HOST_X}" cy="{LANE_Y}" r="5" fill="{VERMILION}"/>')
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
.lab {{ position: absolute; font-size: 19px; color: #8b8a84; }}
.lab b {{ font-weight: 400; color: #e9e7e0; }}
.code {{ font-family: {MONO}; font-style: normal; font-size: 13px; color: #8b8a84; letter-spacing: .02em; }}
.node {{ position: absolute; width: 150px; text-align: right; font-size: 19px; color: #8b8a84; }}
.node b {{ font-weight: 400; color: #e9e7e0; }}
.node span {{ font-family: {MONO}; font-style: normal; font-size: 12.5px; }}
.legend {{ position: absolute; left: 66px; top: 556px; width: 1068px; display: flex; gap: 30px; align-items: baseline; font-size: 23px; color: #8b8a84; }}
.legend b {{ font-weight: 400; color: #e9e7e0; }}
.dot {{ display: inline-block; width: 13px; height: 13px; border-radius: 50%; margin-right: 10px; transform: translateY(-1px); }}
.ring {{ display: inline-block; width: 9px; height: 9px; border-radius: 50%; border: 2.4px solid {VERMILION}; margin-right: 10px; transform: translateY(-1px); }}
.tag {{ margin-left: auto; }}
</style></head><body>
<img class="mark" src="rr-mark.png">
<div class="caption">RAO STUDIOS · WEAVE · THREADS, WOVEN INTO ONE SEARCH</div>
<div class="title">Weave</div>
<div class="sub">spawn AIIs, and search every Thread as one</div>
<svg width="1200" height="630">{query}{strands}{host}</svg>
<div class="lab" style="left:{PORT_X - 2}px; top:{LANE_Y - 44}px"><b>your query</b> <span class="code">:47600</span></div>
<div class="lab" style="left:{HOST_X - 40}px; top:{LANE_Y + 22}px"><b>the host</b></div>
{labels}
<div class="legend">
  <span><i class="ring"></i><b>host</b> · a Sewn</span>
  <span><i class="dot" style="background:{BLUE}"></i><b>alpha</b></span>
  <span><i class="dot" style="background:{GREEN}"></i><b>beta</b></span>
  <span><i class="dot" style="background:{ORANGE}"></i><b>gamma</b> · Threads</span>
  <span class="tag">one query, every partition, merged by score</span>
</div>
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
