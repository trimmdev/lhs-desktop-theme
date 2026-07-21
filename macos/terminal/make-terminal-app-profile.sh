#!/bin/bash
# ---------------------------------------------------------------------------
# make-terminal-app-profile.sh
# Liberty Hill Studios - generates the "Liberty Hill Dusk" profile for
# Apple's Terminal.app, on macOS, from the studio palette.
#
# Palette source of truth: <repo>/terminal/liberty-hill-dusk.json
# (the Windows Terminal scheme). The hexes below are byte-identical to it.
#
# WHY THIS SCRIPT EXISTS AT ALL
#   Every other emulator in this folder takes a plain-text colour file that we
#   can just commit. Terminal.app does not: each colour in a .terminal file is
#   an NSKeyedArchiver-encoded NSColor stored as a base64 <data> blob. So this
#   file is the generator, and it runs on the Mac.
#
# WHAT IT DOES / DOES NOT DO
#   * Writes ONE file: "Liberty Hill Dusk.terminal".
#   * Verifies the file it just wrote by unarchiving every colour back out and
#     comparing to the palette. It REFUSES TO INSTALL a file whose colours
#     verify WRONG. If verification cannot RUN at all (osascript produced no
#     output), it installs the structurally-verified file and says so in a
#     warning -- those are two different outcomes and the script does not
#     conflate them.
#   * Never uses sudo. Never deletes anything. Backs up any file it would
#     overwrite to <file>.lhs-backup-<timestamp> first.
#   * Does NOT change your Terminal settings unless you pass --set-default,
#     and even then it records your previous profile so you can put it back.
#   * Never runs `defaults write com.apple.Terminal ...`. Terminal is running
#     while you read this; it rewrites its own preference domain when it quits
#     and would silently discard any scripted write. Importing the file is the
#     only stable path.
#
# TOOLCHAIN (in order; the first that works wins)
#   1. /usr/bin/osascript with AppleScript-ObjC. Present on every macOS, no
#      Xcode, no Homebrew, no Python. Uses the real NSKeyedArchiver, so the
#      blobs are exactly what Terminal.app itself would write.
#   2. python3 + the STDLIB plistlib module (no PyObjC - Apple's python3 does
#      NOT ship PyObjC, so any generator that imports Foundation fails on a
#      stock Mac). Only tried if a real python3 is found; we never invoke
#      /usr/bin/python3 unless Xcode Command Line Tools are installed, because
#      without them it is a stub that pops a GUI installer dialog and blocks.
#   If both are unavailable the script fails LOUDLY and writes nothing.
#
# COLOUR-SPACE CAVEAT (documented, deliberate)
#   Colours are archived as NSDeviceRGB (NSColorSpace = 2), which is what
#   effectively every .terminal generator emits and what the format's
#   3-object archive shape assumes. NSDeviceRGB is not strictly sRGB, so on a
#   wide-gamut (P3) display Terminal may render these a touch more saturated
#   than the hexes. Terminal.app also re-saves profiles through its own colour
#   conversion, so exact hex fidelity in Terminal.app is not achievable by any
#   method. If you need exact colour, use iTerm2 / kitty / WezTerm / Ghostty /
#   Alacritty from this same folder - all five are exact.
#
# bash 3.2 safe (that is the bash Apple ships, frozen at 3.2.57): no
# associative arrays, no mapfile, no ${v^^}, no ((i++)), no `sed -i`.
# ---------------------------------------------------------------------------

set -u

SELF="make-terminal-app-profile"
PROFILE_NAME="Liberty Hill Dusk"
STAMP="$(date +%Y%m%d-%H%M%S)"

DEFAULT_DIR="$HOME/Library/Application Support/Liberty Hill Studios/terminal"
OUT=""
SET_DEFAULT=0

# Where the generators' stderr goes. Kept for the life of the run so a failure
# can print WHY, then removed on exit. If mktemp is unavailable we fall back to
# /dev/null -- losing the diagnostics is bad, but not writing anywhere
# unexpected matters more.
ERRLOG="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/lhs-termgen.XXXXXX" 2>/dev/null)" || ERRLOG=/dev/null
lhs_cleanup_errlog() {
  if [ "$ERRLOG" != "/dev/null" ] && [ -f "$ERRLOG" ]; then rm -f -- "$ERRLOG"; fi
  return 0
}
trap 'lhs_cleanup_errlog' EXIT

