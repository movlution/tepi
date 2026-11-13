Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$exePath = Resolve-Path "D:\PROJECT\Other\tepi\Tepi.exe"
$asm = [System.Reflection.Assembly]::LoadFrom($exePath)

$inkType = $asm.GetType("Tepi.Ink")
$islandType = $asm.GetType("Tepi.Island")
$toneType = $asm.GetType("Tepi.Tone")

Write-Host "=========================================================="
Write-Host "   FORENSIC INTEGRITY AUDIT TEST SUITE - MILESTONE 1     "
Write-Host "=========================================================="

$failures = 0

function Assert-Check($name, $condition, $details) {
    if ($condition) {
        Write-Host "[PASS] $name : $details" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $name : $details" -ForegroundColor Red
        $global:failures++
    }
}

# -------------------------------------------------------------------
# CHECK 1: Font Resolution and Static Constructor Protection
# -------------------------------------------------------------------
Write-Host "`n--- CHECK 1: Typography Resolution & Static Constructor ---"

$menuFam = $inkType.GetProperty("MenuFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$hero = $inkType.GetProperty("Hero", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$title1 = $inkType.GetProperty("Title1", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$headline = $inkType.GetProperty("Headline", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$caption = $inkType.GetProperty("Caption", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)

Assert-Check "MenuFamily Non-Null" ($menuFam -ne $null -and $menuFam -ne "") "MenuFamily = '$menuFam'"
Assert-Check "Hero Family" ($hero -ne $null) "Hero = '$($hero.FontFamily.Name)'"
Assert-Check "Headline Family" ($headline -ne $null) "Headline = '$($headline.FontFamily.Name)'"
Assert-Check "Caption Family" ($caption -ne $null) "Caption = '$($caption.FontFamily.Name)'"

# Inspect installed font collection for Segoe UI Variable Display Semib
$fc = New-Object System.Drawing.Text.InstalledFontCollection
$haveSegVar = $false
foreach ($f in $fc.Families) {
    if ($f.Name -like "Segoe UI Variable Display*") {
        $haveSegVar = $true
        Write-Host "  Found installed family in GDI collection: $($f.Name)"
    }
}
if ($haveSegVar) {
    Assert-Check "Win11 Segoe UI Variable Display resolved" ($hero.FontFamily.Name -like "*Variable Display*") "Resolved to '$($hero.FontFamily.Name)'"
}

# -------------------------------------------------------------------
# CHECK 2: Light Mode Accent Presets & WCAG AA Contrast Compliance
# -------------------------------------------------------------------
Write-Host "`n--- CHECK 2: Light Mode Accent Presets WCAG Contrast ---"

$paper = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
$contrastMi = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]"Public,Static")
$hexOfMi = $islandType.GetMethod("HexOf", [System.Reflection.BindingFlags]"Public,Static")
$applyMi = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]"Public,Static")
$setAccentMi = $inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]"Public,Static")

