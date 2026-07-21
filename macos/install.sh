#!/bin/bash
# ===========================================================================
#  Liberty Hill Studios Desktop Theme  --  macOS installer
# ===========================================================================
#
#  WHAT THE DEFAULT INSTALL DOES  (no flags)
#    1. copies the living wallpaper to
#         ~/Pictures/Liberty Hill Studios/Living Dusk/index.html
#    2. copies the baked stills to
#         ~/Pictures/Liberty Hill Studios/stills/
#    3. sets the STATIC desktop picture -- the best-fitting still -- on every
#       display, through the one public Apple API for it (NSWorkspace)
#    4. prints how to point Plash at the folder for the ANIMATED wallpaper
#
#  That is the whole default install: it is a wallpaper. Exactly one thing on
#  the Mac changes, and it is the desktop picture.
#
#  EVERYTHING ELSE IS OPT-IN, ONE FLAG EACH, ALL OFF BY DEFAULT
#    --terminal   Liberty Hill Dusk colour scheme, only for emulators that are
#                 actually installed
#    --launcher   Raycast + Alfred themes, only for launchers that are actually
#                 installed
#    --accent     dark mode + gold accent + gold text-selection highlight
#    --icon       the studio .icns on the assets folder
#    --dry-run    print every action, perform none
#    --help
#
#  DELIBERATELY NOT HERE, AND NOT COMING
#    * window management (Rectangle / a FancyZones equivalent). macOS should
#      feel like macOS; snap-to-zone is a Windows idiom and imposing keyboard
#      shortcuts is a behaviour change dressed up as a theme.
#    * notification / per-event sounds. macOS has NO per-event sound mapping:
#      one global Alert sound and two on/off toggles, no per-app API. There is
#      nothing to port, so nothing is shipped and nothing is claimed.
#
# ---------------------------------------------------------------------------
#  WHY THIS SCRIPT LOOKS THE WAY IT DOES  (read before editing)
# ---------------------------------------------------------------------------
#  1. SHEBANG IS #!/bin/bash, NOT #!/usr/bin/env bash.
#     /bin/bash exists on every macOS and is ALWAYS GNU bash 3.2.57 (Apple
#     froze it at the last GPLv2 release). `env bash` would pick a Homebrew
#     bash 5 on some machines and Apple's 3.2 on others, so behaviour would
#     depend on the reader's PATH. We pin one target and write strictly
#     3.2-compatible code -- which also runs fine on 4.x/5.x.
#
#     Therefore, NOWHERE in this file: declare -A / associative arrays,
#     mapfile / readarray, ${var^^} / ${var,,}, local -n, wait -n, ${v@Q},
#     ;;&, coproc, shopt -s globstar|lastpipe|inherit_errexit, EPOCHSECONDS.
#     Also no ((i++)) -- it returns 1 when i was 0, which kills the script
#     under errexit -- and no bare `local v` (that leaves v UNSET, and reading
#     it under `set -u` aborts).
#
#  2. NO GNU-ISMS. macOS ships BSD userland. `sed -i 's/a/b/' f` treats
#     's/a/b/' as the BACKUP SUFFIX and eats a real argument. So: no `sed -i`
#     anywhere, no `readlink -f`, no `date -d`, no `grep -P`, no `stat -c`,
#     no `base64 -w`, no `awk` interval expressions like {6}.
#
#  3. NOTHING DESTRUCTIVE. No sudo. No `rm -rf`. No SIP/Gatekeeper tampering
#     (no csrutil, no spctl, no `xattr -d com.apple.quarantine`). No killall
#     of a user app. Any file we would overwrite is copied to
#     <file>.lhs-backup-<timestamp> first, and every change is recorded so
#     ./uninstall.sh can reverse it.
#
#  4. FAIL SAFE AND FAIL LOUD. Every step runs isolated: if it cannot work it
#     says why and the rest of the install continues. The run never ends
#     half-configured and never claims to have done something it did not do.
#     The summary at the end lists what was done AND what was not.
#
#  5. --dry-run PERFORMS NO MUTATION. Every mutating command goes through
#     run() (or, for the two ObjC-bridge calls that cannot be an argv list,
#     through a wrapper that honours the same flag).
# ===========================================================================

# --- 0. Re-exec guard: works even if invoked as `sh install.sh` -------------
# On macOS /bin/sh IS bash 3.2 running as argv[0]="sh", so BASH_VERSION is SET
# and only POSIX mode gives it away. Testing BASH_VERSION alone would let the
# whole script run in POSIX mode instead of the interpreter the header pins.
# `/bin/bash` invoked as `bash` is never in POSIX mode, so this cannot loop.
if [ -z "${BASH_VERSION:-}" ] || shopt -qo posix 2>/dev/null; then
  if [ -x /bin/bash ] && [ -f "$0" ]; then exec /bin/bash "$0" "$@"; fi
  echo "lhs: please run this with:  bash $0" >&2
  exit 2
fi

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace          # so the ERR trap also fires inside functions
umask 022
# Deliberately NOT setting IFS=$'\n\t': it silently changes "$*" joining and
# word-splitting for every later line, which is a net risk in a script nobody
# on this project can test.

LHS_NAME="Liberty Hill Studios Desktop Theme"
LHS_STAMP="$(/bin/date +%Y%m%d-%H%M%S)"

# Resolve the repo from the script's own location, so this runs from any cwd.
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO="$(cd -- "$HERE/.." && pwd)"

ASSETS="$HOME/Pictures/Liberty Hill Studios"
LIVE="$ASSETS/Living Dusk"                 # Plash gets THIS folder, not a file
STILLS="$ASSETS/stills"
SUPPORT="$HOME/Library/Application Support/Liberty Hill Studios"
MANIFEST="$SUPPORT/install-manifest.txt"   # every file we created
UNDO="$SUPPORT/undo.log"                   # verbs uninstall.sh replays
TSV="$SUPPORT/appearance-backup.tsv"       # pre-install values of every key

# --- 1. Flags --------------------------------------------------------------
DO_TERMINAL=0
DO_LAUNCHER=0
DO_ACCENT=0
DO_ICON=0
DRY_RUN=0

NOTES=""                                   # temp file: per-step summary lines
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
  printf '\n%s[error]%s install.sh: line %s exited %s.\n' \
    "$C_RED" "$C_OFF" "${2:-?}" "${1:-?}" >&2
  printf '        If that was inside a step, the step is abandoned and the\n' >&2
  printf '        rest of the install continues. Undo anything already applied\n' >&2
  printf '        with:  bash "%s/uninstall.sh"\n' "$HERE" >&2
}
trap 'lhs_on_err "$?" "$LINENO"' ERR

# Steps run in a subshell (see guard), so summary lines go through a file.
NOTES="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/lhs-notes.XXXXXX" 2>/dev/null)" || NOTES=""
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

# note_done <label> <did-text> <would-text> -- an "ok" note whose wording flips
# in a dry run. Nothing may appear under DONE that a dry run did not do.
note_done() {
  if [ "$DRY_RUN" = "1" ]; then
    note ok "${1:-}" "${3:-}"
  else
    note ok "${1:-}" "${2:-}"
  fi
  return 0
}

# --- 3. Help ---------------------------------------------------------------
usage() {
  cat <<'USAGE'
Liberty Hill Studios Desktop Theme -- macOS installer

  ./install.sh [options]

WITH NO OPTIONS it does exactly four things, and changes exactly one macOS
setting (your desktop picture):

  * copies the living wallpaper to
      ~/Pictures/Liberty Hill Studios/Living Dusk/index.html
  * copies the baked stills to
      ~/Pictures/Liberty Hill Studios/stills/
  * sets the best-fitting still as the desktop picture on every display
  * prints how to point Plash at that folder for the animated version

OPTIONS
  --terminal   Install the Liberty Hill Dusk colour scheme for the terminal
               emulators that are actually installed. Never edits a config
               file you already have -- it drops the theme next to it and
               prints the one line to add.
  --launcher   Install the Liberty Hill Dusk theme for Raycast and Alfred,
               for whichever is actually installed. Both need one click from
               you to apply, and both have a paywall -- see the notes it
               prints. Neither launcher can be animated; nothing here claims
               otherwise.
  --accent     Dark mode + gold accent + gold text-selection highlight.
               Every key is backed up first and reversed exactly.
  --icon       Put the studio icon on ~/Pictures/Liberty Hill Studios.
  --dry-run    Print every action, perform none.
  --help, -h   This text.

NOT INCLUDED, ON PURPOSE
  * No window manager and no snap-to-zone layouts. macOS should feel like
    macOS.
  * No notification sounds. macOS has no per-event sound mapping to hook.
  * No app is ever installed for you, with or without a flag.

EXAMPLES
  ./install.sh --dry-run                 preview; changes nothing
  ./install.sh                           the wallpaper, and only the wallpaper
  ./install.sh --terminal --accent       plus terminals and the gold accent
  ./install.sh --terminal --launcher --accent --icon    everything

WHAT IT WRITES  (nothing else, ever)
  ~/Pictures/Liberty Hill Studios/                    the assets (~172 MB)
  ~/Library/Application Support/Liberty Hill Studios/ state, backups, themes
  ~/.config/{kitty,alacritty,wezterm,ghostty}/...     only with --terminal,
                                                      only for apps you have
  a few NSGlobalDomain keys                           only with --accent

Undo everything:  ./uninstall.sh        (add --dry-run to preview that too)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --terminal)   DO_TERMINAL=1 ;;
    --launcher)   DO_LAUNCHER=1 ;;
    --accent)     DO_ACCENT=1 ;;
    --icon)       DO_ICON=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
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

