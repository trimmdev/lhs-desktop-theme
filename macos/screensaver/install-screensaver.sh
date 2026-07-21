#!/bin/bash
# ===========================================================================
#  Liberty Hill Studios Desktop Theme  --  macOS SCREEN SAVER installer
# ===========================================================================
#
#  WHAT THIS DOES
#    1. copies the living wallpaper -- the SAME file the desktop and the
#       Windows theme use, ../../wallpaper/lhs-dusk.html -- to
#         /Users/Shared/LibertyHillDusk/index.html
#    2. installs WebViewScreenSaver (Apache-2.0) into
#         ~/Library/Screen Savers/          (per-user; never sudo)
#    3. points that saver at the scene by writing WVSSDefaultAddressURL into
#       the bundle's Info.plist, then RE-SIGNING the bundle ad-hoc
#    4. prints the one step nobody can script for you: picking the saver in
#       System Settings, and setting Duration to -1
#
#  THE URL IS NOT NEGOTIABLE, AND BOTH HALVES MATTER
#      file:///Users/Shared/LibertyHillDusk/index.html?nosleep=1
#
#    * /Users/Shared, NOT ~/Documents or ~/Desktop or ~/Downloads. Those three
#      are TCC-protected; the sandboxed screen-saver host (legacyScreenSaver)
#      cannot read out of them and you get a black screen with no error.
#      /Users/Shared exists on every Mac, is world-writable, and needs no sudo.
#      The path is also deliberately SPACE-FREE, which sidesteps every
#      percent-encoding bug a file:// URL can have. This is why the screen
#      saver does NOT reuse the desktop theme's
#      ~/Pictures/Liberty Hill Studios path.
#
#    * ?nosleep=1 is MANDATORY. The screen-saver host reports its own web view
#      as document.hidden, and the page's normal behaviour is to stop
#      rendering when hidden -- a deliberate CPU saving that is exactly right
#      for a wallpaper and exactly wrong here. Without this flag the scene
#      freezes to a STILL FRAME, silently, with no error and no way to tell it
#      apart from working. The page implements the flag (see the comment above
#      `const NOSLEEP` in wallpaper/lhs-dusk.html). Do not "tidy it away".
#
#  WHY THIS SCRIPT LOOKS THE WAY IT DOES  (read before editing)
#    1. SHEBANG IS #!/bin/bash. That is ALWAYS GNU bash 3.2.57 on macOS
#       (Apple froze it at the last GPLv2 release). So nowhere in this file:
#       declare -A / associative arrays, mapfile / readarray, ${var^^},
#       ${var,,}, local -n, wait -n, coproc, shopt -s globstar. Also no
#       ((i++)) -- it returns 1 when i was 0, which kills the script under
#       errexit -- and no bare `local v` (that leaves v UNSET, and reading it
#       under `set -u` aborts).
#    2. NO GNU-ISMS. macOS ships BSD userland: `sed -i 's/a/b/' f` eats a real
#       argument as the backup suffix. So no `sed -i`, no `readlink -f`, no
#       `stat -c`, no `grep -P`, no `date -d`.
#    3. NO SUDO, EVER. Every path written here is per-user or world-writable.
#    4. NOTHING IS DELETED WITHOUT A GUARD. --revert removes exactly two
#       paths, both matched against a literal allow-list before any rm runs.
#    5. FAIL SAFE AND FAIL LOUD. Every step is isolated: if it cannot work it
#       says why and the rest of the run continues. The summary lists what was
#       done AND what was not.
#    6. --dry-run MUTATES NOTHING. Every mutating command goes through run().
# ===========================================================================

# --- 0. Re-exec guard: works even if invoked as `sh install-screensaver.sh` --
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -x /bin/bash ] && [ -f "$0" ]; then exec /bin/bash "$0" "$@"; fi
  echo "lhs: please run this with:  bash $0" >&2
  exit 2
fi

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace          # so the ERR trap also fires inside functions
umask 022

LHS_NAME="Liberty Hill Studios -- macOS screen saver"
LHS_STAMP="$(/bin/date +%Y%m%d-%H%M%S)"

# Resolve the repo from the script's own location, so this runs from any cwd.
# This file lives at <repo>/macos/screensaver/, so the repo is two levels up.
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO="$(cd -- "$HERE/../.." && pwd)"
SRC_PAGE="$REPO/wallpaper/lhs-dusk.html"

# --- The two paths this script owns. Nothing else is ever written. ----------
SCENE_DIR="/Users/Shared/LibertyHillDusk"
SCENE_FILE="$SCENE_DIR/index.html"
SCENE_URL="file:///Users/Shared/LibertyHillDusk/index.html?nosleep=1"

SAVER_NAME="WebViewScreenSaver.saver"
SAVER_DIR="$HOME/Library/Screen Savers"
SAVER="$SAVER_DIR/$SAVER_NAME"
SAVER_PLIST="$SAVER/Contents/Info.plist"
SYS_SAVER="/Library/Screen Savers/$SAVER_NAME"

