"""Renders Weave's README hero in the Rao plate style (Braid's Docs/README_Assets/src/build.py hero,
Craft's plates.py shoot), from HTML, through the installed Google Chrome driven by Playwright.

    python3 -I Docs/README_Assets/src/plates.py Docs/README_Assets

Inputs:  this folder's rr-mark.png; Playfair Display Italic from ~/Library/Fonts.
Outputs in argv[1]: hero.png (1200x630 at 2x: 2400x1260); hosting.png and datasets.png, the plates on
why Weave (1600 wide at 2x). Name targets to render only those: plates.py <out> hosting.

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
.mark {{ position: absolute; left: 64.6px; top: 62.6px; width: 51.9px; }}
.caption {{ position: absolute; left: 138.8px; top: 72px; letter-spacing: .3em; font-size: 16.5px; color: #8b8a84; }}
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


# MARK: Plates

W = 1600

PLATE_CSS = f"""
@font-face {{{{ font-family: "Playfair"; font-style: italic; font-weight: 400 900; src: url("file://{PLAYFAIR}") format("truetype"), local("Playfair Display Italic"); }}}}
html, body {{{{ margin: 0; width: {W}px; overflow: hidden; }}}}
body {{{{ position: relative; font-family: "Playfair", Georgia, serif; font-style: italic; color: #a29f97; font-variant-numeric: lining-nums;
       background: radial-gradient(ellipse 90% 100% at 22% 20%, #20201c 0%, #191917 45%, #121211 100%); }}}}
.mark {{{{ position: absolute; left: 68.8px; top: 69.3px; width: 46.2px; }}}}
.caption {{{{ position: absolute; left: 145.8px; top: 78px; letter-spacing: .3em; font-size: 15px; color: #8b8a84; }}}}
.title {{{{ position: absolute; left: 30px; padding-left: 40px; top: 150px; font-size: 104px; line-height: 1; font-weight: 500; padding-right: 30px; padding-bottom: 20px;
         background: linear-gradient(100deg, #8d9097 0%, #c8cad0 35%, #f2f3f6 58%, #b6b9c1 100%);
         -webkit-background-clip: text; background-clip: text; color: transparent; white-space: nowrap; }}}}
.sub {{{{ position: absolute; left: 66px; top: 272px; font-size: 32px; color: #9b9991; white-space: nowrap; }}}}
svg.wires {{{{ position: absolute; left: 0; top: 0; }}}}
.card {{{{ position: absolute; box-sizing: border-box; border: 1px solid rgba(255,255,255,.11); border-radius: 14px; background: rgba(255,255,255,.03); padding: 14px 18px; }}}}
.card .name {{{{ font-size: 25px; color: #e9e7e0; }}}}
.card .line {{{{ font-size: 17px; color: #8b8a84; margin-top: 4px; }}}}
.mono {{{{ font-family: {MONO}; font-style: normal; font-size: 13px; color: #a29f97; letter-spacing: .01em; }}}}
.chip {{{{ display: inline-block; font-family: {MONO}; font-style: normal; font-size: 11.5px; padding: 3px 8px; border-radius: 6px; margin: 8px 6px 0 0;
         background: rgba(255,255,255,.06); color: #b9b6ad; }}}}
.boundary {{{{ position: absolute; box-sizing: border-box; border: 1.5px dashed rgba(203,200,192,.28); border-radius: 22px; }}}}
.boundary .label {{{{ position: absolute; left: 22px; top: -11px; padding: 0 10px; background: #171715; letter-spacing: .22em; font-size: 13px; color: #8b8a84; font-style: italic; }}}}
.lab {{{{ position: absolute; font-size: 19px; color: #8b8a84; white-space: nowrap; }}}}
.lab b {{{{ font-weight: 400; color: #e9e7e0; }}}}
.tag {{{{ position: absolute; left: 66px; font-size: 23px; color: #8b8a84; }}}}
.tag b {{{{ font-weight: 400; color: #e9e7e0; }}}}
.dot {{{{ display: inline-block; width: 11px; height: 11px; border-radius: 50%; margin-right: 8px; transform: translateY(-1px); }}}}
.code {{{{ font-family: {MONO}; font-style: normal; font-size: 12.5px; line-height: 1.6; color: #b9b6ad; white-space: pre; }}}}
.code .k {{{{ color: #8b8a84; }}}} .code .s {{{{ color: #d9c9a3; }}}} .code .v {{{{ color: {VERMILION}; }}}}
"""

# The plates' header alignment: the title's and subtitle's first ink on the mark's left edge.
PLATE_ALIGN = ALIGN.replace(str(EDGE), "66")


def node_icon(x, y, colour, size=34):
    """The app's AII node: a ringed core, three links out (as on the Fabric page's cards)."""
    s, c = size, size / 2
    links = ""
    for angle in (-90, 30, 150):
        a = math.radians(angle)
        px, py = c + s * 0.33 * math.cos(a), c + s * 0.33 * math.sin(a)
        links += (f'<line x1="{c}" y1="{c}" x2="{px:.1f}" y2="{py:.1f}" stroke="#cbc8c0" stroke-opacity=".45" stroke-width="{s * .05:.1f}" stroke-linecap="round"/>'
                  f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{s * .065:.1f}" fill="#cbc8c0" fill-opacity=".7"/>')
    return (f'<svg style="position:absolute; left:{x}px; top:{y}px" width="{s}" height="{s}">'
            f'<rect width="{s}" height="{s}" rx="{s * .26:.1f}" fill="{colour}" fill-opacity=".14"/>{links}'
            f'<circle cx="{c}" cy="{c}" r="{s * .18:.1f}" fill="#191917" stroke="{colour}" stroke-width="{s * .06:.1f}"/>'
            f'<circle cx="{c}" cy="{c}" r="{s * .07:.1f}" fill="{colour}"/></svg>')


def needle_svg(x, y, length=96, angle=45):
    """The app's needle, drawn along its own axis from its eye (x, y), then turned."""
    w = 4.2
    body = (f"M-9,0 Q-9,{-w} -2,{-w} L{length - 24},{-w * .75} L{length},0 L{length - 24},{w * .75} L-2,{w} Q-9,{w} -9,0 Z")
    return (f'<g transform="translate({x} {y}) rotate({angle})">'
            f'<path d="{body}" fill="#000" fill-opacity=".38" transform="translate(2 3)"/>'
            f'<path d="{body}" fill="url(#steel)"/>'
            f'<rect x="-6" y="-1.5" width="11" height="3" rx="1.5" fill="#121211"/></g>')


STEEL = """<defs><linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f5f7"/>
<stop offset=".45" stop-color="#c3c8cf"/><stop offset="1" stop-color="#7f858e"/></linearGradient></defs>"""


def curve(x0, y0, x1, y1, colour, width=2.6, dash=None, opacity=1):
    mid = (x0 + x1) / 2
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<path d="M{x0},{y0} C{mid},{y0} {mid},{y1} {x1},{y1}" fill="none" stroke="{colour}" stroke-width="{width}" '
            f'stroke-opacity="{opacity}" stroke-linecap="round"{d}/>')


def arrow(x, y, colour):
    return f'<path d="M{x - 9},{y - 7} L{x},{y} L{x - 9},{y + 7}" fill="none" stroke="{colour}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'


def plate(browser, name, height, caption, title, sub, body):
    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>{PLATE_CSS.format()}
html, body {{ height: {height}px; }}</style></head><body>
<img class="mark" src="rr-mark.png">
<div class="caption">{caption}</div>
<div class="title">{title}</div>
<div class="sub">{sub}</div>
{body}
</body></html>"""
    shoot(browser, page, os.path.join(OUT, f"{name}.png"), viewport=(W, height), prepare=PLATE_ALIGN)


def hosting(browser):
    """Why Weave: every partition hosted on this Mac, each its own AII, fed through one forwarding port."""
    sources = [("an app", "POST /v1/batch/embeddings", 392), ("a notebook", "POST /v1/search", 532), ("a crawler", '"weave": {"aii": "gamma"}', 672)]
    aiis = [("alpha", "Textile archive", 47611, BLUE, 380), ("beta", "Engines", 47621, GREEN, 540), ("gamma", "Lovelace notes", 47631, ORANGE, 700)]
    port = (640, 520, 290, 168)          # x, y, width, height
    px, py, pw, ph = port
    cards = ""
    wires = STEEL
    for label, line, y in sources:
        cards += f'<div class="card" style="left:66px; top:{y}px; width:330px; height:104px"><div class="name">{label}</div><div class="line mono">{line}</div></div>'
        wires += curve(396, y + 52, px - 4, py + ph / 2, LINE, width=2.2, opacity=.55) + arrow(px - 4, py + ph / 2, LINE)
    cards += (f'<div class="card" style="left:{px}px; top:{py}px; width:{pw}px; height:{ph}px; border-color: rgba(212,97,61,.45)">'
              f'<div class="name" style="padding-left:58px">Weave&rsquo;s port</div><div class="line mono" style="padding-left:58px">127.0.0.1:47600</div>'
              f'<div class="line" style="margin-top:18px">forwards each AII&rsquo;s own API</div>'
              f'<span class="chip">&quot;weave&quot;: {{&quot;aii&quot;: id}}</span></div>')
    wires += needle_svg(px + 22, py + 24, length=44, angle=45)
    for name, label, http, colour, y in aiis:
        cards += (f'<div class="card" style="left:1072px; top:{y}px; width:450px; height:138px">'
                  f'<div class="name" style="padding-left:50px">{name} <span class="mono" style="font-size:12.5px">:{http}</span></div>'
                  f'<div class="line" style="padding-left:50px">{label}</div>'
                  f'<span class="chip">embeddings · on device</span><span class="chip">graph · on device</span><span class="chip">its own index</span></div>'
                  + node_icon(1090, y + 16, colour))
        wires += curve(px + pw, py + ph / 2, 1068, y + 69, colour, width=3) + arrow(1068, y + 69, colour)
    boundary = ('<div class="boundary" style="left:600px; top:350px; width:950px; height:560px">'
                '<div class="label">THIS MAC · ~/LIBRARY/APPLICATION SUPPORT/WEAVE/AIIS</div></div>')
    models = ('<div class="card" style="left:640px; top:846px; width:882px; height:44px; padding:10px 18px; background: rgba(199,166,89,.06); border-color: rgba(199,166,89,.3)">'
              f'<span class="mono" style="color:{GOLD}">~/.rao/models</span><span class="line" style="margin-left:14px">voyage-4-nano and granite-4.0-h-micro, linked into every AII: downloaded once, shared</span></div>')
    labels = ('<div class="lab" style="left:66px; top:350px"><b>your sources</b> · anything on this Mac</div>')
    tag = ('<div class="tag" style="top:950px">Every partition is hosted here as its own AII: <b>its own Thread, index, graph and port</b>. '
           'Nothing leaves the Mac; nothing is downloaded twice.</div>')
    body = f'<svg class="wires" width="{W}" height="1010">{wires}</svg>{boundary}{labels}{cards}{models}{tag}'
    plate(browser, "hosting", 1010, "RAO STUDIOS · WEAVE · HOSTED ON THIS MAC", "Hosted here",
          "every partition its own AII, fed through one forwarding port", body)


def datasets(browser):
    """Why Weave: questions across every partition, answers with their provenance, a training set."""
    questions = ["How did punched cards reach computing?", "What did the Analytical Engine’s mill do?", "Who wrote Note G, and what did it compute?"]
    rows = [("alpha", BLUE, "The Jacquard loom reads a chain of punched cards…", "d·1491…", "0.21"),
            ("gamma", ORANGE, "Lovelace: the engine weaves algebraic patterns…", "d·5121…", "0.24"),
            ("beta", GREEN, "Babbage took instructions on punched cards…", "d·2401…", "0.27"),
            ("gamma", ORANGE, "Her Note G computes Bernoulli numbers…", "d·0912…", "0.31"),
            ("beta", GREEN, "The store held numbers; the mill operated…", "d·3304…", "0.33")]
    wires = STEEL
    cards = ""
    # Questions.
    for i, q in enumerate(questions):
        y = 400 + i * 96
        cards += f'<div class="card" style="left:66px; top:{y}px; width:300px; height:78px; padding:12px 16px"><div class="line" style="margin:0; color:#d6d3cb; font-size:18px">{q}</div></div>'
        wires += curve(366, y + 39, 452, 545, LINE, width=2, opacity=.5)
    # The host: a needle; three strands out to the AIIs and back into the answers.
    wires += needle_svg(452, 545, length=70, angle=-35)
    wires += f'<circle cx="452" cy="545" r="3.4" fill="{VERMILION}"/>'
    lab = '<div class="lab" style="left:400px; top:648px; line-height:1.25"><b>the host</b><br>one search</div>'
    for name, colour, y in [("alpha", BLUE, 430), ("beta", GREEN, 545), ("gamma", ORANGE, 660)]:
        wires += curve(458, 545, 600, y, colour, width=3)
        cards += (f'<div class="card" style="left:600px; top:{y - 26}px; width:130px; height:52px; padding:8px 12px">'
                  f'<span class="dot" style="background:{colour}"></span><span class="name" style="font-size:21px">{name}</span></div>')
        wires += curve(730, y, 784, 545, colour, width=3, opacity=.85)
    wires += arrow(786, 545, LINE)
    # Answers with provenance.
    table = ''.join(
        f'<div style="display:flex; align-items:baseline; gap:12px; padding:9px 0; border-top:1px solid rgba(255,255,255,.07)">'
        f'<span class="chip" style="margin:0; min-width:54px; text-align:center; color:{colour}; background:rgba(255,255,255,.05)">{aii}</span>'
        f'<span class="line" style="margin:0; flex:1; color:#d6d3cb; font-size:16px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis">{text}</span>'
        f'<span class="mono" style="font-size:11.5px">{doc}</span><span class="mono" style="font-size:11.5px; color:#8b8a84">{score}</span></div>'
        for aii, colour, text, doc, score in rows)
    cards += (f'<div class="card" style="left:792px; top:380px; width:428px; height:330px">'
              f'<div class="name">Answers, with provenance</div><div class="line" style="margin-bottom:10px">each hit: its AII, its document, its distance</div>{table}</div>')
    wires += curve(1220, 545, 1248, 545, LINE, width=2.4) + arrow(1250, 545, LINE)
    jsonl = ('<span class="k">{</span><span class="s">"prompt"</span>: <span class="s">"How did…"</span>,\n'
             ' <span class="s">"context"</span>: [\n'
             '   <span class="s">"The Jacquard loom…"</span>,\n'
             '   <span class="s">"Babbage took…"</span>],\n'
             ' <span class="s">"sources"</span>: [\n'
             '   {<span class="s">"aii"</span>: <span class="v">"alpha"</span>,\n'
             '    <span class="s">"document_id"</span>: <span class="s">"1491…"</span>},\n'
             '   …]<span class="k">}</span>')
    cards += (f'<div class="card" style="left:1256px; top:380px; width:278px; height:330px; border-color: rgba(199,166,89,.35); background: rgba(199,166,89,.05)">'
              f'<div class="name">A training set</div><div class="line">your pipeline, one row a question</div>'
              f'<div class="code" style="margin-top:12px; font-size:11px; line-height:1.5">{jsonl}</div>'
              f'<span class="chip" style="color:{GOLD}">train.jsonl</span></div>')
    under = ('<div class="lab" style="left:1256px; top:726px; white-space:normal; width:278px; font-size:17px">'
             '<b>a fine-tune</b>, a LoRA, an eval: every row traceable to the AII and document it came from</div>')
    tag = ('<div class="tag" style="top:850px">Weave hosts and retrieves; <b>every answer keeps its source</b>. '
           'Your pipeline turns the answers into a training set you can trace back, row by row.</div>')
    body = f'<svg class="wires" width="{W}" height="920">{wires}</svg>{lab}{cards}{under}{tag}'
    plate(browser, "datasets", 920, "RAO STUDIOS · WEAVE · FROM PARTITIONS TO A TRAINING SET", "Training sets",
          "ask every partition at once; keep where each answer came from", body)


TARGETS = {"hero": hero, "hosting": hosting, "datasets": datasets}


def main():
    os.makedirs(OUT, exist_ok=True)
    wanted = [name for name in sys.argv[2:] if name in TARGETS] or list(TARGETS)
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome")
        for name in wanted:
            TARGETS[name](browser)
            print("wrote", os.path.join(OUT, f"{name}.png"))
        browser.close()


if __name__ == "__main__":
    main()
