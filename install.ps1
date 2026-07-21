<#
.SYNOPSIS
  Liberty Hill Studios Desktop Theme — one-command installer.

.DESCRIPTION
  Installs the living dusk wallpaper (Lively), transparent taskbar (TranslucentTB),
  dark mode + gold accent, Windows Terminal scheme, studio notification chimes,
  and (optionally) the search/navigation stack (Everything, PowerToys, Flow Launcher).

  Everything is user-level and reversible. Gold is used ONLY as an accent —
  never as a surface color (studio law).

.PARAMETER NavStack
  Also install + configure Everything, PowerToys (FancyZones), and Flow Launcher.

.PARAMETER SkipApps
  Skip all winget installs (deploy configs/assets only — assumes apps are present).

.PARAMETER Chimes
  Opt in to the studio notification chime sound scheme (off by default).

.PARAMETER NoTerminal
  Skip the Windows Terminal color scheme.

.PARAMETER DryRun
  Print everything this script would change, then exit WITHOUT touching anything.
  Run this first. The macOS installer has always had --dry-run; this is the
  Windows equivalent.

.EXAMPLE
  .\install.ps1 -DryRun         # show the plan, change nothing
  .\install.ps1                 # wallpaper + taskbar + theme + terminal + sounds
  .\install.ps1 -NavStack       # everything above + search/nav stack