WVSS_KEY="WVSSDefaultAddressURL"
WVSS_REPO="https://github.com/liquidx/webviewscreensaver"
WVSS_RELEASES="https://github.com/liquidx/webviewscreensaver/releases"

# --- 1. Flags --------------------------------------------------------------
DRY_RUN=0
DO_REVERT=0
ASSUME_YES=0

NOTES=""
MACOS_VER=""
MACOS_MAJOR=0
MACOS_MINOR=0

# --- 2. Output -------------------------------------------------------------
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  C_GOLD=$'\033[38;5;179m'; C_DIM=$'\033[2m'; C_RED=$'\033[38;5;174m'
  C_GRN=$'\033[38;5;108m';  C_OFF=$'\033[0m'
else
  C_GOLD=''; C_DIM=''; C_RED=''; C_GRN=''; C_OFF=''
fi

say()   { printf '%s\n' "${*:-}"; }
head1() { printf '\n%s=== %s ===%s\n' "$C_GOLD" "${*:-}" "$C_OFF"; }
head2() { printf '\n%s--%s %s\n'      "$C_GOLD" "$C_OFF" "${*:-}"; }
ok()    { printf '  %s[ok]%s   %s\n'  "$C_GRN"  "$C_OFF" "${*:-}"; }
skip()  { printf '  %s[skip]%s %s\n'  "$C_DIM"  "$C_OFF" "${*:-}"; }
warn()  { printf '  %s[warn]%s %s\n'  "$C_RED"  "$C_OFF" "${*:-}" >&2; }
info()  { printf '  %s.%s      %s\n'  "$C_DIM"  "$C_OFF" "${*:-}"; }
dry()   { printf '  %s[dry-run]%s %s\n' "$C_DIM" "$C_OFF" "${*:-}"; }
die()   { printf '\n%s[error]%s %s\n' "$C_RED"  "$C_OFF" "${*:-}" >&2; exit 1; }

lhs_on_err() {
  printf '\n%s[error]%s install-screensaver.sh: line %s exited %s.\n' \
    "$C_RED" "$C_OFF" "${2:-?}" "${1:-?}" >&2
  printf '        If that was inside a step, the step is abandoned and the\n' >&2
  printf '        rest of the run continues. Undo everything with:\n' >&2
  printf '          bash "%s/install-screensaver.sh" --revert\n' "$HERE" >&2
}
trap 'lhs_on_err "$?" "$LINENO"' ERR

# Steps run in a subshell (see guard), so summary lines go through a file.
NOTES="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/lhs-saver-notes.XXXXXX" 2>/dev/null)" || NOTES=""
lhs_cleanup() {
  if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then /bin/rm -f -- "$NOTES"; fi
  return 0
}
trap 'lhs_cleanup' EXIT

# note <ok|skip|warn> <label> <detail>   -- one line in the closing summary.
note() {
  [ -n "$NOTES" ] || return 0
  printf '%s|%s|%s\n' "${1:-ok}" "${2:-}" "${3:-}" >> "$NOTES" 2>/dev/null || true
  return 0
}

# --- 3. Help ---------------------------------------------------------------
usage() {
  cat <<'USAGE'
Liberty Hill Studios -- macOS screen saver installer

  ./install-screensaver.sh [options]

Runs the studio's living dusk scene as the macOS SCREEN SAVER, so an idle or
locked Mac shows the animated scene with its real sun and its real moon.

WITH NO OPTIONS it does four things, none of which need sudo:

  * copies wallpaper/lhs-dusk.html to
      /Users/Shared/LibertyHillDusk/index.html
    (NOT ~/Documents or ~/Desktop -- those are TCC-protected and the
     sandboxed screen-saver host cannot read out of them)
  * installs WebViewScreenSaver into ~/Library/Screen Savers/
    (via Homebrew if you have it; otherwise it prints the manual steps --
     it will NEVER install Homebrew for you)
  * writes the scene URL into the saver's Info.plist and re-signs the bundle
  * prints the manual selection step, which Apple made unscriptable

OPTIONS
  --dry-run, -n   Print every action, perform none.
  --revert        Remove the saver bundle and /Users/Shared/LibertyHillDusk,
                  then reload the screen-saver host. Combine with --dry-run
                  to preview it.
  --yes, -y       Do not prompt before the Homebrew cask install.
  --help, -h      This text.

WHAT IT WRITES  (nothing else, ever)
  /Users/Shared/LibertyHillDusk/index.html      the scene (~92 KB)
  ~/Library/Screen Savers/WebViewScreenSaver.saver

WHAT IT CANNOT DO
  Select the screen saver for you. On macOS 14+ that setting lives in a
  base64 binary plist nested inside com.apple.wallpaper's Index.plist; Apple
  DTS has confirmed the old `defaults write com.apple.screensaver moduleDict`
  route is inert. This script does not guess at undocumented formats, so the
  last click is yours. It prints exactly where to click for YOUR macOS.

Undo everything:  ./install-screensaver.sh --revert
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --revert)     DO_REVERT=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --help|-h)    usage; exit 0 ;;
    *)            usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

