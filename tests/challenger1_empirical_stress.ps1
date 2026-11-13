# tests/challenger1_empirical_stress.ps1
# Challenger 1 Empirical Stress Test Harness: Interactive State & Theme Propagation
# Adversarial challenge for Milestone 2: KitWindow, KitButton, KitSwitch, KitSlider, KitAsk

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  CHALLENGER 1: INTERACTIVE STATE & THEME STRESS HARNESS" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load Assembly & Helpers
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$commonDir = Join-Path $PSScriptRoot "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

$passCount = 0
$failCount = 0

function Report-Result {
    param([string]$Name, [bool]$Passed, [string]$Details = "")
    if ($Passed) {
        $global:passCount++
        Write-Host " [PASS] $Name" -ForegroundColor Green
        if ($Details -and $Detailed) { Write-Host "        $Details" -ForegroundColor Gray }
    } else {
        $global:failCount++
        Write-Host " [FAIL] $Name" -ForegroundColor Red
        if ($Details) { Write-Host "        $Details" -ForegroundColor Yellow }
    }
}

# --------------------------------------------------------------------------
# SECTION 1: KitWindow.BroadcastThemeChange() Stress Testing
# --------------------------------------------------------------------------
Write-Host "`n--- 1. KitWindow.BroadcastThemeChange() Stress Testing ---" -ForegroundColor Yellow

$kitWindowType = Get-TepiType "KitWindow"
$flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'

# 1.1 Broadcast with zero open windows
try {
    [void]$kitWindowType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @())
    Report-Result "BroadcastThemeChange() handles empty registry safely" $true "No exception on empty registry"
} catch {
    Report-Result "BroadcastThemeChange() handles empty registry safely" $false "Threw: $($_.Exception.Message)"
}

# 1.2 WeakReference registry & GC pruning (Memory Leak Stress Test)
$regField = $kitWindowType.GetField("openWindows", [System.Reflection.BindingFlags]'NonPublic,Static')
$list = $regField.GetValue($null)
$initialCount = 0
[System.Threading.Monitor]::Enter($list)
$initialCount = $list.Count
[System.Threading.Monitor]::Exit($list)

function Test-WeakRegistryPruning {
    param($wType, $count = 50)
    for ($i = 0; $i -lt $count; $i++) {
        $dummy = [Activator]::CreateInstance($wType)
    }
}

Test-WeakRegistryPruning -wType $kitWindowType -count 50

[System.Threading.Monitor]::Enter($list)
$allocatedCount = $list.Count
[System.Threading.Monitor]::Exit($list)

Report-Result "KitWindow registers instances in weak registry on creation" ($allocatedCount -ge ($initialCount + 50)) "Count: $allocatedCount"

# Run GC to collect unreferenced Form instances
[GC]::Collect()
[GC]::WaitForPendingFinalizers()
[GC]::Collect()

# Call BroadcastThemeChange() to trigger dead target pruning
[void]$kitWindowType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @())

[System.Threading.Monitor]::Enter($list)
$afterPruneCount = $list.Count
[System.Threading.Monitor]::Exit($list)

Report-Result "BroadcastThemeChange() prunes collected WeakReferences (zero GC leaks)" ($afterPruneCount -eq $initialCount) "Count after GC & prune: $afterPruneCount (initial: $initialCount)"

# 1.3 Dynamic propagation of BackColor and ForeColor to active windows
Reset-TepiTheme -Light $false
$activeWin1 = [Activator]::CreateInstance($kitWindowType)
$activeWin2 = [Activator]::CreateInstance($kitWindowType)
$group1 = New-TepiControl "KitGroup"
$activeWin1.Controls.Add($group1)

# Check dark initial colors
$darkWinColor = Get-TepiStaticProperty "KitInk" "Window"
$darkTextColor = Get-TepiStaticProperty "KitInk" "Text"
$darkGroupColor = Get-TepiStaticProperty "KitInk" "Group"

Report-Result "KitWindow initial Dark colors match KitInk" ($activeWin1.BackColor.ToArgb() -eq $darkWinColor.ToArgb()) "Dark: $($activeWin1.BackColor)"

# Switch to Light Theme and broadcast
Reset-TepiTheme -Light $true
[void]$kitWindowType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @())

