#!/usr/bin/env python3
"""The installer people see: runs install.sh (AMC_UI=1) and draws its steps, then guides the one step macOS
leaves to the person, Full Disk Access, before opening any window. Standard library only."""
import json, os, re, shutil, signal, socket, subprocess, sys, threading, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTHOR, HANDLE, SITE, TEAM = "Ivan Gonzalez", "tomacco", "tomac.co", "Y4UQ4S5ANQ"
LOG = os.path.expanduser("~/Library/Logs/amc-install.log")
OUT = sys.stdout

CLAWD = ["..XXXXXXXX..", "..X.XXXX.X..", "XXX.XXXX.XXX", "XXXXXXXXXXXX",
         "..XXXXXXXX..", "..XXXXXXXX..", "..X.X..X.X..", "..X.X..X.X.."]
ORANGE, PINK, VIOLET = (217, 119, 87), (214, 64, 159), (142, 78, 198)
GREEN, AMBER, RED, GREY, WHITE = (48, 164, 108), (255, 197, 61), (229, 72, 77), (128, 128, 140), (235, 235, 240)
SPIN = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
STEPS = [("build", "Building the app"), ("sign", "Checking the signature"), ("app", "Installing into ~/Applications"),
         ("agents", "Starting the background services"), ("hook", "Connecting Claude Code"),
         ("start", "Waiting for the app to answer")]


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
    home = os.environ.get("AMC_FLAG") or os.path.expanduser("~/.amc/hands-off")
    return os.path.exists(home)


def chime():
    if not hands_off():
        subprocess.Popen(["/usr/bin/afplay", "/System/Library/Sounds/Glass.aiff"], stderr=subprocess.DEVNULL)


# ── header ────────────────────────────────────────────────────────────────────

def clawd_rows(color):
    rows = []
    for top, bot in zip(CLAWD[0::2], CLAWD[1::2]):
        line = ""
        for a, b in zip(top, bot):
            ch = {("X", "X"): "█", ("X", "."): "▀", (".", "X"): "▄"}.get((a, b), " ")
            line += ch * 2
        rows.append(fg(color) + line + R)
    return rows


def header():
    w("\n")
    rows = clawd_rows(ORANGE)
    title = f"Agents Mission Control"
    lines = [title, f"version {version()} · macOS menu bar app for local coding agents",
             f"by {AUTHOR} ({HANDLE}) · {SITE}", ""]
    for i, r in enumerate(rows):  # Clawd rises row by row
        w("  " + r + "\n"); time.sleep(0.06)
    w(f"\x1b[{len(rows)}A")
    for i, r in enumerate(rows):
        text = ""
        if i == 0:
            for k in range(1, len(title) + 1):  # title types itself in
                w(f"\r  {r}   {B}{gradient(title[:k])}{R}"); time.sleep(0.018)
            w("\n"); continue
        if i == 1: text = f"{fg(GREY)}{lines[1]}{R}"
        if i == 2: text = f"{fg(WHITE)}by {B}{AUTHOR}{R}{fg(GREY)} ({HANDLE}) · {R}{fg(ORANGE)}{link('https://' + SITE, SITE)}{R}"
        w(f"\r  {r}   {text}\n"); time.sleep(0.05)
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
    for k in range(6):  # a small burst
        w(f"\r\x1b[2K  {fg(mix(ORANGE, GREEN, k / 5))}{'✦ ' * (k + 1)}{R}"); time.sleep(0.06)
    w(f"\r\x1b[2K  {fg(GREEN)}{B}✓ Full Disk Access is on.{R} Privileged sessions are ready.\n")
    chime()


def full_disk_access(appname, sock):
    st = ask_app({"op": "status"}, sock)
    if st.get("fda") is True:
        w(f"\n  {fg(GREEN)}✓ Full Disk Access is on{R}\n"); return True
    explain_fda(appname)
    if ask_yes("Open System Settings and Finder now?"):
        ask_app({"op": "grant"}, sock); chime(); wait_for_grant(sock); return True
    w(f"\n  {fg(AMBER)}Not now: fine.{R} Hands off, caffeinate and the localhost list work without it.\n")
    w(f"  Privileged sessions need it, so you will be asked again: by the {B}menu bar panel{R} (Grant Full Disk Access)\n")
    w(f"  and by Claude Code the first time an agent needs it. Both open the same two windows for you.\n")
    return False


# ── end ───────────────────────────────────────────────────────────────────────

def finale(appname):
    line = "/plugin install amc --marketplace tomacco/agents-mission-control"
    subprocess.run(["/usr/bin/pbcopy"], input=line, text=True)
    w(f"\n  {B}{gradient('Installed.')}{R} Look for Clawd in your menu bar.\n\n")
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