# ===========================================================================
#  SAFETY PRIMITIVES
# ===========================================================================

# shq -- shell-quote arguments for display.
shq() {
  if [ $# -eq 0 ]; then return 0; fi
  local out="" a=""
  for a in "$@"; do
    case "$a" in
      ''|*[!A-Za-z0-9_@%+=:,./-]*)
        out="$out '$(printf '%s' "$a" | /usr/bin/sed "s/'/'\\\\''/g")'" ;;
      *) out="$out $a" ;;
    esac
  done
  printf '%s' "${out# }"
}

# run -- THE one way this script mutates anything. Honours --dry-run.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    dry "$(shq "$@")"
    return 0
  fi
  "$@"
}

# run_soft -- run(), for commands that are ALLOWED to fail (killall on a
# process that is not running, xattr on a file with no such attribute).
# Always returns 0 so the ERR trap never fires on an expected non-failure.
run_soft() {
  if [ "$DRY_RUN" = "1" ]; then
    dry "$(shq "$@")"
    return 0
  fi
  "$@" >/dev/null 2>&1 || return 0
  return 0
}

# run_quiet -- run(), for commands whose OUTPUT is noise but whose EXIT STATUS
# is the answer (PlistBuddy, codesign). Do NOT write `run cmd >/dev/null`
# instead: that redirection also swallows the [dry-run] line, and --dry-run
# printing nothing is the one thing it must never do.
run_quiet() {
  if [ "$DRY_RUN" = "1" ]; then
    dry "$(shq "$@")"
    return 0
  fi
  "$@" >/dev/null 2>&1
}

# okd -- ok(), but never claims a thing was DONE during --dry-run.
okd() {
  if [ "$DRY_RUN" = "1" ]; then
    dry "would: ${*:-}"
  else
    ok "${*:-}"
  fi
}

# guard <fn> <label> -- run a step isolated. A failure inside it can never
# abort the rest of the run. The subshell is what makes that true: errexit
# stays ON inside the step (so it stops at its first real failure) while the
# parent keeps going. Anything a step must remember therefore goes to a file
# (the notes), never to a variable.
guard() {
  local fn="$1" label="$2" rc=0 had_e=0
  case "$-" in *e*) had_e=1 ;; esac
  set +e
  trap - ERR
  ( set -e; trap 'lhs_on_err "$?" "$LINENO"' ERR; "$fn" )
  rc=$?
  trap 'lhs_on_err "$?" "$LINENO"' ERR
  if [ "$had_e" = "1" ]; then set -e; fi
  if [ "$rc" -ne 0 ]; then
    warn "$label did not complete (exit $rc) -- the rest of the run continues"
    note warn "$label" "did not complete (exit $rc)"
  fi
  return 0
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
#  RETURN-CODE CONVENTION FOR STEPS -- keep to it when editing.
#
#  A step returns 0 once it has warn()ed and note()d a problem: it HANDLED the
#  condition, and the summary already lists it under NOT DONE. Returning
#  non-zero there would print the ERR banner ("line NNN exited 1") over a
#  situation the script anticipated and recovered from, and would list the same
#  problem twice. Non-zero is reserved for genuinely UNEXPECTED aborts, which
#  errexit raises on its own inside the guard subshell -- that is exactly what
#  the ERR banner and guard's "did not complete" message are for.
# ---------------------------------------------------------------------------

# ask_yes <prompt> -- Y/n, defaulting to yes. Returns 1 (no) when there is no
# terminal to ask on, so a piped or automated run never blocks and never
# installs anything the caller did not ask for. --yes skips the question.
ask_yes() {
  local prompt="$1" reply=""
  if [ "$ASSUME_YES" = "1" ]; then return 0; fi
  if [ ! -r /dev/tty ] || [ ! -t 1 ]; then return 1; fi
  printf '  %s[?]%s    %s [Y/n] ' "$C_GOLD" "$C_OFF" "$prompt" > /dev/tty
  IFS= read -r reply < /dev/tty || reply=""
  case "$reply" in
    ''|[Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
#  safe_rm_tree <path> -- the ONLY removal in this script.
#
#  --revert deletes directories, so this is the one place a bug could cost
#  somebody real data. The guard is an ALLOW-LIST of the two literal paths
#  this installer creates. An empty, unset, relative, or merely
#  "looks-about-right" path is refused, loudly, and the run continues.
# ---------------------------------------------------------------------------
safe_rm_tree() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    warn "internal: refusing to remove an empty path"
    return 1
  fi
  case "$target" in
    "$SCENE_DIR"|"$SAVER") ;;
    *)
      warn "refusing to remove an unexpected path: $target"
      warn "only $SCENE_DIR and $SAVER are ever removed."
      return 1 ;;
  esac
  if [ ! -e "$target" ]; then
    skip "not present: $target"
    return 0
  fi
  run /bin/rm -rf -- "$target"
  if [ "$DRY_RUN" = "1" ]; then return 0; fi   # run() already printed it
  ok "removed $target"
  return 0
}