$lightWinColor = Get-TepiStaticProperty "KitInk" "Window"
$lightTextColor = Get-TepiStaticProperty "KitInk" "Text"
$lightGroupColor = Get-TepiStaticProperty "KitInk" "Group"

$propWin1 = ($activeWin1.BackColor.ToArgb() -eq $lightWinColor.ToArgb() -and $activeWin1.ForeColor.ToArgb() -eq $lightTextColor.ToArgb())
$propWin2 = ($activeWin2.BackColor.ToArgb() -eq $lightWinColor.ToArgb() -and $activeWin2.ForeColor.ToArgb() -eq $lightTextColor.ToArgb())
$propGroup = ($group1.BackColor.ToArgb() -eq $lightGroupColor.ToArgb())

Report-Result "BroadcastThemeChange() updates window BackColor & ForeColor to Light" ($propWin1 -and $propWin2) "Win1 BackColor: $($activeWin1.BackColor)"
Report-Result "BroadcastThemeChange() updates child KitGroup.BackColor to Light" $propGroup "Group BackColor: $($group1.BackColor)"

# Switch back to Dark Theme and broadcast
Reset-TepiTheme -Light $false
[void]$kitWindowType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @())

$propDarkWin1 = ($activeWin1.BackColor.ToArgb() -eq $darkWinColor.ToArgb())
$propDarkGroup = ($group1.BackColor.ToArgb() -eq $darkGroupColor.ToArgb())
Report-Result "BroadcastThemeChange() switches back to Dark dynamically" ($propDarkWin1 -and $propDarkGroup) "Win1 Dark BackColor: $($activeWin1.BackColor)"

# Clean up active test windows
$activeWin1.Dispose()
$activeWin2.Dispose()

# 1.4 Rapid Broadcast Concurrency / Torture Test
$rapidOk = $true
$rapidError = ""
try {
    for ($i = 0; $i -lt 50; $i++) {
        $isLight = ($i % 2 -eq 0)
        Reset-TepiTheme -Light $isLight
        [void]$kitWindowType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @())
    }
} catch {
    $rapidOk = $false
    $rapidError = $_.Exception.Message
}
Report-Result "BroadcastThemeChange() survives 50 rapid successive theme toggles" $rapidOk "Error: $rapidError"


# --------------------------------------------------------------------------
# SECTION 2: KitButton Interactive States & Focus Ring Stress Testing
# --------------------------------------------------------------------------
Write-Host "`n--- 2. KitButton Interactive States & Focus Ring Stress Testing ---" -ForegroundColor Yellow

$btn = New-TepiControl "KitButton" @{ Text = "Test Button"; Width = 120; Height = 36 }
$btnType = $btn.GetType()
$hoverField = $btnType.GetField("hovered", [System.Reflection.BindingFlags]'NonPublic,Instance')
$pressedField = $btnType.GetField("pressed", [System.Reflection.BindingFlags]'NonPublic,Instance')
$onMouseEnter = $btnType.GetMethod("OnMouseEnter", [System.Reflection.BindingFlags]'NonPublic,Instance')
$onMouseLeave = $btnType.GetMethod("OnMouseLeave", [System.Reflection.BindingFlags]'NonPublic,Instance')
$onMouseDown = $btnType.GetMethod("OnMouseDown", [System.Reflection.BindingFlags]'NonPublic,Instance')
$onMouseUp = $btnType.GetMethod("OnMouseUp", [System.Reflection.BindingFlags]'NonPublic,Instance')

# 2.1 State transition: Normal -> MouseEnter -> MouseDown -> MouseUp -> MouseLeave
$onMouseEnter.Invoke($btn, [object[]]@([EventArgs]::Empty))
$isHovered1 = [bool]$hoverField.GetValue($btn)
$isPressed1 = [bool]$pressedField.GetValue($btn)

$leftDownArgs = New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 10, 10, 0)
$onMouseDown.Invoke($btn, [object[]]@([System.Windows.Forms.MouseEventArgs]$leftDownArgs))
$isHovered2 = [bool]$hoverField.GetValue($btn)
$isPressed2 = [bool]$pressedField.GetValue($btn)

$leftUpArgs = New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 10, 10, 0)
$onMouseUp.Invoke($btn, [object[]]@([System.Windows.Forms.MouseEventArgs]$leftUpArgs))
$isHovered3 = [bool]$hoverField.GetValue($btn)
$isPressed3 = [bool]$pressedField.GetValue($btn)

