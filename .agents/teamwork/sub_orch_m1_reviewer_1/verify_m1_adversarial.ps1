Add-Type -AssemblyName System.Drawing
$asmPath = Resolve-Path "D:\PROJECT\Other\tepi\Tepi.exe"
$asm = [System.Reflection.Assembly]::LoadFrom($asmPath)

$inkType = $asm.GetType("Tepi.Ink")
$islandType = $asm.GetType("Tepi.Island")

$contrast = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]"Public,Static")
$hexOf = $islandType.GetMethod("HexOf", [System.Reflection.BindingFlags]"Public,Static")
$enforceContrast = $islandType.GetMethod("EnforceContrast", [System.Reflection.BindingFlags]"Public,Static")
$derivePalette = $islandType.GetMethod("DerivePalette", [System.Reflection.BindingFlags]"Public,Static")
$toSrgb = $islandType.GetMethod("ToSrgb", [System.Reflection.BindingFlags]"Public,Static")
$computeFrostTint = $islandType.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]"NonPublic,Static")
$apply = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]"Public,Static")
$setAccent = $inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]"Public,Static")

$failures = 0
$totalTests = 0

function Assert-Check($name, $condition, $details) {
    $script:totalTests++
    if ($condition) {
        Write-Host "  [PASS] $name ($details)" -ForegroundColor Green
    } else {
        $script:failures++
        Write-Host "  [FAIL] $name ($details)" -ForegroundColor Red
    }
}

