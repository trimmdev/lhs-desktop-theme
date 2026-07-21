# Liberty Hill Studios — macOS screen saver

Runs the studio's living dusk scene as the macOS **screen saver**, so an idle or locked Mac
shows the animated Hill Country dusk with its real sun and its real moon.

It is the same scene as the wallpaper, because it is the same file:
[`../../wallpaper/lhs-dusk.html`](../../wallpaper/lhs-dusk.html). One self-contained HTML
page — the wordmark font embedded as base64, everything drawn on a canvas, **zero network
calls**. There is no macOS copy of it and no screen-saver copy of it, so the platforms
cannot drift apart. The installer copies that one file into place; it never forks it.

macOS has no public API for a web-backed screen saver, so this leans on
**[WebViewScreenSaver](https://github.com/liquidx/webviewscreensaver)** (Apache-2.0,
v2.5, released 2025-11-15) — a `.saver` plugin that hosts a `WKWebView` and loads a URL.
It handles `file://` URLs properly (`loadFileURL:allowingReadAccessToURL:`), which is the
reason it is the one chosen here.

Everything is user-level. **No sudo.** Two paths are written and the same two are removed
on `--revert`.

---

## Read this first — this port was authored without a Mac

Nobody on this project owns a Mac. The scene itself is certain: it is a self-contained web
page with zero network calls, and if a WebKit view renders it, it is correct. Everything
around it — the plugin, the plist seeding, the click-paths — was written against Apple
documentation and upstream source and has **never been run on real hardware**. It is built
to fail safe and fail loud rather than to be clever.

So preview it first:

```bash
./install-screensaver.sh --dry-run
```

That prints every command it would run and changes nothing. Read it, then decide.

---

## Install, and uninstall

```bash
cd macos/screensaver
./install-screensaver.sh
```

If that reports `Permission denied`, the executable bit did not survive the trip from
the Windows side of this repo. Either `chmod +x install-screensaver.sh`, or just run
`bash install-screensaver.sh` — it works the same.

That does four things:

1. Copies the scene to `/Users/Shared/LibertyHillDusk/index.html`.
2. Installs WebViewScreenSaver into `~/Library/Screen Savers/` — via Homebrew if you have
   it (it asks first), otherwise it prints the manual download steps. **It will never
   install Homebrew for you.**
3. Writes the scene URL into the saver bundle's `Info.plist` and re-signs the bundle.
4. Restarts `legacyScreenSaver` so the change is picked up. No logout needed.

