# Liberty Hill Dusk — launcher themes (macOS)

The macOS port of the Windows [Flow Launcher theme](../../flow-launcher/Liberty%20Hill%20Dusk.xaml)
— whose gold caret and gold search glyph have **no equivalent key on either macOS
launcher**, see the [parity table](#parity-with-windows): a translucent ink surface,
parchment text, and gold only on the hairline, the selected row's wash, the scrollbar and
the ⌘-number.

Two launchers, two very different ceilings:

| | Raycast | Alfred |
|---|---|---|
| Theme format | 12 opaque hex colours + `light`/`dark` | colours **with alpha** + geometry + type |
| Translucency you control | **none** | **yes** — `visualEffectMode` |
| Animation | none | none |
| Costs money | **Raycast Pro** | **Alfred Powerpack** |
| What you get here | an exactly-matched flat ink palette | dark glass over the living wallpaper |

Nothing here needs `sudo`, downloads anything, or runs a background process.
Both files are plain text. Neither touches an app's live preferences behind its back.

---

## First, the honest part: neither launcher can be animated

The brief for this folder was "animated and look cool". Half of that is impossible
and it would be easy to pretend otherwise, so plainly:

> **There is no animation in either theme format.** Alfred's `.alfredappearance`
> has no animation, transition, gradient, image or shader key — it is colour,
> geometry and type, full stop. Raycast's theme model is twelve opaque hex values
> and a light/dark flag. Neither launcher has ever supported a moving theme, and
> nothing in this folder changes that. Any project claiming otherwise is theming
> something else.

## Then the part that is real: Alfred is glass, and the sky moves behind it

Alfred 4.3+ can back its window with a native macOS **visual-effect view** — real
behind-window vibrancy. This theme turns it on (`visualEffectMode: 2`, dark) and
tints it with ink-950 at 60% instead of painting an opaque slab.

macOS vibrancy composites **whatever is actually behind the window**. Behind
Alfred is the desktop picture — and on this machine the desktop picture is
[`lhs-dusk.html`](../../wallpaper/lhs-dusk.html), which is computing the real
solar altitude for Liberty Hill, Texas and redrawing the sky continuously.
Alfred opens near the **top-centre** of the screen, which is precisely the part
of that wallpaper that changes most: the sky.

So the launcher warms at golden hour, cools through twilight, and goes near-black
under a real new moon — **on its own, all day, without one animated pixel in the
theme file.** The motion belongs to the wallpaper and to macOS's compositor, not
to the theme.

Two honest limits on that:

- **Vibrancy blurs and desaturates.** You get a soft colour wash that shifts
  through the day. You do **not** get a crisp view of the moon through your
  launcher. It is a mood, not a window.
- **Unverified on hardware** — see [the caveat at the bottom](#unverified-on-real-hardware).

**Raycast gets none of this.** Its theme format has no alpha channel at all, so
the Raycast half of this folder is a beautifully matched flat ink palette and
nothing more. That asymmetry is the format's, not an oversight here.

---

## Before you start: both are paid features

| Launcher | Requirement | Price | What happens without it |
|---|---|---|---|
| **Raycast** | **Raycast Pro** | $10/mo, $8/mo annual | The deep link opens Raycast and the theme does not apply. |
| **Alfred** | **Alfred Powerpack** | £34 Single (v5), £59 Mega Supporter | Free Alfred **cannot import a theme file at all** — only the bundled themes exist. |

Alfred's own help says it verbatim: *"Creating themes, exporting and importing
them is a Powerpack feature."* Raycast's manual carries the front-matter
*"Tier: Pro Exclusive"* on its Themes page.

> **One live nuance, not a promise.** Raycast v2 is in public beta as of July 2026,
> and the Theme Studio changelog says *"during the Beta period, we're excited to
> offer you full access for free."* If you're on the v2 beta you may get themes
> without Pro **for now, by grace of the beta**. On stable Raycast, Pro is required.
> Don't plan around the beta.

If neither applies to you: the files still install, they cost nothing to keep,
and they import the moment you upgrade.

---

## Files

| File | Launcher | Notes |
|---|---|---|
| `liberty-hill-dusk.raycast.json` | Raycast | Source of truth for the deep link below. Raycast has no import-a-file path — see §1. |
| `Liberty Hill Dusk.alfredappearance` | Alfred 4.3+ / 5 | The theme name comes from the `name` key, not the filename. |

Assume `$LHS` is this folder:

```sh
LHS="$(cd "$(dirname "$0")" && pwd)"   # or just: cd path/to/repo/macos/launcher
```

Both are also installed to `~/Library/Application Support/Liberty Hill Studios/launcher/`
by `../install.sh --launcher`.

---

## 1. Raycast

**Raycast has no themes folder.** There is no path to drop a file into — not in
`~/Library`, not in `~/.config`. Themes live in Raycast's own store and sync
through Raycast Cloud. The **deep link is the only sanctioned import route**, and
it is purely local (no network, which suits this repo's zero-network rule).

Run this, or click it:

```sh
open "raycast://theme?author=Liberty%20Hill%20Studios&authorUsername=libertyhillstudios&version=1&name=Liberty%20Hill%20Dusk&appearance=dark&colors=%230A0807,%231B1612,%23F5ECD9,%234D2C14,%23E8A13A,%23E0604F,%23D4542B,%23E8A13A,%235FB87A,%235AA8E0,%23A878D8,%23C09BE8"
```

Then **click "Set as Current Theme"** in Theme Studio's top bar.

> **The import is not silent and not automatic.** The link opens Theme Studio with
> "Liberty Hill Dusk" *previewed*. It is not applied until you click. Anything
> claiming to "apply" a Raycast theme from a script is wrong.

Optional: in the **Switch Theme** command's Action Panel, choose **Set as Dark Theme**
so it binds to macOS Dark Mode rather than being a manual choice.

**On the Raycast v2 beta the URL scheme is different.** Production Raycast v2
registers `raycast-x://` on macOS, not `raycast://`. If the command above does
nothing, run the same URL with the other scheme:

```sh
open "raycast-x://theme?author=Liberty%20Hill%20Studios&authorUsername=libertyhillstudios&version=1&name=Liberty%20Hill%20Dusk&appearance=dark&colors=%230A0807,%231B1612,%23F5ECD9,%234D2C14,%23E8A13A,%23E0604F,%23D4542B,%23E8A13A,%235FB87A,%235AA8E0,%23A878D8,%23C09BE8"
```

`../install.sh --launcher` tries `raycast://` and falls back to `raycast-x://`
automatically.

**No Pro?** Open `liberty-hill-dusk.raycast.json` and type the twelve values into
Theme Studio by hand — the order in the file is the order Theme Studio asks for them.

### Two things in that URL you must not "tidy up"

- **The `#` is `%23`, but the twelve commas stay literal.** Each colour is
  percent-encoded *individually* and only then joined with raw `,`. If you run an
  encoder over the whole joined string the commas become `%2C` and Raycast
  silently fails to split the list.
- **Colour order is load-bearing.** The named parameters
  (`author`, `version`, `name`, …) can appear in any order, but the twelve values
  inside `colors=` are read **positionally**. Reordering them silently remaps your
  theme.

### Do not add an alpha channel to the Raycast file

Raycast's parser accepts an 8-digit `#RRGGBBAA` and then **throws the alpha away
with no warning** — `#0A0807CC` installs as `#0A0807`. This is a booby trap for
anyone who later tries to "add some transparency". Six digits only.

Raycast's window *does* have its own vibrancy, but that belongs to the app; no
theme key controls it and nothing here can turn it up.

---

## 2. Alfred

### The supported way — one double-click

```sh
open "$LHS/Liberty Hill Dusk.alfredappearance"
```

Alfred's Settings open with a colour preview and an **Import** button. Click it,
then pick **Liberty Hill Dusk** under **Settings → Appearance**. This is the only
route Alfred documents.

> The path has spaces in it. Quote every expansion — `open $LHS/Liberty Hill Dusk.alfredappearance`
> will try to open three files and find none of them.

### The silent way — drop it in the themes folder

What Homebrew casks do. Undocumented, and **Alfred must be restarted** before it
notices; you still have to select the theme yourself.

```sh
bid="com.runningwithcrayons.Alfred-Preferences"
sync=$(defaults read "$bid" syncfolder 2>/dev/null) || sync=""
[ -z "$sync" ] && sync="$HOME/Library/Application Support/Alfred"
case "$sync" in "~"*) sync="$HOME${sync#\~}";; esac      # defaults can return a tilde path

dest="$sync/Alfred.alfredpreferences/themes/theme.libertyhill.dusk"
mkdir -p "$dest"
cp "$LHS/Liberty Hill Dusk.alfredappearance" "$dest/theme.json"
```

Note the rename: on disk Alfred stores each theme as a **folder containing
`theme.json`**. Read the sync folder from `defaults` rather than assuming
`~/Library/Application Support/Alfred` — plenty of people relocate it to iCloud
or Dropbox.

> **Never write `currentthemeuid`** into `Alfred.alfredpreferences/preferences/appearance/prefs.plist`
> to auto-select the theme. That is editing Alfred's live preferences behind a
> running Alfred, and it will lose the race. Let the user click.

To undo this drop-in, remove that one theme folder. Spelled out in full so nothing
depends on a variable surviving from the block above, and nothing can expand to a wide
path:

```sh
bid="com.runningwithcrayons.Alfred-Preferences"
sync=$(defaults read "$bid" syncfolder 2>/dev/null) || sync=""
[ -z "$sync" ] && sync="$HOME/Library/Application Support/Alfred"
case "$sync" in "~"*) sync="$HOME${sync#\~}";; esac
dest="$sync/Alfred.alfredpreferences/themes/theme.libertyhill.dusk"
[ -n "$sync" ] && [ -d "$dest" ] && rm -rf "$dest"
```

This whole section is **your own optional drop-in**, done by hand: `../install.sh` never
creates that folder and `../uninstall.sh` never touches it. So
[`macos/README.md`](../README.md)'s "there is no `rm -rf` anywhere in this port" still
holds for the scripts — the command above is yours, not theirs.

### Requires Alfred 4.3 or newer

Four keys in this theme (`visualEffectMode`, `result.roundness`, `search.roundness`,
`search.paddingHorizontal`) arrived in Alfred 4.3, November 2020. On anything
older the file still imports and still looks right — you just lose the glass and
the rounded corners, which is most of the point.

---

## The palette

Every colour in both files is either an exact studio palette token or a value
already shipped and colour-verified in
[the terminal schemes](../terminal/README.md). **Nothing here was invented for
the launcher.**

| Role | Hex | Token |
|---|---|---|
| surface | `#0A0807` | ink-950 |
| raised surface | `#1B1612` | terminal ANSI black |
| text | `#F5ECD9` | parchment |
| text, selected | `#FDF6E8` | terminal brightWhite |
| subtitle | `#CDBFA6` | terminal ANSI white |
| accent / caret / loader | `#E8A13A` | gold-400 |
| accent, brighter | `#ECBE5B` | gold-300 |
| selection fill | `#4D2C14` | selection ink |
| ember | `#D4542B` | ember-400 |

### Raycast — the twelve slots

| # | Slot | Hex | Why |
|---|---|---|---|
| 1 | `background` | `#0A0807` | ink-950 |
| 2 | `backgroundSecondary` | `#1B1612` | Raycast's second gradient stop — a barely-there lift. Set it to `#0A0807` for dead flat. |
| 3 | `text` | `#F5ECD9` | parchment |
| 4 | `selection` | `#4D2C14` | selection ink — literally what this token is for |
| 5 | `loader` | `#E8A13A` | gold-400 on a 2px progress hairline: textbook accent use |
| 6 | `red` | `#E0604F` | terminal ANSI red |
| 7 | `orange` | `#D4542B` | ember-400 |
| 8 | `yellow` | `#E8A13A` | gold-400 |
| 9 | `green` | `#5FB87A` | terminal ANSI green |
| 10 | `blue` | `#5AA8E0` | terminal ANSI blue |
| 11 | `purple` | `#A878D8` | terminal ANSI purple |
| 12 | `magenta` | `#C09BE8` | terminal brightPurple |

Raycast hard-requires all twelve slots and uses 6–12 only as small semantic
glyph and badge tints. Slots 6–8 run red → ember → gold in true increasing hue
order (7° → 15° → 36°), so they read as a deliberate ramp rather than three
unrelated warms.

> **One thing to know about slot 12.** The kit has no true magenta, so `magenta`
> is the terminal's *brightPurple* — a lighter tint of slot 11 rather than a
> different hue. Consistency with the rest of the kit was worth more than
> inventing a thirteenth colour nobody has approved. Swap it freely; the schema
> does not care.

`gold-600 #B3661F` and `ember-300 #E57A53` have no slot in a twelve-colour model
and are unused here.

Contrast: parchment on ink is **17.0:1** — far past WCAG AAA.

### Alfred — where the gold is allowed to be

Gold appears in exactly six places, all of them small:

| Element | Value | Weight |
|---|---|---|
| Window hairline | `#E8A13A4D` | gold-400 @ 30% — same as the Windows sibling |
| Selected-row wash | `#E8A13A33` | gold-400 @ **20%** — a wash, never a fill |
| Separator hairline | `#E8A13A33` | gold-400 @ 20%, 1px |
| Scrollbar thumb | `#E8A13A73` | gold-400 @ 45% |
| ⌘-number (unsel / sel) | `#ECBE5BA6` / `#ECBE5BE6` | gold-300, small text |
| Subtitle, selected row | `#ECBE5BD9` | gold-300, small text |

The two large surfaces — `window.color` and `search.background` — are ink and
transparent ink respectively. **No gold surface exists in this theme**, and
because `NSVisualEffectView`'s dark material is a fixed system material that
cannot be recoloured, no gold surface is even possible here. The studio design
law comes free.

Every text colour was contrast-checked against its *composited* background
(ink at 60% over macOS dark material, then the gold wash on top):

| | Ratio | |
|---|---|---|
| Result title, unselected | 16.1:1 | AAA |
| Result title, selected | 12.2:1 | AAA |
| Result subtitle, unselected | 5.0:1 | AA |
| Result subtitle, selected | 6.0:1 | AA |
| ⌘-number, unselected | 5.2:1 | AA |
| ⌘-number, selected | 6.5:1 | AA |
| Query text | 16.1:1 | AAA |
| Query text, highlighted | 12.8:1 | AAA |

The selected row deliberately carries **more** gold than the Windows sibling's
`#24E8A13A` (14%): macOS behind-window vibrancy blurs *and desaturates* its
backdrop, so the same wash reads weaker on macOS than it does over Windows
acrylic. 20% is the compensated value.

---

## Tuning the glass

`window.color` is the one knob worth touching. Its alpha is the **ink tint
opacity over the blurred backdrop** — it is what decides slab vs. glass:

| Value | Effect |
|---|---|
| `#0A0807FF` | Opaque. **The vibrancy becomes invisible** and the whole trick dies. Never do this. |
| `#0A0807CC` | 80% — solid, ink-forward, only a hint of sky. |
| **`#0A080799`** | **60% — shipped.** Smoked glass: clearly ink-coloured, clearly moving with the sky. |
| `#0A080766` | 40% — properly glassy; the wallpaper leads and the ink is a tint. |
| `#0A080700` | Pure system material, zero tint. Loses the ink identity entirely. |

Two more, if you want them:

- **Hide the separator:** set `separator.thickness` to `0`. Most modern macOS
  themes do; this one keeps the 1px gold hairline because it is the studio's
  signature and it matches the Windows launcher.
- **Taller rows:** there is no row-height key. Height is derived from
  `result.iconSize`, the text sizes, `result.textSpacing` and
  `result.paddingVertical`. Raise `iconSize` or `paddingVertical`.

Leave `window.blur` at `0`. It is the legacy pre-4.3 translucency mechanism and
a **global** Alfred setting, not a per-theme one; setting both it and
`visualEffectMode` is a mistake no modern theme makes.

---

## Why the font isn't Sora

The wallpaper embeds Sora as base64. The launchers cannot: Alfred's `font` key is
just a display name resolved against installed fonts, there is no embedding
mechanism, and Alfred's own guidance is to use a standard font in a shared theme.
Both files ship **System / System Light** — SF Pro, the closest tasteful analogue,
and the font macOS users expect in a launcher. Nothing gets reskinned into
something unrecognisable.

If you have Sora installed and want it anyway, replace `"System Light"` and
`"System"` in the four `font` fields with `"Sora"` / `"Sora Light"`.

---

## Unverified on real hardware

Nobody on this project owns a Mac. Everything here is derived from Alfred's and
Raycast's own published sources, their documentation, and a corpus of real
published theme files — the schemas and the deep link were checked
programmatically, but **no one has opened either launcher and looked at it.**

Two specific things could not be tested:

1. **Whether Alfred's vibrancy samples a Plash window.** Behind-window vibrancy
   composites what is behind the window, and Plash draws at desktop level, so it
   should. If Plash's window turns out to be excluded, Alfred's glass falls back
   to sampling the static desktop picture underneath — you still get handsome
   dark glass, it just holds one colour instead of drifting with the sun.
2. **Which exact system material Alfred uses.** The contrast figures above assume
   a mid-dark material; a lighter one would make every ratio *better*, not worse.

The `visualEffectMode` key itself is **undocumented** — it appears nowhere in
Alfred's help or changelog. The `{0 = none, 1 = light, 2 = dark}` mapping is
inferred from Alfred's 4.3 release wording, a public VS Code → Alfred converter
that writes `2` for dark themes, and 67 real theme files in which every dark
theme uses `2` and every light theme uses `1`. Confidence is high; it is not a
published contract.

---

## Uninstall

Neither theme leaves anything outside its own launcher.

- **Raycast** — Raycast's theme store is an opaque synced blob with no file to
  delete. Remove it inside Raycast: **Settings → General → Appearance**, pick
  another theme, then delete "Liberty Hill Dusk" in Theme Studio.
- **Alfred** — **Settings → Appearance**, right-click **Liberty Hill Dusk → Delete**.
  If you used the silent drop-in, also remove that one folder under
  `…/Alfred.alfredpreferences/themes/theme.libertyhill.dusk`.
- `../uninstall.sh` removes the copies under
  `~/Library/Application Support/Liberty Hill Studios/launcher/` and prints both
  reminders. It will not reach into either app's preferences.

---

## Parity with Windows

| | Windows (Flow Launcher) | macOS |
|---|---|---|
| Translucent ink window | yes, acrylic @ 72% | yes, `NSVisualEffectView` @ 60% (Alfred); **not possible** (Raycast) |
| Gold 1px window hairline | `#4DE8A13A` | `#E8A13A4D` (Alfred) |
| Gold wash on selected row | `#24E8A13A` (14%) | `#E8A13A33` (20%, compensated) |
| Gold caret | yes | **no key exists** in either format |
| Gold search glyph | yes | **no key exists** in either format |
| Clock / date styling | yes | no such element |
| Animation | no | no |

The two missing rows are format limits, not omissions: neither Alfred nor Raycast
exposes a caret or search-icon colour.
