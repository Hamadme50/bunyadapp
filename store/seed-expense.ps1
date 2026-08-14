# Seeds one demo expense through the app UI, for store screenshots.
#
#   powershell -File store/seed-expense.ps1 -ChipX 541 -ChipY 2126 -Name "Sariya 12mm" -Amount 720000
#
# Run from a stage screen with the suggestion chips visible. -ChipX/-ChipY pick
# the head chip, which opens the sheet with that head already selected.
#
# The soft keyboard scrolls the sheet unpredictably, so after every field the
# IME is dismissed and the sheet is forced back to the top before the next tap.
# That makes the coordinates below fixed rather than a guess.

param(
    # Head chip inside the sheet, not on the stage screen: the stage's own chip
    # row slides up as the timeline fills, while the sheet always opens at the
    # top with its chips in the same place.
    [Parameter(Mandatory = $true)][int]$HeadX,
    [Parameter(Mandatory = $true)][int]$HeadY,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Amount,
    [string]$Serial = "emulator-5554"
)

$adb = "C:\Users\dashi\AppData\Local\Android\Sdk\platform-tools\adb.exe"

function Tap($x, $y) { & $adb -s $Serial shell input tap $x $y; Start-Sleep -Milliseconds 800 }
function HideIme {
    # ESCAPE does not close this IME and BACK is not always consumed on the
    # first try, so ask the framework whether the keyboard is actually gone
    # rather than sleeping and hoping. A stray tap into a still-open keyboard
    # types garbage into whatever field had focus.
    for ($i = 0; $i -lt 5; $i++) {
        $shown = & $adb -s $Serial shell dumpsys input_method | Select-String "mInputShown=true"
        if (-not $shown) { break }
        & $adb -s $Serial shell input keyevent 4
        Start-Sleep -Milliseconds 900
    }
    Start-Sleep -Milliseconds 700
}
function ToTop {
    # Two long downward flings — one is not always enough to reach the top.
    & $adb -s $Serial shell input swipe 540 700 540 2000 400
    Start-Sleep -Milliseconds 600
    & $adb -s $Serial shell input swipe 540 700 540 2000 400
    Start-Sleep -Seconds 2
}
function TypeText($text) {
    $escaped = $text -replace ' ', '%s'
    & $adb -s $Serial shell input text "$escaped"
    Start-Sleep -Seconds 1
}

# The FAB is pinned to the corner, so it is the one control that does not move.
Tap 830 2264
Start-Sleep -Seconds 4

# Head, from the sheet's own chip row.
Tap $HeadX $HeadY
Start-Sleep -Seconds 1

# Expense name.
Tap 538 523
TypeText $Name
HideIme
ToTop

# Amount.
Tap 538 1919
TypeText $Amount
HideIme
ToTop

# Save — footer sits at the bottom once the keyboard is gone.
Tap 864 2295
Start-Sleep -Seconds 7

Write-Output "seeded: $Name  Rs $Amount"
