#!/bin/bash
# ===========================================================================
#  Liberty Hill Studios Desktop Theme  --  macOS uninstaller
# ===========================================================================
#
#  Reverses install.sh, in this order -- and the order is load-bearing:
#
#    1. replays the generated undo log in REVERSE: puts your previous desktop
#       picture back and clears the custom folder icon. This runs BEFORE any
#       deletion, so we never delete the image the desktop is currently
#       pointing at and leave you staring at a blank screen.
#    2. restores every macOS preference key the --accent flag changed, from
#       the values recorded at install time. A key that did not exist before
#       is DELETED, never set to an "opposite" value -- Light Mode literally
#       IS the absence of AppleInterfaceStyle, so writing "Light" would leave
#       a bogus key behind and desync System Settings from everything that
#       reads it.
#    3. removes the files install.sh created -- from its own manifest, and
#       only those whose absolute path matches a hard-coded allow-list.
#       Anything that is STILL your live wallpaper is kept and reported.
#    4. tidies empty directories (rmdir, never rm -r), removes the installer's
#       state files, and tells you plainly what it could NOT undo.
#
#  The assets folder (~/Pictures/Liberty Hill Studios, about 172 MB) is only
#  removed if you say yes when asked.
#
#  SAFETY, same rules as the installer:
#    * bash 3.2 compatible (Apple's /bin/bash), no GNU-isms, no `sed -i`
#    * no sudo, no `rm -rf`, no SIP/Gatekeeper tampering, no killing your apps
#    * BACKUPS ARE NEVER DELETED unless you pass --purge-backups
#    * --dry-run prints everything and changes nothing
#    * a step that cannot finish says why and the rest still runs; the machine
#      is never left half-reverted
# ===========================================================================

# On macOS /bin/sh IS bash 3.2 running as argv[0]="sh", so BASH_VERSION is SET
# and only POSIX mode gives it away. `/bin/bash` invoked as `bash` is never in
# POSIX mode, so this cannot loop.
if [ -z "${BASH_VERSION:-}" ] || shopt -qo posix 2>/dev/null; then
  if [ -x /bin/bash ] && [ -f "$0" ]; then exec /bin/bash "$0" "$@"; fi
  echo "lhs: please run this with:  bash $0" >&2
  exit 2
fi

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
umask 022

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"

ASSETS="$HOME/Pictures/Liberty Hill Studios"
LIVE="$ASSETS/Living Dusk"
STILLS="$ASSETS/stills"
SUPPORT="$HOME/Library/Application Support/Liberty Hill Studios"
MANIFEST="$SUPPORT/install-manifest.txt"
UNDO="$SUPPORT/undo.log"
TSV="$SUPPORT/appearance-backup.tsv"

DRY_RUN=0
ASSUME_YES=0
RESET_APPEARANCE=0
PURGE_BACKUPS=0

REMOVE_ASSETS=0        # decided by the one confirmation prompt
LEFTOVER=""            # temp file: "could not undo" lines for the closing report
WP_CACHE=""            # cached read-back of the current desktop picture(s)
HAD_TERMINAL=0         # did this install ever include --terminal? (from the manifest)
HAD_LAUNCHER=0         # did this install ever include --launcher? (from the manifest)

# --- output ----------------------------------------------------------------
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
  printf '\n%s[error]%s uninstall.sh: line %s exited %s.\n' \
    "$C_RED" "$C_OFF" "${2:-?}" "${1:-?}" >&2
  printf '        Re-running this script is safe: it picks up where it stopped.\n' >&2
}
trap 'lhs_on_err "$?" "$LINENO"' ERR

lhs_cleanup() {
  if [ -n "$LEFTOVER" ] && [ -f "$LEFTOVER" ]; then /bin/rm -f -- "$LEFTOVER"; fi
  return 0
}
trap 'lhs_cleanup' EXIT

LEFTOVER="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/lhs-left.XXXXXX" 2>/dev/null)" || LEFTOVER=""

leftover() {
  if [ -z "$LEFTOVER" ]; then warn "${*:-}"; return 0; fi
  printf '%s\n' "${*:-}" >> "$LEFTOVER" 2>/dev/null || true
  return 0
}

