# Liberty Hill Studios — Desktop Theme (macOS)

The studio's **Texas Hill Country dusk**, living on a Mac desktop. This is the same
wallpaper the Windows theme runs — literally the same file,
[`../wallpaper/lhs-dusk.html`](../wallpaper/lhs-dusk.html). There is deliberately no macOS
copy of it, so the two platforms can never drift apart.

One self-contained HTML file: the Sora wordmark font is embedded as base64, everything is
drawn on a canvas, and there are **zero network calls**. Nothing in it is platform-specific.

The scene is computed, not looped:

- **The sun is the real sun.** Solar altitude is solved for
  `lat 30.6624, lon -97.9247` — Liberty Hill, Texas — so sunrise, golden hour, civil
  twilight and full night fire when they actually happen and **drift with the seasons**
  instead of at hardcoded clock times. In January the golden hour arrives on your desktop
  in the late afternoon; in June it holds past 20:00. The ridgeline genuinely occludes the
  disc as it rises and sets.
- **The moon is the real moon.** True position and true phase from abridged lunar theory,
  verified at **0.38 minutes of error per lunation across 618 lunations / 50 years**. A
  real full moon renders full; a real half moon renders exactly half; the waxing crescent
  three days after new is the crescent you would see if you walked outside tonight. The
  terminator is a projected ellipse rather than a drawn arc, the unlit limb carries
  earthshine, the maria rotate with the parallactic angle, and the disc grows and shrinks
  with true perigee/apogee distance.

Everything else in this folder is small and optional. **This port is a wallpaper, plus a
little branding where it is tasteful.** It does not manage your windows and it does not try
to make macOS behave like Windows.

Everything is user-level and reversible. No sudo. No SIP or Gatekeeper changes. No app is
installed for you. Nothing is deleted.

---

## Read this first — this port was authored without a Mac

Nobody on this project owns a Mac. The Windows side has been run and tuned on real
hardware for months. **The macOS side has never been run on a Mac, not once.** It was
written against Apple documentation and upstream source, and it is built to fail safe and
fail loud rather than to be clever.