Then **[two manual steps](#the-part-nobody-can-script-for-you)** that Apple made
unscriptable. They take about twenty seconds.

**Uninstall — kept right here, next to the install, because it is the honest counterweight
to the risks further down:**

```bash
./install-screensaver.sh --revert          # add --dry-run to preview it
brew uninstall --cask webviewscreensaver   # only if you installed it that way
```

`--revert` removes exactly two paths — `~/Library/Screen Savers/WebViewScreenSaver.saver`
and `/Users/Shared/LibertyHillDusk` — then restarts the host. Nothing else was ever
written, so nothing else needs undoing. If the removed saver was your selected one, macOS
falls back on its own.

**Flags:** `--dry-run` / `-n` (print everything, change nothing), `--revert`, `--yes` /
`-y` (skip the Homebrew prompt), `--help`.

---

## The part nobody can script for you

**Selecting a screen saver cannot be scripted on macOS 14 or newer.** The old
`defaults -currentHost write com.apple.screensaver moduleDict` has been inert since Sonoma
— Apple DTS has confirmed it — and the setting moved into a base64 binary plist nested
inside `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`. That format
is undocumented, and this repo does not write undocumented formats. So you click it.

**Step 1 — pick the saver.** Find your row and ignore the others; the installer prints only
the one that matches your Mac.

| Your macOS | Where it is |
|---|---|
| 13 Ventura | System Settings ▸ Screen Saver ▸ **WebViewScreenSaver** (bottom of the list, under Apple's) ▸ Options |
| 14 Sonoma / 15 Sequoia | System Settings ▸ Screen Saver ▸ **Other** ▸ WebViewScreenSaver ▸ Options |
| 26 Tahoe | System Settings ▸ **Wallpaper** ▸ Screen Saver ▸ **Custom** ▸ Other ▸ WebViewScreenSaver ▸ Options — macOS 26 removed the standalone Screen Saver pane |

**Step 2 — in that Options sheet, set Duration to `-1`.**

The URL is already filled in. Duration is the one field the installer cannot pre-set, and
leaving it alone is a visibly worse experience — see below.

---

## Two settings that look like clutter and are not

Both of these get "cleaned up" by well-meaning people. Neither is optional.

### `?nosleep=1` — without it the scene silently freezes

The full URL is:

```
file:///Users/Shared/LibertyHillDusk/index.html?nosleep=1
```

The screen-saver host reports its own web view as `document.hidden`. The page's normal
behaviour is to **stop rendering while hidden** — a deliberate CPU saving that is exactly
right for a wallpaper sitting behind your windows, and exactly wrong here. Drop the flag
and the saver shows a **still frame**: no error, no log line, nothing that distinguishes it
from a working install except that the sun never moves. This was verified empirically. The
page implements the flag deliberately; see the comment above `const NOSLEEP` in
[`lhs-dusk.html`](../../wallpaper/lhs-dusk.html).

### `Duration = -1` — without it the scene restarts every five minutes

WebViewScreenSaver reloads its URL on a timer unless the duration is **negative**. Its
source is explicit: `if (address.duration < 0) return; // Infinite`. The default is **300
seconds**, so out of the box you get a flash and a scene that jumps back to the beginning
every five minutes.

The installer seeds the URL through the bundle's `Info.plist` key
`WVSSDefaultAddressURL`, which is read at runtime. That route is reliable and inspectable,
but it carries no duration — it inherits the 300-second default. The other route, the
container preferences (`net.liquidx.WebViewScreenSaver`, array `kScreenSaverURLList`, keys
`kScreenSaverURL` / `kScreenSaverTime`), *can* carry `-1`, but since macOS 10.15 it lives
inside the sandboxed host's container and upstream's own README lists **four** candidate
paths depending on OS and architecture. Guessing which of four undocumented paths applies
to your Mac is not something this repo will do behind your back. Hence: automatic URL,
manual duration.

### Why `/Users/Shared` and not `~/Pictures`

The desktop wallpaper installs to `~/Pictures/Liberty Hill Studios/`. The screen saver
deliberately does **not** reuse that path.

- `~/Documents`, `~/Desktop` and `~/Downloads` are **TCC-protected**. The sandboxed
  screen-saver host cannot read out of them, and the failure mode is a black screen with no
  error.
- `/Users/Shared` exists on every Mac, is world-writable, and needs no sudo.
- The path is **space-free on purpose**, which sidesteps every percent-encoding bug a
  `file://` URL can have.

---

## Gatekeeper

WebViewScreenSaver is **ad-hoc signed** — not Developer ID, not notarised. macOS will stop
it the first time unless the quarantine flag is off.

The installer passes `--no-quarantine` to the Homebrew cask, which avoids the whole thing.
The manual route it prints includes the equivalent
`xattr -d com.apple.quarantine WebViewScreenSaver.saver`.

If you hit the prompt anyway — you installed it yourself, or the flag survived:

1. Open **System Settings ▸ Privacy & Security**.
2. **Scroll to the bottom** of that pane. The notice about the blocked item is easy to miss.
3. Click **Open Anyway**.
4. Authenticate with Touch ID or your password.

**On macOS 15 and newer that pane is the only route.** Apple removed the old
Control-click ▸ Open bypass. The installer detects a quarantined bundle and tells you,
but it will not strip the flag for you — taking Gatekeeper off a downloaded bundle is a
decision to make knowingly, not a side effect of a theme installer.

Editing `Info.plist` invalidates the bundle's signature, so the installer re-signs it
(`codesign --force --deep --sign - --timestamp=none`) and verifies the result. If signing
is unavailable or fails, it **puts the original `Info.plist` back** — restoring the exact
original bytes restores the original hash, so the original signature becomes valid again —
and tells you to paste the URL into Options by hand. It never leaves you with an edited,
unsigned bundle that will not load.

---

## Risks, stated plainly

This is the honest part. None of it is hidden, and all of it is undone by one command.

- **Apple has left the legacy `.saver` plugin system unmaintained.** An Apple engineer has
  stated publicly that a modern replacement API "will not happen in macOS 26." Everything
  here rests on an interface Apple is no longer investing in.
- **There is an open, unanswered upstream issue ([#97]) reporting a black screen on macOS
  26.3 and newer**, with several reporters. Whether v2.5 fixes it is **unconfirmed**. If
  you are on 26.3+, treat this as something that may simply not work yet.
- **Open Apple bugs affect all third-party savers**, including one where WKWebView-based
  savers fail on **secondary monitors**. Not fixable from this side.
- The saving grace is that **undo is trivial and safe**: `--revert`, and your Mac is
  exactly as it was.

[#97]: https://github.com/liquidx/webviewscreensaver/issues/97

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| **Black screen** | Either the scene file is somewhere the sandboxed host cannot read (a TCC-protected folder like `~/Documents`), or the bundle is quarantined / its signature is invalid, or you are hitting upstream issue [#97] on macOS 26.3+. | Confirm the URL points at `/Users/Shared/LibertyHillDusk/index.html` — never a path under Documents, Desktop or Downloads. Check the file is really there and readable. Clear quarantine (`xattr -dr com.apple.quarantine ~/Library/Screen\ Savers/WebViewScreenSaver.saver`) or approve it in Privacy & Security. Re-run the installer to re-seed and re-sign. If all that is clean and it is still black on 26.3+, it is likely #97 and out of our hands. |
| **It shows a frozen still frame** | `?nosleep=1` is missing from the URL. The host reports the page as hidden and the page pauses rendering when hidden. | Put it back. The URL must be `file:///Users/Shared/LibertyHillDusk/index.html?nosleep=1` exactly. Re-running `./install-screensaver.sh` restores it. |
| **Only works on one monitor** | Known Apple bug affecting WKWebView-based screen savers on secondary displays. | No workaround from this side. Not caused by this installer, and not fixable in it. |
| **The Options button does nothing** | Known macOS bug in System Settings. | Quit System Settings **completely** (Cmd-Q — closing the window is not enough) and reopen it. There is no workaround in code. |
| **It flashes and restarts every 5 minutes** | Duration is `0` or higher, so the saver reloads the URL on a timer. 300 seconds is the default. | Set **Duration** to `-1` in the saver's Options sheet. Negative means infinite. |
| **The saver does not appear in the list at all** | The bundle is not in `~/Library/Screen Savers/`, or the host is still holding a cached list. | `ls ~/Library/Screen\ Savers/` to confirm `WebViewScreenSaver.saver` is there, then `killall legacyScreenSaver`. |
| **Two WebViewScreenSaver entries in the list** | A second copy exists in the system-wide `/Library/Screen Savers/`. | The installer only manages the per-user one (removing the other needs sudo). Delete the system copy yourself if you want it gone. |

### Is it rendering at all?

Temporarily append `&at=2026-07-21T20:30` to the URL:

```
file:///Users/Shared/LibertyHillDusk/index.html?nosleep=1&at=2026-07-21T20:30
```

`?at=` forces the scene to a specific moment, so that should show a **dusk** sky regardless
of the real hour. If you get dusk, the page is loading and rendering correctly and any
remaining problem is elsewhere. Remove the parameter afterwards — with it in place the
scene is pinned to that evening instead of following the real clock.

---

## What gets written

| Path | What |
|---|---|
| `/Users/Shared/LibertyHillDusk/index.html` | The scene, ~92 KB, copied verbatim from `wallpaper/lhs-dusk.html` |
| `~/Library/Screen Savers/WebViewScreenSaver.saver` | The plugin (per-user — this is why no sudo is needed) |
| `…/WebViewScreenSaver.saver/Contents/Info.plist.lhs-backup` | The pristine plist, kept once, so a failed re-sign is recoverable |

Nothing else, ever.
