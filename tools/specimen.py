#!/usr/bin/env python3
"""The Agents Mission Control design system, printed in the terminal it is designed for.
Run: python3 tools/specimen.py   (needs a truecolor terminal; Terminal.app and iTerm2 have one)"""
import json, math, os, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = json.load(open(os.path.join(ROOT, "design", "tokens.json")))
R, B, D = "\x1b[0m", "\x1b[1m", "\x1b[2m"


def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def fg(h): r, g, b = rgb(h); return f"\x1b[38;2;{r};{g};{b}m"
def bg(h): r, g, b = rgb(h); return f"\x1b[48;2;{r};{g};{b}m"
def hexof(c): return "#%02X%02X%02X" % c
def mix(a, b, t): a, b = rgb(a), rgb(b); return hexof(tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)))


def aurora(t):
    """A point on the brand gradient, t from 0 to 1."""
    stops = T["aurora"]; t = min(1, max(0, t)) * (len(stops) - 1); k = min(int(t), len(stops) - 2)
    return mix(stops[k], stops[k + 1], t - k)


def gradient_text(s):
    return "".join(fg(aurora(i / max(1, len(s) - 1))) + ch for i, ch in enumerate(s)) + R


N, S = T["neutral"], T["state"]
def head(title, note):
    print(f"\n  {gradient_text(title.upper())}   {fg(N['50'])}{note}{R}")
    print(f"  {fg(N['30'])}{'─' * 64}{R}")


def label(s): return f"{B}{fg(N['50'])}{' '.join(s.upper())}{R}"


# ── icons: dot line-art, the orb's language ──────────────────────────────────

BITS = [(0, 0, 1), (0, 1, 2), (0, 2, 4), (1, 0, 8), (1, 1, 16), (1, 2, 32), (0, 3, 64), (1, 3, 128)]


def lock(lift, cols=10, rows=7):
    """Rows of (char, kind, x share) for the lock: dotted outline, engraved texture, shackle raised by `lift`."""
    W, H = cols * 2, rows * 4
    bx0, bx1, by0, by1, rr = 1.0, W - 1.0, 15.0, H - 1.0, 3.0
    cx, Rr, cy = W / 2, W * 0.28, 9.0 - lift
    kx, ky = W / 2, by0 + 4.5

    def ink(x, y):
        qx = max(bx0 + rr - x, 0, x - (bx1 - rr)); qy = max(by0 + rr - y, 0, y - (by1 - rr))
        inside = bx0 <= x <= bx1 and by0 <= y <= by1 and math.hypot(qx, qy) <= rr
        if inside:
            if math.hypot(x - kx, y - ky) < 1.3 or (abs(x - kx) < 0.6 and ky < y < ky + 3.5): return "key"
            if math.hypot(x - kx, y - ky) < 2.6: return None
            edge = abs(math.hypot(qx, qy) - rr) if (qx > 0 and qy > 0) else min(x - bx0, bx1 - x, y - by0, by1 - y)
            if edge < 0.9 or (int(x) + int(y)) % 3 == 0: return "body"
            return None
        ring = y <= cy and abs(math.hypot(x - cx, y - cy) - Rr) < 0.75
        left = abs(x - (cx - Rr)) < 0.75 and cy < y < by0
        right = abs(x - (cx + Rr)) < 0.75 and cy < y < (by0 - lift - 1 if lift else by0)
        return "steel" if (ring or left or right) else None

    out = []
    for y0 in range(0, H, 4):
        line = []
        for x0 in range(0, W, 2):
            code, kind = 0, None
            for dx, dy, bit in BITS:
                k = ink(x0 + dx + 0.5, y0 + dy + 0.5)
                if k: code |= bit; kind = "key" if k == "key" or kind == "key" else (kind or k)
            line.append((chr(0x2800 + code) if code else " ", kind, x0 / W))
        out.append(line)
    return out


def paint_lock(rows, accent=None):
    lines = []
    for row in rows:
        s = ""
        for ch, kind, x in row:
            if kind == "body": s += fg(accent or aurora(x)) + ch
            elif kind == "steel": s += fg(N["70"]) + ch
            elif kind == "key": s += fg(N["100"]) + B + ch + R
            else: s += ch
        lines.append(s + R)
    return lines


# ── sections ─────────────────────────────────────────────────────────────────

def wordmark():
    print()
    shut, opened = paint_lock(lock(0)), paint_lock(lock(4))
    text = ["", "", f"{B}{gradient_text('Agents Mission Control')}",
            f"{fg(N['70'])}Full Disk Access for coding agents, approved with Touch ID{R}",
            f"{fg(N['50'])}by {R}{B}Ivan Gonzalez{R}{fg(N['50'])} (tomacco) · {R}{fg(aurora(0))}tomac.co{R}", "", ""]
    for i, l in enumerate(shut): print(f"  {l}   {text[i] if i < len(text) else ''}")


def color():
    head("Color", "one identity gradient, quiet neutrals, state colors that mean one thing each")
    print(f"\n  {label('aurora')}   identity: titles, the wordmark, the lock, celebration")
    print("  " + "".join(bg(aurora(i / 63)) + " " for i in range(64)) + R)
    print("  " + "  ".join(f"{fg(h)}{h}{R}" for h in T["aurora"]))
    print(f"\n  {label('session accents')}   picked along Aurora by session, never a random hue")
    acc = [aurora(i / (T['accents'] - 1)) for i in range(T["accents"])]
    print("  " + " ".join(f"{bg(h)}      {R}" for h in acc))
    print(f"\n  {label('neutral')}   text, rules, surfaces; dim is the default, color is earned")
    print("  " + " ".join(f"{bg(h)}{fg(N['100'] if k in ('10', '0', '30') else N['0'])} {k:>3} {R}" for k, h in N.items()))
    print(f"\n  {label('state')}")
    meaning = {"ok": "done", "busy": "running", "bad": "failed", "touch": "needs you", "info": "fyi"}
    print("  " + "  ".join(f"{bg(h)}{fg('#FFFFFF')}{B} {k} {R} {fg(N['50'])}{meaning[k]}{R}" for k, h in S.items()))