# guard <fn> <label> -- run a step isolated. A failure inside it can never
# abort the rest of the install. The subshell is what makes that true: errexit
# stays ON inside the step (so it stops at its first real failure) while the
# parent keeps going. Everything a step needs to remember therefore goes to a
# file (the manifest, the undo log, the notes), never to a variable.
guard() {
  local fn="$1" label="$2" rc=0 had_e=0
  case "$-" in *e*) had_e=1 ;; esac
  set +e
  # The ERR trap fires regardless of errexit, so without this the parent would
  # print a second banner naming guard's own line -- true but useless. The
  # trap is re-armed INSIDE the subshell, which is where the interesting line
  # number is, and re-armed here afterwards.
  trap - ERR
  ( set -e; trap 'lhs_on_err "$?" "$LINENO"' ERR; "$fn" )
  rc=$?
  trap 'lhs_on_err "$?" "$LINENO"' ERR
  if [ "$had_e" = "1" ]; then set -e; fi
  if [ "$rc" -ne 0 ]; then
    warn "$label did not complete (exit $rc) -- the rest of the install continues"
    note warn "$label" "did not complete (exit $rc)"
  fi
  return 0
}

# record_path -- remember a file we created, so uninstall.sh can remove it.
record_path() {
  [ "$DRY_RUN" = "1" ] && return 0
  /bin/mkdir -p "$SUPPORT" 2>/dev/null || return 0
  if [ -f "$MANIFEST" ] && /usr/bin/grep -qxF -- "$1" "$MANIFEST" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$1" >> "$MANIFEST" 2>/dev/null || true
  return 0
}

# record_undo -- append a verb for uninstall.sh to replay in reverse.
#
# THE FORMAT IS TAB-SEPARATED, NOT A SHELL COMMAND LINE:  <verb><TAB><argument>
# uninstall.sh splits on the tab, matches the verb token EXACTLY against its
# two known verbs, and calls the matching shell function with the argument as
# one word. It never evaluates any of this. That is deliberate: a shell-command
# line would have to be eval'd, and an eval whose input lives in a file the
# user can edit is a hole no amount of quoting closes honestly.
#
# Only two verbs exist, and uninstall.sh executes nothing else:
#   lhs_restore_wallpaper<TAB><path>     lhs_clear_folder_icon<TAB><dir>
record_undo() {
  [ "$DRY_RUN" = "1" ] && return 0
  # Exactly one tab, so the reader's split can never be ambiguous. A path with
  # a tab in it is vanishingly rare and not worth a broken undo log: we decline
  # to record it and say so, rather than write a line that parses wrong.
  case "$1" in
    *$'\t'*$'\t'*)
      warn "not recording an undo step: it contains more than one tab"
      return 0 ;;
    *$'\t'*) ;;
    *)
      warn "not recording a malformed undo step (no tab): $1"
      return 0 ;;
  esac
  /bin/mkdir -p "$SUPPORT" 2>/dev/null || return 0
  if [ ! -f "$UNDO" ]; then
    {
      printf '# Liberty Hill Studios -- generated undo log.\n'
      printf '# uninstall.sh replays these lines in REVERSE order.\n'
      printf '# Format: <verb><TAB><argument>. NOT a shell command line --\n'
      printf '# uninstall.sh matches the verb exactly and evaluates nothing.\n'
    } > "$UNDO" 2>/dev/null || return 0
  fi
  if /usr/bin/grep -qxF -- "$1" "$UNDO" 2>/dev/null; then return 0; fi
  printf '%s\n' "$1" >> "$UNDO" 2>/dev/null || true
  return 0
}

# backup_file -- copy a file aside BEFORE we overwrite it, at most ONCE ever.
#
# Once-only matters: a second run must never back up the already-installed
# file over the pristine original. That is the most common backup bug there
# is. Stated so it is not mistaken for one: if you edit that file yourself
# after installing and re-run, you do not get a second backup. The first one
# is the one worth keeping.
#
# Backups are never recorded in the manifest, so uninstall.sh never deletes
# them (unless you ask it to with --purge-backups).
backup_file() {
  local target="$1" existing="" dest=""
  [ -e "$target" ] || return 0
  existing="$(/bin/ls -1d "$target".lhs-backup-* 2>/dev/null | /usr/bin/head -n 1 || true)"
  if [ -n "$existing" ]; then
    info "backup already exists (kept as the pristine copy): $existing"
    return 0
  fi
  dest="$target.lhs-backup-$LHS_STAMP"
  # Checked explicitly rather than left to errexit: every caller is inside an
  # `if`, which SUPPRESSES errexit for the whole function body. Without this
  # test a failed backup would fall through and the original would be
  # overwritten anyway -- the one outcome this script must never produce.
  if ! run /bin/cp -p "$target" "$dest"; then
    warn "could not back up $target -- refusing to overwrite it"
    return 1
  fi
  info "backed up $target"
  return 0
}

# install_file <src> <dst> -- backup, copy, record. The workhorse.
#
# Returns 0 ONLY if the file is really there afterwards. Same reason as above:
# callers use `if install_file ...`, which disables errexit inside this
# function, so each step is tested by hand.
install_file() {
  local src="$1" dst="$2"
  [ -f "$src" ] || return 1
  run /bin/mkdir -p "$(dirname -- "$dst")" || return 1
  # Only back up when there is something to preserve. Re-running the installer
  # over an identical file must not litter the disk with copies of our own
  # work -- but a file YOU edited is different from ours, and gets kept.
  if [ -e "$dst" ] && ! /usr/bin/cmp -s "$src" "$dst" 2>/dev/null; then
    backup_file "$dst" || return 1
  fi
  run /bin/cp -f "$src" "$dst" || return 1
  record_path "$dst"
  return 0
}

# (There used to be an install_text() here, for theme content carried INLINE in
# this script. It is gone with the inline themes it existed for: every file
# this installer writes now comes from a repo file, so there is exactly one
# source of truth per theme and nothing to drift.)

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# app_path <Name.app> -- echo where it is, or return 1. No Apple event, so no
# Automation permission prompt (unlike `osascript -e 'id of app "..."'`).
app_path() {
  local n="$1" d=""
  for d in /Applications "$HOME/Applications" /Applications/Utilities \
           /System/Applications /System/Applications/Utilities; do
    if [ -d "$d/$n" ]; then printf '%s' "$d/$n"; return 0; fi
  done
  return 1
}

# app_glob <pattern> -- for version-numbered bundles like "Alfred 5.app".
app_glob() {
  local pat="$1" d=""
  for d in /Applications/$pat "$HOME"/Applications/$pat; do
    if [ -d "$d" ]; then printf '%s' "$d"; return 0; fi
  done
  return 1
}

# ---------------------------------------------------------------------------
#  macOS version. Two traps in 2026:
#    (a) SYSTEM_VERSION_COMPAT=1 makes the version come from
#        SystemVersionCompat.plist -- Big Sur reports 10.16, Tahoe reports 16.0
#    (b) Apple jumped macOS 15 (Sequoia) straight to 26 (Tahoe), so a major of
#        16..25 can only ever be a compat rendering of 26..35.
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

# ---------------------------------------------------------------------------
#  defaults(1) rules, all learned the hard way by other people:
#    * NEVER hand-edit ~/Library/Preferences/*.plist -- cfprefsd caches them
#      in memory and will overwrite you. Always go through /usr/bin/defaults.
#    * `defaults delete` EXITS 1 when the key is absent, so every delete needs
#      `|| true` or it kills an uninstall halfway through.
#    * Light Mode is the ABSENCE of AppleInterfaceStyle. Never write "Light".
# ---------------------------------------------------------------------------
backup_key() {
  local d="$1" k="$2" t="" v="" lines=0
  if [ "$DRY_RUN" = "1" ]; then
    dry "record the current value of $d $k (for uninstall)"
    return 0
  fi
  /bin/mkdir -p "$SUPPORT" 2>/dev/null || return 0
  [ -f "$TSV" ] || : > "$TSV"
  # Write-once: keep the pristine baseline across re-runs.
  if /usr/bin/awk -F'\t' -v d="$d" -v k="$k" \
       '$1==d && $2==k {found=1} END {exit found?0:1}' "$TSV" 2>/dev/null; then
    return 0
  fi
  if v="$(/usr/bin/defaults read "$d" "$k" 2>/dev/null)"; then
    lines="$(printf '%s\n' "$v" | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
    if [ "$lines" != "1" ]; then
      warn "$d $k is not a simple value -- NOT recorded, so it will NOT be reverted"
      return 0
    fi
    t="$(/usr/bin/defaults read-type "$d" "$k" 2>/dev/null | /usr/bin/sed 's/^Type is //')"
    printf '%s\t%s\t%s\t%s\n' "$d" "$k" "$t" "$v" >> "$TSV"
  else
    printf '%s\t%s\t%s\t%s\n' "$d" "$k" "ABSENT" "" >> "$TSV"
  fi
  return 0
}

# set_default <domain> <key> <-type> <value>
set_default() {
  local d="$1" k="$2" t="$3" v="$4" cur=""
  backup_key "$d" "$k"
  cur="$(/usr/bin/defaults read "$d" "$k" 2>/dev/null || true)"
  if [ "$t" = "-bool" ]; then
    case "$cur" in 1) cur="true" ;; 0) cur="false" ;; esac
  fi
  if [ "$cur" = "$v" ]; then
    skip "$d $k is already $v"
    return 0
  fi
  run /usr/bin/defaults write "$d" "$k" "$t" "$v"
  ok "$d $k = $v"
  return 0
}

# ===========================================================================
#  THE OBJC BRIDGE
# ===========================================================================
#  Two system calls in this installer are Objective-C, not shell:
#    -[NSWorkspace setDesktopImageURL:forScreen:options:error:]   (10.6 -> now)
#    -[NSWorkspace setIcon:forFile:options:]
#  Both are called IN-PROCESS from osascript, so no Apple event leaves the
#  process and macOS raises NO "wants access to control ..." prompt.
#
#  They cannot be expressed as an argv list, so they do not go through run().
#  Instead osa_exec's callers carry their own --dry-run branch -- the rule
#  "--dry-run mutates nothing" is what matters, and it holds.
# ===========================================================================

# osa_exec <js|as> <script> [args...]
osa_exec() {
  local lang="$1" script="$2"
  shift 2
  if [ "$lang" = "js" ]; then
    printf '%s\n' "$script" | /usr/bin/osascript -l JavaScript - ${1+"$@"}
  else
    printf '%s\n' "$script" | /usr/bin/osascript - ${1+"$@"}
  fi
}