# ---------------------------------------------------------------------------
#  macOS version. Two traps in 2026:
#    (a) SYSTEM_VERSION_COMPAT=1 makes the version come from
#        SystemVersionCompat.plist -- Big Sur reports 10.16, Tahoe reports 16.0
#    (b) Apple jumped macOS 15 (Sequoia) straight to 26 (Tahoe), so a major of
#        16..25 can only ever be a compat rendering of 26..35.
#  This matters here because the Screen Saver pane MOVED in macOS 26, and
#  printing the wrong click-path is worse than printing none.
# ---------------------------------------------------------------------------
read_macos_version() {
  MACOS_VER="$(SYSTEM_VERSION_COMPAT=0 /usr/bin/sw_vers -productVersion 2>/dev/null || true)"
  if [ -z "$MACOS_VER" ] && [ -x /usr/bin/plutil ]; then
    # `-o -` is REQUIRED: without it, `plutil -extract` WRITES A FILE.
    MACOS_VER="$(/usr/bin/plutil -extract ProductVersion raw -o - \
                 /System/Library/CoreServices/SystemVersion.plist 2>/dev/null || true)"
  fi
  if [ -z "$MACOS_VER" ]; then MACOS_MAJOR=0; MACOS_MINOR=0; return 0; fi
  MACOS_MAJOR="$(printf '%s' "$MACOS_VER" | /usr/bin/awk -F. '{print $1+0}')"
  MACOS_MINOR="$(printf '%s' "$MACOS_VER" | /usr/bin/awk -F. '{print $2+0}')"
  if [ "$MACOS_MAJOR" -eq 10 ] && [ "$MACOS_MINOR" -ge 16 ]; then
    MACOS_MAJOR=11; MACOS_MINOR=0
  elif [ "$MACOS_MAJOR" -ge 16 ] && [ "$MACOS_MAJOR" -le 25 ]; then
    MACOS_MAJOR=$((MACOS_MAJOR + 10))
  fi
  return 0
}

# ===========================================================================
#  STEP 0 -- PREFLIGHT   (the only step allowed to abort the run)
# ===========================================================================
step_preflight() {
  [ "$(/usr/bin/uname -s)" = "Darwin" ] || die "this installer is macOS-only."
  [ "$(/usr/bin/id -u)" != "0" ] || die "do not run this as root or with sudo. It does not need it, and a root-owned screen saver in your home folder is a mess to clean up."

  read_macos_version
  if [ -z "$MACOS_VER" ]; then
    warn "could not read the macOS version; the click-path advice will list every variant"
  else
    info "macOS $MACOS_VER  (major $MACOS_MAJOR)"
  fi
  return 0
}

# ===========================================================================
#  STEP 1 -- THE SCENE FILE
# ===========================================================================
#  ONE file, shared verbatim by the Windows theme, the macOS desktop
#  wallpaper and this screen saver. It is copied, never forked. If you find
#  yourself editing a second copy of this page, stop: the whole point of the
#  repo layout is that the two platforms cannot drift apart.
# ===========================================================================
step_scene() {
  if [ ! -f "$SRC_PAGE" ]; then
    warn "this does not look like the lhs-desktop-theme repo:"
    warn "  no wallpaper/lhs-dusk.html under $REPO"
    note warn "scene file" "wallpaper/lhs-dusk.html missing from the repo"
    return 0
  fi

  # The entire install depends on the page honouring ?nosleep=1. If a future
  # edit drops that flag, the saver renders one frame and freezes -- with no
  # error anywhere. Better to shout about it here than to ship a still image
  # and let somebody spend an evening on it.
  if ! /usr/bin/grep -q 'nosleep' "$SRC_PAGE" 2>/dev/null; then
    warn "wallpaper/lhs-dusk.html has no 'nosleep' handling in it."
    warn "The screen saver host reports the page as hidden, so WITHOUT that"
    warn "flag the scene will freeze to a still frame. Installing anyway, but"
    warn "expect a frozen picture until the page supports ?nosleep=1 again."
    note warn "scene file" "the page no longer implements ?nosleep=1 -- expect a frozen frame"
  fi

  if [ ! -d /Users/Shared ]; then
    warn "/Users/Shared does not exist. That is very unusual on macOS."
    warn "Without it there is no non-TCC-protected place to put the scene."
    note warn "scene file" "/Users/Shared is missing"
    return 0
  fi
  if [ ! -w /Users/Shared ] && [ ! -d "$SCENE_DIR" ]; then
    warn "/Users/Shared is not writable by you, so the scene cannot be installed"
    warn "without sudo -- and this script will not use sudo. Fix the permissions"
    warn "or install the scene by hand:"
    say  "          mkdir -p $SCENE_DIR"
    say  "          cp $(shq "$SRC_PAGE") $(shq "$SCENE_FILE")"
    note warn "scene file" "/Users/Shared is not writable -- copy it by hand"
    return 0
  fi

  run /bin/mkdir -p "$SCENE_DIR"
  run /bin/cp -f "$SRC_PAGE" "$SCENE_FILE"
  # World-readable on purpose: the screen-saver host may run outside your
  # login session, and a mode-600 file in a shared folder is the sort of thing
  # that produces a black screen and no explanation.
  run_soft /bin/chmod 0755 "$SCENE_DIR"
  run_soft /bin/chmod 0644 "$SCENE_FILE"

  if [ "$DRY_RUN" = "1" ]; then
    note ok "scene file" "would copy lhs-dusk.html -> $SCENE_FILE"
    return 0
  fi
  if [ -s "$SCENE_FILE" ]; then
    ok "scene -> $SCENE_FILE"
    info "not in ~/Documents or ~/Desktop on purpose: those are TCC-protected"
    info "and the sandboxed saver host cannot read them."
    note ok "scene file" "installed at $SCENE_FILE"
  else
    warn "the copy at $SCENE_FILE is empty"
    note warn "scene file" "copied, but the result is empty"
    return 0
  fi
  return 0
}

