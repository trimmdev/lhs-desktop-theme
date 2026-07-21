# Liberty Hill Dusk — terminal colour schemes (macOS)

The macOS port of the Windows Terminal scheme in
[`../../terminal/liberty-hill-dusk.json`](../../terminal/liberty-hill-dusk.json).
**The palette is byte-identical to the Windows side** — no colour was
re-derived, re-toned or invented for macOS.

Nothing in this folder needs `sudo`, downloads anything, or runs a background
process. Five of the six files are plain text you copy into place. The sixth
(Apple's Terminal.app) needs a generator, because that format stores colours as
binary `NSKeyedArchiver` blobs — see [Terminal.app](#6-apples-terminalapp) below.

---

## The palette

| Role | Hex | Token |
|---|---|---|
| background | `#0A0807` | ink-950 |
| foreground | `#F5ECD9` | parchment |
| cursor | `#E8A13A` | gold-400 |
| selection background | `#4D2C14` | — |
| link / bright yellow | `#ECBE5B` | gold-300 |
| split / rule | `#B3661F` | gold-600 |
| badge / bell | `#D4542B` | ember-400 |
| bright red | `#E57A53` | ember-300 |

| # | ANSI | Hex | | # | ANSI | Hex |
|---|---|---|---|---|---|---|
| 0 | black | `#1B1612` | | 8 | brightBlack | `#6F6557` |
| 1 | red | `#E0604F` | | 9 | brightRed | `#E57A53` |
| 2 | green | `#5FB87A` | | 10 | brightGreen | `#83C99B` |
| 3 | yellow | `#E8A13A` | | 11 | brightYellow | `#ECBE5B` |
| 4 | blue | `#5AA8E0` | | 12 | brightBlue | `#7DBDE8` |
| 5 | purple / magenta | `#A878D8` | | 13 | brightPurple | `#C09BE8` |
| 6 | cyan | `#7FBFB4` | | 14 | brightCyan | `#9AD1C7` |
| 7 | white | `#CDBFA6` | | 15 | brightWhite | `#FDF6E8` |

> **Design law.** Gold and ember are **accents**, never surfaces. In these files
> they appear only on the cursor, the selection fill, links, thin window/split
> borders and the active-tab *text*. Every large surface is ink-950. Nothing
> reskins a standard affordance into something unrecognisable.

---

## Files

| File | Emulator | Colour fidelity |
|---|---|---|
| `liberty-hill-dusk.itermcolors` | iTerm2 | exact (sRGB) |
| `liberty-hill-dusk.alacritty.toml` | Alacritty 0.13+ | exact |
| `liberty-hill-dusk.kitty.conf` | kitty | exact |
| `liberty-hill-dusk.wezterm.lua` | WezTerm | exact |
| `liberty-hill-dusk.ghostty` | Ghostty | exact |
| `make-terminal-app-profile.sh` | Apple Terminal.app | approximate — [see below](#colour-fidelity-caveat) |

Assume `$LHS` is this folder:

```sh
LHS="$(cd "$(dirname "$0")" && pwd)"   # or just: cd path/to/repo/macos/terminal
```

---

## 1. iTerm2

```sh
mkdir -p ~/Library/Application\ Support/iTerm2
cp "$LHS/liberty-hill-dusk.itermcolors" "$HOME/Downloads/Liberty Hill Dusk.itermcolors"
open "$HOME/Downloads/Liberty Hill Dusk.itermcolors"
```

Then: **iTerm2 → Settings → Profiles → Colors → Color Presets… → Liberty Hill Dusk**.

> **Why the copy-and-rename.** iTerm2 takes the preset name from the **filename**,
> not from anything inside the file — the `.itermcolors` format has no name
> field. Importing `liberty-hill-dusk.itermcolors` as-is gives you a preset
> called `liberty-hill-dusk`. Copying it to `Liberty Hill Dusk.itermcolors`
> first is the only way to get the proper name in the menu. If you don't care,
> just `open "$LHS/liberty-hill-dusk.itermcolors"` directly.

Prefer no download folder? Double-clicking the file in Finder does the same import.

**Two things in that file you must not "tidy up":**

- The keys use **American** spelling — `Ansi 0 Color`, `Background Color`.
  A file written with `Colour` is still valid XML and iTerm2 imports it as an
  **empty preset with no error message**.
- Every colour dict carries `Color Space = sRGB`. Drop that key and iTerm2
  falls back to Generic/Calibrated RGB, so `#E8A13A` renders as a visibly
  different orange — while still appearing to "work".

`Tab Color` is deliberately absent: it is only honoured when the profile has
*use tab color* enabled, and it would paint a large gold surface.

**Never** hand-edit `~/Library/Preferences/com.googlecode.iterm2.plist`. iTerm2
caches its preferences in memory and rewrites that file on quit, discarding
your edit.

---

## 2. Alacritty

```sh
mkdir -p ~/.config/alacritty/themes
cp "$LHS/liberty-hill-dusk.alacritty.toml" ~/.config/alacritty/themes/
```

Then add to `~/.config/alacritty/alacritty.toml`:

```toml
[general]
import = ["~/.config/alacritty/themes/liberty-hill-dusk.alacritty.toml"]
```

> **Check your version first:** `alacritty --version`.
> Alacritty switched from YAML (`alacritty.yml`) to TOML at **0.13**. On an
> older build this file is **ignored silently** — no error, no colours, and
> nothing to indicate why. Upgrade, or convert the file to YAML by hand.

Config search order on macOS (first hit wins):
`$XDG_CONFIG_HOME/alacritty/alacritty.toml` → `$XDG_CONFIG_HOME/alacritty.toml`
→ `~/.config/alacritty/alacritty.toml` → `~/.alacritty.toml` →
`/etc/alacritty/alacritty.toml`.

Note the key is `magenta`, not `purple` — Alacritty uses the ANSI name.
`[colors.dim]` is deliberately omitted; Alacritty derives dim from normal, and
inventing six colours the studio palette does not define would be a fake.

**Uninstall:** delete the `import` line and the theme file.

---

## 3. kitty

```sh
mkdir -p ~/.config/kitty
cp "$LHS/liberty-hill-dusk.kitty.conf" ~/.config/kitty/
```

Then append **one line** to `~/.config/kitty/kitty.conf`:

```conf
include liberty-hill-dusk.kitty.conf
```

Relative includes resolve against the directory of the including file, so the
bare filename is correct. Reload with `ctrl+cmd+,` — no restart needed.

**Uninstall:** delete that one line, and the file.

---

## 4. WezTerm

```sh
mkdir -p ~/.config/wezterm/colors
cp "$LHS/liberty-hill-dusk.wezterm.lua" ~/.config/wezterm/colors/
```

Then in `~/.config/wezterm/wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config  = wezterm.config_builder()

local lhs = dofile(wezterm.config_dir .. '/colors/liberty-hill-dusk.wezterm.lua')
lhs.apply(config)

return config
```

Already define your own schemes? Pass them through so they survive:

```lua
lhs.apply(config, { ['My Other Scheme'] = { --[[ ... ]] } })
```

Or wire it up by hand:

```lua
config.color_schemes = { [lhs.name] = lhs.scheme }
config.color_scheme  = lhs.name
```

> **Why a `.lua` module rather than `colors/*.toml`.** WezTerm derives a TOML
> scheme's *name* from its *filename*, so the TOML form would have to be named
> exactly `Liberty Hill Dusk.toml` — spaces and all — or
> `config.color_scheme = 'Liberty Hill Dusk'` silently fails to resolve. A Lua
> module carries its own name, survives any rename, and Lua-defined schemes take
> precedence over every other source.
>
> Use `dofile`, not `require`: the filename contains dots, which Lua's module
> resolver reads as directory separators.

**Uninstall:** remove the three lines and the file.

---

## 5. Ghostty

```sh
mkdir -p ~/.config/ghostty/themes
cp "$LHS/liberty-hill-dusk.ghostty" ~/.config/ghostty/themes/liberty-hill-dusk
```

Then add **one line** to whichever config file you actually have — check all
three, Ghostty reads the config from any of them:

- `~/Library/Application Support/com.mitchellh.ghostty/config`
- `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`
- `~/.config/ghostty/config`

```conf
theme = /Users/YOURNAME/.config/ghostty/themes/liberty-hill-dusk
```

> **Path gotcha — this one bites.** On macOS, Ghostty reads user **themes** only
> from `~/.config/ghostty/themes/`, *not* from
> `~/Library/Application Support/com.mitchellh.ghostty/themes/` (the **config**
> file is read from both; themes are XDG-only). Giving `theme` an **absolute
> path** bypasses theme discovery entirely, which is why the line above spells
> out `/Users/YOURNAME/...`. `theme` does **not** expand `~`.

Equally valid and equally reversible — keep the extension and include the file
directly instead of registering it as a theme:

```conf
config-file = /Users/YOURNAME/.config/ghostty/themes/liberty-hill-dusk.ghostty
```

Reload live with `cmd+shift+,`. List what Ghostty can see: `ghostty +list-themes`.

**Uninstall:** delete that one line, and the file.

---

## 6. Apple's Terminal.app

Terminal.app is the only emulator here that cannot ship as a committed text
file: each colour in a `.terminal` profile is an `NSKeyedArchiver`-encoded
`NSColor` stored as a base64 `<data>` blob. So this one is generated **on the
Mac**:

```sh
chmod +x "$LHS/make-terminal-app-profile.sh"
"$LHS/make-terminal-app-profile.sh"
```

It writes:

```
~/Library/Application Support/Liberty Hill Studios/terminal/Liberty Hill Dusk.terminal
```

(That location is deliberate — it is **not** TCC-protected, unlike `~/Desktop`,
`~/Documents` and `~/Downloads`. Override with `--out PATH`.)

Then import it and make it default:

```sh
open ~/Library/Application\ Support/Liberty\ Hill\ Studios/terminal/Liberty\ Hill\ Dusk.terminal
```

**Terminal → Settings… → Profiles →** select **Liberty Hill Dusk** → click
**Default** at the bottom of the list. That one button sets both the *default*
profile (every new window) and the *startup* profile (the first window at
launch). Setting only one of the two gives a half-themed result that looks like
a bug.

Prefer it done for you? `--set-default` does the import and sets both:

```sh
"$LHS/make-terminal-app-profile.sh" --set-default
```

That flag is opt-in because it sends an Apple event, so macOS shows a one-time
*"Terminal wants to control Terminal"* prompt. Your previous profile name is
saved to `previous-terminal-profile.txt` next to the generated file first, so
you can always put it back. Declining the prompt breaks nothing — set the
profile by hand instead.

### How the generator works, and how it fails

Two independent toolchains, tried in order:

1. **`/usr/bin/osascript` + AppleScript-ObjC.** Present on every macOS. No
   Xcode, no Homebrew, no Python. It uses the *real* `NSKeyedArchiver`, so the
   blobs are exactly what Terminal.app itself would write.
2. **`python3` + the stdlib `plistlib` module.** Hand-builds the same archive.
   Note: **not PyObjC** — Apple's `python3` does *not* ship PyObjC, so any
   generator that does `import Foundation` fails on a stock Mac. The script also
   refuses to invoke `/usr/bin/python3` unless `xcode-select -p` proves Command
   Line Tools are installed, because without them that binary is a stub that
   pops a GUI installer dialog and blocks forever.

If both fail it writes **nothing** and prints why, along with what to install.

Before installing anything, the script reads the file it just generated back
off disk, **unarchives all 21 colours and compares them to the palette**. If a
single colour is wrong, or the plist is malformed, or the profile name is wrong,
it deletes the temp file and refuses. It also backs up any file it would
overwrite to `<file>.lhs-backup-<timestamp>`.

It never runs `defaults write com.apple.Terminal …`. Terminal is running while
you use it, and it rewrites its own preference domain on quit — a scripted
write there is silently discarded. Importing the file is the only stable path.

### Colour fidelity caveat

Terminal.app is the one **approximate** target in this folder. Colours are
archived as `NSDeviceRGB` (`NSColorSpace = 2`), which is what effectively every
`.terminal` generator emits and what the format's compact archive shape
assumes. `NSDeviceRGB` is not strictly sRGB, so on a wide-gamut (P3) display
Terminal may render these slightly more saturated than the hex values. Terminal
also re-saves profiles through its own colour conversion, so exact hex fidelity
in Terminal.app is not achievable by any method.

**If you want the palette exactly right, use iTerm2, kitty, WezTerm, Ghostty or
Alacritty** — all five are exact.

---

## Uninstall (all emulators)

| Emulator | Undo |
|---|---|
| iTerm2 | Settings → Profiles → Colors → Color Presets… → pick another. Right-click the preset → Delete. |
| Alacritty | Remove the `import` line; delete `~/.config/alacritty/themes/liberty-hill-dusk.alacritty.toml` |
| kitty | Remove the `include` line; delete `~/.config/kitty/liberty-hill-dusk.kitty.conf` |
| WezTerm | Remove the `dofile`/`apply` lines; delete `~/.config/wezterm/colors/liberty-hill-dusk.wezterm.lua` |
| Ghostty | Remove the `theme` (or `config-file`) line; delete `~/.config/ghostty/themes/liberty-hill-dusk` |
| Terminal.app | Settings → Profiles → select your old profile → **Default**, then right-click *Liberty Hill Dusk* → Remove. Delete the generated `.terminal` file. |

Nothing here writes outside your home folder, and nothing is ever deleted on
your behalf. Backups are left in place on purpose — find them with:

```sh
find "$HOME" -maxdepth 6 -name '*.lhs-backup-*' 2>/dev/null
```

---

## What was actually verified, and what could not be

These files were authored and checked on **Windows**. Nobody on this project has
a Mac, so this section is deliberately explicit about the difference.

**Verified by execution:**

- Every hex → float conversion computed from the hex, not typed by hand.
- `liberty-hill-dusk.itermcolors` parses as a property list; **all 26 colours
  round-trip back to the exact source hex**; every dict carries
  `Color Space = sRGB`; no unexpected keys.
- `liberty-hill-dusk.alacritty.toml` parses as TOML; all 24 colours match.
- kitty, Ghostty and WezTerm files parse structurally; all 16 ANSI colours plus
  every core colour match, and no off-palette colour appears in any of them.
- `make-terminal-app-profile.sh` is `bash -n` clean and passes a static lint for
  bash-4-only syntax, GNU-only tool flags, `sudo`, `rm -rf`, `killall` of user
  apps and SIP/Gatekeeper/TCC tampering.
- The generator's palette table was executed: it emits exactly 21 correct
  `KEY=R,G,B` triples.
- The generator's **Python tier was run end-to-end** and its output decoded:
  a valid XML plist, 21 `NSKeyedArchiver` blobs, each with `NSColorSpace = 2`,
  the required trailing NUL on `NSRGB`, and **all 21 colours exact**.

**Not verifiable without a Mac:**

- The AppleScript-ObjC tier (tier 1) of the generator — the ASObjC bridging
  forms, `NSPropertyListSerialization`, and the read-back verifier. This is why
  the Python tier exists as an independent fallback, and why the script verifies
  its own output before installing anything.
- Whether each emulator *renders* as intended — only that the files are
  well-formed and carry the right values.
- The exact current wording of menu items in each app's settings UI.