#  setDesktopImageURL:forScreen:options:error: RETURNS A BOOL. Both copies
#  below capture it and fail loudly when it is false. Discarding it (which an
#  earlier draft did, by wrapping the call in bare parentheses as a statement)
#  makes the handler return "ok" unconditionally -- which makes wp_set always
#  succeed, makes the JXA fallback dead code, and makes the whole "could not
#  set the desktop picture" recovery branch unreachable. Design rule 4 of this
#  file is that it never claims to have done something it did not do.
JXA_SET_WALLPAPER="$(/bin/cat <<'JXA'
ObjC.import('AppKit');
function run(argv) {
  var url = $.NSURL.fileURLWithPath(argv[0]);
  var ws = $.NSWorkspace.sharedWorkspace;
  var screens = $.NSScreen.screens;
  var n = screens.count;
  if (n === 0) { throw new Error('no screens attached'); }
  for (var i = 0; i < n; i++) {
    var scr = screens.objectAtIndex(i);
    var opts = ws.desktopImageOptionsForScreen(scr);
    if (!ws.setDesktopImageURLForScreenOptionsError(url, scr, opts, $())) {
      throw new Error('setDesktopImageURL:forScreen:options:error: returned false');
    }
  }
  return 'ok';
}
JXA
)"

ASOBJC_SET_WALLPAPER="$(/bin/cat <<'APPLESCRIPT'
use framework "Foundation"
use framework "AppKit"
use scripting additions
on run argv
	set theURL to current application's |NSURL|'s fileURLWithPath:(item 1 of argv)
	set ws to current application's NSWorkspace's sharedWorkspace()
	set screenList to current application's NSScreen's screens()
	set n to (screenList's |count|()) as integer
	if n = 0 then error "no screens attached" number 8000
	repeat with i from 0 to n - 1
		set scr to (screenList's objectAtIndex:i)
		set opts to (ws's desktopImageOptionsForScreen:scr)
		set okFlag to (ws's setDesktopImageURL:theURL forScreen:scr options:opts |error|:(missing value))
		if (okFlag as boolean) is false then error "setDesktopImageURL returned false" number 8001
	end repeat
	return "ok"
end run
APPLESCRIPT
)"

ASOBJC_READ_WALLPAPER="$(/bin/cat <<'APPLESCRIPT'
use framework "Foundation"
use framework "AppKit"
use scripting additions
on run
	set ws to current application's NSWorkspace's sharedWorkspace()
	set screenList to current application's NSScreen's screens()
	set n to (screenList's |count|()) as integer
	if n = 0 then return ""
	set out to {}
	repeat with i from 0 to n - 1
		set u to (ws's desktopImageURLForScreen:(screenList's objectAtIndex:i))
		if u is missing value then
			set end of out to ""
		else
			set end of out to ((u's |path|()) as text)
		end if
	end repeat
	set AppleScript's text item delimiters to linefeed
	return out as text
end run
APPLESCRIPT
)"

ASOBJC_SCREEN_PX="$(/bin/cat <<'APPLESCRIPT'
use framework "Foundation"
use framework "AppKit"
use scripting additions
on run
	set ss to current application's NSScreen's screens()
	if ((ss's |count|()) as integer) = 0 then return ""
	set scr to ss's objectAtIndex:0
	set k to (scr's backingScaleFactor()) as real
	set fr to scr's frame()
	set w to ((item 1 of item 2 of fr) as real) * k
	set h to ((item 2 of item 2 of fr) as real) * k
	return ((round w) as integer as text) & "x" & ((round h) as integer as text)
end run
APPLESCRIPT
)"

JXA_SET_ICON="$(/bin/cat <<'JXA'
ObjC.import('AppKit');
function run(argv) {
  var img = $.NSImage.alloc.initWithContentsOfFile(argv[0]);
  if (!img || !img.isValid) { throw new Error('could not load the icns'); }
  if (!$.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, argv[1], 0)) {
    throw new Error('setIcon:forFile:options: returned false');
  }
  return 'ok';
}
JXA
)"

# ===========================================================================
#  STEP 0 -- PREFLIGHT   (the only step allowed to abort the run)
# ===========================================================================
step_preflight() {
  [ "$(/usr/bin/uname -s)" = "Darwin" ] || die "this installer is macOS-only."
  [ "$(/usr/bin/id -u)" != "0" ] || die "do not run this as root or with sudo. It does not need it."

  read_macos_version
  if [ -z "$MACOS_VER" ]; then
    warn "could not read the macOS version; version-gated advice will be generic"
  else
    info "macOS $MACOS_VER  (major $MACOS_MAJOR)"
  fi

  if [ ! -f "$REPO/wallpaper/lhs-dusk.html" ]; then
    die "this does not look like the lhs-desktop-theme repo: no wallpaper/lhs-dusk.html above $HERE"
  fi

  if [ "$DO_ACCENT" = "1" ]; then
    # cfprefsd hands a running System Settings its cached copy of
    # NSGlobalDomain and can flush that stale copy back over our writes
    # seconds later. This is the likeliest cause of "it ran clean and nothing
    # changed".
    # macOS pgrep matches kp_proc.p_comm, which the kernel truncates to
    # MAXCOMLEN = 16 characters. "System Settings" is 15 and matches; "System
    # Preferences" is 18 and is stored as "System Preferenc", so -x on the full
    # name can NEVER match on macOS 12 and earlier. Match the bundle path
    # instead, which is what actually identifies it.
    if /usr/bin/pgrep -x "System Settings" >/dev/null 2>&1 \
       || /usr/bin/pgrep -f '/System Preferences.app/Contents/MacOS/' >/dev/null 2>&1; then
      warn "System Settings is open. macOS caches these preferences while it runs"
      warn "and can overwrite our writes. Quit it and re-run --accent if the"
      warn "appearance does not change. Everything else installs fine now."
    fi
  fi

  # --launcher has no built-in theme to fall back on, by design. Say so up
  # front rather than letting the step discover it halfway down the output.
  if [ "$DO_LAUNCHER" = "1" ]; then
    if [ ! -f "$REPO/macos/launcher/liberty-hill-dusk.raycast.json" ] \
       && [ ! -f "$REPO/macos/launcher/Liberty Hill Dusk.alfredappearance" ]; then
      warn "--launcher was requested but neither theme file is in this checkout:"
      warn "  $REPO/macos/launcher/liberty-hill-dusk.raycast.json"
      warn "  $REPO/macos/launcher/Liberty Hill Dusk.alfredappearance"
      warn "Nothing will be installed for the launchers. There is no built-in"
      warn "copy on purpose -- see the comment above step 5."
    fi
  fi

  if [ -f "$MANIFEST" ]; then
    info "previous install found -- re-running is safe and idempotent"
  fi
  return 0
}

# ===========================================================================
#  STEP 1 -- ASSETS   (default; the wallpaper is the whole point)
# ===========================================================================
step_assets() {
  local src="$REPO/wallpaper/lhs-dusk.html" f="" base="" n=0

  run /bin/mkdir -p "$ASSETS" "$LIVE" "$STILLS" "$SUPPORT"

  if [ ! -f "$src" ]; then
    warn "wallpaper/lhs-dusk.html is missing -- nothing to install"
    note warn "wallpaper page" "wallpaper/lhs-dusk.html missing from the repo"
    return 1
  fi

  # ONE file, shared by both platforms, renamed to index.html because that is
  # what a sandboxed wallpaper host loads out of a folder you hand it. With no
  # query string the page runs live off the real clock -- real solar altitude,
  # real moon phase -- which is exactly what a wallpaper wants.
  if install_file "$src" "$LIVE/index.html"; then
    ok "living wallpaper -> $LIVE/index.html"
  else
    warn "could not install the wallpaper page"
    note warn "wallpaper page" "could not be copied to $LIVE/index.html"
    return 1
  fi

  for f in "$REPO"/stills/lhs-*.png; do
    [ -f "$f" ] || continue
    base="$(/usr/bin/basename -- "$f")"
    # Through install_file, not a raw cp: that is what makes the backup promise
    # at the top of this file true for the stills as well. Its `cmp -s`
    # short-circuit means re-running over identical files still writes no
    # backups, while a still YOU baked or edited is preserved before we
    # overwrite it. install_file also records the path for uninstall.
    if install_file "$f" "$STILLS/$base"; then
      n=$((n + 1))
    else
      warn "could not install $base -- continuing with the rest"
    fi
  done
  if [ "$n" -gt 0 ]; then
    ok "$n stills -> $STILLS"
    info "other moods are in there too: right-click one > Set Desktop Picture"
    note ok "wallpaper assets" "page + $n stills -> ~/Pictures/Liberty Hill Studios"
  else
    warn "no stills found in $REPO/stills"
    note warn "wallpaper assets" "page installed; no stills found in the repo"
  fi
  return 0
}

# ===========================================================================
#  STEP 2 -- STATIC DESKTOP PICTURE   (default)
# ===========================================================================
#  Apple has rewritten wallpaper STORAGE twice since Ventura:
#    macOS 14 -> ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
#    macOS 26 -> ~/Library/Containers/com.apple.wallpaper.extension.image/
#  Both are undocumented, hold base64 binary-plist blobs, and differ between
#  fresh and migrated accounts. WE TOUCH NEITHER. We also never touch the old
#  ~/Library/Application Support/Dock/desktoppicture.db (dead since Sonoma).
#
#  We use the ONE public, documented, still-supported API:
#     -[NSWorkspace setDesktopImageURL:forScreen:options:error:]
#  in-process from osascript, iterating every NSScreen.
#
#  DO NOT "simplify" this to:
#     tell application "System Events" to tell every desktop to set picture ...
#  It fires an Apple event, so macOS shows a modal "wants access to control
#  System Events" dialog (error -1743 if declined); it only reliably reaches
#  the ACTIVE Space; and on macOS 26 it silently switches OFF System Settings'
#  "Show on all Spaces". Surprising a stranger with a permission modal is
#  worse than a printed instruction.
# ===========================================================================

# is_wxh -- true only for a strict "<digits>x<digits>".
is_wxh() {
  local a="" b=""
  case "$1" in
    ''|x*|*x)  return 1 ;;
    *[!0-9x]*) return 1 ;;
    *x*)       ;;
    *)         return 1 ;;
  esac
  a="${1%%x*}"; b="${1##*x}"
  case "$a" in ''|*[!0-9]*) return 1 ;; esac
  case "$b" in ''|*[!0-9]*) return 1 ;; esac
  return 0
}

