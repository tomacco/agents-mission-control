# Roadmap

## Phase 1 (done 2026-10-07)
Menu bar panel with hands off, caffeinate and localhost tiles; enforcer and Claude Code hook; tests.

## Phase 2: native Control Center controls
Add the same switches to Control Center through "Edit Controls", with a WidgetKit `ControlWidget` extension
(`ControlWidgetToggle` for hands off and caffeinate). A control writes the same flag, so the enforcer does not change.

What it needs:
- An Xcode project (a widget extension cannot be built from a plain Swift package).
- The flag in a location the sandboxed extension can write: an App Group container, with `helmd`, the hook and `helmctl` reading it there.
- Signing with an Apple Development identity. An ad-hoc signed extension is not offered in Control Center.

## Phase 1.5: block synthetic input at the source
A `CGEventTap` in Helm that drops mouse and keyboard events posted by other processes while hands off is on,
so a driver under any name is stopped. Needs the Accessibility grant for Helm.
