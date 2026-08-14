# Captures one screen at all three Play device classes.
#
#   powershell -File store/capture.ps1 -Name 01-gate
#
# The emulator is resized rather than swapped for tablet AVDs: `wm size` plus
# `wm density` gives the same logical layout a real 7" or 10" tablet reports,
# which is what the app lays out against. Density stays 320 (xhdpi) for both,
# so 1200x1920 reads as 600x960dp and 1600x2560 as 800x1280dp — the sw600dp and
# sw800dp breakpoints Android itself uses to tell the classes apart.
#
# -Pause is the seconds to wait after each resize. The app restarts on a
# configuration change that large, so it needs a moment to draw.

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Serial = "emulator-5554",
    [int]$Pause = 7
)

$ErrorActionPreference = "Stop"
$adb = "C:\Users\dashi\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$root = Split-Path -Parent $PSScriptRoot
# Raw captures only. make_screenshots.py reads these and writes the framed
# listing images one level up, so capturing never clobbers a finished asset.
$shots = Join-Path $root "store\screenshots\raw"

$profiles = @(
    @{ Dir = "phone";    Size = "1080x2424"; Density = 420 },
    @{ Dir = "tablet7";  Size = "1200x1920"; Density = 320 },
    @{ Dir = "tablet10"; Size = "1600x2560"; Density = 320 }
)

foreach ($p in $profiles) {
    & $adb -s $Serial shell wm size $p.Size | Out-Null
    & $adb -s $Serial shell wm density $p.Density | Out-Null
    Start-Sleep -Seconds $Pause

    $out = Join-Path $shots "$($p.Dir)\$Name.png"
    & $adb -s $Serial shell screencap -p /sdcard/_shot.png
    & $adb -s $Serial pull /sdcard/_shot.png $out | Out-Null
    & $adb -s $Serial shell rm /sdcard/_shot.png

    Write-Output "$($p.Dir)/$Name.png  $($p.Size) @ $($p.Density)dpi"
}

# Back to the phone the emulator actually is, so the next interaction lines up
# with the coordinates everything else uses.
& $adb -s $Serial shell wm size reset | Out-Null
& $adb -s $Serial shell wm density reset | Out-Null
Start-Sleep -Seconds 4
