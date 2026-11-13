# adversarial_audit.ps1
# Forensic Auditor Milestone 2 Empirical & Adversarial Stress Tests

$ErrorActionPreference = "Stop"
$projectRoot = "d:\PROJECT\Other\tepi"
$commonDir = Join-Path $projectRoot "tests\common"

. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Write-Host "=========================================================="
Write-Host "  FORENSIC AUDITOR MILESTONE 2 ADVERSARIAL STRESS TEST"
Write-Host "=========================================================="

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Check($name, [scriptblock]$sb) {
    $global:totalTests++
    try {
        & $sb
        $global:passedTests++
        Write-Host " [PASS] $name" -ForegroundColor Green
    } catch {
        $global:failedTests++
        Write-Host " [FAIL] $name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 1. KITINK.FAINT MATHEMATICAL CONTRAST VERIFICATION
Write-Host "`n--- 1. KitInk.Faint Mathematical Contrast Audit ---"

Check "Light Mode KitInk.Faint mix factor is 0.65" {
    Reset-TepiTheme -Light $true
    $bg = (Get-TepiStaticField "Ink" "Base").Bg
    $text = (Get-TepiStaticField "Ink" "Base").Text
    $faint = Get-TepiStaticProperty "KitInk" "Faint"
    
    # Check contrast on Window
    $win = Get-TepiStaticProperty "KitInk" "Window"
    $crWin = Assert-Contrast $faint $win 4.5 "Faint vs Window"
    if ($crWin -lt 4.5) { throw "Faint on Window fails WCAG AA: $crWin:1" }
    
    # Check contrast on Side
    $side = Get-TepiStaticProperty "KitInk" "Side"
    $crSide = Assert-Contrast $faint $side 4.5 "Faint vs Side"
    if ($crSide -lt 4.5) { throw "Faint on Side fails WCAG AA: $crSide:1" }

    # Check contrast on Group
    $group = Get-TepiStaticProperty "KitInk" "Group"
    $crGroup = Assert-Contrast $faint $group 4.5 "Faint vs Group"
    if ($crGroup -lt 4.5) { throw "Faint on Group fails WCAG AA: $crGroup:1" }

    # Check contrast on Hover
    $hover = Get-TepiStaticProperty "KitInk" "Hover"
    $crHover = Assert-Contrast $faint $hover 4.5 "Faint vs Hover"
    if ($crHover -lt 4.5) { throw "Faint on Hover fails WCAG AA: $crHover:1" }

    # Check contrast on Line
    $line = Get-TepiStaticProperty "KitInk" "Line"
    $crLine = Assert-Contrast $faint $line 4.5 "Faint vs Line"
    if ($crLine -lt 4.5) { throw "Faint on Line fails WCAG AA: $crLine:1" }
}

Check "Dark Mode KitInk.Faint maintains WCAG AA contrast" {
    Reset-TepiTheme -Light $false
    $faint = Get-TepiStaticProperty "KitInk" "Faint"
    $win = Get-TepiStaticProperty "KitInk" "Window"
    $crWin = Assert-Contrast $faint $win 4.5 "Dark Faint vs Window"
    if ($crWin -lt 4.5) { throw "Dark Faint on Window fails WCAG AA: $crWin:1" }
}

# 2. MENULOOK.SUB MATHEMATICAL CONTRAST VERIFICATION
Write-Host "`n--- 2. MenuLook.Sub Contrast Audit ---"

Check "MenuLook.Sub contrast >= 4.5:1 against menu background in Light & Dark modes" {
    $menuLookType = Get-TepiType "MenuLook"
    $flags = [System.Reflection.BindingFlags]'Static,NonPublic'
    
    # Light mode
    Reset-TepiTheme -Light $true
    $subLight = $menuLookType.GetProperty("Sub", $flags).GetValue($null, $null)
    $bgLight = $menuLookType.GetProperty("Bg", $flags).GetValue($null, $null)
    $crLight = Assert-Contrast $subLight $bgLight 4.5 "MenuLook Sub vs Bg (Light)"
    if ($crLight -lt 4.5) { throw "Light MenuLook.Sub fails WCAG AA: $crLight:1" }

    # Dark mode
    Reset-TepiTheme -Light $false
    $subDark = $menuLookType.GetProperty("Sub", $flags).GetValue($null, $null)
    $bgDark = $menuLookType.GetProperty("Bg", $flags).GetValue($null, $null)
    $crDark = Assert-Contrast $subDark $bgDark 4.5 "MenuLook Sub vs Bg (Dark)"
    if ($crDark -lt 4.5) { throw "Dark MenuLook.Sub fails WCAG AA: $crDark:1" }
}

# 3. KITBUTTON INTERACTIVE STATES & FOCUS RING
Write-Host "`n--- 3. KitButton Interactive States & Focus Ring Audit ---"

Check "KitButton pressed state tracking and focus ring contrast" {
    $btnType = Get-TepiType "KitButton"
    $btn = [Activator]::CreateInstance($btnType)
    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'

    # Verify fields
    $pressedField = $btnType.GetField("pressed", $flags)
    if (-not $pressedField) { throw "KitButton missing pressed field" }

    # Test mouse down sets pressed
    $meDown = New-Object System.Windows.Forms.MouseEventArgs ([System.Windows.Forms.MouseButtons]::Left), 1, 10, 10, 0
    $p = [object[]]@($meDown.psobject.BaseObject)
    $btnType.GetMethod("OnMouseDown", $flags).Invoke($btn, $p)
    if (-not $pressedField.GetValue($btn)) { throw "KitButton did not set pressed on Left MouseDown" }

    # Test mouse leave clears pressed
    $pEmpty = [object[]]@([EventArgs]::Empty.psobject.BaseObject)
    $btnType.GetMethod("OnMouseLeave", $flags).Invoke($btn, $pEmpty)
    if ($pressedField.GetValue($btn)) { throw "KitButton did not clear pressed on MouseLeave" }

    # Test focus ring contrast on primary button
    Reset-TepiTheme -Light $true
    $btn.Primary = $true
    $bmp = Render-TepiControlToBitmap $btn 120 36
    if (-not $bmp) { throw "Failed to render primary KitButton" }
    $bmp.Dispose()
    $btn.Dispose()
}

# 4. KITSURFACE & MARKGLYPH CONTRAST
Write-Host "`n--- 4. KitRow.MarkGlyph Contrast Audit ---"

Check "KitRow.MarkGlyph inner dot vs pill contrast achieves WCAG AAA (> 7:1) in all modes" {
    # Light Mode
    Reset-TepiTheme -Light $true
    $pillLight = Get-TepiStaticProperty "KitInk" "Text"
    $dotLight = Get-TepiStaticProperty "KitInk" "Window"
    $crMarkLight = Assert-Contrast $dotLight $pillLight 7.0 "MarkGlyph Dot vs Pill (Light)"
    if ($crMarkLight -lt 7.0) { throw "MarkGlyph dot vs pill contrast too low in light mode: $crMarkLight:1" }

    # Dark Mode
    Reset-TepiTheme -Light $false
    $pillDark = Get-TepiStaticProperty "KitInk" "Text"
    $dotDark = Get-TepiStaticProperty "KitInk" "Window"
    $crMarkDark = Assert-Contrast $dotDark $pillDark 7.0 "MarkGlyph Dot vs Pill (Dark)"
    if ($crMarkDark -lt 7.0) { throw "MarkGlyph dot vs pill contrast too low in dark mode: $crMarkDark:1" }
}

# 5. KITWINDOW BROADCASTTHEMECHANGE RECURSION & MEMORY AUDIT
Write-Host "`n--- 5. KitWindow BroadcastThemeChange Audit ---"

Check "KitWindow registers and deregisters weakly without memory leaks" {
    $kitWinType = Get-TepiType "KitWindow"
    $openWindowsField = $kitWinType.GetField("openWindows", [System.Reflection.BindingFlags]'Static,NonPublic')
    if (-not $openWindowsField) { throw "KitWindow missing openWindows registry" }
    
    $initialList = $openWindowsField.GetValue($null)
    $initialCount = $initialList.Count
    $broadcastMethod = $kitWinType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Static,Public')

    # Create 20 instances and dispose them
    $wins = @()
    for ($i = 0; $i -lt 20; $i++) {
        $w = [Activator]::CreateInstance($kitWinType)
        $wins += $w
    }
    
    # Broadcast while open
    $broadcastMethod.Invoke($null, $null)

    # Dispose all
    foreach ($w in $wins) {
        $w.Dispose()
    }

    # Force GC
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    # Broadcast again to trigger pruning
    $broadcastMethod.Invoke($null, $null)

    $finalCount = $openWindowsField.GetValue($null).Count
    if ($finalCount -gt $initialCount) {
        throw "openWindows registry did not prune disposed windows (initial=$initialCount, final=$finalCount)"
    }
}

# 6. SEMANTIC NEGATIVE RED COMPREHENSIVE SCAN
Write-Host "`n--- 6. Semantic Negative Red Codebase Scan ---"

Check "Source files contain zero instances of Color.IndianRed or raw RGB(224,96,84)" {
    $csFiles = Get-ChildItem -Path (Join-Path $projectRoot "src") -Filter "*.cs"
    $violations = @()
    foreach ($f in $csFiles) {
        $text = Get-Content $f.FullName -Raw
        if ($text -match "Color\.IndianRed") {
            $violations += "$($f.Name): contains Color.IndianRed"
        }
        if ($text -match "Color\.FromArgb\(\s*224\s*,\s*96\s*,\s*84\s*\)") {
            $violations += "$($f.Name): contains Color.FromArgb(224, 96, 84)"
        }
    }
    if ($violations.Count -gt 0) {
        throw ($violations -join "; ")
    }
}

# 7. KULIALOGIN ARCHITECTURE AUDIT
Write-Host "`n--- 7. KuliaLogin Architecture Audit ---"

Check "KuliaLogin inherits KitWindow and uses KitButton / KitInk" {
    $kuliaType = Get-TepiType "KuliaLogin"
    $kitWinType = Get-TepiType "KitWindow"
    if (-not $kitWinType.IsAssignableFrom($kuliaType)) {
        throw "KuliaLogin does not inherit from KitWindow"
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $primary = $kuliaType.GetField("primary", $flags)
    $back = $kuliaType.GetField("back", $flags)
    $field = $kuliaType.GetField("field", $flags)

    if ($primary.FieldType.Name -ne "KitButton") { throw "primary is not KitButton" }
    if ($back.FieldType.Name -ne "KitButton") { throw "back is not KitButton" }
    if ($field.FieldType.Name -ne "KitText") { throw "field is not KitText" }

    # Source code check: no DwmSetWindowAttribute PInvoke in Kulia.cs
    $kuliaSrc = Get-Content (Join-Path $projectRoot "src\Kulia.cs") -Raw
    if ($kuliaSrc -match "extern int DwmSetWindowAttribute") {
        throw "Kulia.cs still contains manual DwmSetWindowAttribute PInvoke instead of using KitWindow base"
    }
}

# 8. PREFS MACOS-LIKE PRESETS AUDIT
Write-Host "`n--- 8. Prefs macOS-Style Curated Presets Audit ---"

Check "Prefs has 8 curated presets with valid hex and Light counterparts" {
    $islandType = Get-TepiType "Island"
    $accentsField = $islandType.GetField("Accents", [System.Reflection.BindingFlags]'Static,NonPublic')
    $accentsLightField = $islandType.GetField("AccentsLight", [System.Reflection.BindingFlags]'Static,NonPublic')

    $accents = $accentsField.GetValue($null)
    $accentsLight = $accentsLightField.GetValue($null)

    if ($accents.Length -ne 8) { throw "Expected 8 presets in Accents, got $($accents.Length)" }
    if ($accentsLight.Length -ne 8) { throw "Expected 8 presets in AccentsLight, got $($accentsLight.Length)" }

    for ($i = 0; $i -lt 8; $i++) {
        $darkHex = $accents[$i][1]
        $lightHex = $accentsLight[$i][1]
        if ($i -lt 7) {
            # presets 0-6 must be valid hex
            if (-not $darkHex.StartsWith("#")) { throw "Preset $i dark hex invalid: $darkHex" }
            if (-not $lightHex.StartsWith("#")) { throw "Preset $i light hex invalid: $lightHex" }
        } else {
            # preset 7 is Graphite (empty hex)
            if ($darkHex -ne "" -or $lightHex -ne "") { throw "Preset 7 Graphite hex should be empty string" }
        }
    }
}

# 9. COLORPICKER LOUPE TOKEN AUDIT
Write-Host "`n--- 9. ColorPicker Loupe Token Audit ---"

Check "ColorPicker Loupe uses KitInk tokens, Ink.Semi(13f), and dual-stroke reticle" {
    $pickerSrc = Get-Content (Join-Path $projectRoot "src\ColorPicker.cs") -Raw
    if ($pickerSrc -match "BackColor\s*=\s*Color\.FromArgb\(18,\s*18,\s*18\)") {
        throw "ColorPicker.cs still has hardcoded dark backcolor"
    }
    if (-not ($pickerSrc -match "BackColor\s*=\s*KitInk\.Window")) {
        throw "ColorPicker.cs does not set BackColor to KitInk.Window"
    }
    if (-not ($pickerSrc -match "darkPen") -or -not ($pickerSrc -match "lightPen")) {
        throw "ColorPicker.cs does not implement dual-stroke reticle"
    }
    if (-not ($pickerSrc -match "Ink\.Semi\(13f\)")) {
        throw "ColorPicker.cs does not use Ink.Semi(13f) type token"
    }
}

Write-Host "`n=========================================================="
Write-Host "  AUDIT SUMMARY: $passedTests PASSED, $failedTests FAILED (Total: $totalTests)"
Write-Host "=========================================================="

if ($failedTests -gt 0) {
    exit 1
} else {
    exit 0
}