usage() {
  cat <<'USAGE'
Liberty Hill Studios Desktop Theme -- macOS uninstaller

  ./uninstall.sh [options]

WHAT IT DOES
  * puts your previous desktop picture back (it was recorded at install time)
  * restores every appearance preference --accent changed, exactly: a key that
    did not exist before is deleted, not set to an opposite value
  * removes the files the installer created, from its own manifest
  * asks before removing ~/Pictures/Liberty Hill Studios (about 172 MB)
  * tells you what it could not undo, instead of pretending

OPTIONS
  --dry-run           Print every action, change absolutely nothing. (The
                      preview assumes you would say yes to the assets folder,
                      so you can see the full list.)
  --yes, -y           Do not ask about the assets folder -- remove it.
  --reset-appearance  Only useful if the recorded "before" values are missing:
                      delete the appearance keys the installer sets, returning
                      macOS to ITS defaults (Light/Auto, blue accent, blue
                      highlight). Off by default, because it cannot tell our
                      value from one you had already.
  --purge-backups     Also delete the *.lhs-backup-* files. Off by default --
                      your originals are worth more than a tidy folder.
  --help, -h          This text.

Backups, unless you pass --purge-backups, are left exactly where they are:
  find "$HOME" -maxdepth 6 -name '*.lhs-backup-*' 2>/dev/null
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n)       DRY_RUN=1 ;;
    --yes|-y)           ASSUME_YES=1 ;;
    --reset-appearance) RESET_APPEARANCE=1 ;;
    --purge-backups)    PURGE_BACKUPS=1 ;;
    --help|-h)          usage; exit 0 ;;
    *)                  usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

# --- primitives ------------------------------------------------------------
# shq -- shell-quote for display. Every path here can contain spaces
# ("Liberty Hill Studios"), so an unquoted dry-run line would be ambiguous
# about where one argument ends and the next begins.
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

run() {
  if [ "$DRY_RUN" = "1" ]; then
    dry "$(shq "$@")"
    return 0
  fi
  "$@"
}

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
    warn "$label did not complete (exit $rc) -- continuing with the rest"
    leftover "$label -- did not complete; re-run ./uninstall.sh"
  fi
  return 0
}

