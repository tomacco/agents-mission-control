#!/usr/bin/env python3
"""The installer people see: runs install.sh (AMC_UI=1) and draws its steps, then guides the one step macOS
leaves to the person, Full Disk Access, before opening any window. Standard library only."""
import json, os, re, shutil, signal, socket, subprocess, sys, threading, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTHOR, HANDLE, SITE, TEAM = "Ivan Gonzalez", "tomacco", "tomac.co", "Y4UQ4S5ANQ"
LOG = os.path.expanduser("~/Library/Logs/amc-install.log")
OUT = sys.stdout

# The lock, in pixels. A pixel is two terminal columns of background color: background fills the whole
# cell, so no line spacing or font leaves seams (half-block glyphs did). In BODY, "." is the keyhole.
SHACKLE = ["..XXXXX..", ".XX...XX.", ".X.....X.", ".X.....X."]
BODY = ["XXXXXXXXX", "XXX...XXX", "XXXX.XXXX", "XXXX.XXXX", "XXXXXXXXX", "XXXXXXXXX"]
LIFT = 2  # rows the shackle starts above its closed place
ORANGE, PINK, VIOLET = (217, 119, 87), (214, 64, 159), (142, 78, 198)
GREEN, AMBER, RED, GREY, WHITE = (48, 164, 108), (255, 197, 61), (229, 72, 77), (128, 128, 140), (235, 235, 240)
SPIN = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
STEPS = [("build", "Building the app"), ("sign", "Checking the signature"), ("app", "Installing into ~/Applications"),
         ("agents", "Starting the app at login"), ("start", "Waiting for the app to answer")]

def fg(c): return f"\x1b[38;2;{c[0]};{c[1]};{c[2]}m"
def bg(c): return f"\x1b[48;2;{c[0]};{c[1]};{c[2]}m"
B, D, R = "\x1b[1m", "\x1b[2m", "\x1b[0m"
def link(url, text): return f"\x1b]8;;{url}\x1b\\{text}\x1b]8;;\x1b\\"
def w(s): OUT.write(s); OUT.flush()
def cols(): return shutil.get_terminal_size((80, 24)).columns


def mix(a, b, t): return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(text, stops=(ORANGE, PINK, VIOLET)):
    n = max(1, len(text) - 1); out = []
    for i, ch in enumerate(text):
        t = i / n * (len(stops) - 1); k = min(int(t), len(stops) - 2)
        out.append(fg(mix(stops[k], stops[k + 1], t - k)) + ch)
    return "".join(out) + R


def version():
    m = re.search(r"CFBundleShortVersionString</key><string>([^<]+)", open(os.path.join(ROOT, "build.sh")).read())
    return m.group(1) if m else "?"


def hands_off():
    return os.path.exists(os.path.expanduser("~/.agent-board/hands-off"))  # Agent Board's switch, if installed


def chime():
    if not hands_off():
        subprocess.Popen(["/usr/bin/afplay", "/System/Library/Sounds/Glass.aiff"], stderr=subprocess.DEVNULL)


# ── header ────────────────────────────────────────────────────────────────────