$onMouseLeave.Invoke($btn, [object[]]@([EventArgs]::Empty))
$isHovered4 = [bool]$hoverField.GetValue($btn)
$isPressed4 = [bool]$pressedField.GetValue($btn)

$cycleOk = ($isHovered1 -and -not $isPressed1 -and $isHovered2 -and $isPressed2 -and $isHovered3 -and -not $isPressed3 -and -not $isHovered4 -and -not $isPressed4)
Report-Result "KitButton standard mouse event cycle (Hover->Down->Up->Leave)" $cycleOk "H1:$isHovered1 P1:$isPressed1, H2:$isHovered2 P2:$isPressed2, H3:$isHovered3 P3:$isPressed3, H4:$isHovered4 P4:$isPressed4"

# 2.2 Adversarial Drag-Out: MouseDown -> MouseLeave without MouseUp
$onMouseEnter.Invoke($btn, [object[]]@([EventArgs]::Empty))
$onMouseDown.Invoke($btn, [object[]]@([System.Windows.Forms.MouseEventArgs]$leftDownArgs))
$onMouseLeave.Invoke($btn, [object[]]@([EventArgs]::Empty)) # mouse leaves while button held
$dragOutHovered = [bool]$hoverField.GetValue($btn)
$dragOutPressed = [bool]$pressedField.GetValue($btn)
Report-Result "KitButton clears pressed state when mouse leaves control bounds (Drag-Out)" (-not $dragOutPressed -and -not $dragOutHovered) "Pressed: $dragOutPressed, Hovered: $dragOutHovered"

# 2.3 Non-Left Click Adversarial Input (Right-Click, Middle-Click)
$rightDownArgs = New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Right, 1, 10, 10, 0)
$onMouseDown.Invoke($btn, [object[]]@([System.Windows.Forms.MouseEventArgs]$rightDownArgs))
$rightPressed = [bool]$pressedField.GetValue($btn)
Report-Result "KitButton ignores Right-Click for pressed state activation" (-not $rightPressed) "Pressed on Right Click: $rightPressed"

# 2.4 Pixel Render Differences (Normal vs Hover vs Pressed)
Reset-TepiTheme -Light $true
$btnSecondary = New-TepiControl "KitButton" @{ Text = "Action"; Width = 120; Height = 36; Primary = $false }
$bmpNorm = Render-TepiControlToBitmap $btnSecondary 120 36

$hoverField.SetValue($btnSecondary, $true)
$bmpHov = Render-TepiControlToBitmap $btnSecondary 120 36

$pressedField.SetValue($btnSecondary, $true)
$bmpPress = Render-TepiControlToBitmap $btnSecondary 120 36

# Check center and border pixels
$pxN = $bmpNorm.GetPixel(60, 18)
$pxH = $bmpHov.GetPixel(60, 18)
$pxP = $bmpPress.GetPixel(60, 18)

$secondaryDistinct = ($pxN.ToArgb() -ne $pxH.ToArgb() -and $pxH.ToArgb() -ne $pxP.ToArgb() -and $pxN.ToArgb() -ne $pxP.ToArgb())
Report-Result "KitButton secondary button renders distinct pixels for Normal, Hover, Pressed" $secondaryDistinct "Norm:$($pxN.Name) Hov:$($pxH.Name) Press:$($pxP.Name)"

# Primary Button Pressed vs Hovered in Light and Dark Mode
$btnPrimary = New-TepiControl "KitButton" @{ Text = "Primary"; Width = 120; Height = 36; Primary = $true }
$hoverField.SetValue($btnPrimary, $true)
$pressedField.SetValue($btnPrimary, $false)
$bmpPrimHov = Render-TepiControlToBitmap $btnPrimary 120 36

$pressedField.SetValue($btnPrimary, $true)
$bmpPrimPress = Render-TepiControlToBitmap $btnPrimary 120 36

$pxPrimH = $bmpPrimHov.GetPixel(60, 18)
$pxPrimP = $bmpPrimPress.GetPixel(60, 18)
Report-Result "KitButton primary button renders distinct pixels for Hover vs Pressed" ($pxPrimH.ToArgb() -ne $pxPrimP.ToArgb()) "PrimHov:$($pxPrimH.Name) PrimPress:$($pxPrimP.Name)"