# ===========================================================================
#  PATH ALLOW-LIST
# ===========================================================================
#  Nothing is ever removed unless its absolute path matches one of these. The
#  manifest is a plain text file in the user's home folder, so it is treated
#  as UNTRUSTED input: a typo, a hand-edit or a stale entry must not be able
#  to delete something that is not ours.
# ===========================================================================
path_allowed() {
  local p="$1"
  case "$p" in
    ''|/|"$HOME"|"$HOME"/) return 1 ;;
    *../*|*/..|*//*)       return 1 ;;
    *.lhs-backup-*)        return 1 ;;   # backups are sacred
  esac
  case "$p" in
    "$SUPPORT"/*) return 0 ;;
    "$ASSETS"/*)
      # Only with your say-so. Everything else above is small state; this is
      # 172 MB of wallpaper you may well want to keep.
      [ "$REMOVE_ASSETS" = "1" ] && return 0
      return 1 ;;
    "$HOME/.config/kitty/liberty-hill-dusk.kitty.conf")             return 0 ;;
    "$HOME/.config/alacritty/themes/liberty-hill-dusk.alacritty.toml") return 0 ;;
    "$HOME/.config/wezterm/colors/liberty-hill-dusk.wezterm.lua")   return 0 ;;
    "$HOME/.config/ghostty/themes/liberty-hill-dusk")               return 0 ;;
  esac
  return 1
}

# remove_file <path> -- returns 0 only if the path was ours to remove, so the
# caller's tally can never count something it refused to touch.
remove_file() {
  local p="$1"
  if [ ! -e "$p" ]; then return 1; fi
  if ! path_allowed "$p"; then
    case "$p" in
      "$ASSETS"/*) return 1 ;;    # kept on purpose; reported once, not per file
      *)
        warn "refusing to remove an out-of-scope path: $p"
        leftover "not removed (outside the allow-list): $p"
        return 1 ;;
    esac
  fi
  if [ -d "$p" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      dry "rmdir $(shq "$p")   (only if empty)"
      return 0
    fi
    # A directory that was NOT removed must not be counted as removed.
    if /bin/rmdir "$p" 2>/dev/null; then
      return 0
    fi
    info "not empty, left in place: $p"
    return 1
  fi
  run /bin/rm -f -- "$p"
  return 0
}

# reverse_lines <file> -- print a file backwards. `tail -r` is BSD-only and
# `tac` is GNU-only, so neither is used.
reverse_lines() {
  /usr/bin/awk '{a[NR]=$0} END {for (i=NR; i>0; i--) print a[i]}' "$1"
}

confirm() {
  local prompt="$1" ans=""
  if [ "$ASSUME_YES" = "1" ]; then return 0; fi
  if [ "$DRY_RUN" = "1" ]; then
    dry "would ask: $prompt"
    info "(the preview below assumes YES, so you can see everything it covers)"
    return 0
  fi
  if [ ! -t 0 ]; then
    info "not an interactive terminal, so the answer is NO."
    info "Re-run with --yes if you meant to remove it."
    return 1
  fi
  printf '  %s [y/N] ' "$prompt"
  IFS= read -r ans || ans=""
  case "$ans" in
    y|Y|yes|YES|Yes) return 0 ;;
    *)               return 1 ;;
  esac
}

# ===========================================================================
#  WALLPAPER HELPERS
# ===========================================================================
#  Same public API as the installer: -[NSWorkspace setDesktopImageURL:...]
#  called in-process from osascript. No Apple event leaves the process, so
#  there is no Automation permission prompt.
# ===========================================================================
osa_exec() {
  local lang="$1" script="$2"
  shift 2
  if [ "$lang" = "js" ]; then
    printf '%s\n' "$script" | /usr/bin/osascript -l JavaScript - ${1+"$@"}
  else
    printf '%s\n' "$script" | /usr/bin/osascript - ${1+"$@"}
  fi
}

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
		-- The API returns a BOOL. CAPTURE IT: discarding it makes this handler
		-- return "ok" unconditionally, which would make the caller print
		-- "desktop picture restored" with no evidence it happened.
		set okFlag to (ws's setDesktopImageURL:theURL forScreen:scr options:opts |error|:(missing value))
		if (okFlag as boolean) is false then error "setDesktopImageURL returned false" number 8001
	end repeat
	return "ok"
end run
APPLESCRIPT
)"

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

refresh_wp_cache() {
  WP_CACHE="$(osa_exec as "$ASOBJC_READ_WALLPAPER" 2>/dev/null || true)"
  return 0
}

is_live_wallpaper() {
  local p="$1" line=""
  [ -n "$WP_CACHE" ] || return 1
  while IFS= read -r line; do
    [ "$line" = "$p" ] && return 0
  done <<EOF
$WP_CACHE
EOF
  return 1
}

# ===========================================================================
#  UNDO-LOG VERBS
#  install.sh writes TAB-SEPARATED records into undo.log:
#      <verb><TAB><argument>
#  NOT shell command lines. The reader below splits on the tab, compares the
#  verb token EXACTLY against the two names here, and calls the matching
#  function with the argument as a single word. There is no eval anywhere: the
#  undo log lives in a user-writable folder, and an eval over user-writable
#  input is a hole that quoting does not close (a prefix-matching case pattern
#  like "lhs_restore_wallpaper "* constrains only the PREFIX, so the rest of
#  the line would still run -- and would run during --dry-run too).
#
#  Both verbs must be safe to run twice and safe to run when the thing they
#  undo is already gone.
# ===========================================================================
lhs_restore_wallpaper() {
  local p="${1:-}"
  [ -n "$p" ] || return 0
  if [ ! -f "$p" ]; then
    skip "your previous desktop picture is gone: $p"
    leftover "previous desktop picture could not be restored (the file no longer exists): $p"
    leftover "  -> pick one yourself: System Settings > Wallpaper"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    dry "set the desktop picture back to $p"
    return 0
  fi
  if osa_exec as "$ASOBJC_SET_WALLPAPER" "$p" >/dev/null 2>&1 \
     || osa_exec js "$JXA_SET_WALLPAPER" "$p" >/dev/null 2>&1; then
    /bin/sleep 1
    refresh_wp_cache
    ok "desktop picture restored to $p"
  else
    warn "could not restore the previous desktop picture automatically"
    leftover "pick a wallpaper yourself: System Settings > Wallpaper (we wanted $p)"
  fi
  return 0
}

lhs_clear_folder_icon() {
  local dir="${1:-}" fi_hex="" rest="" flags=0
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] || return 0
  # A custom folder icon is a hidden file literally named Icon + carriage
  # return, plus the kHasCustomIcon flag inside the folder's FinderInfo xattr.
  # Removing the Icon file ALONE already stops Finder drawing the custom icon.
  if [ -e "$dir/Icon"$'\r' ]; then
    run /bin/rm -f -- "$dir/Icon"$'\r'
  fi
  # com.apple.FinderInfo is a 32-byte STRUCTURE, not just the icon flag: it
  # also carries the Finder flags, which include your colour tag/label index
  # and the invisible bit. Deleting the whole attribute would silently throw
  # away a tag you applied to this folder, and this script promises not to
  # delete things you did not ask it to. So we only clear it when it is empty
  # apart from the icon flag; otherwise we say exactly how to clear it.
  #
  # The check: `xattr -p` prints the 32 bytes as hex. For a folder those bytes
  # are a FolderInfo -- rect (0-7), FINDER FLAGS (8-9), location (10-13),
  # reserved (14-15), then 16 more extended bytes. kHasCustomIcon is 0x0400
  # inside the flags word; your colour LABEL lives in bits 1-3 of the same
  # word. So we clear the whole attribute ONLY when, with the icon bit masked
  # off, every remaining bit of every byte is zero. Anything else -- a label, a
  # stationery/invisible flag, an extended field -- and we leave it alone and
  # print the command.
  if [ "$DRY_RUN" = "1" ]; then
    dry "xattr -d com.apple.FinderInfo $dir   (only if it holds nothing but the icon flag)"
  else
    fi_hex="$(/usr/bin/xattr -p com.apple.FinderInfo "$dir" 2>/dev/null \
              | /usr/bin/tr -d ' \n' || true)"
    case "$fi_hex" in
      *[!0-9A-Fa-f]*) fi_hex="" ;;   # not the plain hex we know how to read
    esac
    if [ -z "$fi_hex" ]; then
      :                              # no attribute, or an unreadable one: leave it
    elif [ "${#fi_hex}" -ne 64 ]; then
      info "left com.apple.FinderInfo on $dir intact (unexpected size)"
      info "  clear it yourself with:  xattr -d com.apple.FinderInfo \"$dir\""
    else
      # 0xFBFF = every flag bit EXCEPT kHasCustomIcon (0x0400).
      flags=$(( 16#${fi_hex:16:4} & 65535 ))
      rest="${fi_hex:0:16}${fi_hex:20:44}"
      case "$rest" in *[!0]*) rest="nonzero" ;; *) rest="" ;; esac
      if [ "$(( flags & 64511 ))" -eq 0 ] && [ -z "$rest" ]; then
        /usr/bin/xattr -d com.apple.FinderInfo "$dir" 2>/dev/null || true
      else
        info "left com.apple.FinderInfo on $dir intact -- it also stores your"
        info "Finder tag/label, and this script will not delete that for you."
        info "The custom icon is gone either way. Clear the rest yourself with:"
        info "  xattr -d com.apple.FinderInfo \"$dir\""
      fi
    fi
  fi
  ok "custom folder icon cleared on $dir"
  info "Finder caches icons -- close and reopen the window if it still shows."
  return 0
}

# ===========================================================================
#  STEPS
# ===========================================================================

# scan_manifest_evidence -- set HAD_TERMINAL / HAD_LAUNCHER from the manifest.
# Evidence, not guesswork: these are the paths install.sh records for --terminal
# and --launcher. Anything unrecognised is ignored (the manifest is untrusted
# input; this only ever flips a flag that makes the closing report LONGER).
scan_manifest_evidence() {
  local p=""
  [ -f "$MANIFEST" ] || return 0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      "$SUPPORT"/terminal/*)            HAD_TERMINAL=1 ;;
      "$HOME"/.config/kitty/*)          HAD_TERMINAL=1 ;;
      "$HOME"/.config/alacritty/*)      HAD_TERMINAL=1 ;;
      "$HOME"/.config/wezterm/*)        HAD_TERMINAL=1 ;;
      "$HOME"/.config/ghostty/*)        HAD_TERMINAL=1 ;;
      "$SUPPORT"/launcher/*)            HAD_LAUNCHER=1 ;;
    esac
  done < "$MANIFEST"
  return 0
}

step_preflight() {
  [ "$(/usr/bin/uname -s)" = "Darwin" ] || die "this uninstaller is macOS-only."
  [ "$(/usr/bin/id -u)" != "0" ] || die "do not run this as root or with sudo. It does not need it."

  # macOS pgrep matches kp_proc.p_comm, truncated by the kernel to MAXCOMLEN =
  # 16 characters, so -x "System Preferences" (18 chars) can never match.
  # Match its bundle path instead.
  if /usr/bin/pgrep -x "System Settings" >/dev/null 2>&1 \
     || /usr/bin/pgrep -f '/System Preferences.app/Contents/MacOS/' >/dev/null 2>&1; then
    warn "System Settings is open. macOS caches these preferences while it runs"
    warn "and can write its stale copy back over ours. Quit it and re-run if the"
    warn "appearance does not change back."
  fi

  # Read the manifest ONCE, here, while it still exists: the closing "what this
  # could not undo" report must only walk you through removing a Raycast theme
  # or a kitty include line if this install actually put one there. The default
  # install is a wallpaper and nothing else, and its uninstall should read that
  # way. This runs OUTSIDE guard(), so the two flags survive into the report.
  scan_manifest_evidence

  if [ ! -d "$SUPPORT" ] && [ ! -d "$ASSETS" ]; then
    say ""
    say "  Nothing to uninstall: neither"
    say "    $SUPPORT"
    say "  nor"
    say "    $ASSETS"
    say "  exists. Nothing was changed."
    exit 0
  fi
  refresh_wp_cache
  return 0
}

# --- the one question ------------------------------------------------------
step_ask() {
  local size=""
  if [ ! -d "$ASSETS" ]; then
    REMOVE_ASSETS=0
    skip "$ASSETS does not exist -- nothing to ask about"
    return 0
  fi
  size="$(/usr/bin/du -sh "$ASSETS" 2>/dev/null | /usr/bin/awk '{print $1}' || true)"
  say ""
  say "  The assets folder holds the living wallpaper page and every baked"
  say "  still${size:+ (}${size}${size:+)}:"
  say "    $ASSETS"
  say ""
  if confirm "Remove it?"; then
    REMOVE_ASSETS=1
    ok "it will be removed"
  else
    REMOVE_ASSETS=0
    ok "keeping it -- everything else is still reverted"
    leftover "kept at your request: $ASSETS"
  fi
  return 0
}

# --- 1. replay the undo log (BEFORE any deletion) --------------------------
step_replay_undo() {
  local line="" verb="" arg=""
  if [ ! -f "$UNDO" ]; then
    skip "no undo log at $UNDO"
    leftover "no undo log was found, so your previous desktop picture is unknown"
    leftover "  -> if the desktop goes blank, pick one: System Settings > Wallpaper"
    return 0
  fi
  # Newest lines are last in the file, so replay it reversed.
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    # A line written by an OLDER install.sh is space-separated and shell-quoted
    # ("lhs_restore_wallpaper '/path with spaces'"). We do not parse it and we
    # do not eval it -- it is reported and skipped, with the file named so you
    # can act on it yourself. Silently mis-parsing it would be worse.
    case "$line" in
      *$'\t'*) ;;
      *)
        warn "old-format line in the undo log, NOT executed: $line"
        leftover "undo log line skipped (pre-tab format, from an older install): $line"
        continue ;;
    esac
    verb="${line%%$'\t'*}"
    arg="${line#*$'\t'}"
    # EXACT match on the verb token, then a direct call. No eval, so nothing
    # after the argument can ever be executed, in a dry run or otherwise.
    case "$verb" in
      lhs_restore_wallpaper)
        lhs_restore_wallpaper "$arg" || warn "undo step failed: $verb $arg" ;;
      lhs_clear_folder_icon)
        lhs_clear_folder_icon "$arg" || warn "undo step failed: $verb $arg" ;;
      *)
        warn "unrecognised verb in the undo log, NOT executed: $line"
        leftover "undo log line skipped (unrecognised verb): $line"
        ;;
    esac
  done <<EOF
$(reverse_lines "$UNDO")
EOF
  return 0
}

# --- 2. appearance ---------------------------------------------------------
step_appearance() {
  local d="" k="" t="" v="" n=0
  if [ -f "$TSV" ]; then
    while IFS="$(printf '\t')" read -r d k t v; do
      [ -n "${d:-}" ] || continue
      [ -n "${k:-}" ] || continue
      case "${t:-}" in
        ABSENT)
          # The key did not exist before we installed, so DELETE it. Never
          # write an "opposite" value: Light Mode literally IS the absence of
          # AppleInterfaceStyle, and `defaults delete` exits 1 on a missing
          # key, which is why every one of these carries `|| true`.
          if [ "$DRY_RUN" = "1" ]; then
            dry "defaults delete $d $k"
          else
            /usr/bin/defaults delete "$d" "$k" 2>/dev/null || true
          fi
          ;;
        string)  run /usr/bin/defaults write "$d" "$k" -string "${v:-}" ;;
        integer) run /usr/bin/defaults write "$d" "$k" -int    "${v:-}" ;;
        float)   run /usr/bin/defaults write "$d" "$k" -float  "${v:-}" ;;
        boolean)
          case "${v:-}" in 1) v="true" ;; 0) v="false" ;; esac
          run /usr/bin/defaults write "$d" "$k" -bool "${v:-false}"
          ;;
        *)
          warn "$d $k: unsupported recorded type '${t:-}' -- restore it by hand"
          leftover "preference not restored: $d $k (recorded type '${t:-}')"
          continue
          ;;
      esac
      n=$((n + 1))
    done < "$TSV"
    ok "restored $n preference key(s) to their exact pre-install values"
  elif [ "$RESET_APPEARANCE" = "1" ]; then
    warn "no recorded values at $TSV -- falling back to --reset-appearance."
    warn "This returns macOS to ITS defaults, not necessarily to yours."
    for k in AppleInterfaceStyle AppleInterfaceStyleSwitchesAutomatically \
             AppleHighlightColor AppleAccentColor AppleAquaColorVariant; do
      if [ "$DRY_RUN" = "1" ]; then
        dry "defaults delete NSGlobalDomain $k"
      else
        /usr/bin/defaults delete NSGlobalDomain "$k" 2>/dev/null || true
      fi
    done
    ok "appearance keys deleted (macOS defaults restored)"
  else
    skip "no recorded values at $TSV -- appearance left exactly as it is"
    say  "        Nothing was guessed at. That file only exists if you ran"
    say  "        install.sh --accent. If you want macOS's own defaults back,"
    say  "        re-run with --reset-appearance, or run these five yourself:"
    say  "          defaults delete -g AppleInterfaceStyle"
    say  "          defaults delete -g AppleInterfaceStyleSwitchesAutomatically"
    say  "          defaults delete -g AppleHighlightColor"
    say  "          defaults delete -g AppleAccentColor"
    say  "          defaults delete -g AppleAquaColorVariant"
    return 0
  fi
  info "apps already running keep the old colours until you relaunch them."
  info "Log out and back in for a clean, consistent result. No app is killed."
  return 0
}

# --- 3. remove the files we installed --------------------------------------
step_remove_files() {
  local p="" n=0 kept=0 assets_skipped=0
  if [ ! -f "$MANIFEST" ]; then
    skip "no manifest at $MANIFEST -- nothing recorded to remove"
    leftover "no install manifest was found, so no files could be removed automatically"
    return 0
  fi
  refresh_wp_cache

  # Reverse order: newest entries first, so a directory recorded early is the
  # last thing considered.
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$p" ] || continue
    # NEVER delete the image the desktop is currently pointing at. Step 1
    # already tried to put your previous wallpaper back; if that could not
    # happen (nothing recorded, or the old file is gone) this is what stops
    # the uninstall from leaving you with a blank desktop.
    if is_live_wallpaper "$p"; then
      kept=$((kept + 1))
      warn "still your live desktop picture, so it is NOT deleted:"
      say  "          $p"
      leftover "left in place because it is still your desktop picture: $p"
      leftover "  -> pick another wallpaper (System Settings > Wallpaper), then delete that file"
      continue
    fi
    case "$p" in
      "$ASSETS"/*)
        if [ "$REMOVE_ASSETS" != "1" ]; then
          assets_skipped=$((assets_skipped + 1))
          continue
        fi
        ;;
    esac
    if remove_file "$p"; then n=$((n + 1)); fi
  done <<EOF
$(reverse_lines "$MANIFEST")
EOF

  # A dry run removed nothing, so it must not say "removed" in the past tense:
  # a reader who takes in only the last line would believe it had already run.
  if [ "$DRY_RUN" = "1" ]; then
    ok "would remove $n recorded file(s)"
  else
    ok "removed $n recorded file(s)"
  fi
  if [ "$assets_skipped" -gt 0 ]; then
    info "$assets_skipped file(s) under $ASSETS kept at your request"
  fi
  if [ "$kept" -gt 0 ]; then
    info "$kept file(s) kept because they are your live wallpaper"
  fi
  return 0
}

# --- 4. empty directories --------------------------------------------------
step_prune_dirs() {
  local d=""
  # Deepest first. `rmdir` (never `rm -r`) so a directory holding anything we
  # did not put there survives untouched, with its contents.
  for d in \
    "$LIVE" "$STILLS" "$ASSETS/icons" "$ASSETS" \
    "$SUPPORT/terminal" "$SUPPORT/launcher" "$SUPPORT/icons" \
    "$HOME/.config/alacritty/themes" "$HOME/.config/wezterm/colors" \
    "$HOME/.config/ghostty/themes"
  do
    [ -d "$d" ] || continue
    case "$d" in
      "$ASSETS"|"$LIVE"|"$STILLS"|"$ASSETS/icons")
        [ "$REMOVE_ASSETS" = "1" ] || continue ;;
    esac
    if [ "$DRY_RUN" = "1" ]; then
      dry "rmdir $(shq "$d")   (only if empty)"
    elif /bin/rmdir "$d" 2>/dev/null; then
      ok "removed empty directory $d"
    fi
  done
  return 0
}

# --- 5. installer state + backups ------------------------------------------
step_state() {
  local f="" tmp="" survivors=0 p=""

  # If anything we recorded is STILL on disk -- because you kept the assets
  # folder, or because a file was held back for being your live wallpaper --
  # the manifest is pruned to just those and KEPT. Deleting it would strand
  # them: a later ./uninstall.sh would have no record of what is ours, and
  # would refuse to touch anything. This is what makes "keep it for now" a
  # decision you can change your mind about.
  # Skipped in a dry run: nothing was actually deleted, so every path would
  # look like a survivor and the message would be nonsense.
  if [ "$DRY_RUN" != "1" ] && [ -f "$MANIFEST" ]; then
    tmp="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/lhs-man.XXXXXX" 2>/dev/null)" || tmp=""
    if [ -n "$tmp" ]; then
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        [ -e "$p" ] || continue
        printf '%s\n' "$p" >> "$tmp"
        survivors=$((survivors + 1))
      done < "$MANIFEST"
    fi
  fi

  if [ "$survivors" -gt 0 ]; then
    # `cat >` rather than `mv`: it preserves the file's inode and mode.
    /bin/cat "$tmp" > "$MANIFEST"
    ok "kept the installer's state: $survivors file(s) are still on disk"
    info "run ./uninstall.sh again (with --yes) to finish removing them."
    leftover "$survivors installed file(s) are still on disk -- re-run ./uninstall.sh --yes to remove them"
    [ -n "$tmp" ] && [ -f "$tmp" ] && /bin/rm -f -- "$tmp"
    return 0
  fi
  [ -n "$tmp" ] && [ -f "$tmp" ] && /bin/rm -f -- "$tmp"

  for f in "$MANIFEST" "$UNDO" "$TSV"; do
    [ -e "$f" ] || continue
    run /bin/rm -f -- "$f"
  done
  ok "removed the installer's own state files"

  if [ "$PURGE_BACKUPS" = "1" ]; then
    warn "--purge-backups: deleting *.lhs-backup-* files under your home folder"
    if [ "$DRY_RUN" = "1" ]; then
      /usr/bin/find "$HOME" -maxdepth 6 -name '*.lhs-backup-*' -type f -print 2>/dev/null \
        | /usr/bin/sed 's/^/  [dry-run] rm -f /' || true
    else
      # -delete is deliberately not used: an explicit per-file rm behind a
      # second pattern check is easier to audit and cannot be widened by a
      # stray argument.
      /usr/bin/find "$HOME" -maxdepth 6 -name '*.lhs-backup-*' -type f -print 2>/dev/null \
        | while IFS= read -r f; do
            case "$f" in *.lhs-backup-*) /bin/rm -f -- "$f" ;; esac
          done || true
    fi
  fi

  if [ -d "$SUPPORT" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      dry "rmdir $(shq "$SUPPORT")   (only if empty)"
    elif /bin/rmdir "$SUPPORT" 2>/dev/null; then
      ok "removed $SUPPORT"
    else
      info "kept $SUPPORT -- it still holds backups, or files we did not put"
      info "there. Delete it yourself once you are happy."
    fi
  fi
  return 0
}

# ===========================================================================
#  RUN
# ===========================================================================
head1 "Liberty Hill Studios Desktop Theme -- macOS uninstall"
if [ "$DRY_RUN" = "1" ]; then
  say ""
  say "  DRY RUN. Every action below is printed and NOTHING is changed."
fi

head2 "preflight"
step_preflight

head2 "the assets folder"
# NOT run through guard: guard isolates a step in a SUBSHELL, and the answer
# to this question has to survive into every later step.
step_ask

head2 "restoring what we replaced"
guard step_replay_undo "undo log"

head2 "appearance preferences"
guard step_appearance "appearance restore"

head2 "removing installed files"
guard step_remove_files "file removal"

head2 "empty directories"
guard step_prune_dirs "directory tidy-up"

head2 "installer state"
guard step_state "state cleanup"

# ---------------------------------------------------------------------------
head1 "What this could NOT undo automatically"
say ""
say " None of these were installed by writing to a place we control, so it"
say " would be dishonest to claim they are gone. Each takes seconds by hand:"
say ""
say "  * PLASH'S FOLDER PICK. Plash holds its own security-scoped bookmark to"
say "    the \"Living Dusk\" folder -- that is Plash's state, not a file of"
say "    ours. Remove the website entry inside Plash. (And Plash itself was"
say "    never installed by us, so it is not uninstalled by us either.)"
say "  * YOUR PREVIOUS DESKTOP PICTURE, if the installer never recorded one --"
say "    for instance if the old wallpaper was a system asset or a dynamic"
say "    desktop rather than a plain file. System Settings > Wallpaper."
# The launcher and terminal bullets are gated on EVIDENCE from the manifest.
# After the default install -- a wallpaper and nothing else -- nobody should be
# walked through deleting a Raycast theme they never had or hunting for a line
# in a kitty.conf they never edited.
if [ "$HAD_LAUNCHER" = "1" ]; then
say "  * RAYCAST / ALFRED THEMES. Raycast has no on-disk theme folder at all"
say "    (the deep link is its only import route) and Alfred imports into its"
say "    own preferences folder, which you are free to relocate -- so we never"
say "    wrote to either. Remove them in-app:"
say "      Raycast: Settings > General > Appearance > right-click the theme"
say "      Alfred:  Settings > Appearance > right-click Liberty Hill Dusk"
fi
if [ "$HAD_TERMINAL" = "1" ]; then
say "  * TERMINAL PROFILES YOU IMPORTED. Terminal.app and iTerm2 own their"
say "    preferences while they run, so the installer let them import rather"
say "    than writing to their plists:"
say "      Terminal.app: Settings > Profiles > select another > Default, then"
say "                    right-click Liberty Hill Dusk > Remove"
say "      iTerm2:       Settings > Profiles > Colors > Color Presets... >"
say "                    pick another, then right-click ours > Delete"
say "  * THE ONE LINE YOU ADDED to kitty.conf / alacritty.toml / wezterm.lua /"
say "    the Ghostty config. The installer never edited those files, so it"
say "    will not edit them now either -- delete that line yourself. The theme"
say "    files it dropped next to them have been removed, so leaving the line"
say "    behind would make the app complain about a missing file."
fi
say "  * APPS THAT ARE ALREADY RUNNING keep the old colours until they are"
say "    relaunched. Log out and back in to finish the job. Nothing here kills"
say "    an app of yours to force it."
if [ -n "$LEFTOVER" ] && [ -s "$LEFTOVER" ]; then
  say ""
  say " From this run specifically:"
  /usr/bin/sed 's/^/  * /' "$LEFTOVER"
fi
say ""
if [ "$PURGE_BACKUPS" != "1" ]; then
  say " Backups were left in place on purpose. Find them with:"
  say "   find \"\$HOME\" -maxdepth 6 -name '*.lhs-backup-*' 2>/dev/null"
  say " (Re-run with --purge-backups to delete them once you are happy.)"
  say ""
fi
say " Reinstall any time:  bash \"$HERE/install.sh\""
say ""
exit 0
