# Liberty Hill Studios — Desktop Theme

The studio's signature **Texas Hill Country dusk**, living on your desktop. A fully
animated wallpaper that follows the real clock — golden afternoon → signature dusk →
deep night with fireflies and a faint Milky Way → warm dawn — plus a complete Windows
brand kit: transparent taskbar, dark + gold accent theme, terminal colors, notification
chimes, icons, and an optional keyboard-driven search/navigation stack.

![Living wallpaper preview](docs/preview-live.gif)

| Dusk | Night | Day |
|---|---|---|
| ![dusk](docs/preview-dusk.jpg) | ![night](docs/preview-night.jpg) | ![day](docs/preview-day.jpg) |

## Quick install

```powershell
git clone https://github.com/trimmdev/lhs-desktop-theme
cd lhs-desktop-theme
.\install.ps1              # wallpaper + taskbar + theme + terminal + chimes (opt-in)
.\install.ps1 -NavStack    # ...plus Everything, PowerToys FancyZones, Flow Launcher
```

Everything is **user-level and reversible**. One or two UAC prompts may appear for app
installers. See the end-of-install output for the three optional manual finishing touches
(avatar, gold pointer, lock screen).

## The field guide

An animated walkthrough of every feature and shortcut lives at [`docs/guide.html`](docs/guide.html) —
open it in any browser after cloning.

## What's inside

- **`wallpaper/lhs-dusk.html`** — the living wallpaper. Self-contained single file
  (Sora font embedded, zero network calls). Canvas-rendered at native resolution on any
  monitor: noise-generated ridgelines, god-rays, drifting valley mist, rising embers that
  become fireflies at night, twinkling stars + shooting stars, film grain, and the Lone
  Star + wordmark lockup. 30fps capped, ~1–2% CPU per monitor, auto-pauses under
  fullscreen apps (via Lively). URL params: `?mood=day|dusk|night` pins a mood
  (default follows your clock); `?still=1` renders one deterministic frame.
- **`stills/`** — pixel-perfect PNG renders at 16 standard resolutions (1366×768 → 8K,
  16:10, ultrawides, 5K, portrait) + night/day variants at common sizes. Use as static
  wallpapers or lock screens. Need another size? `node tools/bake-stills.mjs 7680x2160`.
- **`terminal/liberty-hill-dusk.json`** — Windows Terminal scheme (ink background,
  parchment text, gold cursor, ember/verdant/sky/plum ANSI ramp).
- **`flow-launcher/Liberty Hill Dusk.xaml`** — Flow Launcher theme (translucent ink
  glass, gold caret + selection).
- **`fancyzones/`** — PowerToys FancyZones config: gold snap highlights + three studio
  layouts (*LHS Ultrawide 30-40-30*, *LHS Quad*, *LHS Halves*).
- **`icons/`** — multi-size `lhs.ico` (Lone Star mark), account avatar, OEM logo.
- **`sounds/`** — two short studio chimes (finish + attention), wired to the Windows
  sound events `SystemAsterisk`, `SystemExclamation`, and `Notification.Default`.

## Design law

Gold `#E8A13A` is an **accent, never a background**: cursors, highlights, selection,
icons — small elements only. Surfaces stay translucent ink (`#0A0807`). Standard system
affordances (drive icons, capacity bars) are never reskinned.

## The stack it rides on

[Lively Wallpaper](https://github.com/rocksdanister/lively) ·
[TranslucentTB](https://github.com/TranslucentTB/TranslucentTB) ·
[PowerToys](https://github.com/microsoft/PowerToys) ·
[Everything](https://www.voidtools.com/) ·
[Flow Launcher](https://github.com/Flow-Launcher/Flow.Launcher) — all free, all excellent.
Wordmark font: [Sora](https://fonts.google.com/specimen/Sora) (SIL Open Font License),
embedded as base64.

## Palette

| Token | Hex | | Token | Hex |
|---|---|---|---|---|
| ink-950 | `#0a0807` | | gold-400 | `#e8a13a` |
| parchment | `#f5ecd9` | | gold-300 | `#ecbe5b` |
| ember-400 | `#d4542b` | | gold-600 | `#b3661f` |

Mirrors `liberty-hill-studios/src/lib/palette.ts` — change them together or the dusk
drifts from the site.

---

Built with care at Liberty Hill Studios. 🌵⭐