Write-Host "=== SECTION 1: FONTS & STATIC INITIALIZATION ==="
$menuFamily = $inkType.GetProperty("MenuFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$iconFamily = $inkType.GetProperty("IconFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$hero = $inkType.GetProperty("Hero", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$title1 = $inkType.GetProperty("Title1", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$headline = $inkType.GetProperty("Headline", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$caption = $inkType.GetProperty("Caption", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)

Assert-Check "MenuFamily initialized" (![string]::IsNullOrEmpty($menuFamily)) "Val: $menuFamily"
Assert-Check "IconFamily initialized" (![string]::IsNullOrEmpty($iconFamily)) "Val: $iconFamily"
Assert-Check "Hero font resolved" ($hero -ne $null -and $hero.FontFamily.Name -ne "") "Val: $($hero.FontFamily.Name)"
Assert-Check "Title1 font resolved" ($title1 -ne $null -and $title1.FontFamily.Name -ne "") "Val: $($title1.FontFamily.Name)"
Assert-Check "Headline font resolved" ($headline -ne $null -and $headline.FontFamily.Name -ne "") "Val: $($headline.FontFamily.Name)"
Assert-Check "Caption font resolved" ($caption -ne $null -and $caption.FontFamily.Name -ne "") "Val: $($caption.FontFamily.Name)"

Write-Host "`n=== SECTION 2: LIGHT ACCENTS WCAG CALIBRATION ==="
$darkAccentsField = $inkType.GetField("DarkAccents", [System.Reflection.BindingFlags]"Public,Static")
$lightAccentsField = $inkType.GetField("LightAccents", [System.Reflection.BindingFlags]"Public,Static")
$darkAccents = $darkAccentsField.GetValue($null)
$lightAccents = $lightAccentsField.GetValue($null)

Assert-Check "Preset count match" ($darkAccents.Length -eq $lightAccents.Length) "Dark: $($darkAccents.Length), Light: $($lightAccents.Length)"

for ($i = 1; $i -lt $darkAccents.Length; $i++) {
    $name = $darkAccents[$i][0]
    $darkHex = $darkAccents[$i][1]
    $lightHex = $lightAccents[$i][1]

    # Test setting dark accent and applying light mode
    $setAccent.Invoke($null, @($darkHex))
    $apply.Invoke($null, @($true))
    $baseTone = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
    $actLightHex = $hexOf.Invoke($null, @($baseTone.Accent))
    $crLightVsPaper = [float]$contrast.Invoke($null, @($baseTone.Accent, $baseTone.Bg))
    $crOnAccent = [float]$contrast.Invoke($null, @($baseTone.OnAccent, $baseTone.Accent))

    Assert-Check "$name Light Hex Mapping" ($actLightHex -eq $lightHex) "Expected: $lightHex, Got: $actLightHex"
    Assert-Check "$name Light Contrast >= 3.5:1" ($crLightVsPaper -ge 3.5) "CR vs Paper: $([math]::Round($crLightVsPaper, 2)):1"
    Assert-Check "$name OnAccent Contrast >= 4.5:1" ($crOnAccent -ge 4.5) "OnAccent CR: $([math]::Round($crOnAccent, 2)):1"

    # Test switching back to dark mode
    $apply.Invoke($null, @($false))
    $baseToneDark = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
    $actDarkHex = $hexOf.Invoke($null, @($baseToneDark.Accent))
    $crDark = [float]$contrast.Invoke($null, @($baseToneDark.Accent, $baseToneDark.Bg))
    Assert-Check "$name Dark Hex Mapping" ($actDarkHex -eq $darkHex) "Expected: $darkHex, Got: $actDarkHex"
    Assert-Check "$name Dark Contrast >= 4.5:1" ($crDark -ge 4.5) "Dark CR: $([math]::Round($crDark, 2)):1"
}

Write-Host "`n=== SECTION 3: ADVERSARIAL ACCENT CORNER CASES ==="
# Test uncalibrated custom low-contrast colors in light mode
$adversarialAccents = @("#FFFF00", "#FFFFAA", "#FFFFFF", "#000000", "#808080", "#123456")
foreach ($hex in $adversarialAccents) {
    $setAccent.Invoke($null, @($hex))
    $apply.Invoke($null, @($true))
    $baseTone = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
    $actHex = $hexOf.Invoke($null, @($baseTone.Accent))
    $cr = [float]$contrast.Invoke($null, @($baseTone.Accent, $baseTone.Bg))
    $onAccCr = [float]$contrast.Invoke($null, @($baseTone.OnAccent, $baseTone.Accent))
    Assert-Check "Custom Accent $hex Guard" ($cr -ge 3.5) "Result: $actHex, CR: $([math]::Round($cr, 2)):1"
    Assert-Check "Custom Accent $hex OnAccent" ($onAccCr -ge 4.5) "OnAccent: $($hexOf.Invoke($null, @($baseTone.OnAccent))), CR: $([math]::Round($onAccCr, 2)):1"
}

Write-Host "`n=== SECTION 4: ADVERSARIAL PALETTE DERIVATION ==="
$extremePalettes = @(
    @{ Name = "Pitch Black on Pitch Black"; Bg = [System.Drawing.Color]::Black; Text = [System.Drawing.Color]::Black; Accent = [System.Drawing.Color]::Black },
    @{ Name = "Pure White on Pure White"; Bg = [System.Drawing.Color]::White; Text = [System.Drawing.Color]::White; Accent = [System.Drawing.Color]::White },
    @{ Name = "Mid Gray on Mid Gray"; Bg = [System.Drawing.Color]::FromArgb(255, 128, 128, 128); Text = [System.Drawing.Color]::FromArgb(255, 128, 128, 128); Accent = [System.Drawing.Color]::FromArgb(255, 128, 128, 128) },
    @{ Name = "Near Threshold Gray"; Bg = [System.Drawing.Color]::FromArgb(255, 118, 118, 118); Text = [System.Drawing.Color]::FromArgb(255, 119, 119, 119); Accent = [System.Drawing.Color]::FromArgb(255, 120, 120, 120) },
    @{ Name = "Neon Yellow on White"; Bg = [System.Drawing.Color]::White; Text = [System.Drawing.Color]::FromArgb(255, 255, 255, 0); Accent = [System.Drawing.Color]::FromArgb(255, 255, 240, 0) },
    @{ Name = "Dark Navy on Black"; Bg = [System.Drawing.Color]::FromArgb(255, 5, 5, 10); Text = [System.Drawing.Color]::FromArgb(255, 10, 15, 25); Accent = [System.Drawing.Color]::FromArgb(255, 12, 18, 30) }
)

foreach ($ep in $extremePalettes) {
    $pal = $derivePalette.Invoke($null, @($ep.Bg, $ep.Text, $ep.Accent))
    $bgCol = [System.Drawing.ColorTranslator]::FromHtml($pal["bg"])
    $textCol = [System.Drawing.ColorTranslator]::FromHtml($pal["text"])
    $subCol = [System.Drawing.ColorTranslator]::FromHtml($pal["sub"])
    $faintCol = [System.Drawing.ColorTranslator]::FromHtml($pal["faint"])
    $accCol = [System.Drawing.ColorTranslator]::FromHtml($pal["accent"])
    $onAccCol = [System.Drawing.ColorTranslator]::FromHtml($pal["onAccent"])

    $crText = [float]$contrast.Invoke($null, @($textCol, $bgCol))
    $crSub = [float]$contrast.Invoke($null, @($subCol, $bgCol))
    $crFaint = [float]$contrast.Invoke($null, @($faintCol, $bgCol))
    $crAcc = [float]$contrast.Invoke($null, @($accCol, $bgCol))
    $crOnAcc = [float]$contrast.Invoke($null, @($onAccCol, $accCol))

    Assert-Check "$($ep.Name): Primary Text >= 4.5:1" ($crText -ge 4.5) "Text: $($pal['text']), CR: $([math]::Round($crText, 2)):1"
    Assert-Check "$($ep.Name): Subtext >= 4.0:1" ($crSub -ge 4.0) "Sub: $($pal['sub']), CR: $([math]::Round($crSub, 2)):1"
    Assert-Check "$($ep.Name): Faint >= 2.8:1" ($crFaint -ge 2.8) "Faint: $($pal['faint']), CR: $([math]::Round($crFaint, 2)):1"
    Assert-Check "$($ep.Name): Accent >= 3.5:1" ($crAcc -ge 3.5) "Accent: $($pal['accent']), CR: $([math]::Round($crAcc, 2)):1"
    Assert-Check "$($ep.Name): OnAccent >= 4.5:1" ($crOnAcc -ge 4.5) "OnAccent: $($pal['onAccent']), CR: $([math]::Round($crOnAcc, 2)):1"

    # Card palette
    $cbgCol = [System.Drawing.ColorTranslator]::FromHtml($pal["card.bg"])
    $ctextCol = [System.Drawing.ColorTranslator]::FromHtml($pal["card.text"])
    $csubCol = [System.Drawing.ColorTranslator]::FromHtml($pal["card.sub"])
    $cfaintCol = [System.Drawing.ColorTranslator]::FromHtml($pal["card.faint"])
    $caccCol = [System.Drawing.ColorTranslator]::FromHtml($pal["card.accent"])
    $conAccCol = [System.Drawing.ColorTranslator]::FromHtml($pal["card.onAccent"])

    $crCText = [float]$contrast.Invoke($null, @($ctextCol, $cbgCol))
    $crCSub = [float]$contrast.Invoke($null, @($csubCol, $cbgCol))
    $crCFaint = [float]$contrast.Invoke($null, @($cfaintCol, $cbgCol))
    $crCAcc = [float]$contrast.Invoke($null, @($caccCol, $cbgCol))
    $crCOnAcc = [float]$contrast.Invoke($null, @($conAccCol, $caccCol))

    Assert-Check "$($ep.Name): Card Text >= 4.5:1" ($crCText -ge 4.5) "CText: $($pal['card.text']), CR: $([math]::Round($crCText, 2)):1"
    Assert-Check "$($ep.Name): Card Sub >= 4.0:1" ($crCSub -ge 4.0) "CSub: $($pal['card.sub']), CR: $([math]::Round($crCSub, 2)):1"
    Assert-Check "$($ep.Name): Card Faint >= 2.8:1" ($crCFaint -ge 2.8) "CFaint: $($pal['card.faint']), CR: $([math]::Round($crCFaint, 2)):1"
    Assert-Check "$($ep.Name): Card Accent >= 3.5:1" ($crCAcc -ge 3.5) "CAccent: $($pal['card.accent']), CR: $([math]::Round($crCAcc, 2)):1"
    Assert-Check "$($ep.Name): Card OnAccent >= 4.5:1" ($crCOnAcc -ge 4.5) "COnAccent: $($pal['card.onAccent']), CR: $([math]::Round($crCOnAcc, 2)):1"
}

Write-Host "`n=== SECTION 5: COLOR SCIENCE & GLASS SHADER MATHEMATICS ==="
# Test ToSrgb out of bounds and precision
Assert-Check "ToSrgb(-1.0) = 0" ([int]$toSrgb.Invoke($null, @([float]-1.0)) -eq 0) "Got: $([int]$toSrgb.Invoke($null, @([float]-1.0)))"
Assert-Check "ToSrgb(2.0) = 255" ([int]$toSrgb.Invoke($null, @([float]2.0)) -eq 255) "Got: $([int]$toSrgb.Invoke($null, @([float]2.0)))"
Assert-Check "ToSrgb(0.0) = 0" ([int]$toSrgb.Invoke($null, @([float]0.0)) -eq 0) "Got: $([int]$toSrgb.Invoke($null, @([float]0.0)))"
Assert-Check "ToSrgb(1.0) = 255" ([int]$toSrgb.Invoke($null, @([float]1.0)) -eq 255) "Got: $([int]$toSrgb.Invoke($null, @([float]1.0)))"

# Test ComputeFrostTint edge conditions
$nullTint = [float]$computeFrostTint.Invoke($null, [object[]]@($null, 0, [System.Drawing.Color]::Black, $false))
Assert-Check "ComputeFrostTint null sig fallback" ([math]::Abs($nullTint - 0.42) -lt 0.001) "Got: $nullTint"

[byte[]]$shortBuffer = New-Object byte[] 10
$zeroLenTint = [float]$computeFrostTint.Invoke($null, [object[]]@($shortBuffer, 2, [System.Drawing.Color]::Black, $false))
Assert-Check "ComputeFrostTint short len fallback" ([math]::Abs($zeroLenTint - 0.42) -lt 0.001) "Got: $zeroLenTint"

# Test adaptive scaling monotonicity: higher wallpaper luminance -> higher or equal tint in dark mode
$lums = @(0.0, 0.2, 0.5, 0.8, 1.0)
$prevTint = 0.4199
foreach ($l in $lums) {
    [byte[]]$wall = New-Object byte[] 400
    $byteVal = [byte][math]::Round($l * 255)
    for ($k = 0; $k -lt 400; $k += 4) { $wall[$k] = $byteVal; $wall[$k+1] = $byteVal; $wall[$k+2] = $byteVal; $wall[$k+3] = 255 }
    $t = [float]$computeFrostTint.Invoke($null, [object[]]@($wall, 400, [System.Drawing.Color]::Black, $false))
    $cond = ($t -ge $prevTint - 0.001) -and ($t -ge 0.4199) -and ($t -le 0.6701)
    Assert-Check "Dark Mode Tint at lum $l" $cond "Tint: $([math]::Round($t, 4)), Prev: $([math]::Round($prevTint, 4))"
    $prevTint = $t
}

# Test adaptive scaling monotonicity: lower wallpaper luminance -> higher or equal tint in light mode
$lumsLight = @(1.0, 0.8, 0.5, 0.2, 0.0)
$prevTintL = 0.4199
foreach ($l in $lumsLight) {
    [byte[]]$wall = New-Object byte[] 400
    $byteVal = [byte][math]::Round($l * 255)
    for ($k = 0; $k -lt 400; $k += 4) { $wall[$k] = $byteVal; $wall[$k+1] = $byteVal; $wall[$k+2] = $byteVal; $wall[$k+3] = 255 }
    $t = [float]$computeFrostTint.Invoke($null, [object[]]@($wall, 400, [System.Drawing.Color]::White, $true))
    $cond = ($t -ge $prevTintL - 0.001) -and ($t -ge 0.4199) -and ($t -le 0.8401)
    Assert-Check "Light Mode Tint at lum $l" $cond "Tint: $([math]::Round($t, 4)), Prev: $([math]::Round($prevTintL, 4))"
    $prevTintL = $t
}

Write-Host "`n=== SUMMARY ==="
Write-Host "Total Tests: $totalTests"
Write-Host "Failures: $failures"
if ($failures -eq 0) {
    Write-Host "ALL VERIFICATIONS PASSED CLEANLY!" -ForegroundColor Green
    Exit 0
} else {
    Write-Host "FAILURES DETECTED: $failures" -ForegroundColor Red
    Exit 1
}