# screen_px -- pixel size of the main display, or "" if it cannot be read.
# system_profiler first (it reports true backing pixels, including Retina);
# then NSScreen[0] (the menu-bar display) through the ObjC bridge. Both are
# read-only. If both fail the caller falls back to a sane default and carries
# on -- an unreadable display size must never abort an install.
screen_px() {
  local out=""
  out="$(/usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null \
         | /usr/bin/awk '/Resolution:/ {print $2 "x" $4; exit}' || true)"
  if is_wxh "$out"; then printf '%s' "$out"; return 0; fi
  out="$(osa_exec as "$ASOBJC_SCREEN_PX" 2>/dev/null || true)"
  if is_wxh "$out"; then printf '%s' "$out"; return 0; fi
  printf ''
  return 0
}

abs_int() { if [ "$1" -lt 0 ]; then printf '%s' "$((0 - $1))"; else printf '%s' "$1"; fi; }

# pick_still <pixelwidth> <pixelheight> -- echo the best-fitting dusk still.
#
# Score = |dw| + |dh| + 4*|aspect delta in thousandths|, plus an upscaling
# penalty of 500 + the shortfall in each axis. Pure integer arithmetic: no bc,
# no awk float traps.
#
# Why those weights: the scene is gradients, noise and dithering, so mild
# scaling is invisible while a wrong aspect ratio crops the ridgeline -- hence
# aspect is weighted 4x. Counting the shortfall a second time makes a big
# upscale lose to a same-aspect downscale (a 6016x3384 Pro Display XDR gets
# 7680x4320, not 5120x2880) while a mild one still wins on aspect (a 3024x1964
# MacBook Pro gets 16:10 2880x1800, not 16:9 3840x2160).
pick_still() {
  local pw="$1" ph="$2" f="" base="" dims="" w=0 h=0 ratio=0 pratio=0
  local score=0 dw=0 dh=0 dr=0 best="" best_score=""
  case "$pw" in ''|*[!0-9]*|0) pw=2560 ;; esac
  case "$ph" in ''|*[!0-9]*|0) ph=1600 ;; esac
  pratio=$(( pw * 1000 / ph ))
  # Scanned in the REPO, not in the installed copy: this must give the same
  # answer during --dry-run, when nothing has been copied anywhere yet.
  for f in "$REPO"/stills/lhs-dusk-*x*.png; do
    [ -f "$f" ] || continue
    base="$(/usr/bin/basename -- "$f" .png)"
    dims="${base##*-}"
    w="${dims%%x*}"
    h="${dims##*x}"
    case "$w" in ''|*[!0-9]*) continue ;; esac
    case "$h" in ''|*[!0-9]*) continue ;; esac
    [ "$h" -gt 0 ] || continue
    ratio=$(( w * 1000 / h ))
    dw="$(abs_int $(( w - pw )))"
    dh="$(abs_int $(( h - ph )))"
    dr="$(abs_int $(( ratio - pratio )))"
    score=$(( dw + dh + 4 * dr ))
    if [ "$w" -lt "$pw" ] || [ "$h" -lt "$ph" ]; then
      score=$(( score + 500 ))
      if [ "$w" -lt "$pw" ]; then score=$(( score + pw - w )); fi
      if [ "$h" -lt "$ph" ]; then score=$(( score + ph - h )); fi
    fi
    if [ -z "$best_score" ] || [ "$score" -lt "$best_score" ]; then
      best_score="$score"
      best="$f"
    fi
  done
  printf '%s' "$best"
}

wp_read() { osa_exec as "$ASOBJC_READ_WALLPAPER" 2>/dev/null || true; }

wp_set() {
  local img="$1"
  if [ "$DRY_RUN" = "1" ]; then
    dry "NSWorkspace setDesktopImageURL: $(shq "$img")   (every display)"
    return 0
  fi
  osa_exec as "$ASOBJC_SET_WALLPAPER" "$img" >/dev/null 2>&1 && return 0
  osa_exec js "$JXA_SET_WALLPAPER"    "$img" >/dev/null 2>&1 && return 0
  return 1
}

# Read the wallpaper back through the sibling API. No Apple event, no prompt.
# This is what turns a blind script into a self-checking one.
wp_verify() {
  local want="$1" got="" line=""
  /bin/sleep 1                      # let the wallpaper manager settle
  got="$(wp_read)"
  [ -n "$got" ] || return 1
  while IFS= read -r line; do
    [ "$line" = "$want" ] || return 1
  done <<EOF
$got
EOF
  return 0
}