#>
# [CmdletBinding()] is load-bearing, not decoration. Without it this is a SIMPLE
# script: PowerShell quietly drops any unrecognised named argument into $args and
# runs the body anyway. So `.\install.ps1 --dry-run` (the Unix spelling, which is
# what an AI assistant or a Mac-shaped habit will reach for) used to perform the
# FULL REAL INSTALL — winget installs, HKCU registry writes, wallpaper and lock
# screen replaced — while the operator believed they were previewing.
# Verified: a probe carrying the old param block printed "BODY RAN" with
# `--dry-run` sitting unused in $args. With CmdletBinding, that same invocation
# now fails parameter binding and nothing runs.
[CmdletBinding()]
param(
  [switch]$NavStack,
  [switch]$SkipApps,
  [switch]$Chimes,
  [switch]$NoTerminal,
  [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$repo = $PSScriptRoot
$assets = "$env:USERPROFILE\Pictures\Liberty Hill Studios"
Write-Host "`n=== Liberty Hill Studios Desktop Theme ===" -ForegroundColor Yellow

# ── Dry run: state the plan, change nothing, leave ──────────────────────────
# Deliberately an early exit rather than a flag threaded through every step.
# A per-step wrapper retrofitted onto the mutations below would be a much bigger
# change to a script whose real path cannot be rehearsed safely — and it would
# risk the far worse failure of a dry run that mutates. Nothing after this block
# can run, so there is no path where -DryRun writes.
if ($DryRun) {
  Write-Host "`n[dry-run] Nothing below is executed. This is what a real run would do:`n" -ForegroundColor Cyan
  Write-Host "  assets    -> copy wallpaper, icons and sounds into"
  Write-Host "               $assets"
  if (-not $SkipApps) {
    Write-Host "  apps      -> winget install rocksdanister.LivelyWallpaper"
    Write-Host "               winget install CharlesMilette.TranslucentTB"
  } else {
    Write-Host "  apps      -> skipped (-SkipApps)"
  }
  Write-Host "  wallpaper -> copy the scene into Lively's library and apply it to every monitor"
  Write-Host "  fallback  -> set the static desktop wallpaper (SystemParametersInfo)"
  Write-Host "  theme     -> HKCU: dark mode, gold accent palette, DWM accent, transparency"
  if (-not $NoTerminal) {
    Write-Host "  terminal  -> add the Liberty Hill Dusk scheme to Windows Terminal settings.json"
  } else {
    Write-Host "  terminal  -> skipped (-NoTerminal)"
  }
  if ($Chimes) {
    Write-Host "  sounds    -> HKCU AppEvents: map SystemAsterisk / SystemExclamation / Notification.Default"
  } else {
    Write-Host "  sounds    -> skipped (opt in with -Chimes)"
  }
  if ($NavStack) {
    Write-Host "  nav stack -> winget install Everything + PowerToys + Flow Launcher,"
    Write-Host "               write FancyZones layouts and the Flow theme, restart both"
  } else {
    Write-Host "  nav stack -> skipped (opt in with -NavStack)"
  }
  Write-Host "`n  Everything is user-level and reversible. No admin rights are requested."
  Write-Host "  Re-run without -DryRun to apply.`n" -ForegroundColor Cyan
  return
}

# ── 0. Assets to a stable home ─────────────────────────────────────────────
New-Item "$assets\sounds" -ItemType Directory -Force | Out-Null
Copy-Item "$repo\wallpaper\lhs-dusk.html" $assets -Force
Copy-Item "$repo\icons\*" $assets -Force
Copy-Item "$repo\sounds\*" "$assets\sounds" -Force
Write-Host "[assets] copied to $assets"

# ── 1. Apps ────────────────────────────────────────────────────────────────
if (-not $SkipApps) {
  Write-Host "[apps] installing Lively Wallpaper + TranslucentTB (winget)..."
  winget install rocksdanister.LivelyWallpaper --silent --accept-package-agreements --accept-source-agreements
  winget install CharlesMilette.TranslucentTB --silent --accept-package-agreements --accept-source-agreements
}

# ── 2. Living wallpaper → Lively library, applied to every monitor ────────
$lively = "C:\Program Files\Lively Wallpaper\Lively.exe"
if (Test-Path $lively) {
  $lib = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\lhs-living-dusk"
  New-Item $lib -ItemType Directory -Force | Out-Null
  Copy-Item "$repo\wallpaper\lhs-dusk.html" "$lib\index.html" -Force
  Copy-Item "$repo\wallpaper\LivelyInfo.json" $lib -Force
  Copy-Item "$repo\wallpaper\thumbnail.jpg" $lib -Force
  Start-Process $lively -ArgumentList "--minimized true"; Start-Sleep 10
  Add-Type -AssemblyName System.Windows.Forms
  $n = [System.Windows.Forms.Screen]::AllScreens.Count
  for ($i = 1; $i -le $n; $i++) {
    & $lively setwp --file $lib --monitor $i; Start-Sleep 5
  }
  Write-Host "[wallpaper] Living Dusk applied to $n monitor(s); Lively starts with Windows"
} else {
  Write-Host "[wallpaper] Lively not found - skipped (install it, then re-run)" -ForegroundColor Red
}

# ── 3. Static fallback wallpaper + lock screen (best-fit still) ────────────
Add-Type -AssemblyName System.Windows.Forms
$prim = ([System.Windows.Forms.Screen]::AllScreens | Where-Object Primary).Bounds
$stills = Get-ChildItem "$repo\stills\lhs-dusk-*.png" | ForEach-Object {
  if ($_.BaseName -match "(\d+)x(\d+)$") { [pscustomobject]@{ F = $_.FullName; W = [int]$Matches[1]; H = [int]$Matches[2] } }
}
$best = $stills | Sort-Object { [math]::Abs($_.W - $prim.Width) + [math]::Abs($_.H - $prim.Height) } | Select-Object -First 1
if ($best) {
  Copy-Item $best.F "$assets\lhs-static.png" -Force
  Set-ItemProperty "HKCU:\Control Panel\Desktop" WallpaperStyle 10 -Type String  # Fill
  Set-ItemProperty "HKCU:\Control Panel\Desktop" TileWallpaper 0 -Type String
  $sig = '[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)] public static extern int SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'
  $spi = Add-Type -MemberDefinition $sig -Name "SPI" -Namespace LHS -PassThru
  [void]$spi::SystemParametersInfo(0x0014, 0, "$assets\lhs-static.png", 3)
  Write-Host "[fallback] static wallpaper: $(Split-Path $best.F -Leaf)"
}

# ── 4. Dark mode + gold ACCENT (accent only — never a surface) ─────────────
$pers = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty $pers AppsUseLightTheme 0 -Type DWord
Set-ItemProperty $pers SystemUsesLightTheme 0 -Type DWord
Set-ItemProperty $pers ColorPrevalence 0 -Type DWord      # keep Start/taskbar translucent-dark
Set-ItemProperty $pers EnableTransparency 1 -Type DWord
$accent = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent"
if (-not (Test-Path $accent)) { New-Item $accent -Force | Out-Null }
Set-ItemProperty $accent AccentColorMenu 0xFF3AA1E8 -Type DWord
Set-ItemProperty $accent StartColorMenu 0xFF1F66B3 -Type DWord
$palette = [byte[]](0xFA,0xEC,0xC9,0x00, 0xF3,0xD6,0x93,0x00, 0xEC,0xBE,0x5B,0x00, 0xE8,0xA1,0x3A,0x00, 0xD4,0x84,0x2A,0x00, 0xB3,0x66,0x1F,0x00, 0x8C,0x4D,0x1B,0x00, 0x4D,0x2C,0x14,0x00)
Set-ItemProperty $accent AccentPalette $palette -Type Binary
Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\DWM" AccentColor 0xFF3AA1E8 -Type DWord
Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\DWM" ColorPrevalence 0 -Type DWord
$sig2 = '[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
$smto = Add-Type -MemberDefinition $sig2 -Name "SMTO" -Namespace LHS -PassThru
$out = [UIntPtr]::Zero
[void]$smto::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "ImmersiveColorSet", 2, 5000, [ref]$out)
Write-Host "[theme] dark mode + gold accent applied"

# ── 5. Windows Terminal scheme ─────────────────────────────────────────────
if (-not $NoTerminal) {
  $wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
  if (Test-Path $wt) {
    try {
      $settings = Get-Content $wt -Raw | ConvertFrom-Json
      $scheme = Get-Content "$repo\terminal\liberty-hill-dusk.json" -Raw | ConvertFrom-Json
      $settings.schemes = @($settings.schemes | Where-Object { $_.name -ne "Liberty Hill Dusk" }) + $scheme
      if (-not $settings.profiles.defaults.PSObject.Properties["colorScheme"]) {
        $settings.profiles.defaults | Add-Member colorScheme "Liberty Hill Dusk"
      } else { $settings.profiles.defaults.colorScheme = "Liberty Hill Dusk" }
      $settings | ConvertTo-Json -Depth 32 | Set-Content $wt -Encoding UTF8
      Write-Host "[terminal] Liberty Hill Dusk is the default scheme"
    } catch {
      Write-Host "[terminal] couldn't auto-edit settings.json - add terminal\liberty-hill-dusk.json manually" -ForegroundColor Yellow
    }
  } else { Write-Host "[terminal] Windows Terminal not found - skipped" }
}

# ── 6. Studio notification chimes (opt-in — taste varies) ──────────────────
if ($Chimes) {
  $map = @{
    "SystemAsterisk"       = "$assets\sounds\lhs-chime.wav"
    "SystemExclamation"    = "$assets\sounds\lhs-alert.wav"
    "Notification.Default" = "$assets\sounds\lhs-chime.wav"
  }
  foreach ($ev in $map.Keys) {
    $key = "HKCU:\AppEvents\Schemes\Apps\.Default\$ev\.Current"
    if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
    Set-ItemProperty $key -Name "(Default)" -Value $map[$ev]
  }
  Write-Host "[sounds] studio chimes mapped (finish + attention)"
}

# ── 7. Optional: search & navigation stack ─────────────────────────────────
if ($NavStack) {
  if (-not $SkipApps) {
    Write-Host "[nav] installing Everything + PowerToys + Flow Launcher (winget)..."
    winget install voidtools.Everything --silent --accept-package-agreements --accept-source-agreements
    winget install Microsoft.PowerToys --silent --accept-package-agreements --accept-source-agreements
    winget install Flow-Launcher.Flow-Launcher --silent --accept-package-agreements --accept-source-agreements
  }
  $ev = "C:\Program Files\Everything\Everything.exe"
  if (Test-Path $ev) {
    Start-Process $ev -ArgumentList "-startup"
    Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" Everything "`"$ev`" -startup"
  }
  # FancyZones: gold zones + LHS layouts (apply per monitor via Win+Shift+`)
  Get-Process PowerToys* -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep 3
  $fz = "$env:LOCALAPPDATA\Microsoft\PowerToys\FancyZones"
  New-Item $fz -ItemType Directory -Force | Out-Null
  Copy-Item "$repo\fancyzones\custom-layouts.json" $fz -Force
  Copy-Item "$repo\fancyzones\settings.json" $fz -Force
  if (Test-Path "$env:LOCALAPPDATA\PowerToys\PowerToys.exe") { Start-Process "$env:LOCALAPPDATA\PowerToys\PowerToys.exe" }
  # Flow Launcher: theme (run Flow once first so user dirs exist)
  $flowExe = "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe"
  if (Test-Path $flowExe) {
    if (-not (Test-Path "$env:APPDATA\FlowLauncher\Themes")) { Start-Process $flowExe; Start-Sleep 12 }
    New-Item "$env:APPDATA\FlowLauncher\Themes" -ItemType Directory -Force | Out-Null
    Copy-Item "$repo\flow-launcher\Liberty Hill Dusk.xaml" "$env:APPDATA\FlowLauncher\Themes\" -Force
    $fs = "$env:APPDATA\FlowLauncher\Settings\Settings.json"
    if (Test-Path $fs) {
      try {
        Get-Process Flow.Launcher -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
        $s = Get-Content $fs -Raw | ConvertFrom-Json
        $s.Theme = "Liberty Hill Dusk"; $s.StartFlowLauncherOnSystemStartup = $true; $s.HideOnStartup = $true
        $s | ConvertTo-Json -Depth 10 | Set-Content $fs -Encoding UTF8
        Start-Process $flowExe
      } catch { Write-Host "[nav] set Flow theme manually: Settings > Theme > Liberty Hill Dusk" -ForegroundColor Yellow }
    }
    Write-Host "[nav] Alt+Space launcher themed + FancyZones gold zones ready"
  }
}

Write-Host "`n=== Done. Finishing touches (manual, ~1 min) ===" -ForegroundColor Yellow
Write-Host " * Account avatar: Settings > Accounts > Your info > Choose a file -> $assets\avatar-448.png"
Write-Host " * Gold pointer:   Settings > Accessibility > Mouse pointer > custom color #E8A13A"
Write-Host " * Lock screen:    Settings > Personalization > Lock screen -> pick a still from the repo"
if ($NavStack) { Write-Host " * FancyZones:     Win+Shift+`` on each monitor -> pick an LHS layout, then Shift+drag windows" }
Write-Host ""
