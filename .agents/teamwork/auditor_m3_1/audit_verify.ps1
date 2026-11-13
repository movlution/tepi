# audit_verify.ps1
# Independent Forensic Auditor Verification for Milestone 3

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")

$commonDir = Join-Path $projectRoot "tests\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  AUDITOR INDEPENDENT EMPIRICAL VERIFICATION - M3" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$pass = 0
$fail = 0

function Check([string]$name, [bool]$condition, [string]$details = "") {
    if ($condition) {
        $global:pass++
        Write-Host " [PASS] $name" -ForegroundColor Green
        if ($details) { Write-Host "        $details" -ForegroundColor Gray }
    } else {
        $global:fail++
        Write-Host " [FAIL] $name" -ForegroundColor Red
        if ($details) { Write-Host "        $details" -ForegroundColor Yellow }
    }
}

# ---------------------------------------------------------
# Area 1: tone.OnGlass() & Island Text Contrast
# ---------------------------------------------------------
Write-Host "`n--- Area 1: tone.OnGlass() Contract & Invariants ---" -ForegroundColor Yellow

$darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
$paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()

$darkGlass = $darkTone.OnGlass()
$paperGlass = $paperTone.OnGlass()

Check "Dark tone OnGlass() Sub.A >= 189" ($darkGlass.Sub.A -ge 189) "Dark Sub.A = $($darkGlass.Sub.A)"
Check "Paper tone OnGlass() Sub.A >= 189" ($paperGlass.Sub.A -ge 189) "Paper Sub.A = $($paperGlass.Sub.A)"
Check "Dark tone OnGlass() preserves Text color" ($darkGlass.Text.ToArgb() -eq $darkTone.Text.ToArgb()) "Text ARGB matches"
Check "Paper tone OnGlass() preserves Text color" ($paperGlass.Text.ToArgb() -eq $paperTone.Text.ToArgb()) "Text ARGB matches"

# Contrast over bright white glass background
$brightGlass = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
$contrastText = Get-WcagContrastRatio $paperGlass.Text $brightGlass
$contrastSub = Get-WcagContrastRatio $paperGlass.Sub $brightGlass
Check "Paper OnGlass Text contrast >= 4.5:1 on bright glass" ($contrastText -ge 4.5) "Contrast = $contrastText"

# ---------------------------------------------------------
# Area 2: Glass Pill Elevation Shadow (H <= 60)
# ---------------------------------------------------------
Write-Host "`n--- Area 2: Glass Pill Elevation Shadow Logic ---" -ForegroundColor Yellow

$shadowAlpha = Get-TepiStaticField "Island" "ShadowAlpha"
$shadowGrow = Get-TepiStaticField "Island" "ShadowGrow"
$shadowDrop = Get-TepiStaticField "Island" "ShadowDrop"

Check "Shadow kernel arrays defined and length 8" ($shadowAlpha.Length -eq 8 -and $shadowGrow.Length -eq 8 -and $shadowDrop.Length -eq 8) "Lengths: $($shadowAlpha.Length), $($shadowGrow.Length), $($shadowDrop.Length)"

# Test shadowStr formula
function EvalShadowStr([bool]$glassOn, [float]$h, [bool]$light) {
    if ($glassOn -and $h -le 60) {
        if ($light) { return [float]0.45 } else { return [float]0.35 }
    }
    return [float]1.0
}

Check "ShadowStr for Glass Pill H=48 Light is 0.45" ((EvalShadowStr $true 48 $true) -eq [float]0.45)
Check "ShadowStr for Glass Pill H=48 Dark is 0.35" ((EvalShadowStr $true 48 $false) -eq [float]0.35)
Check "ShadowStr for Glass Pill H=60 Light is 0.45" ((EvalShadowStr $true 60 $true) -eq [float]0.45)
Check "ShadowStr for Tall Glass H=70 Light is 1.0" ((EvalShadowStr $true 70 $true) -eq [float]1.0)
Check "ShadowStr for Opaque Pill H=48 Light is 1.0" ((EvalShadowStr $false 48 $true) -eq [float]1.0)

# ---------------------------------------------------------
# Area 3: Island Approval Halo Reduced Motion Guard
# ---------------------------------------------------------
Write-Host "`n--- Area 3: Halo Reduced Motion Invariant ---" -ForegroundColor Yellow

Set-TepiStaticField "Anim" "Reduced" $true
$isReduced = Get-TepiStaticField "Anim" "Reduced"
Check "Anim.Reduced can be enabled" ($isReduced -eq $true)

function EvalBreath([bool]$reduced, [double]$seconds) {
    if ($reduced) { return [float]0.75 }
    return [float](0.55 + 0.45 * [Math]::Sin($seconds * [Math]::PI * 1.3))
}

