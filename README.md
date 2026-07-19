# Switch — window-level Cmd+Tab for macOS

A lightweight menu-bar app that replaces the default (app-level) Cmd+Tab with a
**per-window** switcher.

## Behavior

- **Cmd+Tab** — open the switcher / advance to the next window
- **Cmd+Shift+Tab** — go backwards
- **Release Cmd** — bring the highlighted window to the front (and activate its app)
- **Escape** — cancel without switching
- Windows are ordered **most-recently-used**, so selection starts on the previous
  window — tap Cmd+Tab once to toggle between your two latest windows
- Icon + "App — Window title" list; needs only Accessibility permission (no screen
  recording, low resource use)

## Build

Requires the Swift toolchain (Command Line Tools is enough — full Xcode not needed).

```sh
./build.sh              # build only → build/Switch.app
./build.sh --install    # build, then install to /Applications
open build/Switch.app
```

`build.sh` compiles with SwiftPM, assembles `build/Switch.app`, and ad-hoc signs it
so the Accessibility grant survives rebuilds. With `--install` it also quits any
running instance and copies the bundle to `/Applications` (preferred before enabling
launch-at-login).

## First run

1. `open build/Switch.app` — a `⇥` icon appears in the menu bar.
2. macOS prompts for **Accessibility** permission. Grant it in
   **System Settings → Privacy & Security → Accessibility** (toggle *Switch* on).
   The app polls and starts intercepting Cmd+Tab automatically once granted.
3. Quit anytime from the menu-bar `⇥` menu.

## Launch at login

Toggle **Launch at Login** from the menu-bar `⇥` menu. It registers the `.app`
bundle via `SMAppService`, so move `Switch.app` to its final location (e.g.
`/Applications`) *before* enabling — the login item points at the current path.
It appears under **System Settings → General → Login Items**.

## Not yet implemented (planned)

- Preferences UI
- Optional window thumbnails