step_desktop_picture() {
  local px="" pw=0 ph=0 best="" bname="" target="" prev="" byhand=""

  info "reading the display size (system_profiler can take a few seconds)..."
  px="$(screen_px)"
  if is_wxh "$px"; then
    pw="${px%%x*}"; ph="${px##*x}"
    info "main display: ${pw}x${ph} pixels"
  else
    pw=2560; ph=1600
    warn "could not read the display size; assuming ${pw}x${ph} and carrying on"
  fi

  best="$(pick_still "$pw" "$ph")"
  if [ -z "$best" ]; then
    warn "no lhs-dusk-<W>x<H>.png stills in $REPO/stills -- desktop picture not set"
    note warn "desktop picture" "no stills to choose from"
    return 1
  fi
  bname="$(/usr/bin/basename -- "$best")"
  target="$STILLS/$bname"
  ok "best fit for ${pw}x${ph}: $bname"

  if [ -x /usr/bin/sips ] && [ "$DRY_RUN" != "1" ]; then
    if ! /usr/bin/sips -g pixelWidth "$best" >/dev/null 2>&1; then
      warn "$bname is not a decodable image (sips refused it) -- not setting it"
      note warn "desktop picture" "$bname failed the image sanity check"
      return 1
    fi
  fi

  # We hand the API the INSTALLED still, not the one in the repo, so the
  # desktop keeps working if the checkout is moved or deleted. The assets step
  # already copied it; this is the belt-and-braces case where that step failed.
  # The path we tell you to use by hand is whichever of these actually exists,
  # so the recovery instructions can never name a file that is not there.
  byhand="$best"
  if [ "$DRY_RUN" != "1" ] && [ ! -f "$target" ]; then
    if install_file "$best" "$target"; then
      byhand="$target"
    else
      warn "could not copy $bname into $STILLS -- using the repo copy instead"
    fi
  elif [ -f "$target" ]; then
    byhand="$target"
  fi

  # A friendly, stable copy next to the assets, for the manual route
  # (System Settings > Wallpaper > Add Photo...). NOT the file we hand the
  # API: macOS caches the wallpaper BY PATH, so a stable filename whose
  # CONTENT can change between runs is exactly how you get "the script ran and
  # nothing happened". The still itself never changes content for a given
  # name, which is why that is the one we set.
  #
  # It is DECORATION, and decoration must never pre-empt the one thing this
  # step exists to do. If the volume is full or the folder is read-only, this
  # is exactly where ENOSPC/EACCES lands -- so it warns and carries on rather
  # than aborting the step before wp_set is ever reached.
  if install_file "$best" "$ASSETS/lhs-static.png"; then
    byhand="$ASSETS/lhs-static.png"
  else
    warn "could not write $ASSETS/lhs-static.png (a convenience copy only) -- continuing"
  fi

  # Remember the wallpaper we are replacing so uninstall.sh can put it back.
  # Without this, uninstalling would delete the image the desktop points at
  # and leave a blank desktop -- exactly the half-broken state this project
  # must never produce.
  if [ "$DRY_RUN" != "1" ]; then
    prev="$(wp_read | /usr/bin/head -n 1 || true)"
    case "$prev" in
      "$STILLS"/*|"$ASSETS"/*) prev="" ;;   # ours already, from an earlier run
    esac
    if [ -n "$prev" ] && [ -f "$prev" ]; then
      # TAB-separated verb + argument. uninstall.sh matches the verb exactly
      # and never evaluates the line -- so no shell quoting is wanted here.
      record_undo "$(printf 'lhs_restore_wallpaper\t%s' "$prev")"
      info "your previous desktop picture is remembered for uninstall"
    fi
  fi

  # Never hand the API a path that is not there: setDesktopImageURL can accept
  # a missing file and leave you with a blank desktop. If the installed copy
  # could not be made, set the repo copy -- second best (it breaks if the
  # checkout moves) but visibly correct now, and the next run fixes the path.
  if [ "$DRY_RUN" != "1" ] && [ ! -f "$target" ]; then
    warn "$target is not there -- setting the repo copy instead:"
    warn "  $best"
    target="$best"
  fi

  if ! wp_set "$target"; then
    warn "could not set the desktop picture. NOTHING was changed."
    say  "        Set it by hand -- it takes ten seconds:"
    say  "          System Settings > Wallpaper > Add Photo... and choose"
    say  "            $byhand"
    say  "        Then re-run this script: once Wallpaper settings has seen the"
    say  "        image, the API call usually succeeds."
    note warn "desktop picture" "not set automatically -- set $byhand by hand"
    return 1
  fi

  if [ "$DRY_RUN" = "1" ]; then
    note ok "desktop picture" "would set $bname on every display"
    return 0
  fi

  if wp_verify "$target"; then
    ok "desktop picture set on every display (verified by reading it back)"
    note ok "desktop picture" "$bname, verified by read-back"
  else
    warn "the API reported success but the read-back did not match on every"
    warn "display. Check System Settings > Wallpaper; if it is wrong, add"
    warn "$byhand by hand there."
    note warn "desktop picture" "set, but the read-back did not match every display"
  fi
  say ""
  say "        SPACES: no public API sets the wallpaper on every Space -- every"
  say "        tool has this limit, ours included. If you use several Spaces,"
  say "        tick System Settings > Wallpaper > \"Show on all Spaces\"."
  return 0
}

# ===========================================================================
#  STEP 3 -- THE ANIMATED WALLPAPER   (instructions only; never forced)
# ===========================================================================
#  There is NO zero-dependency way to run an animated HTML wallpaper on macOS.
#  Apple exposes no public API for a live/web desktop background: the system
#  supports static images and .heic "dynamic desktops" (a bundle of stills
#  that cross-fade on solar elevation -- not animation), and Sonoma's video
#  aerials are Apple-signed assets third parties cannot add to. Every animated
#  route needs a third-party app. On macOS that app is Plash.
#
#  Plash CANNOT be automated for a local file, and this is structural, not
#  laziness: its plash:add?url= scheme documents verbatim "Local file URLs are
#  not supported", and Plash is sandboxed, so it can only read what a HUMAN
#  hands it through a macOS open panel (that is what mints the security-scoped
#  bookmark). Hence: you pick a FOLDER, Plash loads index.html out of it, and
#  the one-time pick is irreducibly manual. Same shape as Lively on Windows,
#  whose library entry is also a folder plus an index.html.
# ===========================================================================
step_plash_notes() {
  say ""
  if app_path "Plash.app" >/dev/null 2>&1; then
    ok "Plash is installed."
  else
    say "  1. Install Plash. THERE IS NO HOMEBREW CASK -- \`brew install --cask plash\`"
    say "     is a 404. Get it from the Mac App Store:"
    say "       https://apps.apple.com/us/app/plash/id1494023538"
    if [ "$MACOS_MAJOR" -eq 0 ]; then
      say "     The App Store build needs macOS 26.4 or newer. On anything older,"
      say "     take the matching legacy build from the GitHub \`older-releases\` tag:"
      say "       https://github.com/sindresorhus/Plash/releases/tag/older-releases"
      say "       macOS 15 -> Plash 2.16.0   macOS 14 -> 2.15.0   macOS 13 -> 2.14.1"
    # A TUPLE compare, not two independent tests. `MAJOR -ge 26 && MINOR -ge 4`
    # is false on 27.0, which would send someone on a NEWER macOS to the
    # "update macOS, or take the macOS 15 legacy build" branch -- advice that
    # is both impossible and a downgrade. The braces form is bash 3.2 safe;
    # the semicolon before the closing brace is required.
    elif [ "$MACOS_MAJOR" -gt 26 ] || { [ "$MACOS_MAJOR" -eq 26 ] && [ "$MACOS_MINOR" -ge 4 ]; }; then
      say "     You are on macOS $MACOS_VER, so the App Store build is the right one."
    elif [ "$MACOS_MAJOR" -ge 26 ]; then
      say "     You are on macOS $MACOS_VER and the App Store build requires 26.4 or"
      say "     newer, so it will refuse to install. Update macOS, or try the"
      say "     macOS 15 legacy build (Plash 2.16.0) from the \`older-releases\` tag:"
      say "       https://github.com/sindresorhus/Plash/releases/tag/older-releases"
    else
      say "     That build requires macOS 26.4 or newer, and you are on $MACOS_VER."
      say "     Take the legacy build for your system from the \`older-releases\` tag:"
      say "       https://github.com/sindresorhus/Plash/releases/tag/older-releases"
      case "$MACOS_MAJOR" in
        15) say "       macOS 15 Sequoia -> Plash 2.16.0" ;;
        14) say "       macOS 14 Sonoma  -> Plash 2.15.0" ;;
        13) say "       macOS 13 Ventura -> Plash 2.14.1" ;;
        *)  say "       macOS $MACOS_MAJOR is older than this port was reasoned for;"
            say "       pick the newest build on that page your system accepts." ;;
      esac
      say "     Those ZIPs come from GitHub, so Gatekeeper quarantines them:"
      say "     RIGHT-CLICK Plash.app > Open > Open the first time. Do NOT run"
      say "     anything that strips the quarantine flag."
    fi
  fi

  say ""
  say "  2. Point Plash at the scene. This part is MANUAL and cannot be"
  say "     scripted: Plash is sandboxed, so only a folder YOU pick in the open"
  say "     panel grants it access."
  say "       * open Plash, click its menu-bar icon"
  say "       * choose the option to open a LOCAL FOLDER / DIRECTORY"
  say "         (the exact wording moves between versions)"
  say "       * pick the FOLDER named \"Living Dusk\" -- NOT the index.html"
  say "         inside it. Shift-Command-G in the panel pastes a path:"
  say ""
  say "             $LIVE"
  say ""
  say "       * turn on \"Open at Login\" in Plash's settings"
  say ""
  say "     With no query string the page runs live off the real clock: real"
  say "     solar altitude for Liberty Hill, Texas, and the real moon phase."
  say "     There is nothing to configure."
  say ""
  say "  Known caveat, so you are not surprised: on some versions the folder"
  say "  permission prompt reappears after unlock, and WKWebView has a"
  say "  long-standing \"loads a local file only once\" bug. If that bites, the"
  say "  static picture set above is a first-class fallback, not a consolation"
  say "  prize -- it needs no app and no permissions."
  note ok "Plash guidance" "printed (the folder pick is manual by design)"
  return 0
}

# ===========================================================================
#  STEP 4 -- TERMINAL SCHEMES   (--terminal)
# ===========================================================================
#  Rule for this whole section: WE NEVER EDIT A CONFIG FILE YOU ALREADY HAVE.
#  The theme is copied next to it and the one line to add is printed. That is
#  slower by ten seconds and it cannot corrupt a config we cannot see -- a
#  duplicate TOML table or a stray line after wezterm.lua's `return config`
#  would break your terminal, and the author of this port has no Mac to test
#  the recovery on.
#
#  We also never `defaults write com.apple.Terminal` or com.googlecode.iterm2:
#  those apps are running, hold their preferences in memory, and rewrite the
#  domain on quit, so scripted writes are silently discarded.
# ===========================================================================
TERMDIR=""

step_terminal() {
  TERMDIR="$REPO/macos/terminal"
  if [ ! -d "$TERMDIR" ]; then
    warn "$TERMDIR is missing -- no terminal schemes to install"
    note warn "terminal schemes" "macos/terminal/ missing from the repo"
    return 1
  fi
  run /bin/mkdir -p "$SUPPORT/terminal"

  guard term_iterm     "iTerm2 scheme"
  guard term_kitty     "kitty scheme"
  guard term_alacritty "Alacritty scheme"
  guard term_wezterm   "WezTerm scheme"
  guard term_ghostty   "Ghostty scheme"
  guard term_apple     "Terminal.app profile"
  return 0
}

term_iterm() {
  # iTerm2 takes the preset NAME from the FILENAME -- the .itermcolors format
  # has no name field -- so the copy is renamed on the way in.
  local src="$TERMDIR/liberty-hill-dusk.itermcolors"
  local dst="$SUPPORT/terminal/Liberty Hill Dusk.itermcolors"
  if ! app_path "iTerm.app" >/dev/null 2>&1; then
    skip "iTerm2 not installed"
    note skip "iTerm2" "not installed"
    return 0
  fi
  if [ ! -f "$src" ]; then
    skip "iTerm2: $src is missing"
    note skip "iTerm2" "theme file missing from the repo"
    return 0
  fi
  install_file "$src" "$dst"
  ok "iTerm2: colour preset -> $dst"
  if [ "$DRY_RUN" = "1" ]; then
    dry "open $(shq "$dst")"
    note ok "iTerm2" "would import the preset"
    return 0
  fi
  say "        Importing it brings iTerm2 forward:"
  # An `open` that fails must not abandon the step: the FILE is installed, and
  # the instructions below are the whole point of the step. LaunchServices can
  # refuse (an app dragged in but never launched has not registered its file
  # types yet), and that is a "do it yourself" case, not a failure.
  if ! /usr/bin/open "$dst"; then
    warn "could not hand the preset to iTerm2"
    say  "        Double-click it yourself: $dst"
    note warn "iTerm2" "open failed -- double-click $dst"
    return 0
  fi
  say "        Then: iTerm2 > Settings > Profiles > Colors > Color Presets... >"
  say "        Liberty Hill Dusk."
  note ok "iTerm2" "preset imported -- pick it in Profiles > Colors"
  return 0
}

term_kitty() {
  local src="$TERMDIR/liberty-hill-dusk.kitty.conf"
  local dir="$HOME/.config/kitty"
  if ! app_path "kitty.app" >/dev/null 2>&1 && ! have_cmd kitty && [ ! -d "$dir" ]; then
    skip "kitty not installed"
    note skip "kitty" "not installed"
    return 0
  fi
  if [ ! -f "$src" ]; then
    skip "kitty: $src is missing"
    note skip "kitty" "theme file missing from the repo"
    return 0
  fi
  install_file "$src" "$dir/liberty-hill-dusk.kitty.conf"
  ok "kitty: theme -> $dir/liberty-hill-dusk.kitty.conf"
  say "        Add this ONE line to $dir/kitty.conf:"
  say ""
  say "            include liberty-hill-dusk.kitty.conf"
  say ""
  say "        (kitty resolves a relative include against the including file's"
  say "        own directory, so the bare filename is correct.)"
  info "Reload without restarting: ctrl+cmd+, in any kitty window."
  note_done "kitty" "theme installed -- add one include line to kitty.conf" \
            "would install the theme (one include line to add afterwards)"
  return 0
}

term_alacritty() {
  local src="$TERMDIR/liberty-hill-dusk.alacritty.toml"
  local dir="$HOME/.config/alacritty"
  if ! app_path "Alacritty.app" >/dev/null 2>&1 && ! have_cmd alacritty && [ ! -d "$dir" ]; then
    skip "Alacritty not installed"
    note skip "Alacritty" "not installed"
    return 0
  fi
  if [ ! -f "$src" ]; then
    skip "Alacritty: $src is missing"
    note skip "Alacritty" "theme file missing from the repo"
    return 0
  fi
  install_file "$src" "$dir/themes/liberty-hill-dusk.alacritty.toml"
  ok "Alacritty: theme -> $dir/themes/liberty-hill-dusk.alacritty.toml"
  if [ -f "$dir/alacritty.yml" ] && [ ! -f "$dir/alacritty.toml" ]; then
    # Alacritty before 0.13 used YAML. A .toml import would do nothing at all
    # and you would never learn why.
    warn "you have alacritty.yml (pre-0.13 YAML config). A TOML import is"
    warn "IGNORED SILENTLY by that version -- upgrade Alacritty, or port the"
    warn "theme file to YAML by hand."
    note warn "Alacritty" "pre-0.13 YAML config -- theme copied but it will not load"
    return 0
  fi
  say "        Add this to $dir/alacritty.toml, inside its [general] table"
  say "        (TOML forbids declaring [general] twice -- if you already have"
  say "        one, add the import line to it rather than pasting both):"
  say ""
  say "            [general]"
  say "            import = [\"$dir/themes/liberty-hill-dusk.alacritty.toml\"]"
  say ""
  note_done "Alacritty" "theme installed -- add the import line to alacritty.toml" \
            "would install the theme (one import line to add afterwards)"
  return 0
}

term_wezterm() {
  local src="$TERMDIR/liberty-hill-dusk.wezterm.lua"
  local dir="$HOME/.config/wezterm"
  if ! app_path "WezTerm.app" >/dev/null 2>&1 && ! have_cmd wezterm && [ ! -d "$dir" ]; then
    skip "WezTerm not installed"
    note skip "WezTerm" "not installed"
    return 0
  fi
  if [ ! -f "$src" ]; then
    skip "WezTerm: $src is missing"
    note skip "WezTerm" "theme file missing from the repo"
    return 0
  fi
  install_file "$src" "$dir/colors/liberty-hill-dusk.wezterm.lua"
  ok "WezTerm: scheme -> $dir/colors/liberty-hill-dusk.wezterm.lua"
  # We do NOT edit wezterm.lua. It is a program ending in `return config`;
  # anything appended after that is dead code at best, a syntax error at
  # worst. Two lines by hand beat parsing Lua in bash.
  say "        Add these TWO lines to $dir/wezterm.lua, above its"
  say "        \`return config\`:"
  say ""
  say "            local lhs = dofile(wezterm.config_dir .. '/colors/liberty-hill-dusk.wezterm.lua')"
  say "            lhs.apply(config)"
  say ""
  say "        (dofile, not require: the filename contains dots, which Lua's"
  say "        module resolver reads as directory separators.)"
  note_done "WezTerm" "scheme installed -- add two lines to wezterm.lua" \
            "would install the scheme (two lines to add afterwards)"
  return 0
}

term_ghostty() {
  local src="$TERMDIR/liberty-hill-dusk.ghostty"
  local xdg="$HOME/.config/ghostty"
  local appsup="$HOME/Library/Application Support/com.mitchellh.ghostty"
  local cfg="" cand=""
  if ! app_path "Ghostty.app" >/dev/null 2>&1 && ! have_cmd ghostty \
     && [ ! -d "$xdg" ] && [ ! -d "$appsup" ]; then
    skip "Ghostty not installed"
    note skip "Ghostty" "not installed"
    return 0
  fi
  if [ ! -f "$src" ]; then
    skip "Ghostty: $src is missing"
    note skip "Ghostty" "theme file missing from the repo"
    return 0
  fi
  # On macOS, Ghostty reads user THEMES only from ~/.config/ghostty/themes --
  # not from Application Support (the CONFIG file is read from both). We put
  # the theme in the XDG path and reference it by ABSOLUTE path, which
  # bypasses theme discovery entirely. `theme` does not expand ~.
  install_file "$src" "$xdg/themes/liberty-hill-dusk"
  ok "Ghostty: theme -> $xdg/themes/liberty-hill-dusk"
  for cand in "$appsup/config" "$appsup/config.ghostty" "$xdg/config"; do
    if [ -f "$cand" ]; then cfg="$cand"; break; fi
  done
  if [ -n "$cfg" ]; then
    say "        Add this ONE line to $cfg:"
  else
    cfg="$xdg/config"
    say "        You have no Ghostty config file yet. Create this one:"
    say "          $cfg"
    say "        and put this ONE line in it:"
  fi
  say ""
  say "            theme = $xdg/themes/liberty-hill-dusk"
  say ""
  info "Reload without restarting: cmd+shift+, in any Ghostty window."
  note_done "Ghostty" "theme installed -- add one theme line to your config" \
            "would install the theme (one theme line to add afterwards)"
  return 0
}

term_apple() {
  # Terminal.app is the one emulator whose profile cannot ship as committed
  # text: every colour is an NSKeyedArchiver-encoded NSColor in a base64
  # <data> blob, so it is generated ON the Mac. The generator verifies its own
  # output (it unarchives all 21 colours and compares them to the palette)
  # before installing anything.
  local gen="$TERMDIR/make-terminal-app-profile.sh"
  local out="$SUPPORT/terminal/Liberty Hill Dusk.terminal"
  if [ ! -f "$gen" ]; then
    skip "Terminal.app: $gen is missing"
    note skip "Terminal.app" "generator missing from the repo"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    dry "bash $(shq "$gen")            # generates $out"
    dry "open $(shq "$out")"
    note ok "Terminal.app" "would generate and import the profile"
    return 0
  fi
  if ! /bin/bash "$gen"; then
    warn "the Terminal.app profile generator could not run (it says why above)."
    warn "Nothing was written. Every other emulator is unaffected."
    note warn "Terminal.app" "generator failed -- no profile written"
    return 0
  fi
  if [ -f "$out" ]; then
    record_path "$out"
    # The profile is written either way; an `open` that LaunchServices refuses
    # must not swallow the instructions below.
    if ! /usr/bin/open "$out"; then
      warn "could not hand the profile to Terminal.app"
      say  "        Double-click it yourself: $out"
      note warn "Terminal.app" "open failed -- double-click $out"
      return 0
    fi
    ok "Terminal.app: profile imported"
    say "        Make it stick: Terminal > Settings > Profiles > Liberty Hill"
    say "        Dusk > the Default button at the bottom. That one button sets"
    say "        BOTH the default and the startup profile -- setting only one"
    say "        gives a half-themed result that looks like a bug."
    note ok "Terminal.app" "profile imported -- click Default in Settings > Profiles"
  else
    warn "the generator reported success but $out is not there"
    note warn "Terminal.app" "profile not found after generation"
  fi
  return 0
}

# ===========================================================================
#  STEP 5 -- LAUNCHER THEMES   (--launcher)
# ===========================================================================
#  THE HONEST ANSWER TO "make it animated and look cool":
#
#  NEITHER Raycast NOR Alfred supports an animated theme. Both formats are
#  colour + geometry only -- there is no animation, transition, gradient,
#  image or shader key anywhere in either schema. Nothing here pretends
#  otherwise.
#
#  But Alfred DOES support real translucency: `visualEffectMode: 2` backs its
#  window with a native NSVisualEffectView (dark behind-window vibrancy), and
#  a low-alpha window colour makes it a sheet of dark glass rather than a
#  slab. macOS behind-window vibrancy samples whatever is composited behind
#  the window -- the desktop picture -- and Alfred opens near the top-centre
#  of the screen, which is the SKY region of our wallpaper: the part that
#  changes most from dawn through golden hour to night. So the glass warms and
#  cools with the real sun on its own, without one animated pixel in the theme
#  file. That claim is about macOS compositing, not about the theme.
#
#  Two honest limits on that: vibrancy BLURS and DESATURATES, so it is a soft
#  colour wash that shifts through the day, not a crisp view of the moon
#  through your launcher. And whether the vibrancy samples a Plash desktop
#  window or only the static picture underneath is UNVERIFIED -- nobody on
#  this project has a Mac. Either way the launcher is correct dark glass.
#
#  Raycast has no transparency knob at all: 12 opaque hex colours plus a
#  light/dark flag, and 8-digit #RRGGBBAA values have their alpha silently
#  CHOPPED by its parser. It gets a beautifully matched flat ink palette and
#  nothing more.
#
#  Studio design law is satisfied structurally here: NSVisualEffectView's dark
#  material is a fixed system material that cannot be tinted gold, so gold can
#  only live in selection fills, the shortcut glyphs, the scrollbar and a
#  hairline border. Never a surface.
# ===========================================================================

# The deep link is the ONLY sanctioned way to hand Raycast a theme -- it has
# no on-disk theme folder. Purely local; no network (a themes.ray.so link
# would need one, which this project does not do).
# Colour ORDER inside `colors` is positional and load-bearing:
#   background, backgroundSecondary, text, selection, loader,
#   red, orange, yellow, green, blue, purple, magenta
# Each '#' is percent-encoded SEPARATELY to %23; the 12 commas stay LITERAL.
# Encoding the joined string instead would turn the commas into %2C and
# Raycast would not split the list.
#
# THERE IS DELIBERATELY NO BUILT-IN COPY OF EITHER THEME IN THIS FILE.
# There used to be, and it was a trap: an inline "fallback" palette is a second
# source of truth that nothing checks, so it drifts from the committed theme
# file and from launcher/README.md -- and then a checkout whose theme file has
# merely been RENAMED silently installs an unreviewed palette while reporting
# success. Installing a theme nobody designed is worse than installing none.
# So: the repo file is the only source. If it is missing, the step says exactly
# which file it wanted and stops. Nothing is substituted.

step_launcher() {
  run /bin/mkdir -p "$SUPPORT/launcher"
  guard launcher_raycast "Raycast theme"
  guard launcher_alfred  "Alfred theme"
  say ""
  say "  Neither launcher can be animated -- there is no animation, transition"
  say "  or gradient key in either theme format, and this installer will not"
  say "  pretend otherwise. What IS real: Alfred's dark vibrancy makes its"
  say "  window a sheet of glass over the living wallpaper, and Alfred opens"
  say "  over the SKY -- the part of the scene that changes most through the"
  say "  day. It warms at golden hour and darkens at night on its own."
  return 0
}

# find_first <pattern...> -- echo the first existing file, else return 1.
find_first() {
  local f=""
  for f in "$@"; do
    if [ -f "$f" ]; then printf '%s' "$f"; return 0; fi
  done
  return 1
}

# raycast_url <json> -- build the deep link FROM the shipped JSON so the two
# can never drift. macOS has no jq, so each colour is pulled with one sed and
# validated as exactly '#' + 6 hex digits. If ANY of the twelve cannot be read
# and validated, this returns 1 and prints nothing: the caller then tells you
# to enter the palette by hand rather than opening Theme Studio with a link
# built from a guess.
raycast_url() {
  local f="${1:-}" v="" colors="" k=""
  [ -n "$f" ] && [ -f "$f" ] || return 1
  for k in background backgroundSecondary text selection loader \
           red orange yellow green blue purple magenta; do
    v="$(/usr/bin/sed -n 's/.*"'"$k"'"[[:space:]]*:[[:space:]]*"\(#[0-9A-Fa-f]*\)".*/\1/p' "$f" \
         | /usr/bin/head -n 1 || true)"
    case "$v" in
      '#'[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
      *) return 1 ;;
    esac
    # 6-digit only. An 8-digit value would have its alpha silently chopped by
    # Raycast's own parser, so we refuse it above rather than ship a booby trap.
    if [ -z "$colors" ]; then colors="%23${v#\#}"; else colors="$colors,%23${v#\#}"; fi
  done
  printf 'theme?author=Liberty%%20Hill%%20Studios&authorUsername=libertyhillstudios&version=1&name=Liberty%%20Hill%%20Dusk&appearance=dark&colors=%s' "$colors"
  return 0
}