die()  { printf '\n%s: ERROR: %s\n' "$SELF" "$*" >&2; exit 1; }
warn() { printf '%s: warning: %s\n' "$SELF" "$*" >&2; }
info() { printf '%s: %s\n' "$SELF" "$*"; }

usage() {
  cat <<'USAGE'
Liberty Hill Dusk - Apple Terminal.app profile generator

  ./make-terminal-app-profile.sh [--out PATH] [--set-default] [--help]

  --out PATH      where to write the .terminal file. Default:
                  ~/Library/Application Support/Liberty Hill Studios/terminal/
                  (chosen because it is NOT a TCC-protected folder, unlike
                  ~/Desktop, ~/Documents and ~/Downloads)
  --set-default   after generating, import the profile and make it Terminal's
                  default AND startup profile. OPT-IN: this sends an Apple
                  event, so macOS will show a one-time "Terminal wants to
                  control Terminal" permission prompt. Your previous profile
                  name is saved next to the .terminal file first.
  --help          this text

No sudo. Nothing is deleted. Any file we would overwrite is copied to
<file>.lhs-backup-<timestamp> first.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --out)          shift; OUT="${1:-}"; [ -n "$OUT" ] || die "--out needs a path" ;;
    --set-default)  SET_DEFAULT=1 ;;
    --help|-h)      usage; exit 0 ;;
    *)              die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

[ "$(uname -s)" = "Darwin" ] || die "this generator only runs on macOS (it needs Apple's NSKeyedArchiver)."
[ "$(id -u)" != "0" ] || die "do not run this as root / with sudo. It writes only inside your own home folder."

if [ -z "$OUT" ]; then
  OUT="$DEFAULT_DIR/$PROFILE_NAME.terminal"
fi
case "$OUT" in
  *'"'*|*'\'*) die "refusing an output path containing a quote or backslash: $OUT" ;;
esac
# --out must name a FILE. Given a directory, everything downstream misbehaves
# quietly: `cp -p` cannot back it up (no -R), `mv -f "$TMP" "$OUT"` succeeds by
# depositing the temp file INSIDE it, and `chmod 644` then strips the execute
# bit off the user's directory and makes it un-enterable -- after which the
# script prints "wrote: ~/Desktop" and exits 0.
case "$OUT" in
  */) die "--out must name a file, not a directory path (it ends in /): $OUT" ;;
esac
if [ -d "$OUT" ]; then
  die "--out must name a FILE, not an existing directory: $OUT"
fi

OUTDIR="$(dirname "$OUT")"