def type_():
    head("Type", "five roles; nothing else")
    print(f"\n  {B}{gradient_text('Title')}{R}                          bold, Aurora; one per screen")
    print(f"  {label('label')}                          letter-spaced, bold, neutral 50")
    print(f"  {fg(N['100'])}Body text that explains.{R}        neutral 100")
    print(f"  {fg(aurora(0.15))}{B}❯{R} {fg(N['100'])}ls ~/Library/Mail{R}              command: Aurora prompt, plain text")
    print(f"  {fg(N['50'])}2 minutes ago · 3 runs{R}          meta: neutral 50")
    print(f"\n  Big type is pixel letters in background-colored cells (no seams), for moments only: YOUR TURN, ALL SET!")


def glyphs():
    head("Glyphs", "each one means one thing")
    g = T["glyphs"]
    rows = [(g["done"], S["ok"], "done"), (g["failed"], S["bad"], "failed"), (g["running"][0], S["busy"], "running (◐◓◑◒)"),
            (g["open"], S["ok"], "access open"), (g["shut"], N["70"], "no access"), (g["touch"], S["touch"], "waiting for Touch ID"),
            (g["path"], aurora(0.15), "a protected path"), (g["command"], aurora(0.15), "a command"),
            (g["output"], N["50"], "command output"), (g["rule"], N["30"], "a divider")]
    for i in range(0, len(rows), 2):
        print("  " + "    ".join(f"{fg(c)}{B}{ch}{R}  {fg(N['70'])}{m:<22}{R}" for ch, c, m in rows[i:i + 2]))


def icons():
    head("Icons", "dot line-art in Braille, like the orb: outline, engraved texture, depth from dot density")
    a, b = paint_lock(lock(0)), paint_lock(lock(4))
    c = paint_lock(lock(0), accent=aurora(0.55))
    for i in range(len(a)): print(f"  {a[i]}      {b[i]}      {c[i]}")
    print(f"  {fg(N['50'])}shut (Aurora)            open (shackle up)         a session's accent{R}")
    print(f"\n  The orb ({T['motion']['touch']}, {T['motion']['running']}, ...) is the motion icon: thinking-orbs by Jakub Antalik, drawn in Braille.")


def components():
    head("Components", "")
    print(f"\n  {label('badges')}")
    print(f"  {bg(S['ok'])}{fg('#FFFFFF')}{B} ● ACCESS OPEN {R}  {bg(N['10'])}{fg(N['70'])}{B} ○ NO ACCESS {R}  {bg(S['touch'])}{fg('#FFFFFF')}{B} ◉ TOUCH ID {R}")
    print(f"\n  {label('run card')}   border in the state color, time right, output under a gutter")
    w = 40
    for state, title, when in ((S["ok"], "✓ done", "a minute ago"), (S["busy"], "◐ running", "")):
        print(f"  {fg(state)}╭{'─' * w}╮{R}")
        print(f"  {fg(state)}│{R} {fg(state)}{B}{title}{R}{' ' * (w - 2 - len(title) - len(when))}{fg(N['50'])}{when}{R} {fg(state)}│{R}")
        print(f"  {fg(state)}│{R} {fg(aurora(0.15))}{B}❯{R} {fg(N['100'])}{'ls -la ~/Library/Mail':<{w - 4}}{R} {fg(state)}│{R}")
        print(f"  {fg(state)}│{R} {fg(N['50'])}{'│ drwxr-xr-x  V10':<{w - 2}}{R} {fg(state)}│{R}")
        print(f"  {fg(state)}╰{'─' * w}╯{R}")


def motion():
    head("Motion", "motion always means something; nothing moves while idle")
    m = T["motion"]
    for what, how in ((f"orb · {m['touch']}", "waiting for you (Touch ID)"), (f"orb · {m['running']}", "a command runs"),
                      (f"orb · {m['granting']}", "waiting for the Full Disk Access switch"), ("shackle slides up", "access just opened"),
                      ("pulse ×3 + chime", "your action is needed"), ("confetti + wipe", "done, celebrate once")):
        print(f"  {fg(aurora(0.4))}{what:<26}{R}{fg(N['70'])}{how}{R}")
    print(f"  {fg(N['50'])}{m['fps']} fps for frame animations; sounds only when Agent Board's hands off is off.{R}")
    if sys.stdout.isatty():
        print(f"\n  {fg(N['50'])}the lock opening:{R}")
        drawn = 0; sys.stdout.write("\x1b[?25l")
        for lift in [0] * 6 + [1, 2, 3, 4] + [4] * 8:
            rows = paint_lock(lock(lift))
            if drawn: sys.stdout.write(f"\x1b[{drawn}A")
            for r in rows: sys.stdout.write("\x1b[2K  " + r + "\n")
            drawn = len(rows); sys.stdout.flush(); time.sleep(0.08)
        sys.stdout.write("\x1b[?25h")


if __name__ == "__main__":
    wordmark(); color(); type_(); glyphs(); icons(); components(); motion(); print()