launcher_raycast() {
  # The installed copy keeps the SAME NAME the repo and the docs use, so the
  # file you are told to read the twelve values out of is findable by name.
  local src="" dst="$SUPPORT/launcher/liberty-hill-dusk.raycast.json" q=""
  # The committed file is macos/launcher/liberty-hill-dusk.raycast.json. The
  # raycast/ subfolder candidates are kept so a future reorganisation of that
  # folder keeps working -- but the real, current filename is FIRST, because
  # missing it is exactly how an earlier draft shipped a palette that matched
  # nothing in this repo.
  src="$(find_first \
          "$REPO/macos/launcher/liberty-hill-dusk.raycast.json" \
          "$REPO/macos/launcher/"*.raycast.json \
          "$REPO/macos/launcher/raycast/liberty-hill-dusk.json" \
          "$REPO/macos/launcher/raycast/"*.json \
          "$REPO/macos/launcher/liberty-hill-dusk.json" || true)"
  if [ -z "$src" ]; then
    warn "the Raycast theme file is not in this checkout. Nothing was installed."
    say  "        Expected:  $REPO/macos/launcher/liberty-hill-dusk.raycast.json"
    say  "        There is no built-in copy on purpose: substituting an"
    say  "        unreviewed palette that matches no file in this repo would be"
    say  "        worse than skipping the step."
    note warn "Raycast" "theme file missing from the checkout -- nothing installed"
    return 0
  fi
  install_file "$src" "$dst"
  ok "Raycast palette -> $dst"

  q="$(raycast_url "$src" || true)"
  if [ -z "$q" ]; then
    warn "could not read all twelve colours out of $src -- no deep link built."
    say  "        Enter the 12 values by hand from:"
    say  "          $dst"
    note warn "Raycast" "the theme file did not parse -- enter the palette by hand"
    return 0
  fi

  if ! app_path "Raycast.app" >/dev/null 2>&1; then
    skip "Raycast not installed -- nothing was changed"
    say  "        Import it later with:"
    say  "          open \"raycast://$q\""
    note skip "Raycast" "not installed (palette saved for later)"
    return 0
  fi

  say "        Custom themes are a Raycast PRO feature (\$8-10/mo). On a free"
  say "        account Theme Studio will refuse -- that is expected, not a bug."
  say "        (Raycast v2 is in public beta and grants themes free FOR NOW,"
  say "        by grace of the beta. Do not build a habit on that.)"
  if [ "$DRY_RUN" = "1" ]; then
    dry "open $(shq "raycast://$q")"
    note ok "Raycast" "would open Theme Studio with Liberty Hill Dusk"
    return 0
  fi
  # Classic Raycast registers raycast:// ; Raycast v2 registers raycast-x://
  # on macOS. `open` exits non-zero when no app claims the scheme, which is
  # what makes this fallback work.
  if /usr/bin/open "raycast://$q" 2>/dev/null; then
    :
  elif /usr/bin/open "raycast-x://$q" 2>/dev/null; then
    :
  else
    warn "could not hand the theme to Raycast (custom themes need Raycast Pro)."
    say  "        Enter the 12 values by hand from:"
    say  "          $dst"
    note warn "Raycast" "the deep link did not open -- enter the palette by hand"
    return 0
  fi
  ok "Raycast: Theme Studio opened with Liberty Hill Dusk loaded"
  say "        ONE CLICK LEFT: click \"Set as Current Theme\" in Theme Studio."
  say "        (Optional: in Switch Theme's Action Panel, \"Set as Dark Theme\""
  say "        binds it to Dark Mode.)"
  note ok "Raycast" "Theme Studio opened -- click Set as Current Theme"
  return 0
}