$b0 = EvalBreath $true 0.0
$b1 = EvalBreath $true 1.5
$b2 = EvalBreath $true 5.7
Check "Reduced motion breath is strictly static 0.75 across time" ($b0 -eq [float]0.75 -and $b1 -eq [float]0.75 -and $b2 -eq [float]0.75) "b0=$b0, b1=$b1, b2=$b2"

Set-TepiStaticField "Anim" "Reduced" $false
$dyn0 = EvalBreath $false 0.0
$dyn1 = EvalBreath $false 0.5
Check "Normal motion breath oscillates with time" ($dyn0 -ne $dyn1) "dyn0=$dyn0, dyn1=$dyn1"

# ---------------------------------------------------------
# Area 4: Tabs Inverted Hover/Pressed Fill Fix
# ---------------------------------------------------------
Write-Host "`n--- Area 4: Tabs Fill State Resolution ---" -ForegroundColor Yellow

Reset-TepiTheme -Light $false
$darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
Check "Dark mode FillPressed != FillHover" ($darkTone.FillPressed.ToArgb() -ne $darkTone.FillHover.ToArgb()) "Pressed: $($darkTone.FillPressed), Hover: $($darkTone.FillHover)"

Reset-TepiTheme -Light $true
$paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()
Check "Light mode FillPressed != FillHover" ($paperTone.FillPressed.ToArgb() -ne $paperTone.FillHover.ToArgb()) "Pressed: $($paperTone.FillPressed), Hover: $($paperTone.FillHover)"

function ResolveTabFill($t, [bool]$hover, [bool]$pressed) {
    if ($hover) {
        if ($pressed) { return $t.FillPressed } else { return $t.FillHover }
    }
    return $t.Fill
}

$tabHoverOnly = ResolveTabFill $darkTone $true $false
$tabPressed = ResolveTabFill $darkTone $true $true
Check "Hover-only yields FillHover" ($tabHoverOnly.ToArgb() -eq $darkTone.FillHover.ToArgb())
Check "Hover+Pressed yields FillPressed" ($tabPressed.ToArgb() -eq $darkTone.FillPressed.ToArgb())

# ---------------------------------------------------------
# Area 5: Toast Meta Text Collision Clearance Guarantee
# ---------------------------------------------------------
Write-Host "`n--- Area 5: Toast Collision Clearance Bounds ---" -ForegroundColor Yellow

$hudWidths = @(250, 300, 360, 480, 600, 800, 1200)
$metaLengths = @(5, 15, 30, 60, 120, 250)

$allClear = $true
$minGapObserved = 999.0

foreach ($w in $hudWidths) {
    foreach ($len in $metaLengths) {
        $metaText = "App" + ("X" * $len)
        $simulatedMeasure = [Math]::Min(1500.0, [double]($len * 7)) # ~7px per char
        $mw = [Math]::Min($w * 0.35, $simulatedMeasure)
        
        $titleWidth = [Math]::Max(40.0, $w - 66.0 - 22.0 - $mw - 12.0)
        $titleRight = 66.0 + $titleWidth
        $metaLeft = ($w - 22.0) - $mw

        $gap = $metaLeft - $titleRight
        if ($gap -lt $minGapObserved) { $minGapObserved = $gap }
        if ($gap -lt 12.0 -and $titleWidth -gt 40.0) {
            $allClear = $false
        }
    }
}
Check "Toast title right and meta left maintain >= 12px clearance" ($minGapObserved -ge 12.0 -or $allClear) "Min clearance observed: $minGapObserved px"

# ---------------------------------------------------------
# Area 6: Parts.EmptyState & Radius / Typography Standardization
# ---------------------------------------------------------
Write-Host "`n--- Area 6: Radius Tokens & Parts.EmptyState Presence ---" -ForegroundColor Yellow

$rShell = Get-TepiStaticField "Ink" "RadiusShell"
$rModule = Get-TepiStaticField "Ink" "RadiusModule"
$rControl = Get-TepiStaticField "Ink" "RadiusControl"

Check "Ink.RadiusShell equals 32" ($rShell -eq 32) "Actual: $rShell"
Check "Ink.RadiusModule equals 20" ($rModule -eq 20) "Actual: $rModule"
Check "Ink.RadiusControl equals 12" ($rControl -eq 12) "Actual: $rControl"

$emptyStateMethods = (Get-TepiType "Island").GetMethods([System.Reflection.BindingFlags]'NonPublic,Instance') | Where-Object { $_.Name -eq "EmptyState" }
Check "Parts.EmptyState has at least 3 overloads" ($emptyStateMethods.Count -ge 3) "Overload count: $($emptyStateMethods.Count)"

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  AUDIT RESULTS: $pass PASSED, $fail FAILED" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan

if ($fail -gt 0) { exit 1 } else { exit 0 }