def lock_rows(lift, shine=None, flash=0.0):
    """The lock as text rows. lift: rows the shackle hangs above closed. shine: column of the sweeping highlight."""
    width = len(BODY[0]); h = LIFT + len(SHACKLE) + len(BODY)
    px = [[None] * width for _ in range(h)]
    top = LIFT - lift
    steel = lambda c: mix((150, 150, 165), (225, 225, 235), c / width)
    for r, row in enumerate(SHACKLE):
        for c, ch in enumerate(row):
            if ch == "X": px[top + r][c] = steel(c)
    for r in range(top + len(SHACKLE), LIFT + len(SHACKLE)):  # open: the left leg stays in the body, the right one is out
        for c, ch in enumerate(SHACKLE[-1][:width // 2]):
            if ch == "X": px[r][c] = steel(c)
    for r, row in enumerate(BODY):
        for c, ch in enumerate(row):
            if ch != "X":
                px[LIFT + len(SHACKLE) + r][c] = (40, 26, 46); continue
            t = c / (width - 1); col = mix(ORANGE, PINK, t * 2) if t < .5 else mix(PINK, VIOLET, (t - .5) * 2)
            if shine is not None and abs((c - r * 0.8) - shine) < 0.9: col = mix(col, (255, 255, 255), 0.7)
            px[LIFT + len(SHACKLE) + r][c] = mix(col, (255, 255, 255), flash)
    return ["".join((bg(p) + "  " + R) if p else "  " for p in row) for row in px]


def lock_film(text_for_row=lambda i, k: "", typing=0):
    """Plays the lock closing: shackle drops, a click flash, a highlight sweep. Text rides on the right."""
    frames = [(l, None, 0.0) for l in (LIFT, LIFT, LIFT, LIFT, 1, 0)] + [(0, None, f) for f in (0.6, 0.3, 0.1)]
    frames += [(0, s, 0.0) for s in range(-4, len(BODY[0]) + 6)] + [(0, None, 0.0)]
    drawn = 0; w("\x1b[?25l")
    for n, (lift, shine, flash) in enumerate(frames):
        k = min(typing, int(n * typing / max(1, len(frames) - 6))) if typing else 0
        rows = lock_rows(lift, shine, flash)
        if drawn: w(f"\x1b[{drawn}A")
        for i, r in enumerate(rows): w("\x1b[2K  " + r + "   " + text_for_row(i, k) + "\n")
        drawn = len(rows); time.sleep(0.07 if shine is None else 0.035)
    w("\x1b[?25h")


def header():
    w("\n")
    title = "Agents Mission Control"
    def text(i, k):
        if i == 7: return B + gradient(title[:k]) + R
        if i == 8 and k >= len(title): return f"{fg(GREY)}version {version()} · Full Disk Access for coding agents, approved with Touch ID{R}"
        if i == 9 and k >= len(title):
            return f"{fg(WHITE)}by {B}{AUTHOR}{R}{fg(GREY)} ({HANDLE}) · {R}{fg(ORANGE)}{link('https://' + SITE, SITE)}{R}"
        return ""
    lock_film(text, typing=len(title))
    w("\n")


# ── steps ─────────────────────────────────────────────────────────────────────

class Steps:
    def __init__(self):
        self.state = {k: "todo" for k, _ in STEPS}; self.times = {}; self.cur = None; self.t0 = time.time()
        self.progress = None; self.drawn = 0; self.lock = threading.Lock(); self.stop = False
        self.signer = self.team = ""

    def bar(self, frac, width=22):
        full = int(frac * width); part = " ▏▎▍▌▋▊▉"[int((frac * width - full) * 8)] if full < width else ""
        return fg(ORANGE) + "█" * full + part + R + fg(GREY) + "·" * (width - full - (1 if part else 0)) + R

    def render(self, tick=0):
        out = []
        for k, title in STEPS:
            s = self.state[k]
            if s == "done":
                out.append(f"  {fg(GREEN)}✓{R} {title}  {fg(GREY)}{self.times.get(k, 0):.1f}s{R}")
            elif s == "fail":
                out.append(f"  {fg(RED)}✗ {title}{R}")
            elif s == "run":
                el = time.time() - self.t0
                extra = f"  {self.bar(self.progress)}" if (k == "build" and self.progress is not None) else ""
                out.append(f"  {fg(ORANGE)}{SPIN[tick % len(SPIN)]}{R} {B}{title}{R}{extra}  {fg(GREY)}{el:.1f}s{R}")
            else:
                out.append(f"  {fg(GREY)}○ {title}{R}")
        with self.lock:
            if self.drawn: w(f"\x1b[{self.drawn}A")
            for line in out: w("\x1b[2K" + line + "\n")
            self.drawn = len(out)

    def spin(self):
        tick = 0
        while not self.stop:
            self.render(tick); tick += 1; time.sleep(0.08)

    def begin(self, key):
        if self.cur: self.finish(self.cur)
        self.cur, self.t0, self.progress = key, time.time(), None
        self.state[key] = "run"

    def finish(self, key, ok=True):
        self.state[key] = "done" if ok else "fail"; self.times[key] = time.time() - self.t0


def run_install(env):
    st = Steps(); log = open(LOG, "w")
    th = threading.Thread(target=st.spin, daemon=True); th.start()
    p = subprocess.Popen(["/bin/zsh", os.path.join(ROOT, "install.sh")], cwd=ROOT, env=env,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    for line in p.stdout:
        log.write(line)
        m = re.match(r"@@step (\w+) ?(.*)", line)
        if m and m.group(1) in dict(STEPS): st.begin(m.group(1)); continue
        if m and m.group(1) == "signer": st.signer = m.group(2).strip(); continue
        if m and m.group(1) == "team": st.team = m.group(2).strip(); continue
        m = re.search(r"\[(\d+)/(\d+)\]", line)
        if m and st.cur == "build": st.progress = int(m.group(1)) / int(m.group(2))
    code = p.wait(); log.close()
    if st.cur: st.finish(st.cur, ok=(code == 0))
    st.stop = True; th.join(); st.render()
    if code:
        w(f"\n  {fg(RED)}{B}The install stopped.{R} Last lines of {LOG}:\n\n")
        for l in open(LOG).read().splitlines()[-12:]: w(f"    {fg(GREY)}{l}{R}\n")
        w("\n"); sys.exit(code)
    return st


def signature_card(st):
    w("\n")
    if st.team == TEAM:
        w(f"  {fg(GREEN)}🔏 Signed by {AUTHOR} ({TEAM}){R}  {fg(GREY)}Developer ID, verified by macOS{R}\n")
    elif st.team and st.team != "not set":
        w(f"  {fg(AMBER)}🔏 Signed by {st.signer or st.team}{R}  {fg(GREY)}your own build, not one {AUTHOR} signed{R}\n")
    else:
        w(f"  {fg(AMBER)}🔏 Signed on this Mac only (ad hoc){R}  {fg(GREY)}macOS forgets the Full Disk Access grant at each rebuild{R}\n")


# ── Full Disk Access ──────────────────────────────────────────────────────────

def ask_app(req, sock):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(3); s.connect(sock)
        s.sendall(json.dumps(req).encode() + b"\n"); buf = b""
        while not buf.endswith(b"\n"):
            c = s.recv(65536)
            if not c: break
            buf += c
        return json.loads(buf or b"{}")
    except (OSError, ValueError):
        return {}


def mock_frame(appname, chip_pos, row_on, toggle):
    """A drawing of System Settings > Full Disk Access with the app chip on its way in."""
    W = 58
    def box(t): return f"  {fg(GREY)}│{R}" + t + " " * max(0, W - len(re.sub(r"\x1b\[[0-9;]*m", "", t))) + f"{fg(GREY)}│{R}"
    knob_off, knob_on = f"{fg(GREY)}( ○   ){R}", f"{bg(GREEN)}{fg(WHITE)}(   ● ){R}"
    knob = knob_on if toggle else knob_off
    lines = [f"  {fg(GREY)}╭─ System Settings ─{'─' * (W - 19)}╮{R}",
             box(f"  {fg(GREY)}‹ ›{R}  Privacy & Security › {B}Full Disk Access{R}"),
             box(""),
             box(f"  {fg(GREY)}Allow the applications below to access all files.{R}"),
             box(f"  ┌{'─' * 48}┐"),
             box(f"  │  ▣ Terminal{' ' * 27}{knob_off}  │")]
    if row_on:
        name = f"▣ {appname}"
        lines.append(box(f"  │  {fg(WHITE) if toggle else ''}{name}{R}{' ' * max(1, 37 - len(name))}{knob}  │"))
    else:
        lines.append(box(f"  │{' ' * 48}│"))
    lines += [box(f"  └{'─' * 48}┘"), box(f"  {fg(GREY)}[+] [−]{R}"), f"  {fg(GREY)}╰{'─' * W}╯{R}", ""]
    chip = f"{bg(ORANGE)}{fg(WHITE)} {appname}.app {R}"
    finder = f"  {fg(GREY)}Finder:{R}  " + (chip if chip_pos is None else f"{fg(GREY)}[{' ' * (len(appname) + 6)}]{R}")
    lines.append(finder)
    return lines, (chip, chip_pos)


def explain_fda(appname):
    w(f"\n  {B}{gradient('One step only you can do')}{R}\n\n")
    w(f"  Agents will ask this app to read files macOS protects (Mail, Messages, other apps' data).\n")
    w(f"  macOS lets only {B}you{R} allow that, in System Settings, and no app can ask for it with a prompt.\n")
    w(f"  Here is what you will do:\n\n")
    w(f"    {fg(ORANGE)}1{R}  Drag {B}{appname}.app{R} from the Finder window into the list\n")
    w(f"    {fg(ORANGE)}2{R}  Switch it {fg(GREEN)}on{R}  {fg(GREY)}(macOS may ask for your password and to reopen the app: say yes){R}\n\n")
    if cols() < 64: return
    # A short film of it: the chip flies from Finder into the list, then the switch turns on.
    w("\x1b[?25l"); drawn = 0
    path = [(11, 14), (10, 12), (9, 10), (8, 8), (7, 6), (6, 6)]
    for loop in range(2):
        frames = [(None, False, False)] * 6 + [(p, False, False) for p in path] + [(None, True, False)] * 6 + [(None, True, True)] * 10
        for chip, row, tog in frames:
            lines, (chip_txt, at) = mock_frame(appname, chip, row, tog)
            if drawn: w(f"\x1b[{drawn}A")
            for i, l in enumerate(lines):  # the chip in flight is drawn over its row, not in place of it
                w("\x1b[2K" + l + (f"\r\x1b[{at[1]}C{chip_txt}" if at and at[0] == i else "") + "\n")
            drawn = len(lines); time.sleep(0.12)
    w("\x1b[?25h")


def ask_yes(question):
    w(f"\n  {B}{question}{R} {fg(GREY)}[Y/n]{R} ")
    try:
        ans = input().strip().lower()
    except EOFError:
        ans = "n"
    return ans in ("", "y", "yes")


def wait_for_grant(sock):
    w(f"\n  {fg(GREY)}System Settings and Finder are open. This screen moves on by itself once it is on.{R}\n\n")
    hints = ["Drag the app from Finder into the list", "…then switch it on", "Asked to reopen the app? Choose Quit & Reopen",
             "Not in the list? Press + and pick it from ~/Applications"]
    t0, tick = time.time(), 0
    w("\x1b[?25l")
    try:
        while True:
            if ask_app({"op": "status"}, sock).get("fda") is True: break
            hint = hints[int((time.time() - t0) / 3.5) % len(hints)]
            w(f"\r\x1b[2K  {fg(ORANGE)}{SPIN[tick % len(SPIN)]}{R} Waiting for Full Disk Access  {fg(GREY)}{hint}{R}")
            tick += 1; time.sleep(0.1)
    finally:
        w("\x1b[?25h")
    w("\r\x1b[2K\n")
    done = f"{fg(GREEN)}{B}✓ Full Disk Access is on.{R}"
    lock_film(lambda i, k: done if i == 8 else (f"{fg(GREY)}Privileged sessions are ready.{R}" if i == 9 else ""))
    chime()


def full_disk_access(appname, sock):
    st = ask_app({"op": "status"}, sock)
    if st.get("fda") is True:
        w(f"\n  {fg(GREEN)}✓ Full Disk Access is on{R}\n"); return True
    explain_fda(appname)
    if ask_yes("Open System Settings and Finder now?"):
        ask_app({"op": "grant"}, sock); chime(); wait_for_grant(sock); return True
    w(f"\n  {fg(AMBER)}Not now: fine.{R} Nothing else changes on this Mac.\n")
    w(f"  Agents cannot use privileged sessions without it, so Claude Code asks again the first time an agent needs it,\n")
    w(f"  and opens the same two windows for you. Running ./install.sh again does too.\n")
    return False


# ── end ───────────────────────────────────────────────────────────────────────

def finale(appname):
    line = "/plugin install amc --marketplace tomacco/agents-mission-control"
    subprocess.run(["/usr/bin/pbcopy"], input=line, text=True)
    w(f"\n  {B}{gradient('Installed.')}{R} It runs in the background, with nothing in the menu bar.\n\n")
    w(f"  {B}Next{R}, in Claude Code {fg(GREY)}(on your clipboard){R}:\n")
    w(f"    {fg(ORANGE)}{line}{R}\n\n")
    w(f"  {fg(GREY)}Remove it any time: ./uninstall.sh   ·   Log: {LOG}{R}\n")
    w(f"\n  {fg(GREY)}Made by{R} {B}{AUTHOR}{R} {fg(GREY)}({HANDLE}) ·{R} {fg(ORANGE)}{link('https://' + SITE, SITE)}{R}\n\n")


def main():
    signal.signal(signal.SIGINT, lambda *_: (w("\x1b[?25h\n"), sys.exit(130)))
    env = dict(os.environ, AMC_UI="1")
    ch = os.environ.get("AMC_CHANNEL", "")
    appname = "AgentsMissionControl" + (f"-{ch}" if ch else "")
    sock = os.path.expanduser(f"~/.amc{'-' + ch if ch else ''}/amc.sock")
    header()
    st = run_install(env)
    signature_card(st)
    full_disk_access(appname, sock)
    finale(appname)


if __name__ == "__main__":
    main()