launcher_alfred() {
  local src="" dst="$SUPPORT/launcher/Liberty Hill Dusk.alfredappearance" a=""
  # Current, committed location FIRST; the alfred/ subfolder candidates are for
  # a possible future reorganisation. Same rule as Raycast: no built-in copy,
  # because a stale inline theme is a silent wrong answer.
  src="$(find_first \
          "$REPO/macos/launcher/Liberty Hill Dusk.alfredappearance" \
          "$REPO/macos/launcher/"*.alfredappearance \
          "$REPO/macos/launcher/alfred/Liberty Hill Dusk.alfredappearance" \
          "$REPO/macos/launcher/alfred/"*.alfredappearance || true)"
  if [ -z "$src" ]; then
    warn "the Alfred theme file is not in this checkout. Nothing was installed."
    say  "        Expected:  $REPO/macos/launcher/Liberty Hill Dusk.alfredappearance"
    note warn "Alfred" "theme file missing from the checkout -- nothing installed"
    return 0
  fi
  install_file "$src" "$dst"
  ok "Alfred theme -> $dst"

  # The bundle is version-numbered ("Alfred 5.app"), so glob for it. Never
  # `osascript -e 'id of app "Alfred"'` -- that fires an Apple event and can
  # trigger an Automation prompt.
  a="$(app_glob 'Alfred*.app' || true)"
  if [ -z "$a" ]; then
    skip "Alfred not installed -- nothing was changed"
    say  "        Double-click that file once Alfred is installed, or run:"
    say  "          open \"$dst\""
    note skip "Alfred" "not installed (theme saved for later)"
    return 0
  fi

  say "        Alfred custom themes require the POWERPACK (GBP 34 single"
  say "        licence). Free Alfred cannot import a theme file at all -- the"
  say "        file is saved above and will import the moment you upgrade."
  # The supported, documented route: double-clicking (open) the file makes
  # Alfred show a colour preview with an Import button. We deliberately do NOT
  # copy into Alfred.alfredpreferences/themes/ behind its back: that folder is
  # user-relocatable (iCloud/Dropbox), Alfred must be restarted to notice a
  # drop-in, and writing `currentthemeuid` into its live prefs is editing a
  # running app's settings behind it.
  if [ "$DRY_RUN" = "1" ]; then
    dry "open $(shq "$dst")"
    note ok "Alfred" "would open the theme for import"
    return 0
  fi
  # An Alfred that was dragged in but never launched has not registered the
  # .alfredappearance type with LaunchServices, so `open` exits non-zero. The
  # FILE is installed either way -- say where it is instead of abandoning the
  # step and swallowing the instructions below.
  if ! /usr/bin/open "$dst"; then
    warn "could not hand the theme to Alfred"
    say  "        Double-click it yourself: $dst"
    note warn "Alfred" "open failed -- double-click $dst"
    return 0
  fi
  ok "Alfred: theme opened for import"
  say "        ONE CLICK LEFT: Alfred shows a colour preview -- click Import,"
  say "        then Settings > Appearance > Liberty Hill Dusk."
  note ok "Alfred" "opened for import -- click Import, then pick it in Appearance"
  return 0
}

