$commonDir = "d:\PROJECT\Other\tepi\tests\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Write-Host "=== KitButton Focus Ring Contrast Check ==="
foreach ($light in @($true, $false)) {
    Reset-TepiTheme -Light $light
    $modeName = if ($light) { "Light" } else { "Dark" }
    Write-Host "`n--- Mode: $modeName ---"

    $win = Get-TepiStaticProperty "KitInk" "Window"
    $text = Get-TepiStaticProperty "KitInk" "Text"
    $line = Get-TepiStaticProperty "KitInk" "Line"

    $fallbackBlue = if ($light) { [System.Drawing.Color]::FromArgb(255, 22, 104, 232) } else { [System.Drawing.Color]::FromArgb(255, 59, 130, 246) }

    # Secondary button bg: Line
    # Primary button bg: Text
    $secBg = $line
    $primBg = $text

    Write-Host ("Fallback Blue: #{0:X2}{1:X2}{2:X2} (Lum={3:F4})" -f $fallbackBlue.R, $fallbackBlue.G, $fallbackBlue.B, (Get-WcagLuminance $fallbackBlue))
    Write-Host ("  vs Secondary Button Bg (#{0:X2}{1:X2}{2:X2}): Contrast={3:F2}:1 [{4}]" -f `
        $secBg.R, $secBg.G, $secBg.B, (Get-WcagContrastRatio $fallbackBlue $secBg), `
        $(if ((Get-WcagContrastRatio $fallbackBlue $secBg) -ge 3.0) { "PASS (>= 3:1)" } else { "FAIL" }))

    Write-Host ("  vs Primary Button Bg   (#{0:X2}{1:X2}{2:X2}): Contrast={3:F2}:1 [{4}]" -f `
        $primBg.R, $primBg.G, $primBg.B, (Get-WcagContrastRatio $fallbackBlue $primBg), `
        $(if ((Get-WcagContrastRatio $fallbackBlue $primBg) -ge 3.0) { "PASS (>= 3:1)" } else { "FAIL" }))

    Write-Host ("  vs Window Container    (#{0:X2}{1:X2}{2:X2}): Contrast={3:F2}:1 [{4}]" -f `
        $win.R, $win.G, $win.B, (Get-WcagContrastRatio $fallbackBlue $win), `
        $(if ((Get-WcagContrastRatio $fallbackBlue $win) -ge 3.0) { "PASS (>= 3:1)" } else { "FAIL" }))
}