# ===========================================================================
#  STEP 2 -- THE SAVER BUNDLE
# ===========================================================================
#  WebViewScreenSaver, Apache-2.0, v2.5 (2025-11-15). It loads file:// URLs
#  properly (loadFileURL:allowingReadAccessToURL:), which is the whole reason
#  it is the one chosen here.
#
#  It is AD-HOC SIGNED, not Developer ID and not notarised. Homebrew's
#  --no-quarantine flag is what turns a five-click Gatekeeper detour into
#  nothing at all; without it macOS 15+ requires
#    System Settings > Privacy & Security > (scroll to the bottom) > Open Anyway
#  because macOS 15 removed the old Control-click > Open bypass.
#
#  ~/Library/Screen Savers is per-user, so NO SUDO is involved anywhere here.
# ===========================================================================
brew_bin() {
  local b=""
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then printf '%s' "$b"; return 0; fi
  done
  if have_cmd brew; then command -v brew; return 0; fi
  return 1
}

print_manual_saver_steps() {
  say ""
  say "        Install it by hand -- four commands, no sudo:"
  say ""
  say "          curl -L -o /tmp/wvss.zip \\"
  say "            \"$WVSS_RELEASES/latest/download/WebViewScreenSaver.saver.zip\""
  say "          unzip -o /tmp/wvss.zip -d /tmp/wvss"
  say "          xattr -d com.apple.quarantine /tmp/wvss/$SAVER_NAME"
  say "          mkdir -p $(shq "$SAVER_DIR")"
  say "          cp -R /tmp/wvss/$SAVER_NAME $(shq "$SAVER_DIR")/"
  say ""
  say "        (Check the asset name on the releases page first -- it has"
  say "        changed between releases:"
  say "          $WVSS_RELEASES )"
  say ""
  say "        The xattr line is what avoids the Gatekeeper detour. If you"
  say "        skip it, macOS will refuse the saver until you go to"
  say "        System Settings > Privacy & Security, scroll to the BOTTOM,"
  say "        click \"Open Anyway\" and authenticate. On macOS 15+ that pane"
  say "        is the only route -- Control-click > Open no longer works."
  say ""
  say "        Then re-run this script to point it at the scene:"
  say "          bash $(shq "$HERE/install-screensaver.sh")"
  return 0
}