$darkAccents = $inkType.GetField("DarkAccents", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$lightAccents = $inkType.GetField("LightAccents", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)

for ($i = 0; $i -ge 0 -and $i -lt $darkAccents.Length; $i++) {
    $name = $darkAccents[$i][0]
    $dHex = $darkAccents[$i][1]
    $lHex = $lightAccents[$i][1]

    if ($dHex -eq "" -or $lHex -eq "") { continue }

    $dColor = [System.Drawing.ColorTranslator]::FromHtml($dHex)

    # Test Ink.Apply mapping in light mode
    $setAccentMi.Invoke($null, @($dHex))
    $applyMi.Invoke($null, @($true))
    $baseTone = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
    $activeAccent = $baseTone.Accent
    $onAccent = $baseTone.OnAccent

    $crAccentPaper = [double]$contrastMi.Invoke($null, @($activeAccent, $paper))
    $crOnAccent = [double]$contrastMi.Invoke($null, @($onAccent, $activeAccent))

    $hexStr = [string]$hexOfMi.Invoke($null, @($activeAccent))
    $onHexStr = [string]$hexOfMi.Invoke($null, @($onAccent))

    Assert-Check "Accent $name Non-Text Contrast (>= 3.5:1)" ($crAccentPaper -ge 3.5) "$hexStr vs #F5F5F5 = $($crAccentPaper.ToString('0.00')):1"
    Assert-Check "Accent $name Text Contrast (>= 4.5:1)" ($crAccentPaper -ge 4.5) "$hexStr vs #F5F5F5 = $($crAccentPaper.ToString('0.00')):1"
    Assert-Check "Accent $name OnAccent Contrast (>= 4.5:1)" ($crOnAccent -ge 4.5) "$onHexStr vs $hexStr = $($crOnAccent.ToString('0.00')):1"
}

# -------------------------------------------------------------------
# CHECK 3: EnforceContrast Convergence & Stress Testing
# -------------------------------------------------------------------
Write-Host "`n--- CHECK 3: EnforceContrast Stress Testing ---"

$enforceMi = $islandType.GetMethod("EnforceContrast", [System.Reflection.BindingFlags]"Public,Static")

# Test 3a: Identical black on black
$cBlack = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
$res3a = $enforceMi.Invoke($null, @($cBlack, $cBlack, 4.5))
$cr3a = [double]$contrastMi.Invoke($null, @($res3a, $cBlack))
Assert-Check "Black-on-Black Convergence" ($cr3a -ge 4.5) "Result $([string]$hexOfMi.Invoke($null, @($res3a))) CR = $($cr3a.ToString('0.00')):1"

# Test 3b: Identical white on white
$cWhite = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$res3b = $enforceMi.Invoke($null, @($cWhite, $cWhite, 4.5))
$cr3b = [double]$contrastMi.Invoke($null, @($res3b, $cWhite))
Assert-Check "White-on-White Convergence" ($cr3b -ge 4.5) "Result $([string]$hexOfMi.Invoke($null, @($res3b))) CR = $($cr3b.ToString('0.00')):1"

# Test 3c: Identical mid-gray on mid-gray
$cGray = [System.Drawing.Color]::FromArgb(255, 128, 128, 128)
$res3c = $enforceMi.Invoke($null, @($cGray, $cGray, 4.5))
$cr3c = [double]$contrastMi.Invoke($null, @($res3c, $cGray))
Assert-Check "Gray-on-Gray Convergence" ($cr3c -ge 4.5) "Result $([string]$hexOfMi.Invoke($null, @($res3c))) CR = $($cr3c.ToString('0.00')):1"

# Test 3d: Impossible contrast demand (minContrast = 25.0)
$res3d = $enforceMi.Invoke($null, @($cGray, $cBlack, 25.0))
$cr3d = [double]$contrastMi.Invoke($null, @($res3d, $cBlack))
Assert-Check "Impossible Contrast Demand Termination" ($res3d.R -eq 255 -and $res3d.G -eq 255 -and $res3d.B -eq 255) "Snapped to White CR = $($cr3d.ToString('0.00')):1"

# Test 3e: Already compliant color (should return unchanged)
$res3e = $enforceMi.Invoke($null, @($cWhite, $cBlack, 4.5))
Assert-Check "Already Compliant Color Preserved" ($res3e.ToArgb() -eq $cWhite.ToArgb()) "Returned identical white"

# -------------------------------------------------------------------
# CHECK 4: DerivePalette Contrast Hierarchy
# -------------------------------------------------------------------
Write-Host "`n--- CHECK 4: DerivePalette Contrast Floor Verification ---"

$deriveMi = $islandType.GetMethod("DerivePalette", [System.Reflection.BindingFlags]"Public,Static")

$testPalettes = @(
    @{ Name = "Standard Dark"; Bg = [System.Drawing.Color]::FromArgb(255, 28, 28, 30); Text = [System.Drawing.Color]::FromArgb(255, 255, 255, 255); Accent = [System.Drawing.Color]::FromArgb(255, 76, 141, 255) },
    @{ Name = "Low Contrast Dark"; Bg = [System.Drawing.Color]::FromArgb(255, 28, 28, 30); Text = [System.Drawing.Color]::FromArgb(255, 42, 42, 46); Accent = [System.Drawing.Color]::FromArgb(255, 51, 51, 51) },
    @{ Name = "Extreme White-on-White"; Bg = [System.Drawing.Color]::FromArgb(255, 255, 255, 255); Text = [System.Drawing.Color]::FromArgb(255, 250, 250, 250); Accent = [System.Drawing.Color]::FromArgb(255, 240, 240, 240) },
    @{ Name = "Extreme Gray-on-Gray"; Bg = [System.Drawing.Color]::FromArgb(255, 127, 127, 127); Text = [System.Drawing.Color]::FromArgb(255, 127, 127, 127); Accent = [System.Drawing.Color]::FromArgb(255, 127, 127, 127) }
)

foreach ($tp in $testPalettes) {
    Write-Host "  Testing Palette Scenario: $($tp.Name)"
    $pal = $deriveMi.Invoke($null, @($tp.Bg, $tp.Text, $tp.Accent))
    $bg = [System.Drawing.ColorTranslator]::FromHtml($pal["bg"])
    $text = [System.Drawing.ColorTranslator]::FromHtml($pal["text"])
    $sub = [System.Drawing.ColorTranslator]::FromHtml($pal["sub"])
    $faint = [System.Drawing.ColorTranslator]::FromHtml($pal["faint"])
    $acc = [System.Drawing.ColorTranslator]::FromHtml($pal["accent"])
    $onAcc = [System.Drawing.ColorTranslator]::FromHtml($pal["onAccent"])

    $crText = [double]$contrastMi.Invoke($null, @($text, $bg))
    $crSub = [double]$contrastMi.Invoke($null, @($sub, $bg))
    $crFaint = [double]$contrastMi.Invoke($null, @($faint, $bg))
    $crAcc = [double]$contrastMi.Invoke($null, @($acc, $bg))
    $crOnAcc = [double]$contrastMi.Invoke($null, @($onAcc, $acc))

    Assert-Check "[$($tp.Name)] Primary Text (>= 4.5:1)" ($crText -ge 4.5) "$($pal['text']) vs $($pal['bg']) = $($crText.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Subtext (>= 4.5:1)" ($crSub -ge 4.5) "$($pal['sub']) vs $($pal['bg']) = $($crSub.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Faint (>= 3.0:1)" ($crFaint -ge 3.0) "$($pal['faint']) vs $($pal['bg']) = $($crFaint.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Accent (>= 3.5:1)" ($crAcc -ge 3.5) "$($pal['accent']) vs $($pal['bg']) = $($crAcc.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] OnAccent (>= 4.5:1)" ($crOnAcc -ge 4.5) "$($pal['onAccent']) vs $($pal['accent']) = $($crOnAcc.ToString('0.00')):1"

    # Card checks
    $cbg = [System.Drawing.ColorTranslator]::FromHtml($pal["card.bg"])
    $ctext = [System.Drawing.ColorTranslator]::FromHtml($pal["card.text"])
    $csub = [System.Drawing.ColorTranslator]::FromHtml($pal["card.sub"])
    $cfaint = [System.Drawing.ColorTranslator]::FromHtml($pal["card.faint"])
    $cacc = [System.Drawing.ColorTranslator]::FromHtml($pal["card.accent"])
    $conAcc = [System.Drawing.ColorTranslator]::FromHtml($pal["card.onAccent"])

    $crCText = [double]$contrastMi.Invoke($null, @($ctext, $cbg))
    $crCSub = [double]$contrastMi.Invoke($null, @($csub, $cbg))
    $crCFaint = [double]$contrastMi.Invoke($null, @($cfaint, $cbg))
    $crCAcc = [double]$contrastMi.Invoke($null, @($cacc, $cbg))
    $crCOnAcc = [double]$contrastMi.Invoke($null, @($conAcc, $cacc))

    Assert-Check "[$($tp.Name)] Card Text (>= 4.5:1)" ($crCText -ge 4.5) "$($pal['card.text']) vs $($pal['card.bg']) = $($crCText.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Card Subtext (>= 4.5:1)" ($crCSub -ge 4.5) "$($pal['card.sub']) vs $($pal['card.bg']) = $($crCSub.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Card Faint (>= 3.0:1)" ($crCFaint -ge 3.0) "$($pal['card.faint']) vs $($pal['card.bg']) = $($crCFaint.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Card Accent (>= 3.5:1)" ($crCAcc -ge 3.5) "$($pal['card.accent']) vs $($pal['card.bg']) = $($crCAcc.ToString('0.00')):1"
    Assert-Check "[$($tp.Name)] Card OnAccent (>= 4.5:1)" ($crCOnAcc -ge 4.5) "$($pal['card.onAccent']) vs $($pal['card.accent']) = $($crCOnAcc.ToString('0.00')):1"
}

# -------------------------------------------------------------------
# CHECK 5: Glass Shader Math & Color Space Accuracy
# -------------------------------------------------------------------
Write-Host "`n--- CHECK 5: Glass Shader Math & Color Space Accuracy ---"

$toSrgbMi = $islandType.GetMethod("ToSrgb", [System.Reflection.BindingFlags]"Public,Static")

# Test 5a: ToSrgb mathematical accuracy vs IEEE reference formula
$maxDelta = 0
$mismatchCount = 0
for ($i = 0; $i -le 4095; $i++) {
    $lin = $i / 4095.0
    $ref = if ($lin -le 0.0031308) { $lin * 12.92 } else { 1.055 * [Math]::Pow($lin, 1.0 / 2.4) - 0.055 }
    $expectedByte = [Math]::Max(0, [Math]::Min(255, [Math]::Round($ref * 255.0)))
    $actualByte = [byte]$toSrgbMi.Invoke($null, @([float]$lin))
    $delta = [Math]::Abs($expectedByte - $actualByte)
    if ($delta -gt $maxDelta) { $maxDelta = $delta }
    if ($delta -gt 1) { $mismatchCount++ }
}
Assert-Check "ToSrgb LUT Precision (maxDelta <= 1)" ($maxDelta -le 1) "Max delta = $maxDelta, delta > 1 count = $mismatchCount"

# Test 5b: ToSrgb boundary conditions
$negVal = [byte]$toSrgbMi.Invoke($null, @([float]-1.5))
$posVal = [byte]$toSrgbMi.Invoke($null, @([float]2.5))
$zeroVal = [byte]$toSrgbMi.Invoke($null, @([float]0.0))
$oneVal = [byte]$toSrgbMi.Invoke($null, @([float]1.0))

Assert-Check "ToSrgb Underflow Clamping" ($negVal -eq 0) "ToSrgb(-1.5) = $negVal"
Assert-Check "ToSrgb Overflow Clamping" ($posVal -eq 255) "ToSrgb(2.5) = $posVal"
Assert-Check "ToSrgb Zero" ($zeroVal -eq 0) "ToSrgb(0.0) = $zeroVal"
Assert-Check "ToSrgb One" ($oneVal -eq 255) "ToSrgb(1.0) = $oneVal"

# Test 5c: ComputeFrostTint via reflection
$miFrostTint = $islandType.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]"NonPublic,Static")
Assert-Check "ComputeFrostTint Method Present" ($miFrostTint -ne $null) "Found method"