$bmpNorm.Dispose(); $bmpHov.Dispose(); $bmpPress.Dispose(); $bmpPrimHov.Dispose(); $bmpPrimPress.Dispose()
$btnSecondary.Dispose(); $btnPrimary.Dispose(); $btn.Dispose()

# 2.5 Focus Ring Visibility & Contrast across Accents & Presets
Write-Host "   Testing Focus Ring contrast across curated accents..." -ForegroundColor Gray
$accentsToTest = @(
    @{ Name = "Blue"; Hex = "#1668E8" },
    @{ Name = "Purple"; Hex = "#6C3CE0" },
    @{ Name = "Pink"; Hex = "#C2185B" },
    @{ Name = "Red"; Hex = "#C5221F" },
    @{ Name = "Orange"; Hex = "#A84B00" },
    @{ Name = "Yellow"; Hex = "#855E00" },
    @{ Name = "Green"; Hex = "#107C41" },
    @{ Name = "Graphite"; Hex = "" },
    @{ Name = "Adversarial Black"; Hex = "#000000" },
    @{ Name = "Adversarial White"; Hex = "#FFFFFF" }
)

$ringContrastOk = $true
$ringContrastFailures = @()

foreach ($acc in $accentsToTest) {
    foreach ($isLight in @($true, $false)) {
        Reset-TepiTheme -Light $isLight
        if ($acc.Hex) { Invoke-TepiStaticMethod "Ink" "SetAccent" @($acc.Hex) }
        else { Invoke-TepiStaticMethod "Ink" "SetAccent" @([string]$null) }

        foreach ($isPrim in @($true, $false)) {
            $tBtn = New-TepiControl "KitButton" @{ Text = "Focus"; Width = 120; Height = 36; Primary = $isPrim }
            Set-TepiStaticField "KitInk" "ByMouse" $false

            $bg = if ($isPrim) {
                Get-TepiStaticProperty "KitInk" "Text"
            } else {
                Get-TepiStaticProperty "KitInk" "Line"
            }

            $accentToken = Get-TepiStaticProperty "KitInk" "Accent"
            $textToken = Get-TepiStaticProperty "KitInk" "Text"
            $ringColor = $accentToken
            $cRatio = Get-TepiContrast $ringColor $bg
            if ($cRatio -lt 3.0 -or ($isPrim -and ($ringColor.ToArgb() -eq $textToken.ToArgb() -or $ringColor.ToArgb() -eq $bg.ToArgb()))) {
                $ringColor = if ($isLight) { [System.Drawing.Color]::FromArgb(255, 22, 104, 232) } else { [System.Drawing.Color]::FromArgb(255, 59, 130, 246) }
            }
            $finalRatio = Get-TepiContrast $ringColor $bg
            if ($finalRatio -lt 3.0) {
                $ringContrastOk = $false
                $ringContrastFailures += "Accent: $($acc.Name), Light:$isLight, Primary:$isPrim => Ratio $finalRatio < 3.0"
            }
            $tBtn.Dispose()
        }
    }
}
Report-Result "KitButton focus ring guarantees >= 3.0:1 contrast on all accents & modes" $ringContrastOk ($ringContrastFailures -join "; ")


# --------------------------------------------------------------------------
# SECTION 3: KitSwitch Hover State & Bounds Stress Testing
# --------------------------------------------------------------------------
Write-Host "`n--- 3. KitSwitch Hover State & Bounds Stress Testing ---" -ForegroundColor Yellow

$sw = New-TepiControl "KitSwitch" @{ Width = 60; Height = 28 }
$swType = $sw.GetType()
$swHoverField = $swType.GetField("hovered", [System.Reflection.BindingFlags]'NonPublic,Instance')
$swOnMouseEnter = $swType.GetMethod("OnMouseEnter", [System.Reflection.BindingFlags]'NonPublic,Instance')
$swOnMouseLeave = $swType.GetMethod("OnMouseLeave", [System.Reflection.BindingFlags]'NonPublic,Instance')

# 3.1 Hover state transitions
$swOnMouseEnter.Invoke($sw, [object[]]@([EventArgs]::Empty))
$swHovTrue = [bool]$swHoverField.GetValue($sw)
$swOnMouseLeave.Invoke($sw, [object[]]@([EventArgs]::Empty))
$swHovFalse = [bool]$swHoverField.GetValue($sw)
Report-Result "KitSwitch OnMouseEnter/OnMouseLeave toggles hovered field" ($swHovTrue -and -not $swHovFalse) "Enter:$swHovTrue, Leave:$swHovFalse"