# ===========================================================================
#  STEP 6 -- APPEARANCE   (--accent)
# ===========================================================================
#  STUDIO DESIGN LAW: gold is an ACCENT, never a background or a large
#  surface. Everything here puts colour on small elements only -- the text
#  selection highlight and the system accent (buttons, checkboxes, focus
#  rings). Window and sidebar surfaces stay neutral dark.
# ===========================================================================
step_accent() {
  # ORDER MATTERS. AppleInterfaceStyleSwitchesAutomatically is the "Auto"
  # appearance setting; if it is left on, macOS overrides our explicit style
  # at the next sunrise and the theme appears to "stop working" hours after
  # install. Clear it FIRST, then set the style.
  set_default NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool false
  set_default NSGlobalDomain AppleInterfaceStyle -string "Dark"

  # Text selection highlight = gold-400 #E8A13A.
  # Format: three floats 0.0-1.0 to 6 decimal places, then a NAME token. For a
  # custom colour the token is the literal word `Other`, which is what System
  # Settings itself writes and what makes the Appearance pane show the swatch.
  #   #E8A13A = rgb(232,161,58) -> 232/255=0.909804, 161/255=0.631373,
  #                                58/255=0.227451   (NOT 0.223529)
  # Apple's own highlights are pale tints, so full gold reads noticeably
  # louder than stock, especially selecting a paragraph in Dark Mode. That is
  # the intended studio colour, stated so it is not a surprise.
  set_default NSGlobalDomain AppleHighlightColor -string "0.909804 0.631373 0.227451 Other"

  # AppleAccentColor: 0 red - 1 ORANGE - 2 yellow - 3 green - 4 blue
  #                   5 purple - 6 pink - -1 graphite - key ABSENT = multicolour
  # AppleAquaColorVariant is the legacy companion that MUST be written
  # alongside it: it is 6 when the user is on Graphite, and orange renders
  # wrong until it is 1.
  #
  # HONEST LIMITATION: this is APPLE's orange (about #FF9500), NOT brand gold
  # #E8A13A. No documented, long-stable key accepts an arbitrary accent RGB.
  # macOS 26 added a custom colour picker but the format it stores is
  # undocumented, and we do not guess at undocumented formats.
  set_default NSGlobalDomain AppleAccentColor      -int 1
  set_default NSGlobalDomain AppleAquaColorVariant -int 1
  info "the accent is Apple's orange (~#FF9500), not brand gold -- see the"
  info "comment in this file for why. The HIGHLIGHT above is exact gold."

  say ""
  say "        Apps read these at LAUNCH. A defaults write does not broadcast,"
  say "        so apps that are already open keep their old colours until you"
  say "        relaunch them -- and this installer will not kill your apps to"
  say "        force it. LOG OUT AND BACK IN for a uniform result."
  say ""
  say "        If windows pick up a gold cast, that is macOS wallpaper tinting,"
  say "        not this theme: System Settings > Appearance > \"Allow wallpaper"
  say "        tinting in windows\". Gold belongs on small elements; a tinted"
  say "        sidebar is a large surface, which the design law forbids."
  note ok "appearance" "dark mode + gold highlight + orange accent (log out to finish)"
  return 0
}

# ===========================================================================
#  STEP 7 -- FOLDER ICON   (--icon)
# ===========================================================================
#  NSWorkspace setIcon:forFile:options: through the ObjC bridge. Zero
#  dependencies: no Xcode Command Line Tools (SetFile / Rez / DeRez are NOT on
#  a stock Mac), no Homebrew, no sudo. It sends no Apple event, so it raises no
#  Automation prompt. `sips --addIcon` was removed in High Sierra.
#
#  It is opt-in and best-effort because a custom folder icon lives in a hidden
#  file literally named Icon+CR plus a com.apple.FinderInfo xattr -- which git
#  cannot carry and which any copy to another filesystem loses.
# ===========================================================================
step_icon() {
  local icns="$REPO/macos/icons/lhs.icns"
  if [ ! -f "$icns" ]; then
    skip "macos/icons/lhs.icns is missing -- folder icon not applied"
    note skip "folder icon" "lhs.icns missing from the repo"
    return 0
  fi
  if [ ! -d "$ASSETS" ]; then
    skip "$ASSETS does not exist yet -- folder icon not applied"
    note skip "folder icon" "the assets folder was not created"
    return 0
  fi
  # Keep a copy of the source next to our state, so the icon can be re-applied
  # without the repo. It goes in Application Support, not in the branded
  # folder itself -- ~/Pictures/Liberty Hill Studios stays clean.
  install_file "$icns" "$SUPPORT/icons/lhs.icns" || true

  if [ "$DRY_RUN" = "1" ]; then
    dry "NSWorkspace setIcon:forFile: $(shq "$icns") -> $(shq "$ASSETS")"
    note ok "folder icon" "would brand $ASSETS"
    return 0
  fi
  if osa_exec js "$JXA_SET_ICON" "$icns" "$ASSETS" >/dev/null 2>&1; then
    # TAB-separated verb + argument; see record_undo. Not a shell command line.
    record_undo "$(printf 'lhs_clear_folder_icon\t%s' "$ASSETS")"
    ok "studio icon applied to $ASSETS"
    info "Finder caches icons; reopen the window if it still looks stock."
    note ok "folder icon" "applied to ~/Pictures/Liberty Hill Studios"
  else
    skip "the icon could not be applied (harmless) -- $ASSETS is untouched"
    say  "        This one is pure decoration and needs a working ObjC bridge."
    say  "        You can always drag the icon on by hand: select"
    say  "        $SUPPORT/icons/lhs.icns, Cmd-C, then Get Info on the folder,"
    say  "        click the small icon top-left and Cmd-V."
    note skip "folder icon" "NSWorkspace refused it -- nothing was changed"
  fi
  return 0
}

# ===========================================================================
#  RUN
# ===========================================================================
head1 "$LHS_NAME -- macOS"
if [ "$DRY_RUN" = "1" ]; then
  say ""
  say "  DRY RUN. Every action below is printed and NOTHING is changed."
fi
say ""
info "repo:   $REPO"
info "assets: $ASSETS"
info "state:  $SUPPORT"

head2 "preflight"
step_preflight          # the only step allowed to abort the run

head2 "wallpaper assets"
guard step_assets "wallpaper assets"

head2 "desktop picture"
guard step_desktop_picture "desktop picture"

head2 "animated wallpaper (Plash)"
guard step_plash_notes "Plash guidance"

head2 "terminal schemes"
if [ "$DO_TERMINAL" = "1" ]; then
  guard step_terminal "terminal schemes"
else
  skip "not requested (pass --terminal)"
  note skip "terminal schemes" "not requested (pass --terminal)"
fi

head2 "launcher themes"
if [ "$DO_LAUNCHER" = "1" ]; then
  guard step_launcher "launcher themes"
else
  skip "not requested (pass --launcher)"
  note skip "launcher themes" "not requested (pass --launcher)"
fi

head2 "appearance"
if [ "$DO_ACCENT" = "1" ]; then
  guard step_accent "appearance"
else
  skip "not requested (pass --accent for dark mode + gold accent)"
  note skip "appearance" "not requested (pass --accent)"
fi

head2 "folder icon"
if [ "$DO_ICON" = "1" ]; then
  guard step_icon "folder icon"
else
  skip "not requested (pass --icon)"
  note skip "folder icon" "not requested (pass --icon)"
fi

# ---------------------------------------------------------------------------
head1 "summary"
if [ -n "$NOTES" ] && [ -s "$NOTES" ]; then
  say ""
  say "  DONE"
  if /usr/bin/grep -q '^ok|' "$NOTES" 2>/dev/null; then
    /usr/bin/awk -F'|' '$1=="ok"{printf "    %s+%s %-18s %s\n", g, o, $2, $3}' \
      g="$C_GRN" o="$C_OFF" "$NOTES"
  else
    say "    (nothing)"
  fi
  say ""
  say "  NOT DONE"
  if /usr/bin/grep -qv '^ok|' "$NOTES" 2>/dev/null; then
    /usr/bin/awk -F'|' '$1!="ok"{printf "    %s-%s %-18s %s\n", d, o, $2, $3}' \
      d="$C_DIM" o="$C_OFF" "$NOTES"
  else
    say "    (nothing -- everything requested applied)"
  fi
else
  info "(no per-item notes were recorded)"
fi

# note_status <label> -- the recorded status for a step (ok|skip|warn), or "".
# The closing block below must describe what ACTUALLY happened; asserting "the
# picture is already set" six lines under a summary that says it was not is
# the exact dishonesty design rule 4 forbids.
note_status() {
  [ -n "$NOTES" ] && [ -f "$NOTES" ] || return 0
  /usr/bin/awk -F'|' -v l="${1:-}" '$2==l {st=$1} END {if (st != "") print st}' \
    "$NOTES" 2>/dev/null || true
  return 0
}

head1 "what is left for you"
WP_STATUS="$(note_status 'desktop picture')"
ASSETS_STATUS="$(note_status 'wallpaper assets')"
say ""
if [ "$DRY_RUN" = "1" ]; then
  say " This was a PREVIEW. Nothing above was applied, so there is nothing left"
  say " to do yet. Re-run without --dry-run to actually install."
  say ""
  say " A real run would then leave you two things:"
  say "   * one manual folder pick in Plash, for the ANIMATED wallpaper:"
  say "       $LIVE"
  say "   * a static desktop picture already set, which is a complete answer on"
  say "     its own if you would rather not run a wallpaper app at all."
else
  if [ "$ASSETS_STATUS" = "ok" ]; then
    say " 1. THE ANIMATED WALLPAPER needs one manual folder pick in Plash. Give it"
    say "    this FOLDER (not the file inside it):"
    say ""
    say "      $LIVE"
  else
    say " 1. THE ANIMATED WALLPAPER has nothing to point at yet: the wallpaper"
    say "    assets did not install (see the summary above). Fix that and re-run"
    say "    this script, then give Plash the folder it creates:"
    say ""
    say "      $LIVE"
  fi
  say ""
  if [ "$WP_STATUS" = "ok" ]; then
    say " 2. The static picture is already set, and it is a complete answer on its"
    say "    own if you would rather not run a wallpaper app at all."
  else
    say " 2. THE STATIC PICTURE IS NOT SET -- see the summary above. Set it by"
    say "    hand, which takes ten seconds:"
    say "      System Settings > Wallpaper > Add Photo... and choose"
    say "        $ASSETS/lhs-static.png"
    say "    (or any file in $STILLS)"
  fi
fi
if [ "$DO_ACCENT" = "1" ] && [ "$DRY_RUN" != "1" ]; then
  say ""
  say " 3. LOG OUT AND BACK IN. Dark mode, the accent and the highlight only"
  say "    look consistent across already-running apps after a fresh login."
fi
say ""
say " Optional, and genuinely nice: your account picture."
say "   System Settings > Users & Groups > click your picture > choose a file:"
say "     $REPO/macos/icons/avatar-448.png"
say ""
say " Undo everything:  bash \"$HERE/uninstall.sh\"     (--dry-run to preview)"
say " Backups are never deleted. Find them with:"
say "   find \"\$HOME\" -maxdepth 6 -name '*.lhs-backup-*' 2>/dev/null"
say ""
exit 0