step_saver() {
  local brew=""

  if [ -d "$SYS_SAVER" ]; then
    warn "there is also a system-wide copy at $SYS_SAVER"
    warn "This script only manages the per-user one and will not touch that,"
    warn "because removing it would need sudo. If System Settings shows two"
    warn "WebViewScreenSaver entries, that is why."
  fi

  if [ -d "$SAVER" ]; then
    ok "WebViewScreenSaver is already installed -- not reinstalling"
    info "$SAVER"
    info "only its URL is being re-pointed below."
    note ok "saver bundle" "already installed -- re-pointed, not reinstalled"
    return 0
  fi

  brew="$(brew_bin || true)"
  if [ -z "$brew" ]; then
    warn "WebViewScreenSaver is not installed, and Homebrew is not here either."
    info "This script will NEVER install Homebrew for you."
    print_manual_saver_steps
    note warn "saver bundle" "not installed -- no Homebrew; manual steps printed"
    return 0
  fi

  info "Homebrew found: $brew"
  say  "        It would run:"
  say  "          $brew install --cask --no-quarantine webviewscreensaver"
  say  "        --no-quarantine is deliberate: the bundle is ad-hoc signed, not"
  say  "        notarised, so without it macOS makes you approve it by hand in"
  say  "        System Settings > Privacy & Security > Open Anyway."
  say  "        Source: $WVSS_REPO  (Apache-2.0)"

  if ! ask_yes "Install WebViewScreenSaver with Homebrew now?"; then
    skip "not installing it (no confirmation)"
    print_manual_saver_steps
    note skip "saver bundle" "declined or non-interactive -- manual steps printed"
    return 0
  fi

  if ! run "$brew" install --cask --no-quarantine webviewscreensaver; then
    warn "the Homebrew cask install failed."
    print_manual_saver_steps
    note warn "saver bundle" "brew cask install failed -- manual steps printed"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    note ok "saver bundle" "would install via the Homebrew cask"
    return 0
  fi
  if [ -d "$SAVER" ]; then
    ok "WebViewScreenSaver installed -> $SAVER"
    note ok "saver bundle" "installed via the Homebrew cask"
  else
    warn "the cask reported success but $SAVER is not there."
    warn "Some cask versions install elsewhere. Find it with:"
    say  "          find ~/Library /Library -maxdepth 3 -name '$SAVER_NAME' 2>/dev/null"
    note warn "saver bundle" "cask ran, but the bundle is not at the expected path"
    return 0
  fi
  return 0
}

# ===========================================================================
#  STEP 3 -- POINT THE SAVER AT THE SCENE
# ===========================================================================
#  Two ways exist to pre-seed the URL. This uses the reliable one.
#
#  (1) THE BUNDLE'S Info.plist -- WVSSDefaultAddressURL, read from the bundle
#      at runtime. Simple, inspectable, and it survives a re-login. Its cost:
#      editing Info.plist INVALIDATES the ad-hoc signature, so the bundle MUST
#      be re-signed or macOS will refuse to load it. And it inherits the
#      300-second default duration, which is why you still want Duration = -1
#      in the Options sheet.
#
#  (2) THE CONTAINER PREFERENCES -- domain net.liquidx.WebViewScreenSaver,
#      array kScreenSaverURLList of {kScreenSaverURL, kScreenSaverTime}. This
#      one CAN carry duration -1. It is not used here: since macOS 10.15 the
#      domain lives inside the sandboxed host's container and upstream's own
#      README lists FOUR candidate paths depending on OS and architecture.
#      Guessing which of four undocumented paths applies to your Mac is
#      exactly the kind of shortcut this repo does not take.
#
#  DURATION. WebViewScreenSaver reloads the URL on a timer unless the duration
#  is NEGATIVE -- its source reads `if (address.duration < 0) return; //
#  Infinite`. The default is 300s, so out of the box you get a visible flash
#  and a restarted scene every five minutes. Set it to -1 once, in Options.
#  That single field is the one thing route (1) cannot do for you.
# ===========================================================================
step_point_url() {
  local backup="" got=""

  if [ ! -d "$SAVER" ]; then
    skip "the saver bundle is not installed yet -- nothing to point"
    info "install it (see above), then re-run this script."
    note skip "scene URL" "saver not installed -- URL not seeded"
    return 0
  fi
  if [ ! -f "$SAVER_PLIST" ]; then
    warn "$SAVER_PLIST is missing -- the bundle looks damaged."
    warn "Reinstall it, then re-run this script."
    note warn "scene URL" "the bundle has no Contents/Info.plist"
    return 0
  fi

  # Quarantine check. We report it and print the command rather than silently
  # stripping it: taking a Gatekeeper flag off a user's downloaded bundle is
  # their call to make knowingly, not a side effect of a theme installer.
  if have_cmd xattr; then
    if /usr/bin/xattr -p com.apple.quarantine "$SAVER" >/dev/null 2>&1; then
      warn "this bundle is still quarantined, so macOS will refuse to load it."
      say  "        Either clear the flag:"
      say  "          xattr -dr com.apple.quarantine $(shq "$SAVER")"
      say  "        or approve it once in System Settings > Privacy & Security"
      say  "        (scroll to the BOTTOM) > \"Open Anyway\"."
      note warn "gatekeeper" "the bundle is quarantined -- clear it or click Open Anyway"
    fi
  fi

  # Back the plist up ONCE, before the first edit. This is what makes the
  # re-sign failure below recoverable: restoring the ORIGINAL bytes restores
  # the original hash, which makes the original ad-hoc signature valid again.
  backup="$SAVER_PLIST.lhs-backup"
  if [ ! -f "$backup" ]; then
    run /bin/cp -p "$SAVER_PLIST" "$backup"
    info "kept a pristine copy at $backup"
  fi

  # Set first; Add only if the key is absent. During --dry-run run_quiet is a
  # no-op that returns 0, so only the Set branch is printed -- that is the
  # branch a bundle shipped with the key takes.
  if run_quiet /usr/libexec/PlistBuddy -c "Set :$WVSS_KEY $SCENE_URL" "$SAVER_PLIST"; then
    okd "$WVSS_KEY set"
  elif run_quiet /usr/libexec/PlistBuddy -c "Add :$WVSS_KEY string $SCENE_URL" "$SAVER_PLIST"; then
    okd "$WVSS_KEY added"
  else
    warn "PlistBuddy could not write $WVSS_KEY into $SAVER_PLIST"
    warn "You can still set the URL by hand in the saver's Options sheet."
    note warn "scene URL" "PlistBuddy failed -- set the URL by hand in Options"
    return 0
  fi
  info "URL: $SCENE_URL"

  # Read it back. A blind write is how you end up certain of something untrue.
  if [ "$DRY_RUN" != "1" ]; then
    got="$(/usr/libexec/PlistBuddy -c "Print :$WVSS_KEY" "$SAVER_PLIST" 2>/dev/null || true)"
    if [ "$got" != "$SCENE_URL" ]; then
      warn "read-back does not match. Info.plist now says: ${got:-<nothing>}"
      note warn "scene URL" "written, but the read-back did not match"
      return 0
    fi
    ok "read-back matches"
  fi

  # RE-SIGN. Editing Info.plist broke the ad-hoc signature; an unsigned or
  # badly-signed .saver simply will not load, and the symptom is a black
  # screen with nothing in the log that names this file.
  if ! have_cmd codesign; then
    warn "codesign is not available, so the bundle cannot be re-signed."
    warn "Editing Info.plist invalidated its signature, and macOS will very"
    warn "likely refuse to load it. Restoring the original Info.plist so the"
    warn "saver keeps working, and you can set the URL by hand in Options."
    run /bin/cp -p "$backup" "$SAVER_PLIST"
    note warn "scene URL" "no codesign -- reverted the plist; set the URL by hand in Options"
    return 0
  fi

  if run_quiet /usr/bin/codesign --force --deep --sign - --timestamp=none "$SAVER"; then
    okd "bundle re-signed ad-hoc"
  else
    warn "re-signing failed. An edited-but-unsigned .saver will not load, so"
    warn "the original Info.plist is being put back -- the saver keeps working,"
    warn "you just have to type the URL into the Options sheet yourself:"
    say  ""
    say  "          $SCENE_URL"
    say  ""
    run /bin/cp -p "$backup" "$SAVER_PLIST"
    note warn "scene URL" "codesign failed -- reverted the plist; set the URL by hand in Options"
    return 0
  fi

  if [ "$DRY_RUN" != "1" ]; then
    if /usr/bin/codesign --verify "$SAVER" >/dev/null 2>&1; then
      ok "signature verifies"
    else
      warn "the signature still does not verify. If the saver shows a black"
      warn "screen, reinstall the bundle and set the URL by hand in Options."
      note warn "scene URL" "seeded, but the signature does not verify"
      return 0
    fi
  fi

  note ok "scene URL" "Info.plist seeded with the ?nosleep=1 URL and re-signed"
  return 0
}