| Confidence | What | Why |
|---|---|---|
| **Certain** | `../wallpaper/lhs-dusk.html` | A self-contained web page — Sora embedded as base64, **zero network calls**, canvas only. Nothing in it is platform-specific. If a WebKit view renders it, it is correct. |
| **Certain** | `../stills/` | Plain PNGs, already baked. |
| **Certain** | `terminal/*` | Pure data — plist, TOML, conf, Lua. Machine-checked: every colour round-trips back to the exact source hex. A mistake here would be a *format* mistake, not a runtime one. |
| **Certain** | `launcher/*` | Also pure data — two small JSON files. Every channel was checked arithmetically against the palette (e.g. parchment `#F5ECD9` → Alfred `#F5ECD9FF`, Raycast `#F5ECD9`), and both files parse. These committed files are the *only* source: `install.sh` carries no built-in copy to fall back on, so what it installs is what is reviewed here or nothing at all. |
| **Verified structurally** | `icons/lhs.icns` | Built on Windows, then **parsed back chunk by chunk**: the container is well-formed and every declared size is present. Whether Finder *renders* each size cleanly is unverified — see [Known unknowns](#known-unknowns). |
| **Best effort** | Anything touching system settings — the desktop picture, the `--accent` keys, `--icon` | Each uses the one public, long-stable API for its job and verifies by read-back, but no `defaults`, `osascript` or `sw_vers` call in this repo has ever actually executed. |
| **Best effort** | Terminal.app profile generation | The only emulator whose format has to be *generated* rather than copied — `NSKeyedArchiver` colour blobs. The other five are file copies. |
| **Best effort** | Plash instructions | A third-party, sandboxed, no-longer-open-source app. The mechanism is confirmed by its author; the exact menu wording is not. |
| **Best effort** | Launcher *import*, as opposed to the files | The theme files are data we can verify. Handing them to Raycast/Alfred means opening a URL and an app doing something with it, and neither hand-off has been watched happen. |

**So run the preview first:**

```bash
./install.sh --dry-run
```

That prints every command it would run and changes nothing. Read it. Then decide.

---

## What the default install does

`./install.sh` with no flags touches macOS **once**:

1. Copies the wallpaper and the stills into `~/Pictures/Liberty Hill Studios/`, with the
   animated page laid down as `~/Pictures/Liberty Hill Studios/Living Dusk/index.html`.
2. Sets your **static desktop picture** to the still that best fits your display. This is
   the one system change that happens by default — it is a wallpaper, which is the entire
   point of the project.
3. Prints the steps for the **animated** wallpaper via Plash. It does not install Plash
   and it never claims to have set a live wallpaper.
4. Nothing else. No appearance changes, no accent, no dark mode, no terminal, no launcher,
   no icon.

Note the stills folder is about **172 MB**. `./uninstall.sh` removes it.

### Quick install

```bash
git clone https://github.com/trimmdev/lhs-desktop-theme
cd lhs-desktop-theme/macos

./install.sh --dry-run      # preview — prints every command, changes nothing
./install.sh                # apply
```

Clone it rather than downloading the ZIP in Safari: browser downloads arrive carrying
`com.apple.quarantine`, and this installer will never strip Gatekeeper state to work
around that. `git clone` and `curl -O` don't set the attribute in the first place.

### Flags

Everything beyond the wallpaper is **opt-in, one flag each, all off by default**.

| Flag | Effect |
|---|---|
| *(none)* | Wallpaper only — the four steps above. |
| `--terminal` | Install the Liberty Hill Dusk colour scheme for whichever terminal emulators are actually present. |
| `--launcher` | Install the Liberty Hill Dusk theme for Raycast and Alfred, if present. |
| `--accent` | Dark mode + gold accent + gold text-selection highlight. |
| `--icon` | Apply the studio `.icns` to the `~/Pictures/Liberty Hill Studios` folder. |
| `--dry-run` | Print every action, perform none. |
| `--help` | Usage, and the authoritative flag list for your copy. |

`--help` is the authority. If it disagrees with this table, believe `--help`.

### What it guarantees

- **No sudo, ever.** Nothing is written outside `$HOME`. Nothing lands in `/Library`.
- **Backups happen once.** The first time a file is touched it is copied to
  `<file>.lhs-backup-<timestamp>`. A second run does *not* re-back-up — that would
  overwrite the pristine original with our own version.
- **One failed step doesn't sink the install.** Each step runs guarded; a failure warns
  and the rest continue. The summary at the end lists what applied and what didn't.
- **Every change is recorded** in an install manifest and an undo log, which is exactly
  what `uninstall.sh` replays.
- **Opt-in extras only touch apps you already have.** `--terminal` and `--launcher` write
  their theme files into `~/Library/Application Support/Liberty Hill Studios/`
  unconditionally — so they are waiting if you install the app later — then detect the app
  and skip the hand-off silently when it is absent. Neither installs an app.

---

## The animated wallpaper

**Neither Windows nor macOS renders an HTML page as a desktop background natively.** That
is not a macOS shortcoming — it is why the Windows side of this repo needs
[Lively](https://github.com/rocksdanister/lively) too. Natively macOS gives you static
images and `.heic` "dynamic desktops", which are a bundle of stills that cross-fade on
solar elevation, not animation. Sonoma's video aerials are Apple-signed assets third
parties cannot add to. So the animated route needs a host app. On macOS that app is
**[Plash](https://sindresorhus.com/plash)**, which puts a web view at the wallpaper layer —
the same job Lively does on Windows.

One structural caveat up front: **Plash is sandboxed, so it can only read a folder you
hand it through a file picker.** You cannot type a `file://` URL, the `plash:add` URL
scheme documents verbatim that "Local file URLs are not supported", and no script can do
it for you — macOS only grants a security-scoped bookmark to something a human picked in
an open panel. The folder pick is an irreducible one-time manual step. This mirrors Lively
on Windows exactly, whose library entry is also a folder containing an `index.html`.

### 1. Install Plash — the build that matches your macOS

**There is no Homebrew cask.** `brew install --cask plash` does not exist and will 404.
Get it from the Mac App Store. The current App Store build requires **macOS 26.4 or
newer**; older systems need a specific legacy build from the GitHub `older-releases` tag:

| macOS | Build |
|---|---|
| 26.4 Tahoe and newer | [Mac App Store](https://apps.apple.com/us/app/plash/id1494023538) (free) |
| 15 Sequoia | Plash **2.16.0** — `older-releases` tag |
| 14 Sonoma | Plash **2.15.0** — `older-releases` tag |
| 13 Ventura | Plash **2.14.1** — `older-releases` tag |

Systems older than Ventura have their own builds under the same tag. The installer reads
your version with `sw_vers` and prints the one correct link, so you don't have to pick.
The legacy ZIPs come from GitHub, so Gatekeeper quarantines them — **right-click the app
and choose Open** the first time. Do not run `xattr -d com.apple.quarantine`; this repo
will never tell you to disable Gatekeeper.

### 2. Point Plash at the folder

The installer has already laid the page down at:

```
~/Pictures/Liberty Hill Studios/Living Dusk/index.html
```

It is a copy of `wallpaper/lhs-dusk.html` renamed to `index.html`, because Plash loads
`index.html` from whatever folder you give it.

In Plash, choose the option to open a **local folder/directory** (rather than entering a
URL) and pick the **`Living Dusk` folder itself — not the file inside it**. In the open
panel, ⇧⌘G lets you paste the path. Then turn on **Open at Login** in Plash's settings.

That's it. With no query string the page runs live off the real clock, on real solar
altitude with the real moon — which is exactly what a wallpaper wants. There is nothing
to configure.

Useful Plash settings once it's running: show on a specific display, lower the opacity,
deactivate automatically on battery, hide the menu-bar icon. Plash's URL scheme is also
usable from a shell for the things it *does* support —
`open -g 'plash:reload'`, `plash:next`, `plash:toggle-browsing-mode`. Only the local-file
add is off limits.

### The known Plash caveat

On some versions the local-folder permission prompt **reappears after unlock**, sometimes
with an unresponsive spinner or an error dialog claiming the file can't load before it
loads anyway. Underneath it is a long-standing WKWebView bug where a local file loads only
once. It has been reported fixed and it is version-specific — but if it bites you, don't
fight it. The static wallpaper below is a first-class path here, not a consolation prize.

Plash is also no longer open source (the repo is issues-only), so if local-file support
ever regresses there is nothing to inspect or patch.

---

## The static wallpaper

This one is native, needs no third-party app, no background process and no permissions,
and still gives you a beautiful desktop — just not a moving one. It is what the default
install completes on its own.

`../stills/` holds deterministic single-frame renders of the same scene at native
resolution. The installer copies them to `~/Pictures/Liberty Hill Studios/` and sets the
best fit for your main display.

**How it is set:** `NSWorkspace.setDesktopImageURL:forScreen:options:error:` — the only
public, Apple-supported wallpaper API, unchanged since 10.6 — called in-process through
`osascript`'s ObjC bridge, iterating every `NSScreen`. Because no Apple event leaves the
process, **it raises no Automation permission prompt**. It then reads the wallpaper back
and compares, so it can tell a real success from a silent failure.

> Deliberately *not* used: `tell application "System Events" to tell every desktop to set
> picture`. It fires an Apple event, so macOS shows a modal "wants access to control
> System Events" dialog (error `-1743` if you decline); it only reliably reaches the
> *active* Space; and on macOS 26 it can silently switch off "Show on all Spaces". The
> comment saying so is in `install.sh` too, so nobody helpfully switches back to it.

Two behaviours worth knowing, both of them silent-failure traps elsewhere:

- **macOS caches the wallpaper by path.** Re-setting the same path whose *content* has
  changed does nothing at all. That is why the installer hands the API the immutable
  per-resolution still — `stills/lhs-dusk-<W>x<H>.png`, whose content never changes for a
  given name — and *not* the stable-named `lhs-static.png` copy it also writes for the
  manual System Settings ▸ Wallpaper ▸ Add Photo… route, whose content does change between
  runs. No per-run filename is generated.
- **Spaces cannot be covered by any API.** NSWorkspace, `desktoppr` and AppleScript all set
  only the active Space. If you want it everywhere, tick System Settings ▸ Wallpaper ▸
  *Show on all Spaces*. That is a macOS limitation, not a bug here.

**Choosing a resolution.** Pick by aspect ratio, not exact pixel count — the scene is
gradients, noise and dithering, so mild scaling is invisible. Already baked:

| File | Fits |
|---|---|
| `lhs-dusk-2560x1600.png` · `lhs-dusk-2880x1800.png` | 16:10 laptops |
| `lhs-dusk-5120x2880.png` | 27" 5K — Studio Display, iMac |
| `lhs-dusk-3840x2160.png` · `lhs-dusk-7680x4320.png` | 4K / 8K, 16:9 |
| `lhs-dusk-3440x1440.png` · `lhs-dusk-5120x1440.png` | Ultrawides |
| `lhs-dawn-*` · `lhs-day-*` · `lhs-night-*` | Same scene, other moods |

Want an exact native panel size? Bake it (Node + Playwright, runs on any OS):

```bash
cd ..                                                   # the tool lives at the repo root
node tools/bake-stills.mjs 3456x2234                    # 16" MacBook Pro
node tools/bake-stills.mjs 3024x1964 --moods dusk,night # 14" MacBook Pro
node tools/bake-stills.mjs 6016x3384                    # Pro Display XDR
```

**Lock screen:** macOS ties it to your desktop picture for the logged-in user, so setting
the wallpaper generally covers it. The pre-login login-window background is a system-level
asset needing admin rights; this port does not touch it.

---

## Opt-in extras

### `--terminal`

Installs the Liberty Hill Dusk scheme for the emulators you actually have — iTerm2,
Alacritty, kitty, WezTerm, Ghostty and Apple's Terminal.app. The palette is **byte-identical
to the Windows Terminal scheme**; no colour was re-derived for macOS.

Five of the six are exact. Terminal.app is approximate — its `.terminal` format stores
colours as `NSKeyedArchiver` blobs in device RGB, and Terminal re-saves imported profiles
through its own colour conversion, so expect sub-percent drift. It also needs one click
from you (Settings ▸ Profiles ▸ select ▸ **Default**), because Terminal rewrites its own
preference domain on quit and silently discards scripted writes.

Full per-emulator detail, the palette table, and every gotcha:
[`terminal/README.md`](terminal/README.md).

### `--launcher`

Themes **Raycast** and **Alfred** — but only the ones already installed, same rule as
`--terminal`. Both theme files are written to
`~/Library/Application Support/Liberty Hill Studios/`, whether or not the app is present,
so they're waiting if you install one later. Full detail, the complete colour mapping and
the manual import steps: [`launcher/README.md`](launcher/README.md).

**Neither launcher can be animated. There is no animated launcher theme on macOS.**
Alfred's `.alfredappearance` format has no animation, transition, gradient, image or
shader key; Raycast's theme model is twelve colours and a light/dark flag. That is the
whole format in both cases. Anything claiming otherwise is wrong.

What *is* real, and is the genuinely good version of this:

**Alfred supports vibrancy.** Setting `visualEffectMode: 2` (dark) and keeping
`window.color` at a low alpha — ink-950 at ~60%, `#0A080799` — backs Alfred with a native
`NSVisualEffectView` and paints only a thin ink tint over it. macOS behind-window vibrancy
samples whatever is composited behind the window, which is your desktop. And Alfred opens
near the **top-centre of the screen**, which in this wallpaper is the **sky** — the region
that changes most from dawn through golden hour to twilight to night. So the launcher's
glass warms when the real sun is low and cools to near-black at night, on its own, all day,
without one animated pixel in the theme file.

Two honesties about that, because it is a claim about macOS compositing rather than about
anything we ship:

- **It is a soft colour wash, not a window onto the scene.** Vibrancy blurs and
  desaturates heavily. The dusk sky *tints* the launcher; you will not see the moon
  through it.
- **Untested on hardware, with a known fallback.** Whether Alfred's visual-effect view
  samples Plash's desktop-level window or only the underlying static desktop picture is
  not something we could verify. If it samples Plash, the tint is living. If Plash's window
  is excluded from the sample, the tint comes from the static picture instead — still the
  right ink-and-gold glass, just constant instead of shifting. Either way the theme is
  correct; only the liveliness is in question.

**Raycast gets no transparency at all.** Its theme is twelve opaque `#RRGGBB` values plus
`appearance: dark`. Eight-digit hex is accepted by the parser but the alpha is silently
discarded, and there is no opacity, blur or gradient field anywhere in the model. Whatever
translucency Raycast's own window has belongs to the app, not to anything a theme can set.
So Raycast gets a precisely matched flat ink palette — ink background, parchment text,
selection ink `#4D2C14`, gold `#E8A13A` on the loader — and nothing more. That is the
Raycast/Alfred split, and it's worth knowing before you pick which one to run.

**Both are paywalled, and neither hand-off is silent.** This is the part to read before
running the flag:

| | Raycast | Alfred |
|---|---|---|
| Custom themes require | **Raycast Pro** — $10/mo, $8/mo annual | **Alfred Powerpack** — £34 single, £59 mega supporter |
| On the free tier | Theme Studio refuses | Free Alfred cannot import a `.alfredappearance` **at all** |
| How the installer hands it over | `open` a local `raycast://theme?…` deep link — Raycast has no on-disk theme folder, the deep link is the only sanctioned route | `open` the `.alfredappearance` file |
| What you then do | Theme Studio opens with the theme previewed → click **Set as Current Theme** | Alfred Settings opens with a colour preview → click **Import** |
| Minimum version | — | Alfred 4.3+ (Nov 2020) for the vibrancy and roundness keys |

The Raycast deep link is a purely local URL hand-off — no network, consistent with the rest
of this repo. The installer prints the Pro/Powerpack caveat rather than reporting success,
and it never says "theme applied" when all it did was open a window. Nothing is restarted
or killed. If you're on stable Raycast without Pro, the Alfred half is the half that lands;
if you have neither subscription, the files sit in Application Support costing you nothing.

Two design notes, surfaced rather than buried:

- **Four of Raycast's twelve colours are not studio colours.** Raycast mandates all twelve
  slots and the studio palette supplies eight. `green` / `blue` / `purple` / `magenta` are
  **derived** — a judgement call, not brand colours — chosen to sit beside the gold without
  shouting. They only ever render as small semantic glyphs and badges. Swap them freely;
  the schema does not care. This is the one design decision in the file that isn't
  traceable to the palette, so it's called out rather than passed off as brand-derived.
- **Sora cannot be used.** Neither format can embed a font — the `font` key is just a
  display name resolved against installed fonts, and Alfred's own guidance is to use a
  standard font in shared themes. Both themes ship System / System Light (SF Pro). The
  wallpaper keeps its embedded Sora; the launcher cannot have it.

In the Alfred theme, gold appears only in the selected-row wash (20% alpha), the shortcut
glyphs, the scrollbar, the separator hairline and a low-alpha window border. It is never a
surface — which here is enforced by physics as much as by taste: `NSVisualEffectView`'s
dark material is a fixed system material that cannot be tinted gold at all, so gold can
*only* live in text, selection and hairlines. The window itself is ink `#0A0807` at 60%,
and the search field is fully transparent rather than a solid slab.

### `--accent`

Four settings across **five** global preference keys, all reversible, all backed up
before the first write. (`AppleAccentColor` and `AppleAquaColorVariant` are one setting
in two keys; `uninstall.sh --reset-appearance` lists all five.)

| What | Key | Value |
|---|---|---|
| Dark mode | `AppleInterfaceStyle` | `Dark` |
| …and "Auto" turned off first | `AppleInterfaceStyleSwitchesAutomatically` | `false` |
| Accent | `AppleAccentColor` (+ `AppleAquaColorVariant`) | `1` — Apple's Orange |
| Text selection | `AppleHighlightColor` | `0.909804 0.631373 0.227451 Other` |

Three honest notes:

- **`AppleInterfaceStyleSwitchesAutomatically` matters.** If you are on "Auto" appearance
  and it is left on, macOS flips you back to Light at sunrise and the theme appears to
  stop working hours after install. It is cleared first, and its prior value is saved.
- **The accent is approximated.** No documented, stable key accepts an arbitrary accent
  RGB, so this is Apple's Orange (~`#FF9500`), *not* brand gold `#E8A13A`. Tahoe added a
  custom picker but the format it writes is undocumented and we won't guess at it.
  `AppleAquaColorVariant` is set alongside it because it is `6` when you're on Graphite,
  and orange renders wrong until it is `1`.
- **The highlight is exact.** `AppleHighlightColor` *does* take arbitrary RGB, so text
  selection is true gold `#E8A13A`. Apple's own highlight colours are pale tints, so full
  gold reads notably louder than stock.

**Nothing here restyles apps that are already running.** `defaults write` doesn't
broadcast; each app reads these at launch. Apps opened afterwards pick it up, and a log
out and back in makes everything uniform. That is expected, not a bug — and no app of
yours gets killed to force it.

Reverting is per-key and correct: **Light Mode is the *absence* of `AppleInterfaceStyle`**,
so uninstall deletes the key rather than writing `"Light"`, which would leave a bogus
value behind. Same for the accent and highlight keys — absent means system default.

> If windows pick up a gold cast after you set the wallpaper, that's macOS wallpaper
> tinting, not this theme. System Settings ▸ Appearance ▸ *Allow wallpaper tinting in
> windows*. Gold belongs on small elements; a tinted sidebar is a large surface.

### `--icon`

Applies `icons/lhs.icns` — the Lone Star mark, packed 16 → 1024 px — to the
`~/Pictures/Liberty Hill Studios` folder via `NSWorkspace.setIcon:forFile:options:`
through the ObjC bridge. Zero dependencies: no Xcode Command Line Tools, no Homebrew, no
sudo. The boolean return is checked, so it fails loudly rather than pretending.

It is opt-in and best-effort because a custom folder icon lives in a hidden `Icon\r` file
plus a `com.apple.FinderInfo` xattr, which **git cannot carry** and which is lost on any
copy to a filesystem that doesn't support it. Finder also caches icons aggressively, so
you may need to reopen the window.

Uninstalling it removes the `Icon\r` file, which alone is enough to stop Finder drawing
the custom icon. The `com.apple.FinderInfo` xattr is a 32-byte structure that *also*
carries the folder's Finder flags — including your colour tag/label — so `uninstall.sh`
deletes the whole attribute only when nothing but the custom-icon bit is set in it.
Otherwise it leaves the attribute alone and prints the one command to clear it yourself.
Your colour tag is not collateral damage.

Every blog recipe for this (`SetFile`, `Rez`, `DeRez`) needs Xcode Command Line Tools and
fails on a clean Mac; `sips --addIcon` was removed in High Sierra. None of them appear
here. The `.icns` itself was built on Windows by `tools/build-icns.mjs` — no `iconutil`,
no Mac required — and `icons/lhs.iconset/` is committed alongside it for provenance.

### One manual touch, if you want it

**Account picture** — System Settings ▸ Users & Groups ▸ your account ▸ the picture →
`macos/icons/avatar-448.png`. No script can set this safely; it takes ten seconds.

---

## Windows → macOS parity

Parity is **full** / **close** / **approximated** / **not ported** / **not possible**.
Where it isn't full, the reason is stated.

| Windows feature | macOS | Parity | Note |
|---|---|---|---|
| Living wallpaper via Lively | Plash | close | Same HTML file, same scene, same maths. Both platforms need a third-party host; macOS additionally needs a one-time manual folder pick no script can perform. |
| Lively auto-pause under fullscreen apps | — | not possible | Plash can deactivate on battery; there is no fullscreen-app hook. |
| Static wallpaper, best-fit still | `NSWorkspace.setDesktopImageURL:` | full | Public API, verified by read-back, no permission prompt. |
| Wallpaper on all virtual desktops | — | not possible | No public API sets all Spaces. One tick in System Settings. |
| Lock screen still | Follows the desktop picture | close | The pre-login login-window background is a system asset; out of scope. |
| Dark mode | `AppleInterfaceStyle = Dark` | full | `--accent` |
| Gold accent colour | `AppleAccentColor` = Orange | approximated | Apple's orange (~`#FF9500`), not gold `#E8A13A`. No stable key takes an arbitrary RGB. |
| Gold selection / highlight | `AppleHighlightColor` | full | Exact `#E8A13A`. Arbitrary RGB *is* allowed here. |
| TranslucentTB transparent taskbar | — | not possible | The menu bar and Dock are already translucent; there is no supported knob. Nothing to install. |
| Windows Terminal scheme | iTerm2 / kitty / Alacritty / WezTerm / Ghostty | full | Exact hex, all 16 ANSI + cursor + selection. |
| Windows Terminal scheme | Terminal.app | close | Colour blobs are device RGB; expect sub-percent drift. |
| Flow Launcher theme (translucent ink glass, gold caret) | **Alfred** theme | close | Same idea, achieved natively: `visualEffectMode: 2` + 60%-alpha ink gives real dark glass over the living wallpaper. Needs the Powerpack. |
| Flow Launcher theme | **Raycast** theme | approximated | Colour-exact but **flat** — Raycast's format has no alpha, so there is no translucency to give it. Needs Raycast Pro. |
| Flow Launcher's animated XAML transitions | — | not possible | Neither Raycast nor Alfred has any animation, transition or gradient key. The format simply doesn't exist. |
| `lhs.ico` | `lhs.icns` | full | Packed 16 → 1024 px. |
| Folder icons | `NSWorkspace.setIcon:forFile:` | approximated | Opt-in, xattr-based, cannot live in git, Finder caches. |
| Account avatar | Users & Groups picture | close | Manual — System Settings. |
| **FancyZones window layouts** | — | **not ported** | **macOS should feel like macOS.** Snap-to-zone is a Windows idiom. Installing a window manager and imposing a set of keyboard shortcuts changes how the machine *behaves* — that is not what a theme is for, and it was cut deliberately, not for lack of an option. |
| **Chimes on `SystemAsterisk` / `SystemExclamation` / `Notification.Default`** | — | **not ported** | **macOS has no equivalent to port to.** There is no per-event sound mapping anywhere in the OS — macOS exposes exactly one user-selectable global Alert sound plus two on/off toggles, with no registry of per-event assignments and no per-app alert-sound API. Shipping "chimes" here would mean overwriting your single global alert sound and calling it parity. It isn't, so we don't. |
| Everything (instant file search) | Spotlight | n/a | Nothing to theme, nothing to install. |
| OEM logo (System ▸ About) | — | not possible | No equivalent surface. |
| `install.ps1` installs apps via winget | — | by design | This installer never installs an app for you. It prints the link and skips. |

---

## Uninstall

```bash
./uninstall.sh --dry-run     # preview
./uninstall.sh
```

It replays the undo log in reverse, then removes only paths recorded in the install
manifest, and only those passing an allow-list prefix check —
`~/Pictures/Liberty Hill Studios`, `~/Library/Application Support/Liberty Hill Studios`,
and the four exact `~/.config/{kitty,alacritty,wezterm,ghostty}/…liberty-hill-dusk…` theme
files that `--terminal` dropped there (their parent folders are then removed only if
`rmdir` finds them empty). Files go with `rm -f`; directories
with a bare `rmdir`, which fails safe if you put something of your own inside. **Neither
script in this port contains an `rm -rf`.** (The one `rm -rf` in the docs is in
[`launcher/README.md`](launcher/README.md), for an optional drop-in *you* would do by
hand; no script here creates or touches that folder.) Your previous desktop picture is restored, because
deleting the image the desktop points at and leaving a blank screen is exactly the kind of
half-broken state this project must never produce.

| Flag | Effect |
|---|---|
| `--dry-run` | Print every action, change nothing. |
| `--reset-appearance` | Only if the recorded "before" values are missing: delete the appearance keys, returning macOS to its own defaults. Off by default — it cannot tell our value from one you already had. |
| `--purge-backups` | Also delete the `*.lhs-backup-*` files. Off by default; your originals are worth more than a tidy folder. |

Three things it cannot do, and says so rather than pretending:

- **Plash's folder bookmark** is Plash's own state — remove the website entry in Plash.
- **A launcher theme you accepted** lives inside Raycast's or Alfred's own storage, not in
  a file we wrote. The theme files under Application Support are removed; switching back to
  another theme is one click in the launcher's own settings. Nothing here edits Alfred's
  live preferences or writes `currentthemeuid` behind its back.
- **Nothing installs an app**, so nothing uninstalls one either.

Find backups with:

```bash
find "$HOME" -maxdepth 6 -name '*.lhs-backup-*' 2>/dev/null
```

---

## Known unknowns

If you own a Mac, these are the assumptions to check. All of them fit in five minutes, and
`./install.sh --dry-run` answers several without changing anything.

1. **Does the desktop picture actually change?** If not, add the image once by hand
   (System Settings ▸ Wallpaper ▸ Add Photo…, choose
   `~/Pictures/Liberty Hill Studios/lhs-static.png`) and re-run — there are second-hand
   reports that an image System Settings has never seen doesn't take until then.
2. **Does the wallpaper set with no permission dialog?** It should. The ObjC-bridge call
   sends no Apple event. If you get a TCC prompt, tell us which step triggered it.
3. **Does Plash's local-folder pick still exist, and what is the menu item called?** The
   mechanism is confirmed by Plash's author; the current wording is not, which is why this
   README describes the option instead of quoting a label.
4. **Does the Plash re-prompt bug bite on your macOS version?** If the folder permission
   dialog reappears at every unlock, that is the known WKWebView bug, not this repo.
5. **Does the live scene look right at the wallpaper layer, and what does it cost?**
   On Windows it measures ~0.2% of one CPU core per monitor at 30fps. Check Activity
   Monitor and confirm the moon matches tonight's real phase.
6. **The one genuinely interesting launcher question: does Alfred's glass sample the
   *living* wallpaper?** Run Plash, open Alfred, and look at it at golden hour and again at
   midnight. If the tint shifts, behind-window vibrancy is sampling Plash's desktop-level
   window and the effect is alive. If it looks identical, it is sampling the static desktop
   picture underneath instead — the theme is still correct, the wash is just constant.
7. **`--launcher`: does the Raycast deep link open Theme Studio at all?** Classic Raycast
   registers `raycast://`; the v2 beta registers `raycast-x://` on macOS. The installer
   tries one and falls back to the other. Also worth confirming: `visualEffectMode: 2` is
   an undocumented Alfred key, inferred with high confidence from 67 published themes and
   Alfred's own 4.3 release wording, but it is not a published contract.
8. **`--accent`: does the exact gold highlight read as intentional or too loud?** Apple's
   own highlights are pale tints and ours is roughly twice as saturated.
9. **`--accent`: does uninstall return the machine *exactly* to its prior state?** The
   honest test is `defaults read -g` before and after.
10. **Check `icons/lhs.icns` at every size in Finder.** The committed file declares `ic13`
    at 512 px and `ic14` at 1024 px, where Apple documents `ic13` = 128@2x (256 px) and
    `ic14` = 256@2x (512 px), and it carries `icp4`/`icp5`/`icp6` chunks that have reported
    display quirks on some releases. The container is well-formed and every size is present,
    so it should render — but if the icon looks soft or mis-sized at some scale, that is
    why, and `tools/build-icns.mjs` needs its OSType map corrected before regenerating.
11. **Does the whole thing run clean under Apple's `/bin/bash` 3.2.57 and BSD userland?**
    It is written strictly to 3.2 — no associative arrays, no `mapfile`, no `${var^^}` — and
    avoids GNU-isms entirely (no `sed -i`, no `readlink -f`, no `date -d`, no `grep -P`).
    It has never run against a real BSD toolchain.

---

## Design law

Gold `#E8A13A` is an **accent, never a background**: cursors, selection, highlights, thin
rules — small elements only. Surfaces stay translucent ink `#0A0807`. Standard system
affordances are never reskinned into something unrecognisable. The Dock stays a Dock, and
the launcher stays a launcher.

Palette, scene internals, URL parameters (`?mood=`, `?at=`, `?speed=`, `?still=`), the one
deliberate stylization in the composition, and the solar/lunar maths are documented in the
[root README](../README.md) — the wallpaper is the same file on both platforms, so there
is one place to read about it and one place to change it.

---

Built with care at Liberty Hill Studios. 🌵⭐ — and if you own a Mac, the list above is
where to start.