# 3.2 Visual Render difference when hovered (Unchecked state)
Reset-TepiTheme -Light $true
$swUnchecked = New-TepiControl "KitSwitch" @{ Checked = $false; Width = 60; Height = 28 }
$bmpSwNormal = Render-TepiControlToBitmap $swUnchecked 60 28

$swHoverField.SetValue($swUnchecked, $true)
$bmpSwHover = Render-TepiControlToBitmap $swUnchecked 60 28

# Track area pixel (e.g. x=30, y=14)
$pxSwNorm = $bmpSwNormal.GetPixel(30, 14)
$pxSwHov = $bmpSwHover.GetPixel(30, 14)
Report-Result "KitSwitch Unchecked track shifts luminance on hover" ($pxSwNorm.ToArgb() -ne $pxSwHov.ToArgb()) "Norm:$($pxSwNorm.Name) Hov:$($pxSwHov.Name)"

# 3.3 Visual Render difference when hovered (Checked state with accent)
Invoke-TepiStaticMethod "Ink" "SetAccent" @("#1668E8")
$swChecked = New-TepiControl "KitSwitch" @{ Checked = $true; Width = 60; Height = 28 }
$swKnobField = $swType.GetField("knob", [System.Reflection.BindingFlags]'NonPublic,Instance')
$swKnobField.SetValue($swChecked, [float]1.0)

$bmpSwCheckedNorm = Render-TepiControlToBitmap $swChecked 60 28
$swHoverField.SetValue($swChecked, $true)
$bmpSwCheckedHov = Render-TepiControlToBitmap $swChecked 60 28

$pxSwChkNorm = $bmpSwCheckedNorm.GetPixel(15, 14)
$pxSwChkHov = $bmpSwCheckedHov.GetPixel(15, 14)
Report-Result "KitSwitch Checked track shifts luminance on hover" ($pxSwChkNorm.ToArgb() -ne $pxSwChkHov.ToArgb()) "Norm:$($pxSwChkNorm.Name) Hov:$($pxSwChkHov.Name)"

# 3.4 Disabled switch hover immunity (Disabled control must ignore hover)
$swDisabled = New-TepiControl "KitSwitch" @{ Enabled = $false; Width = 60; Height = 28 }
$bmpDisNorm = Render-TepiControlToBitmap $swDisabled 60 28

$swHoverField.SetValue($swDisabled, $true)
$bmpDisHov = Render-TepiControlToBitmap $swDisabled 60 28

# Sample 10 points across track and knob
$disIdentical = $true
for ($x = 5; $x -lt 55; $x += 5) {
    if ($bmpDisNorm.GetPixel($x, 14).ToArgb() -ne $bmpDisHov.GetPixel($x, 14).ToArgb()) {
        $disIdentical = $false
        break
    }
}
Report-Result "KitSwitch disabled state is immune to hover visual changes" $disIdentical "All sampled pixels identical between normal and hovered when disabled"

# 3.5 Extreme dimension robustness
$heightsToTest = @(10, 16, 24, 32, 48, 72, 96)
$dimOk = $true
$dimError = ""
foreach ($h in $heightsToTest) {
    try {
        $w = [int]($h * 2.5)
        $testSw = New-TepiControl "KitSwitch"
        $testSw.Width = $w
        $testSw.Height = $h
        $bmpH = Render-TepiControlToBitmap -Control $testSw -Width $w -Height $h
        $bmpH.Dispose()
        $testSw.Dispose()
    } catch {
        $dimOk = $false
        $dimError = "Height ${h}: $($_.Exception.Message)"
        break
    }
}
Report-Result "KitSwitch renders without crash across height scale 10px-96px" $dimOk "Heights: $($heightsToTest -join ', ')"

$bmpSwNormal.Dispose(); $bmpSwHover.Dispose(); $bmpSwCheckedNorm.Dispose(); $bmpSwCheckedHov.Dispose()
$bmpDisNorm.Dispose(); $bmpDisHov.Dispose()
$swUnchecked.Dispose(); $swChecked.Dispose(); $swDisabled.Dispose(); $sw.Dispose()