# ---------------------------------------------------------------------------
# THE PALETTE. Single source of truth for this script. Keys are Terminal.app's
# exact plist key names - they are NOT numbered like iTerm2's "Ansi N Color".
# ---------------------------------------------------------------------------
lhs_pairs() {
  # Emits "KEY=R,G,B" with DECIMAL components. Decimal on purpose: AppleScript
  # parses "27" identically in every locale, whereas "0.105882" can fail on a
  # comma-decimal locale. The divide-by-255 happens on the far side.
  local key="" hex="" r=0 g=0 b=0
  while read -r key hex; do
    case "$key" in ''|'#'*) continue ;; esac
    r=$(( 16#${hex:0:2} ))
    g=$(( 16#${hex:2:2} ))
    b=$(( 16#${hex:4:2} ))
    printf '%s=%d,%d,%d\n' "$key" "$r" "$g" "$b"
  done <<'TABLE'
# key                    hex      role
ANSIBlackColor           1B1612
ANSIRedColor             E0604F
ANSIGreenColor           5FB87A
ANSIYellowColor          E8A13A
ANSIBlueColor            5AA8E0
ANSIMagentaColor         A878D8
ANSICyanColor            7FBFB4
ANSIWhiteColor           CDBFA6
ANSIBrightBlackColor     6F6557
ANSIBrightRedColor       E57A53
ANSIBrightGreenColor     83C99B
ANSIBrightYellowColor    ECBE5B
ANSIBrightBlueColor      7DBDE8
ANSIBrightMagentaColor   C09BE8
ANSIBrightCyanColor      9AD1C7
ANSIBrightWhiteColor     FDF6E8
BackgroundColor          0A0807
TextColor                F5ECD9
TextBoldColor            FDF6E8
CursorColor              E8A13A
SelectionColor           4D2C14
TABLE
}

EXPECTED_COLORS=21

# ---------------------------------------------------------------------------
# TIER 1 - AppleScript-ObjC. Builds real NSColor objects, archives them with
# the real NSKeyedArchiver, serialises the profile as an XML property list.
# ---------------------------------------------------------------------------
generate_asobjc() {
  # stderr goes to ERRLOG, not /dev/null: an AppleScript compile error, a
  # sandbox denial and a missing binary are three different problems, and
  # discarding the message makes them indistinguishable to whoever has to fix
  # it. The banner at the bottom of this script prints the tail of this file.
  # shellcheck disable=SC2046   # deliberate word splitting: tokens have no spaces
  /usr/bin/osascript - "$1" $(lhs_pairs) <<'APPLESCRIPT' >/dev/null 2>>"$ERRLOG"
use framework "Foundation"
use framework "AppKit"
use scripting additions

on run argv
	set outPath to item 1 of argv
	if (count of argv) < 2 then error "no colours supplied" number 9001

	set prof to current application's NSMutableDictionary's dictionary()
	prof's setObject:"Liberty Hill Dusk" forKey:"name"
	prof's setObject:"Window Settings" forKey:"type"
	prof's setObject:2.04 forKey:"ProfileCurrentVersion"
	prof's setObject:110 forKey:"columnCount"
	prof's setObject:34 forKey:"rowCount"
	prof's setObject:true forKey:"UseBrightBold"
	-- NOTE: no "Font" key on purpose. Font is itself an NSKeyedArchiver blob,
	-- and omitting it means importing this profile keeps YOUR font.

	repeat with i from 2 to (count of argv)
		set pairText to (item i of argv) as text

		set AppleScript's text item delimiters to "="
		set halves to text items of pairText
		set AppleScript's text item delimiters to ""
		if (count of halves) is not 2 then error "malformed argument: " & pairText number 9002
		set theKey to item 1 of halves

		set AppleScript's text item delimiters to ","
		set comps to text items of (item 2 of halves)
		set AppleScript's text item delimiters to ""
		if (count of comps) is not 3 then error "malformed rgb: " & pairText number 9003

		set rr to ((item 1 of comps) as integer) / 255
		set gg to ((item 2 of comps) as integer) / 255
		set bb to ((item 3 of comps) as integer) / 255

		set theColor to (current application's NSColor's colorWithDeviceRed:rr green:gg blue:bb alpha:1.0)

		-- Modern archiver first (10.13+, not deprecated); fall back to the
		-- legacy one. Same bytes either way; this is redundancy on purpose,
		-- because nobody on this project can test the result on a Mac.
		set blob to missing value
		try
			set blob to (current application's NSKeyedArchiver's archivedDataWithRootObject:theColor requiringSecureCoding:false |error|:(missing value))
		end try
		if blob is missing value then
			try
				set blob to (current application's NSKeyedArchiver's archivedDataWithRootObject:theColor)
			end try
		end if
		if blob is missing value then error "could not archive NSColor for " & theKey number 9004

		(prof's setObject:blob forKey:theKey)
	end repeat

	-- Serialise explicitly as XML so the output format is deterministic
	-- rather than whatever NSDictionary's write method picks this release.
	set plistData to missing value
	try
		set plistData to (current application's NSPropertyListSerialization's dataWithPropertyList:prof format:(current application's NSPropertyListXMLFormat_v1_0) options:0 |error|:(missing value))
	end try

	set wroteOK to false
	if plistData is not missing value then
		try
			set wroteOK to ((plistData's writeToFile:outPath atomically:true) as boolean)
		end try
	end if
	if wroteOK is false then
		try
			set wroteOK to ((prof's writeToFile:outPath atomically:true) as boolean)
		end try
	end if
	if wroteOK is false then error "could not write " & outPath number 9005

	return "ok"
end run
APPLESCRIPT
}

# ---------------------------------------------------------------------------
# TIER 2 - python3 + stdlib plistlib. NO PyObjC (Apple's python3 does not have
# it). Hand-builds the same 3-object NSKeyedArchiver graph that tier 1's real
# archiver produces for an NSDeviceRGB colour.
# ---------------------------------------------------------------------------
find_python3() {
  local cand=""
  # Prefer a Homebrew / user python3: those are real interpreters and safe to
  # invoke unconditionally.
  for cand in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    if [ -x "$cand" ]; then printf '%s' "$cand"; return 0; fi
  done
  # /usr/bin/python3 is a Command Line Tools SHIM. Invoking it without CLT
  # installed pops a GUI "install the developer tools?" dialog and blocks the
  # script forever. Only touch it once xcode-select proves CLT is present.
  if [ -x /usr/bin/xcode-select ] && /usr/bin/xcode-select -p >/dev/null 2>&1; then
    if [ -x /usr/bin/python3 ]; then printf '%s' /usr/bin/python3; return 0; fi
  fi
  return 1
}

generate_python() {
  local out="$1" py=""
  py="$(find_python3)" || return 1
  # plistlib.UID is 3.8+. Apple ships 3.9.x; check anyway rather than assume.
  "$py" -c 'import plistlib,sys; sys.exit(0 if hasattr(plistlib,"UID") else 1)' >/dev/null 2>&1 || return 1
  # shellcheck disable=SC2046   # deliberate word splitting: tokens have no spaces
  "$py" - "$out" $(lhs_pairs) <<'PYEOF' >/dev/null 2>>"$ERRLOG"
import plistlib, sys

out   = sys.argv[1]
pairs = sys.argv[2:]
if not pairs:
    sys.exit(2)

def nscolor(r, g, b):
    # Exactly the object graph NSKeyedArchiver emits for an NSDeviceRGB
    # NSColor: $null, the colour (NSColorSpace 2 + an ASCII "r g b" string
    # with a REQUIRED trailing NUL), and the NSColor class record.
    rgb = ("%.10g %.10g %.10g" % (r / 255.0, g / 255.0, b / 255.0))
    return plistlib.dumps({
        "$version":  100000,
        "$archiver": "NSKeyedArchiver",
        "$top":      {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {"$class": plistlib.UID(2), "NSColorSpace": 2,
             "NSRGB": rgb.encode("ascii") + b"\x00"},
            {"$classes": ["NSColor", "NSObject"], "$classname": "NSColor"},
        ],
    }, fmt=plistlib.FMT_BINARY)

prof = {
    "name": "Liberty Hill Dusk",
    "type": "Window Settings",
    "ProfileCurrentVersion": 2.04,
    "columnCount": 110,
    "rowCount": 34,
    "UseBrightBold": True,
    # no "Font" key on purpose - importing keeps the user's font
}
for p in pairs:
    k, rgb = p.split("=", 1)
    r, g, b = (int(x) for x in rgb.split(","))
    prof[k] = nscolor(r, g, b)

with open(out, "wb") as fh:
    plistlib.dump(prof, fh, fmt=plistlib.FMT_XML, sort_keys=True)
PYEOF
}

# ---------------------------------------------------------------------------
# VERIFY - read the file back off disk, unarchive EVERY colour, compare to the
# palette. This is the whole point: it turns a blind generator into one that
# refuses to install a wrong file.
# ---------------------------------------------------------------------------
verify_structure() {
  local f="$1" blobs=0 nm=""
  /usr/bin/plutil -lint "$f" >/dev/null 2>&1 || { warn "plutil says the generated file is not a valid property list"; return 1; }
  nm="$(/usr/bin/plutil -extract name raw -o - "$f" 2>/dev/null || true)"
  [ "$nm" = "$PROFILE_NAME" ] || { warn "profile name is '$nm', expected '$PROFILE_NAME'"; return 1; }
  blobs="$(/usr/bin/plutil -convert xml1 -o - "$f" 2>/dev/null | /usr/bin/grep -c '<data>' || true)"
  [ "$blobs" = "$EXPECTED_COLORS" ] || { warn "found $blobs colour blobs, expected $EXPECTED_COLORS"; return 1; }
  return 0
}

verify_colors() {
  local f="$1" result="" scpt=""
  # The AppleScript goes to a temp file rather than a here-document, because a
  # here-document nested inside a $( ) command substitution does not terminate
  # correctly in bash - the body leaks out of the substitution. Temp file is
  # unambiguous in every bash from 3.2 up.
  scpt="$OUTDIR/.lhs-verify.$$.applescript"
  cat > "$scpt" <<'APPLESCRIPT'
use framework "Foundation"
use framework "AppKit"
use scripting additions

on run argv
	set f to item 1 of argv
	set d to (current application's NSDictionary's dictionaryWithContentsOfFile:f)
	if d is missing value then return "READFAIL"

	set badList to {}
	repeat with i from 2 to (count of argv)
		set pairText to (item i of argv) as text
		set AppleScript's text item delimiters to "="
		set halves to text items of pairText
		set AppleScript's text item delimiters to ","
		set comps to text items of (item 2 of halves)
		set AppleScript's text item delimiters to ""
		set theKey to item 1 of halves
		set wantR to (item 1 of comps) as integer
		set wantG to (item 2 of comps) as integer
		set wantB to (item 3 of comps) as integer

		set blob to (d's objectForKey:theKey)
		if blob is missing value then
			set end of badList to theKey & "(absent)"
		else
			set c to missing value
			try
				set c to (current application's NSKeyedUnarchiver's unarchiveObjectWithData:blob)
			end try
			if c is missing value then
				try
					set c to (current application's NSKeyedUnarchiver's unarchivedObjectOfClass:(current application's NSColor) fromData:blob |error|:(missing value))
				end try
			end if
			if c is missing value then
				set end of badList to theKey & "(unarchive-failed)"
			else
				set c2 to c
				try
					set c2 to (c's colorUsingColorSpaceName:"NSDeviceRGBColorSpace")
					if c2 is missing value then set c2 to c
				end try
				set gotR to (round ((c2's redComponent()) * 255))
				set gotG to (round ((c2's greenComponent()) * 255))
				set gotB to (round ((c2's blueComponent()) * 255))
				if gotR is not wantR or gotG is not wantG or gotB is not wantB then
					set end of badList to theKey & "(" & gotR & "," & gotG & "," & gotB & ")"
				end if
			end if
		end if
	end repeat

	if (count of badList) is 0 then return "OK"
	set AppleScript's text item delimiters to " "
	set out to badList as text
	set AppleScript's text item delimiters to ""
	return "BAD " & out
end run
APPLESCRIPT
  # shellcheck disable=SC2046   # deliberate word splitting: tokens have no spaces
  result="$(/usr/bin/osascript "$scpt" "$f" $(lhs_pairs) 2>/dev/null || true)"
  rm -f "$scpt" 2>/dev/null
  case "$result" in
    OK)       return 0 ;;
    "")       warn "colour verification could not run (osascript produced no output); relying on the structural check only"
              return 2 ;;
    READFAIL) warn "colour verification could not read the generated file back"; return 1 ;;
    *)        warn "colour verification FAILED: $result"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# GENERATE
# ---------------------------------------------------------------------------
[ "$(lhs_pairs | /usr/bin/wc -l | tr -d ' ')" = "$EXPECTED_COLORS" ] \
  || die "internal: palette table does not hold $EXPECTED_COLORS colours. Refusing to generate."

mkdir -p "$OUTDIR" || die "could not create $OUTDIR"

TMP="$OUTDIR/.lhs-terminal-profile.$$.tmp"
rm -f "$TMP" 2>/dev/null

METHOD=""
info "generating with AppleScript-ObjC (no external dependencies)..."
if generate_asobjc "$TMP" && [ -s "$TMP" ]; then
  METHOD="AppleScript-ObjC"
else
  rm -f "$TMP" 2>/dev/null
  warn "the AppleScript-ObjC path did not produce a file."
  info "trying python3 + stdlib plistlib..."
  if generate_python "$TMP" && [ -s "$TMP" ]; then
    METHOD="python3 (stdlib plistlib)"
  else
    rm -f "$TMP" 2>/dev/null
    cat >&2 <<EOF

$SELF: COULD NOT GENERATE THE PROFILE. Nothing was written or changed.

Both generators failed:
EOF
    if [ "$ERRLOG" != "/dev/null" ] && [ -s "$ERRLOG" ]; then
      printf '\n  What they actually said (last 10 lines):\n' >&2
      /usr/bin/tail -n 10 "$ERRLOG" 2>/dev/null | /usr/bin/sed 's/^/    /' >&2
      printf '\n' >&2
    fi
    cat >&2 <<EOF
  1. /usr/bin/osascript (AppleScript-ObjC) - should exist on every macOS.
     Check it works at all:   osascript -e '1 + 1'
  2. python3 with the stdlib plistlib module - optional. We only use
     /usr/bin/python3 when Xcode Command Line Tools are installed, because
     without them it is a stub that pops a GUI dialog. If you want this
     fallback available:      xcode-select --install
     (or install any python3 - Homebrew's works too)

Terminal.app is the ONLY emulator in this folder that needs a generator.
Everything else is a plain committed file and works right now:
  liberty-hill-dusk.itermcolors        iTerm2
  liberty-hill-dusk.alacritty.toml     Alacritty
  liberty-hill-dusk.kitty.conf         kitty
  liberty-hill-dusk.wezterm.lua        WezTerm
  liberty-hill-dusk.ghostty            Ghostty
See README.md in this folder.

EOF
    exit 1
  fi
fi

info "generated via $METHOD; verifying..."

if ! verify_structure "$TMP"; then
  rm -f "$TMP" 2>/dev/null
  die "the generated profile failed its structural check. Nothing was installed."
fi

verify_colors "$TMP"
VRC=$?
if [ "$VRC" -eq 1 ]; then
  rm -f "$TMP" 2>/dev/null
  die "the generated profile failed colour verification. Nothing was installed."
fi
if [ "$VRC" -eq 0 ]; then
  info "verified: all $EXPECTED_COLORS colours unarchive back to the Liberty Hill palette."
else
  info "structure verified ($EXPECTED_COLORS colour blobs, name '$PROFILE_NAME')."
fi

# Back up anything we are about to replace. Never overwrite silently.
if [ -e "$OUT" ]; then
  cp -p "$OUT" "$OUT.lhs-backup-$STAMP" 2>/dev/null \
    && info "backed up the existing file to $OUT.lhs-backup-$STAMP" \
    || warn "could not back up the existing $OUT (continuing; the new file is verified)"
fi

mv -f "$TMP" "$OUT" || { rm -f "$TMP" 2>/dev/null; die "could not move the profile into $OUT"; }
# Only ever re-mode a regular file. chmod 644 on a directory would remove its
# execute bit and make it un-enterable in Finder and the shell.
if [ -f "$OUT" ]; then
  chmod 644 "$OUT" 2>/dev/null
fi

info "wrote: $OUT"

# ---------------------------------------------------------------------------
# OPTIONAL: import it and make it the default + startup profile
# ---------------------------------------------------------------------------
if [ "$SET_DEFAULT" -eq 1 ]; then
  printf '\n'
  info "--set-default given."
  info "macOS may now show a one-time 'Terminal wants to control Terminal'"
  info "permission prompt. Click OK. If you decline, nothing breaks - you can"
  info "still set the profile by hand (instructions below)."

  PREV="$(/usr/bin/osascript -e 'tell application "Terminal" to get name of default settings' 2>/dev/null || true)"
  if [ -n "$PREV" ]; then
    printf '%s\n' "$PREV" > "$OUTDIR/previous-terminal-profile.txt" 2>/dev/null || true
    info "your previous default profile was '$PREV' (saved to $OUTDIR/previous-terminal-profile.txt)"
  else
    warn "could not read your current default profile - Automation permission"
    warn "was probably declined. Skipping the automatic change; set it by hand."
  fi

  if [ -n "$PREV" ]; then
    # `open` is how Terminal imports a profile: it reads the file, adds the
    # profile, and opens one new window using it. It does not close, quit or
    # disturb any window you already have.
    /usr/bin/open "$OUT" 2>/dev/null || warn "could not open $OUT"
    sleep 2
    if /usr/bin/osascript \
         -e 'tell application "Terminal" to set default settings to settings set "Liberty Hill Dusk"' \
         -e 'tell application "Terminal" to set startup settings to settings set "Liberty Hill Dusk"' \
         >/dev/null 2>&1; then
      info "Liberty Hill Dusk is now Terminal's default AND startup profile."
      info "(Both matter: startup drives the first window at launch, default"
      info " drives every window after that. Setting only one looks like a bug.)"
    else
      warn "could not set the profile automatically. Do it by hand - see below."
      warn "If a permission dialog was declined, re-enable it under"
      warn "System Settings > Privacy & Security > Automation > Terminal."
    fi
  fi
fi

# ---------------------------------------------------------------------------
cat <<EOF

------------------------------------------------------------------------
  Liberty Hill Dusk - Apple Terminal.app
------------------------------------------------------------------------
  Profile file:
    $OUT

  IMPORT IT (one step):
    open "$OUT"

  This adds the profile and opens one new window using it. It does not
  touch, close or restyle any window you already have.

  MAKE IT THE DEFAULT (two clicks, both needed):
    Terminal > Settings... > Profiles
      1. select "Liberty Hill Dusk" in the left-hand list
      2. click "Default" at the bottom of that list
    That single button sets both the default and the startup profile.

  UNDO:
    Terminal > Settings > Profiles > select your old profile > Default
    then right-click "Liberty Hill Dusk" > Remove.
    Delete this generated file whenever you like:
      rm "$OUT"
    Nothing else on your Mac was touched.
------------------------------------------------------------------------

EOF
exit 0
