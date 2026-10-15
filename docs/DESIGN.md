# Design system

Agents Mission Control lives in a terminal: the installer and the Claude Code pane. This page sets how both look, so every screen reads as one product. Values live in `design/tokens.json`; `python3 tools/specimen.py` prints the whole system in a terminal, which is the only place to judge it.

## Principles

1. **Forms are made of dots.** Icons are line art in Braille (2×4 dots per cell): an outline, an engraved texture, depth from dot density. This is the language of the orb. Solid block fills look dated and are not used for icons.
2. **One identity gradient.** Aurora runs from `#D97757` through `#D6409F` to `#8E4EC6`. It marks identity only: the wordmark, titles, the lock, celebrations. A screen has one Aurora title.
3. **Color is earned.** Text is neutral by default. A state color appears only when it means that state.
4. **Motion means something.** Nothing moves while idle. Each animation stands for one situation.
5. **The author signs the work.** The installer and the README name Ivan Gonzalez (tomacco) · tomac.co.

## Color

| Role | Values | Use |
|---|---|---|
| Aurora | `#D97757` `#D6409F` `#8E4EC6` | identity: wordmark, titles, lock body, celebration |
| Session accent | Aurora sampled at 8 points | one per Claude Code session, chosen from its id |
| Neutral | 100 `#EDEDF2`, 70 `#AEB4C6`, 50 `#7C8296`, 30 `#4A4F60`, 10 `#2E3140`, 0 `#1E1A26` | body text, meta, rules, surfaces |
| ok | `#4CC38A` | done, access open |
| busy | `#E8B04A` | running |
| bad | `#F06A6A` | failed |
| touch | `#FF2D55` | waiting for Touch ID |
| info | `#4FB3E8` | a neutral notice |

Session accents come from Aurora so two sessions differ while the product stays one family.

## Type

Five roles. **Title**: bold, Aurora, one per screen. **Label**: letter-spaced capitals, bold, neutral 50. **Body**: neutral 100. **Command**: an Aurora `❯` prompt, then plain text. **Meta**: neutral 50 (times, counts). Big type is pixel letters made of background-colored cells, kept for moments: YOUR TURN, ALL SET!

## Glyphs

`✓` done · `✗` failed · `◐◓◑◒` running · `●` access open · `○` no access · `◉` waiting for Touch ID · `▸` a protected path · `❯` a command · `│` output · `─` a divider. A glyph never takes a second meaning.

## Icons

The lock is the product's mark: a steel shackle, an Aurora body with an engraved texture, a bright keyhole. Its shackle slides up when access opens. The orb from [thinking-orbs](https://libraries.dev/orbs) (Jakub Antalik, MIT) is the motion icon.

## Components

Badges are short capitals on a filled background: ACCESS OPEN (ok), NO ACCESS (neutral 10), TOUCH ID (touch). Run cards have a rounded border in the state color, the time on the right, the command after `❯`, and output under a `│` gutter.

## Motion

| Animation | Means |
|---|---|
| orb, breathing | waiting for you (Touch ID) |
| orb, working | a command runs |
| orb, searching | waiting for the Full Disk Access switch |
| shackle slides up | access just opened |
| pulse ×3 and a chime | your action is needed |
| confetti and a wipe | done; celebrate once |

Frame animations run at 10 fps. Sounds play only when Agent Board's hands off is off.

## Rendering rules

- Never draw icons with half-block glyphs (`▀ ▄`): Terminal.app leaves a seam on every row. Use Braille dots, or background-colored cells for big type.
- Read a pane's size and placement from `e.props`. An invalid color makes Claude Code refuse the whole pane.
