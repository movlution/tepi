$commonDir = "D:\PROJECT\Other\tepi\tests\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

$asm = Initialize-TepiLoader
$inkType = Get-TepiType "Ink"
$toneType = Get-TepiType "Tone"

function Lum([System.Drawing.Color]$c) {
    $r = $c.R / 255.0
    $g = $c.G / 255.0
    $b = $c.B / 255.0
    $r = if ($r -le 0.03928) { $r / 12.92 } else { [Math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $g = if ($g -le 0.03928) { $g / 12.92 } else { [Math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $b = if ($b -le 0.03928) { $b / 12.92 } else { [Math]::Pow(($b + 0.055) / 1.055, 2.4) }
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
    $l1 = Lum $c1
    $l2 = Lum $c2
    if ($l1 -lt $l2) { $tmp = $l1; $l1 = $l2; $l2 = $tmp }
    return ($l1 + 0.05) / ($l2 + 0.05)
}

function Blend([System.Drawing.Color]$fg, [System.Drawing.Color]$bg) {
    $a = $fg.A / 255.0
    $r = [int]($fg.R * $a + $bg.R * (1 - $a))
    $g = [int]($fg.G * $a + $bg.G * (1 - $a))
    $b = [int]($fg.B * $a + $bg.B * (1 - $a))
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

$applyMethod = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static')
$darkMethod = $toneType.GetMethod("Dark", [System.Reflection.BindingFlags]'Public,Static')
$paperMethod = $toneType.GetMethod("Paper", [System.Reflection.BindingFlags]'Public,Static')

Write-Host "=== Dark Mode Tests ==="
$applyMethod.Invoke($null, @($false))
$dark = $darkMethod.Invoke($null, @())
$badgeDark = $dark.Negative
$isDarkProp = $toneType.GetProperty("IsDark")
$isDarkVal = $isDarkProp.GetValue($dark)
$textDark = if ($isDarkVal) { $dark.Bg } else { [System.Drawing.Color]::White }
$badgeTextContrastDark = Contrast $textDark $badgeDark
$badgeSurfaceContrastDark = Contrast $badgeDark $dark.Bg

Write-Host ("Badge Text vs Badge Dark: {0:F2}:1 (Text: {1} on Badge: {2})" -f $badgeTextContrastDark, $textDark, $badgeDark)
Write-Host ("Badge Dark vs Surface: {0:F2}:1" -f $badgeSurfaceContrastDark)
Write-Host ("Passes WCAG AA (>=4.5): " + ($badgeTextContrastDark -ge 4.5 -and $badgeSurfaceContrastDark -ge 4.5))

Write-Host "`n=== Light Mode Tests ==="
$applyMethod.Invoke($null, @($true))
$light = $paperMethod.Invoke($null, @())
$badgeLight = $light.Negative
$isDarkLightVal = $isDarkProp.GetValue($light)
$textLight = if ($isDarkLightVal) { $light.Bg } else { [System.Drawing.Color]::White }
$badgeTextContrastLight = Contrast $textLight $badgeLight
$badgeSurfaceContrastLight = Contrast $badgeLight $light.Bg

Write-Host ("Badge Text vs Badge Light: {0:F2}:1 (Text: {1} on Badge: {2})" -f $badgeTextContrastLight, $textLight, $badgeLight)
Write-Host ("Badge Light vs Surface: {0:F2}:1" -f $badgeSurfaceContrastLight)
Write-Host ("Passes WCAG AA (>=4.5): " + ($badgeTextContrastLight -ge 4.5 -and $badgeSurfaceContrastLight -ge 4.5))

Write-Host "`n=== DockCard Close Button Glyph Contrast ==="
# Close button hover background: p.T.Negative
# Glyph: hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub
$closeDarkGlyph = if ($isDarkVal) { $dark.Bg } else { [System.Drawing.Color]::White }
$closeDarkContrast = Contrast $closeDarkGlyph $dark.Negative
Write-Host ("DockCard Close Glyph vs Negative (Dark): {0:F2}:1 (Pass >=4.5: {1})" -f $closeDarkContrast, ($closeDarkContrast -ge 4.5))

$closeLightGlyph = if ($isDarkLightVal) { $light.Bg } else { [System.Drawing.Color]::White }
$closeLightContrast = Contrast $closeLightGlyph $light.Negative
Write-Host ("DockCard Close Glyph vs Negative (Light): {0:F2}:1 (Pass >=4.5: {1})" -f $closeLightContrast, ($closeLightContrast -ge 4.5))

Write-Host "`n=== Mini Indicator Salience & Contrast ==="
$blackBezel = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
$darkBezel = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
$lightBezel = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)

foreach ($mode in @("Dark", "Light")) {
    $t = if ($mode -eq "Dark") { $dark } else { $light }
    Write-Host ("--- Mini in {0} Mode ---" -f $mode)
    $effTrackBlack = Blend $t.Faint $blackBezel
    $effTrackDark = Blend $t.Faint $darkBezel
    $effTrackLight = Blend $t.Faint $lightBezel
    
    $cTrackBlack = Contrast $effTrackBlack $blackBezel
    $cTrackDark = Contrast $effTrackDark $darkBezel
    $cTrackLight = Contrast $effTrackLight $lightBezel
    Write-Host ("Track (Faint) on Black Monitor: {0:F2}:1 (Pass >=3.0: {1})" -f $cTrackBlack, ($cTrackBlack -ge 3.0))
    Write-Host ("Track (Faint) on Dark Grey Monitor: {0:F2}:1 (Pass >=3.0: {1})" -f $cTrackDark, ($cTrackDark -ge 3.0))
    Write-Host ("Track (Faint) on Light Monitor: {0:F2}:1 (Pass >=3.0: {1})" -f $cTrackLight, ($cTrackLight -ge 3.0))

    $cDotNegativeBlack = Contrast $t.Negative $blackBezel
    $cDotNegativeLight = Contrast $t.Negative $lightBezel
    Write-Host ("Dot (Negative) on Black Monitor: {0:F2}:1 (Pass >=3.0: {1})" -f $cDotNegativeBlack, ($cDotNegativeBlack -ge 3.0))
    Write-Host ("Dot (Negative) on Light Monitor: {0:F2}:1 (Pass >=3.0: {1})" -f $cDotNegativeLight, ($cDotNegativeLight -ge 3.0))
}
