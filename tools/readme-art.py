#!/usr/bin/env python3
"""Draws the README art from design/tokens.json and the installer's lock sprite, so the page and the product
cannot drift apart. Run: python3 tools/readme-art.py   (writes docs/readme/hero.svg and docs/readme/pane.svg)"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from installer import SHACKLE, BODY, LIFT  # noqa: E402  the same pixels the installer draws

T = json.load(open(os.path.join(ROOT, "design", "tokens.json")))
N, S, G = T["neutral"], T["state"], T["glyphs"]
OUT = os.path.join(ROOT, "docs", "readme")
SANS = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace"


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def hexof(c): return "#%02X%02X%02X" % c
def mix(a, b, t): a, b = rgb(a), rgb(b); return hexof(tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)))


def aurora(t):
    stops = T["aurora"]; t = min(1, max(0, t)) * (len(stops) - 1); k = min(int(t), len(stops) - 2)
    return mix(stops[k], stops[k + 1], t - k)


def stops(): return "".join(f'<stop offset="{i / (len(T["aurora"]) - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(T["aurora"]))
def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def lock(x, y, px, opens_at=None):
    """The pixel lock, closed. With opens_at (seconds), the shackle slides up once: access just opened."""
    width, gap = len(BODY[0]), 1  # gap: a hairline between pixels, the way the dots read in a terminal
    cell = lambda c, r, fill: f'<rect x="{x + c * px}" y="{y + r * px}" width="{px - gap}" height="{px - gap}" rx="1" fill="{fill}"/>'
    steel = lambda c: mix("#9696A5", "#E1E1EB", c / width)
    shackle = "".join(cell(c, LIFT + r, steel(c)) for r, row in enumerate(SHACKLE) for c, ch in enumerate(row) if ch == "X")
    top = LIFT + len(SHACKLE)
    body = "".join(cell(c, top + r, aurora(c / (width - 1)) if ch == "X" else N["0"]) for r, row in enumerate(BODY) for c, ch in enumerate(row))
    if opens_at is None: return f"<g>{shackle}</g>{body}"
    # Open: the shackle rises LIFT rows and the left leg stays seated in the body, as on a real padlock.
    leg = "".join(cell(c, top - 1 - k, steel(c)) for k in range(LIFT) for c, ch in enumerate(SHACKLE[-1][:width // 2]) if ch == "X")
    rise = (f'<animateTransform attributeName="transform" type="translate" from="0 0" to="0 {-LIFT * px}" begin="{opens_at}s" '
            f'dur="0.32s" fill="freeze" calcMode="spline" keySplines="0.2 0.8 0.2 1" keyTimes="0;1"/>')
    show = f'<set attributeName="opacity" to="1" begin="{opens_at + 0.1}s"/>'
    return f'<g opacity="0">{leg}{show}</g><g>{shackle}{rise}</g>{body}'


def dots(x0, y0, w, h, step, fill, fade):
    """A Braille-like dot field that thins out to the left: the product's surface texture."""
    out = []
    for j in range(int(h // step)):
        for i in range(int(w // step)):
            t = i / max(1, w // step - 1)
            if (i * 7 + j * 13) % 5 > t * 5: continue  # thinner as it moves away from the edge
            out.append(f'<circle cx="{x0 + i * step:.1f}" cy="{y0 + j * step:.1f}" r="1.3" fill="{fill}" opacity="{fade * t:.2f}"/>')
    return "".join(out)


def hero():
    W, H = 960, 320
    px = 15
    lx, ly = 72, (H - (LIFT + len(SHACKLE) + len(BODY)) * px) / 2
    tx = 270
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="Agents Mission Control: Full Disk Access for Claude Code agents, approved with Touch ID">
<defs>
  <linearGradient id="aurora" x1="{tx}" y1="0" x2="{tx + 560}" y2="0" gradientUnits="userSpaceOnUse">{stops()}</linearGradient>
  <linearGradient id="edge" x1="0" y1="0" x2="1" y2="0">{stops()}</linearGradient>
  <clipPath id="card"><rect width="{W}" height="{H}" rx="18"/></clipPath>
</defs>
<g clip-path="url(#card)">
  <rect width="{W}" height="{H}" fill="{N["0"]}"/>
  {dots(W - 300, 24, 290, H - 40, 9, N["30"], 0.9)}
  <rect y="{H - 4}" width="{W}" height="4" fill="url(#edge)"/>
</g>
<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="17.5" fill="none" stroke="{N["10"]}"/>
{lock(lx, ly, px, opens_at=0.8)}
<g font-family="{SANS}">
  <text x="{tx}" y="104" font-size="13" font-weight="700" letter-spacing="3.2" fill="{N["50"]}">PRIVILEGED SESSIONS FOR AGENTS</text>
  <text x="{tx}" y="158" font-size="46" font-weight="800" letter-spacing="-0.8" fill="url(#aurora)">Agents Mission Control</text>
  <text x="{tx}" y="200" font-size="20" fill="{N["100"]}">Full Disk Access for Claude Code agents on macOS,</text>
  <text x="{tx}" y="228" font-size="20" fill="{N["100"]}">one session at a time, approved with Touch ID.</text>
  <text x="{tx}" y="268" font-size="14" fill="{N["50"]}"><tspan font-family="{MONO}" fill="{S["ok"]}">{G["open"]}</tspan>  every command traced  ·  Ivan Gonzalez (tomacco)  ·  tomac.co</text>
</g>
</svg>
'''


def pane():
    """The Claude Code pane while access is open, drawn after mod/hooks/register.tsx (ui.render)."""
    W, H, lh, cw = 960, 400, 21, 8.4  # line height and monospace cell width, in px
    accent = aurora(0.35)
    x0, y0 = 40, 50
    t = []
    def text(col, row, s, fill=N["100"], weight=400, spacing=0):
        t.append(f'<text x="{x0 + col * cw:.1f}" y="{y0 + row * lh:.1f}" fill="{fill}" font-weight="{weight}" letter-spacing="{spacing}">{esc(s)}</text>')
    def label(col, row, s): text(col, row, " ".join(s), N["50"], 700)
    # Header: the lock, then the agent in its session color, the badge and the summary.
    px = 10.5
    head = lock(x0, y0 - lh + 4, px)
    text(13, 0, "Inbox Archivist", accent, 700)
    text(13, 1, "finding an invoice", N["50"])
    badge_w = len(" ● ACCESS OPEN ") * cw
    badge = f'<rect x="{x0 + 13 * cw - 2}" y="{y0 + 2.2 * lh}" width="{badge_w}" height="{lh}" rx="3" fill="#2F9E6E"/>'
    text(13, 3, f" {G['open']} ACCESS OPEN ", "#FFFFFF", 700)
    text(13, 4, "this session · 2 runs", N["50"])
    # What the person approved.
    rule = f'<line x1="{x0}" y1="{y0 + 5.7 * lh}" x2="{x0 + 50 * cw}" y2="{y0 + 5.7 * lh}" stroke="{N["30"]}"/>'
    label(0, 7, "WHY")
    text(0, 8, "Read the Mail store to find last week's invoice")
    text(0, 9, G["path"], accent); text(2, 9, "~/Library/Mail", N["70"])
    # Recent runs, newest first, each in a card with its state color.
    cards = []
    def card(col, row, rows, state, headline, ago, cmd, tail):
        cx, cy = x0 + col * cw, y0 + (row - 0.8) * lh
        cards.append(f'<rect x="{cx}" y="{cy}" width="{50 * cw}" height="{(rows + 0.6) * lh}" rx="8" fill="none" stroke="{state}" stroke-width="1.4"/>')
        text(col + 1.5, row + 0.2, headline, state, 700)
        if ago: text(col + 48.5 - len(ago), row + 0.2, ago, N["50"])
        text(col + 1.5, row + 1.2, G["command"], accent, 700); text(col + 3.5, row + 1.2, cmd)
        for i, line in enumerate(tail): text(col + 1.5, row + 2.2 + i, f"{G['output']} {line}", N["50"])
    label(56, 0, "RECENT")
    card(56, 1.6, 2, S["busy"], "◐ running", "", "mdfind -onlyin ~/Library/Mail invoice", [])
    card(56, 5.2, 5, S["ok"], f"{G['done']} done", "4s ago", "ls ~/Library/Mail/V10", ["0E4B8A12-…-MailData", "MailData", "Signatures"])
    text(56, 12.4, "Touch ID · every command traced · /amc", N["50"])
    caption = f'<text x="{W / 2}" y="{H - 22}" text-anchor="middle" font-family="{SANS}" font-size="13" fill="{N["50"]}">The pane beside the Claude Code transcript while a session holds access (illustration)</text>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="The Agents Mission Control pane in Claude Code: the agent, ACCESS OPEN, why access was given, and recent commands">
<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="17.5" fill="{N["0"]}" stroke="{N["10"]}"/>
{head}{badge}{rule}{"".join(cards)}
<g font-family="{MONO}" font-size="14.2">{"".join(t)}</g>
{caption}
</svg>
'''


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, svg in (("hero.svg", hero()), ("pane.svg", pane())):
        open(os.path.join(OUT, name), "w").write(svg)
        print(os.path.relpath(os.path.join(OUT, name), ROOT))