if ($miFrostTint -ne $null) {
    # Test on Pure White Wallpaper in Dark Mode
    [byte[]]$whiteSig = New-Object byte[] 64
    for ($i = 0; $i -lt 64; $i++) { $whiteSig[$i] = 255 }
    $darkBg = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
    [object[]]$callArgs1 = @($whiteSig, [int]64, $darkBg, [bool]$false)
    $tintWhiteDark = [float]$miFrostTint.Invoke($null, $callArgs1)
    
    # Calculate surface luminance and text contrast
    $surfByteDark = [Math]::Round(255 * (1 - $tintWhiteDark))
    $surfColorDark = [System.Drawing.Color]::FromArgb(255, $surfByteDark, $surfByteDark, $surfByteDark)
    $crWhiteText = [double]$contrastMi.Invoke($null, @([System.Drawing.Color]::White, $surfColorDark))

    Assert-Check "Frost Tint on White Wall (Dark Mode) >= 0.65" ($tintWhiteDark -ge 0.65) "Tint = $($tintWhiteDark.ToString('0.000'))"
    Assert-Check "White Text on Frost over White Wall (>= 4.5:1)" ($crWhiteText -ge 4.5) "Surface Byte = $surfByteDark, CR = $($crWhiteText.ToString('0.00')):1"

    # Test on Pure Black Wallpaper in Light Mode
    [byte[]]$blackSig = New-Object byte[] 64
    for ($i = 0; $i -lt 64; $i++) { $blackSig[$i] = 0 }
    $lightBg = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
    [object[]]$callArgs2 = @($blackSig, [int]64, $lightBg, [bool]$true)
    $tintBlackLight = [float]$miFrostTint.Invoke($null, $callArgs2)

    # Surface byte = Bg * alpha + Wall * (1 - alpha). With Bg=245, Wall=0: surface byte = 245 * tint
    $surfByteLight = [Math]::Round(245 * $tintBlackLight)
    $surfColorLight = [System.Drawing.Color]::FromArgb(255, $surfByteLight, $surfByteLight, $surfByteLight)
    $crDarkText = [double]$contrastMi.Invoke($null, @([System.Drawing.Color]::FromArgb(255, 17, 17, 17), $surfColorLight))

    Assert-Check "Frost Tint on Black Wall (Light Mode) >= 0.80" ($tintBlackLight -ge 0.80) "Tint = $($tintBlackLight.ToString('0.000'))"
    Assert-Check "Dark Text on Frost over Black Wall (>= 4.5:1)" ($crDarkText -ge 4.5) "Surface Byte = $surfByteLight, CR = $($crDarkText.ToString('0.00')):1"

    # Test on Empty/Null Buffer (Fallback Grace)
    [object[]]$callArgs3 = @($null, [int]0, $darkBg, [bool]$false)
    $tintNull = [float]$miFrostTint.Invoke($null, $callArgs3)
    Assert-Check "Frost Tint Null Buffer Fallback (BaseTint = 0.42)" ([Math]::Abs($tintNull - 0.42) -lt 0.001) "Tint = $tintNull"
}

# -------------------------------------------------------------------
# CHECK 6: Tone.OnGlass() Sub Contrast Guarantee
# -------------------------------------------------------------------
Write-Host "`n--- CHECK 6: Tone.OnGlass() Sub Contrast Guarantee ---"

$baseTone = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$onGlassMi = $toneType.GetMethod("OnGlass", [System.Reflection.BindingFlags]"Public,Instance")
$glassTone = $onGlassMi.Invoke($baseTone, @())

Assert-Check "OnGlass Sub Alpha >= 189" ($glassTone.Sub.A -ge 189) "Sub Alpha = $($glassTone.Sub.A) ($([Math]::Round($glassTone.Sub.A / 255.0 * 100))%)"
Assert-Check "OnGlass Preserves Text" ($glassTone.Text.ToArgb() -eq $baseTone.Text.ToArgb()) "Text preserved"

Write-Host "`n=========================================================="
Write-Host "   AUDIT SUMMARY: $failures failures detected               "
Write-Host "=========================================================="
if ($failures -eq 0) {
    Write-Host "VERDICT: CLEAN - All forensic integrity assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "VERDICT: INTEGRITY VIOLATION - $failures assertion(s) failed." -ForegroundColor Red
    exit 1
}
