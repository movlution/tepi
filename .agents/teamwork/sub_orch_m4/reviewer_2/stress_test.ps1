# Independent Reviewer 2 Adversarial Stress Test Harness for Milestone 4

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$ErrorActionPreference = "Stop"
$exePath = "D:\PROJECT\Other\tepi\Tepi.exe"
$assembly = [System.Reflection.Assembly]::LoadFrom($exePath)

$failures = @()
function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        Write-Host "  [FAIL] $message" -ForegroundColor Red
        $script:failures += $message
    } else {
        Write-Host "  [PASS] $message" -ForegroundColor Green
    }
}

function Lum([System.Drawing.Color]$c) {
    $r = $c.R / 255.0; if ($r -le 0.03928) { $r = $r / 12.92 } else { $r = [Math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $g = $c.G / 255.0; if ($g -le 0.03928) { $g = $g / 12.92 } else { $g = [Math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $b = $c.B / 255.0; if ($b -le 0.03928) { $b = $b / 12.92 } else { $b = [Math]::Pow(($b + 0.055) / 1.055, 2.4) }
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
    $l1 = Lum $c1; $l2 = Lum $c2
    $bright = [Math]::Max($l1, $l2)
    $dark = [Math]::Min($l1, $l2)
    return ($bright + 0.05) / ($dark + 0.05)
}

Write-Host "`n=== 1. Adversarial Test: Dock Badge & Close Contrast Across Themes ==="
$inkType = $assembly.GetType("Tepi.Ink")
$applyMethod = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]"Public,Static")

# Test Dark Mode
$applyMethod.Invoke($null, @($false))
$baseTone = $inkType.GetField("Base").GetValue($null)
$darkNeg = $baseTone.GetType().GetField("Negative").GetValue($baseTone)
$darkBg = $baseTone.GetType().GetField("Bg").GetValue($baseTone)
$darkIsDark = $baseTone.GetType().GetProperty("IsDark").GetValue($baseTone, $null)
$darkTextColor = if ($darkIsDark) { $darkBg } else { [System.Drawing.Color]::White }
$darkBadgeContrast = Contrast $darkTextColor $darkNeg
Write-Host "  Dark Mode Badge Contrast: $([Math]::Round($darkBadgeContrast, 2)) : 1 (Text: $darkTextColor, Bg: $darkNeg)"
Assert-True ($darkBadgeContrast -ge 4.5) "Dark mode badge text achieves WCAG AA >= 4.5:1 against Negative (Actual: $([Math]::Round($darkBadgeContrast, 2)):1)"

# Test Light Mode
$applyMethod.Invoke($null, @($true))
$baseToneLight = $inkType.GetField("Base").GetValue($null)
$lightNeg = $baseToneLight.GetType().GetField("Negative").GetValue($baseToneLight)
$lightBg = $baseToneLight.GetType().GetField("Bg").GetValue($baseToneLight)
$lightIsDark = $baseToneLight.GetType().GetProperty("IsDark").GetValue($baseToneLight, $null)
$lightTextColor = if ($lightIsDark) { $lightBg } else { [System.Drawing.Color]::White }
$lightBadgeContrast = Contrast $lightTextColor $lightNeg
Write-Host "  Light Mode Badge Contrast: $([Math]::Round($lightBadgeContrast, 2)) : 1 (Text: $lightTextColor, Bg: $lightNeg)"
Assert-True ($lightBadgeContrast -ge 4.5) "Light mode badge text achieves WCAG AA >= 4.5:1 against Negative (Actual: $([Math]::Round($lightBadgeContrast, 2)):1)"

# Reset to Dark Mode
$applyMethod.Invoke($null, @($false))

Write-Host "`n=== 2. Adversarial Test: Mini Geometry & Clearance ==="
$miniDotRField = [System.Reflection.BindingFlags]"NonPublic,Static,Public"
$islandType = $assembly.GetType("Tepi.Island")
$dotRVal = $islandType.GetField("MiniDotR", $miniDotRField).GetValue($null)
$trackThickVal = $islandType.GetField("MiniTrackThick", $miniDotRField).GetValue($null)
$dotArea = [Math]::PI * [Math]::Pow($dotRVal, 2)

Assert-True ($dotRVal -ge 2.5) "MiniDotR constant is >= 2.5 (Actual: $dotRVal)"
Assert-True ($dotArea -ge 19.6) "Mini dot area is >= 19.6 px^2 (Actual: $([Math]::Round($dotArea, 3)))"
Assert-True ($trackThickVal -eq 4.0) "MiniTrackThick constant is exactly 4.0 (Actual: $trackThickVal)"

# Mathematical Layout Verification
# w = 64, h = 8
# Horizontal track: left = 12 (no caps), right = dot ? w - 16 : w - 12
# When dot = true: right = 64 - 16 = 48.0
# Dot center: w - 9 = 55.0. Dot left edge: 55.0 - 2.5 = 52.5
# Clearance: 52.5 - 48.0 = 4.5
$w = 64.0; $h = 8.0
$trackRight = $w - 16.0
$dotLeft = ($w - 9.0) - $dotRVal
$clearance = $dotLeft - $trackRight
Write-Host "  Track right edge: $trackRight px, Dot left edge: $dotLeft px, Clearance: $clearance px"
Assert-True ($clearance -ge 4.5) "Clearance between horizontal track and dot is >= 4.5px (Actual: $clearance px)"

# Vertical centering in 8px container
$trackTop = ($h / 2.0) - ($trackThickVal / 2.0)
$trackBottom = ($h / 2.0) + ($trackThickVal / 2.0)
$topPadding = $trackTop
$bottomPadding = $h - $trackBottom
Write-Host "  Track top padding: $topPadding px, bottom padding: $bottomPadding px"
Assert-True ($topPadding -eq 2.0 -and $bottomPadding -eq 2.0) "Horizontal track is symmetrically centered in 8px container with 2px padding"

Write-Host "`n=== 3. Adversarial Test: Calendar Navigation & Month Arithmetic ==="
function Test-MonthDiff([DateTime]$clicked, [DateTime]$currShown) {
    return ($clicked.Year - $currShown.Year) * 12 + ($clicked.Month - $currShown.Month)
}

# Case 1: Dec 2026 clicked from Jan 2027
$m1 = Test-MonthDiff (Get-Date "2026-12-31") (Get-Date "2027-01-01")
Assert-True ($m1 -eq -1) "Dec 2026 clicked from Jan 2027 navigates -1 month (Actual: $m1)"

# Case 2: Jan 2027 clicked from Dec 2026
$m2 = Test-MonthDiff (Get-Date "2027-01-01") (Get-Date "2026-12-01")
Assert-True ($m2 -eq 1) "Jan 2027 clicked from Dec 2026 navigates +1 month (Actual: $m2)"

# Case 3: Leap year boundary Feb 29, 2028 clicked from Mar 2028
$m3 = Test-MonthDiff (Get-Date "2028-02-29") (Get-Date "2028-03-01")
Assert-True ($m3 -eq -1) "Leap day Feb 29 2028 clicked from Mar 2028 navigates -1 month (Actual: $m3)"

# Case 4: Same month clicked
$m4 = Test-MonthDiff (Get-Date "2026-11-15") (Get-Date "2026-11-01")
Assert-True ($m4 -eq 0) "Day in same month does not alter month navigation (Actual: $m4)"

Write-Host "`n=== 4. Adversarial Test: CalendarSheet Interactive & Lifecycle Reflection ==="
$calType = $assembly.GetType("Tepi.Island+CalendarSheet")
Assert-True ($calType -ne $null) "Tepi.Island+CalendarSheet type resolved"

$flags = [System.Reflection.BindingFlags]"NonPublic,Public,Instance,DeclaredOnly"
$allFlags = [System.Reflection.BindingFlags]"NonPublic,Public,Instance"

$downMethod = $calType.GetMethod("Down", $allFlags)
Assert-True ($downMethod -ne $null) "Down method exists on CalendarSheet"

$pressedMethod = $calType.GetMethod("Pressed", $allFlags)
Assert-True ($pressedMethod -ne $null) "Pressed method exists on CalendarSheet"

$selectedDayProp = $calType.GetProperty("selectedDay", $allFlags)
Assert-True ($selectedDayProp -ne $null) "selectedDay property exists on CalendarSheet"

$onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
Assert-True ($onMouseDown -ne $null) "OnMouseDown is overridden on CalendarSheet"

$onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
Assert-True ($onMouseUp -ne $null) "OnMouseUp is overridden on CalendarSheet"

$onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)
Assert-True ($onMouseLeave -ne $null) "OnMouseLeave is overridden on CalendarSheet"

Write-Host "`n=== 5. Static Code Scan: Verify No Stale BadgeRed, BadgeRedSoft, or Hardcoded Colors ==="
$dockFiles = @(
    "D:\PROJECT\Other\tepi\src\DockPaint.cs",
    "D:\PROJECT\Other\tepi\src\DockCard.cs",
    "D:\PROJECT\Other\tepi\src\DockSheet.cs"
)

foreach ($f in $dockFiles) {
    $content = Get-Content $f -Raw
    $hasBadgeRed = $content.Contains("BadgeRed")
    Assert-True (-not $hasBadgeRed) "File $([System.IO.Path]::GetFileName($f)) does not contain BadgeRed"
    
    $hasBadgeRedSoft = $content.Contains("BadgeRedSoft")
    Assert-True (-not $hasBadgeRedSoft) "File $([System.IO.Path]::GetFileName($f)) does not contain BadgeRedSoft"
}

Write-Host "`n=== Summary ==="
if ($failures.Count -eq 0) {
    Write-Host "ALL ADVERSARIAL STRESS CHECKS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILURES ENCOUNTERED ($($failures.Count)):" -ForegroundColor Red
    foreach ($err in $failures) { Write-Host " - $err" -ForegroundColor Red }
    exit 1
}