# ===========================================================================
#  STEP 4 -- RELOAD THE HOST
# ===========================================================================
#  legacyScreenSaver is the sandboxed process that hosts .saver plugins. It
#  caches the bundle, so a freshly installed or freshly edited saver is not
#  picked up until it restarts. Killing it is safe: launchd starts it again on
#  demand, and it owns nothing you can lose. No logout required.
# ===========================================================================
step_reload_host() {
  run_soft /usr/bin/killall legacyScreenSaver
  okd "screen-saver host reloaded (nothing to lose if it was not running)"
  note ok "host reload" "killall legacyScreenSaver"
  return 0
}

# ===========================================================================
#  --revert
# ===========================================================================
step_revert() {
  safe_rm_tree "$SAVER" || true
  safe_rm_tree "$SCENE_DIR" || true
  run_soft /usr/bin/killall legacyScreenSaver
  ok "screen-saver host reloaded"
  say ""
  info "If WebViewScreenSaver was your selected screen saver, macOS falls back"
  info "on its own; pick another one in System Settings whenever you like."
  if have_cmd brew; then
    info "Installed via Homebrew? Also run:  brew uninstall --cask webviewscreensaver"
  fi
  note ok "revert" "saver bundle and $SCENE_DIR removed"
  return 0
}

# ===========================================================================
#  THE MANUAL STEP
# ===========================================================================
#  Selecting a screen saver CANNOT be scripted on macOS 14+. The old
#  `defaults -currentHost write com.apple.screensaver moduleDict` has been
#  inert since Sonoma (confirmed by Apple DTS); the state moved into a base64
#  binary plist nested inside
#    ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
#  and that format is undocumented. We do not write undocumented formats, so
#  this is printed instead of performed. It is four clicks.
# ===========================================================================
print_selection_steps() {
  case "$MACOS_MAJOR" in
    13)
      say " 1. System Settings > Screen Saver > WebViewScreenSaver"
      say "    (it is at the BOTTOM of the list, under the Apple ones) > Options"
      ;;
    14|15)
      say " 1. System Settings > Screen Saver > Other > WebViewScreenSaver > Options"
      ;;
    0)
      say " 1. Pick the saver in System Settings. The pane moved between"
      say "    releases and your macOS version could not be read, so:"
      say "      macOS 13:     Screen Saver > WebViewScreenSaver (bottom) > Options"
      say "      macOS 14/15:  Screen Saver > Other > WebViewScreenSaver > Options"
      say "      macOS 26:     Wallpaper > Screen Saver > Custom > Other >"
      say "                    WebViewScreenSaver > Options"
      ;;
    *)
      if [ "$MACOS_MAJOR" -ge 26 ]; then
        say " 1. System Settings > Wallpaper > Screen Saver > Custom > Other >"
        say "    WebViewScreenSaver > Options"
        say "    (macOS 26 removed the standalone Screen Saver pane -- it lives"
        say "    inside Wallpaper now.)"
      else
        say " 1. System Settings > Screen Saver > WebViewScreenSaver > Options"
        say "    (macOS $MACOS_VER is older than this port was reasoned for; the"
        say "    saver still appears in the list, possibly at the bottom.)"
      fi
      ;;
  esac
  say ""
  say "    If the Options button does nothing, QUIT System Settings entirely"
  say "    (Cmd-Q, not just the window) and reopen it. That is a known macOS"
  say "    bug with no workaround in code."
  return 0
}

