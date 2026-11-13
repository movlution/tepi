$commonDir = "D:\PROJECT\Other\tepi\tests\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

$asm = Initialize-TepiLoader
$flags = [System.Reflection.BindingFlags]'Instance,Public,NonPublic'

Write-Host "=== 1. Static Hardcoded Colors Check ==="
$files = @("src\DockPaint.cs", "src\DockCard.cs", "src\DockSheet.cs")
$pattern = 'BadgeRed|BadgeRedSoft|Color\.FromArgb\([^)]*255,\s*255,\s*255\)'
$matches = Get-ChildItem $files | Select-String -Pattern $pattern
if ($matches) {
    Write-Error "Found matches:"
    $matches | ForEach-Object { Write-Host "$($_.Filename):$($_.LineNumber): $($_.Line)" }
    exit 1
} else {
    Write-Host "PASS: All target hardcoded colors successfully eliminated from Dock files."
}

Write-Host "`n=== 2. Reflection Check for CalendarSheet Pressed State ==="
$islandType = Get-TepiType "Island"
$calType = $islandType.GetNestedType("CalendarSheet", $flags)
if ($null -eq $calType) { throw "CalendarSheet type not found!" }

$pressedIdField = $calType.GetField("pressedId", $flags)
$selectedDayProp = $calType.GetProperty("selectedDay", $flags)
$downMethod = $calType.GetMethod("Down", $flags)
$pressedMethod = $calType.GetMethod("Pressed", $flags)
$onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
$onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
$onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)

Write-Host "pressedId field:   " ($pressedIdField -ne $null)
Write-Host "selectedDay prop:  " ($selectedDayProp -ne $null)
Write-Host "Down method:       " ($downMethod -ne $null)
Write-Host "Pressed method:    " ($pressedMethod -ne $null)
Write-Host "OnMouseDown:       " ($onMouseDown -ne $null)
Write-Host "OnMouseUp:         " ($onMouseUp -ne $null)
Write-Host "OnMouseLeave:      " ($onMouseLeave -ne $null)

if (-not ($pressedIdField -and $selectedDayProp -and $downMethod -and $pressedMethod -and $onMouseDown -and $onMouseUp -and $onMouseLeave)) {
    Write-Error "CalendarSheet reflection check failed!"
    exit 1
}

Write-Host "`n=== 3. Mini Constants and Geometry Check ==="
$miniDotR = $islandType.GetField("MiniDotR", [System.Reflection.BindingFlags]'Static,NonPublic')
$miniTrackThick = $islandType.GetField("MiniTrackThick", [System.Reflection.BindingFlags]'Static,NonPublic')

Write-Host "MiniDotR field:       " ($miniDotR -ne $null)
if ($miniDotR) {
    $rVal = $miniDotR.GetValue($null)
    $area = [Math]::PI * [Math]::Pow($rVal, 2)
    Write-Host "MiniDotR value:       $rVal"
    Write-Host "MiniDot Area (px^2):  $area (Spec >= 19.6)"
    if ($rVal -lt 2.5 -or $area -lt 19.6) {
        Write-Error "MiniDotR does not satisfy spec!"
        exit 1
    }
}

Write-Host "MiniTrackThick field: " ($miniTrackThick -ne $null)
if ($miniTrackThick) {
    $tVal = $miniTrackThick.GetValue($null)
    Write-Host "MiniTrackThick value: $tVal (Spec == 4.0)"
    if ($tVal -lt 4.0) {
        Write-Error "MiniTrackThick does not satisfy spec!"
        exit 1
    }
}

Write-Host "`n=== 4. DockSheet Down Method Check ==="
$dockSheetType = $islandType.GetNestedType("GlassSheet", $flags)
if ($null -eq $dockSheetType) {
    # GlassSheet is in Tepi namespace directly:
    $dockSheetType = Get-TepiType "GlassSheet"
}
Write-Host "GlassSheet found: " ($dockSheetType -ne $null)
if ($dockSheetType) {
    $sheetDown = $dockSheetType.GetMethod("Down", $flags)
    Write-Host "GlassSheet.Down:  " ($sheetDown -ne $null)
    if (-not $sheetDown) {
        Write-Error "GlassSheet.Down not found!"
        exit 1
    }
}

Write-Host "`n=== ALL VERIFICATION CHECKS PASSED ==="