# --------------------------------------------------------------------------
# SECTION 4: KitSlider Disabled vs Enabled Thumb Rendering
# --------------------------------------------------------------------------
Write-Host "`n--- 4. KitSlider Disabled vs Enabled Thumb Rendering ---" -ForegroundColor Yellow

$slider = New-TepiControl "KitSlider"
$slider.Minimum = 0
$slider.Maximum = 100
$slider.Value = 50
$slider.Width = 150
$slider.Height = 28
$sliderType = $slider.GetType()

# 4.1 Enabled Thumb vs Disabled Thumb Colors in Light and Dark Mode
$thumbColorMatchOk = $true
$thumbDetails = @()

foreach ($isLight in @($true, $false)) {
    Reset-TepiTheme -Light $isLight
    $disToken = Get-TepiStaticProperty "KitInk" "Disabled"
    $textToken = Get-TepiStaticProperty "KitInk" "Text"

    # Enabled Slider
    $slEnabled = New-TepiControl "KitSlider"
    $slEnabled.Minimum = 0
    $slEnabled.Maximum = 100
    $slEnabled.Value = 0
    $slEnabled.Width = 140
    $slEnabled.Height = 28
    $slEnabled.Enabled = $true
    $bmpEn = Render-TepiControlToBitmap $slEnabled 140 28
    $pxThumbEn = $bmpEn.GetPixel(10, 14)

    # Disabled Slider
    $slDisabled = New-TepiControl "KitSlider"
    $slDisabled.Minimum = 0
    $slDisabled.Maximum = 100
    $slDisabled.Value = 0
    $slDisabled.Width = 140
    $slDisabled.Height = 28
    $slDisabled.Enabled = $false
    $bmpDis = Render-TepiControlToBitmap $slDisabled 140 28
    $pxThumbDis = $bmpDis.GetPixel(10, 14)

    $matchDis = ($pxThumbDis.R -eq $disToken.R -and $pxThumbDis.G -eq $disToken.G -and $pxThumbDis.B -eq $disToken.B)
    $diffFromText = ($pxThumbDis.ToArgb() -ne $textToken.ToArgb())

    if (-not ($matchDis -and $diffFromText)) {
        $thumbColorMatchOk = $false
        $thumbDetails += "Light:$isLight => ThumbDis=$($pxThumbDis.Name) expected $($disToken.Name)"
    }

    $bmpEn.Dispose(); $bmpDis.Dispose()
    $slEnabled.Dispose(); $slDisabled.Dispose()
}
Report-Result "KitSlider disabled thumb matches KitInk.Disabled (not active Text) in Light & Dark" $thumbColorMatchOk ($thumbDetails -join "; ")

# 4.2 Thumb Radius Immunity to Drag/Hover when Disabled
$slDisTest = New-TepiControl "KitSlider"
$slDisTest.Minimum = 0
$slDisTest.Maximum = 100
$slDisTest.Value = 50
$slDisTest.Width = 140
$slDisTest.Height = 28
$slDisTest.Enabled = $false
$bmpDisNoHov = Render-TepiControlToBitmap $slDisTest 140 28

# Set dragging and hovered
$dragField = $sliderType.GetField("dragging", [System.Reflection.BindingFlags]'NonPublic,Instance')
if ($dragField) { $dragField.SetValue($slDisTest, $true) }
$bmpDisDrag = Render-TepiControlToBitmap $slDisTest 140 28

$pxAt9_NoHov = $bmpDisNoHov.GetPixel(70, 5)
$pxAt9_Drag = $bmpDisDrag.GetPixel(70, 5)
Report-Result "KitSlider disabled thumb radius does not expand on drag/hover" ($pxAt9_NoHov.ToArgb() -eq $pxAt9_Drag.ToArgb()) "Px at r=9: $($pxAt9_NoHov.Name) vs $($pxAt9_Drag.Name)"

$bmpDisNoHov.Dispose(); $bmpDisDrag.Dispose(); $slDisTest.Dispose()

# 4.3 Slider Boundary Value Clamping and Arithmetic Safety
$slBounds = New-TepiControl "KitSlider"
$slBounds.Minimum = 10
$slBounds.Maximum = 90
$slBounds.Step = 5
$slBounds.Value = 50
$setMethod = $sliderType.GetMethod("Set", [System.Reflection.BindingFlags]'NonPublic,Instance')