# ===========================================================================
#  RUN
# ===========================================================================
head1 "$LHS_NAME"
if [ "$DRY_RUN" = "1" ]; then
  say ""
  say "  DRY RUN. Every action below is printed and NOTHING is changed."
fi
say ""
info "repo:  $REPO"
info "scene: $SCENE_FILE"
info "saver: $SAVER"

head2 "preflight"
step_preflight          # the only step allowed to abort the run

if [ "$DO_REVERT" = "1" ]; then
  head2 "revert"
  guard step_revert "revert"

  head1 "summary"
  say ""
  say "  Removed (if they were there):"
  say "    $SAVER"
  say "    $SCENE_DIR"
  say ""
  say "  Nothing else was ever written, so nothing else needs undoing."
  say "  Reinstall any time:  bash \"$HERE/install-screensaver.sh\""
  say ""
  exit 0
fi

head2 "scene file"
guard step_scene "scene file"

head2 "saver bundle"
guard step_saver "saver bundle"

head2 "scene URL"
guard step_point_url "scene URL"

head2 "reload"
guard step_reload_host "host reload"

# ---------------------------------------------------------------------------
head1 "summary"
if [ -n "$NOTES" ] && [ -s "$NOTES" ]; then
  say ""
  say "  DONE"
  if /usr/bin/grep -q '^ok|' "$NOTES" 2>/dev/null; then
    /usr/bin/awk -F'|' '$1=="ok"{printf "    %s+%s %-14s %s\n", g, o, $2, $3}' \
      g="$C_GRN" o="$C_OFF" "$NOTES"
  else
    say "    (nothing)"
  fi
  say ""
  say "  NOT DONE"
  if /usr/bin/grep -qv '^ok|' "$NOTES" 2>/dev/null; then
    /usr/bin/awk -F'|' '$1!="ok"{printf "    %s-%s %-14s %s\n", d, o, $2, $3}' \
      d="$C_DIM" o="$C_OFF" "$NOTES"
  else
    say "    (nothing -- everything applied)"
  fi
else
  info "(no per-item notes were recorded)"
fi

head1 "what is left for you"
say ""
say " Apple made screen-saver SELECTION unscriptable in macOS 14, so these two"
say " steps are yours. They take about twenty seconds."
say ""
print_selection_steps
say ""
say " 2. In that Options sheet, set DURATION to -1."
say ""
say "    The URL is already filled in for you. Duration is the one field this"
say "    script cannot pre-set. Anything zero or above makes the saver RELOAD"
say "    the page on a timer -- 300 seconds by default -- which you see as a"
say "    flash and a restarted scene every five minutes. -1 means infinite."
say ""
say " The URL, if you ever need to retype it (both parts matter):"
say ""
say "     $SCENE_URL"
say ""
say " ?nosleep=1 is NOT decoration. The saver host reports the page as hidden,"
say " and the page pauses rendering when hidden to save CPU as a wallpaper."
say " Without the flag you get a frozen still frame and no error at all."
say ""
say " Check it is really animating: click Preview. If you want to confirm the"
say " scene renders at all, temporarily append  &at=2026-07-21T20:30  to the"
say " URL -- that forces a dusk sky regardless of the real hour."
say ""
say " Undo everything:  bash \"$HERE/install-screensaver.sh\" --revert"
say ""