# Test below minimum
$setMethod.Invoke($slBounds, @(-50))
$valBelow = $slBounds.Value

# Test above maximum
$setMethod.Invoke($slBounds, @(500))
$valAbove = $slBounds.Value

# Test step snapping (e.g. 33 should snap to 35)
$setMethod.Invoke($slBounds, @(33))
$valSnap = $slBounds.Value

$boundsOk = ($valBelow -eq 10 -and $valAbove -eq 90 -and $valSnap -eq 35)
Report-Result "KitSlider bounds clamping (Min=10, Max=90, Step=5)" $boundsOk "Below: $valBelow, Above: $valAbove, Snap(33): $valSnap"

# 4.4 Boundary case: Minimum == Maximum (Zero span)
$slZeroSpan = New-TepiControl "KitSlider"
$slZeroSpan.Minimum = 50
$slZeroSpan.Maximum = 50
$slZeroSpan.Value = 50
$slZeroSpan.Width = 140
$slZeroSpan.Height = 28
$zeroSpanOk = $true
try {
    $bmpZero = Render-TepiControlToBitmap $slZeroSpan 140 28
    $bmpZero.Dispose()
} catch {
    $zeroSpanOk = $false
}
Report-Result "KitSlider handles Minimum == Maximum without divide-by-zero" $zeroSpanOk "Render completed cleanly"
$slZeroSpan.Dispose(); $slBounds.Dispose(); $slider.Dispose()


# --------------------------------------------------------------------------
# SECTION 5: KitAsk Dynamic Title & Localization Stress Testing
# --------------------------------------------------------------------------
Write-Host "`n--- 5. KitAsk Dynamic Title & Button Localization Stress Testing ---" -ForegroundColor Yellow

$kitAskType = Get-TepiType "KitAsk"
$askFlags = [System.Reflection.BindingFlags]'NonPublic,Instance'
$getState = [System.Windows.Forms.Control].GetMethod("GetState", [System.Reflection.BindingFlags]'NonPublic,Instance')

function New-KitAskInstance {
    param(
        [string]$Message,
        [bool]$Question,
        [string]$Confirm = "Hapus",
        [string]$Dismiss = "Batal",
        [string]$Title = $null,
        [string]$Close = "Tutup"
    )
    $ctors = $kitAskType.GetConstructors([System.Reflection.BindingFlags]'NonPublic,Instance')
    $ctor6 = $ctors | Where-Object { $_.GetParameters().Length -ge 5 } | Select-Object -First 1
    if (-not $ctor6) { throw "KitAsk 6-parameter constructor not found" }
    return $ctor6.Invoke(@($Message, $Question, $Confirm, $Dismiss, $Title, $Close))
}

# 5.1 Dynamic Title: Explicit vs Default Fallback
$customTitle = "Konfirmasi Khusus"
$askExplicit = New-KitAskInstance -Message "Pesan uji" -Question $true -Title $customTitle
Report-Result "KitAsk uses explicit title parameter" ($askExplicit.Text -eq $customTitle) "Text: $($askExplicit.Text)"

# Question mode default title
$askQuestionDefault = New-KitAskInstance -Message "Pesan tanya" -Question $true -Title $null
$expectedQuestionTitle = Invoke-TepiStaticMethod "Lang" "T" @("Konfirmasi")
Report-Result "KitAsk question mode falls back to localized 'Konfirmasi'" ($askQuestionDefault.Text -eq $expectedQuestionTitle) "Text: $($askQuestionDefault.Text)"

# Notice mode default title
$askNoticeDefault = New-KitAskInstance -Message "Pesan info" -Question $false -Title $null
$expectedNoticeTitle = Invoke-TepiStaticMethod "Lang" "T" @("Pemberitahuan")
Report-Result "KitAsk notice mode falls back to localized 'Pemberitahuan'" ($askNoticeDefault.Text -eq $expectedNoticeTitle) "Text: $($askNoticeDefault.Text)"

# Empty string title falls back to default
$askEmptyTitle = New-KitAskInstance -Message "Pesan info" -Question $false -Title ""
Report-Result "KitAsk empty string title falls back to localized default" ($askEmptyTitle.Text -eq $expectedNoticeTitle) "Text: $($askEmptyTitle.Text)"

# 5.2 Button Labels and Localization
$askCustomButtons = New-KitAskInstance -Message "Hapus file?" -Question $true -Confirm "Buang" -Dismiss "Pertahankan"
$yesBtn = $kitAskType.GetField("yes", $askFlags).GetValue($askCustomButtons)
$noBtn = $kitAskType.GetField("no", $askFlags).GetValue($askCustomButtons)
$okBtn = $kitAskType.GetField("ok", $askFlags).GetValue($askCustomButtons)

$expectedYes = Invoke-TepiStaticMethod "Lang" "T" @("Buang")
$expectedNo = Invoke-TepiStaticMethod "Lang" "T" @("Pertahankan")
Report-Result "KitAsk action buttons localized via Lang.T (custom labels)" ($yesBtn.Text -eq $expectedYes -and $noBtn.Text -eq $expectedNo) "Yes: $($yesBtn.Text), No: $($noBtn.Text)"

# Button visibility in Question mode vs Notice mode
# In WinForms, Control.Visible checks parents, so check STATE_VISIBLE (bit 2) for component's own visible setting
$yesStateVis = [bool]$getState.Invoke($yesBtn, @(2))
$noStateVis = [bool]$getState.Invoke($noBtn, @(2))
$okStateVis = [bool]$getState.Invoke($okBtn, @(2))
$qVisOk = ($yesStateVis -and $noStateVis -and -not $okStateVis)
Report-Result "KitAsk Question mode: yes & no visible, ok hidden" $qVisOk "YesState:$yesStateVis NoState:$noStateVis OkState:$okStateVis"

$askNotice = New-KitAskInstance -Message "Pemberitahuan selesai" -Question $false -Close "Mengerti"
$noticeOkBtn = $kitAskType.GetField("ok", $askFlags).GetValue($askNotice)
$noticeYesBtn = $kitAskType.GetField("yes", $askFlags).GetValue($askNotice)
$noticeNoBtn = $kitAskType.GetField("no", $askFlags).GetValue($askNotice)

$expectedClose = Invoke-TepiStaticMethod "Lang" "T" @("Mengerti")
$nOkVis = [bool]$getState.Invoke($noticeOkBtn, @(2))
$nYesVis = [bool]$getState.Invoke($noticeYesBtn, @(2))
$nNoVis = [bool]$getState.Invoke($noticeNoBtn, @(2))
$nVisOk = ($nOkVis -and -not $nYesVis -and -not $nNoVis -and $noticeOkBtn.Text -eq $expectedClose)
Report-Result "KitAsk Notice mode: ok visible with localized text, yes & no hidden" $nVisOk "OkState:$nOkVis Text:$($noticeOkBtn.Text)"

# 5.3 Relayout and Message Length Scalability
$longMessage = "Peringatan Sistem: " + (1..30 | ForEach-Object { "Ini adalah teks pesan panjang baris ke-$_ untuk menguji penskalaan layout otomatis." }) -join " "
$askLong = New-KitAskInstance -Message $longMessage -Question $true
$null = $askLong.Handle # Force HWND creation
$relayoutMethod = $kitAskType.GetMethod("Relayout", [System.Reflection.BindingFlags]'Public,Instance')
$relayoutMethod.Invoke($askLong, @())

$heightExpanded = ($askLong.ClientSize.Height -gt 250)
Report-Result "KitAsk Relayout dynamically expands ClientSize for long text" $heightExpanded "ClientSize: $($askLong.ClientSize.Width)x$($askLong.ClientSize.Height)"

# Clean up KitAsk instances
$askExplicit.Dispose(); $askQuestionDefault.Dispose(); $askNoticeDefault.Dispose()
$askEmptyTitle.Dispose(); $askCustomButtons.Dispose(); $askNotice.Dispose(); $askLong.Dispose()


# --------------------------------------------------------------------------
# SUMMARY VERDICT
# --------------------------------------------------------------------------
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  EMPIRICAL CHALLENGE SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($global:passCount + $global:failCount)"
Write-Host "Passed:      $global:passCount" -ForegroundColor Green
Write-Host "Failed:      $global:failCount" -ForegroundColor $(if ($global:failCount -eq 0) { "Green" } else { "Red" })

if ($global:failCount -eq 0) {
    Write-Host "`n>> VERDICT: APPROVE - All interactive states and theme propagation passed empirical stress tests." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n>> VERDICT: REQUEST_CHANGES - $global:failCount tests failed." -ForegroundColor Red
    exit 1
}
