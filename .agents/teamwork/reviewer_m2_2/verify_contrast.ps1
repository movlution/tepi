$commonDir = "d:\PROJECT\Other\tepi\tests\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Write-Host "========================================================"
Write-Host "INDEPENDENT VISUAL & CONTRAST VERIFICATION (REVIEWER 2)"
Write-Host "========================================================"

# --- 1. KitInk.Faint in Light Mode against surfaces ---
Write-Host "`n[1] KitInk.Faint in Light Mode"
Reset-TepiTheme -Light $true
$faintLight = Get-TepiStaticProperty "KitInk" "Faint"
$lumFaintLight = Get-WcagLuminance $faintLight
Write-Host ("  KitInk.Faint: R={0} G={1} B={2} (Hex=#{0:X2}{1:X2}{2:X2}) Lum={3:F4}" -f $faintLight.R, $faintLight.G, $faintLight.B, $lumFaintLight)

$surfacesLight = [ordered]@{
    "Window" = (Get-TepiStaticProperty "KitInk" "Window")
    "Side"   = (Get-TepiStaticProperty "KitInk" "Side")
    "Group"  = (Get-TepiStaticProperty "KitInk" "Group")
    "Hover"  = (Get-TepiStaticProperty "KitInk" "Hover")
    "Line"   = (Get-TepiStaticProperty "KitInk" "Line")
}

foreach ($name in $surfacesLight.Keys) {
    $s = $surfacesLight[$name]
    $lum = Get-WcagLuminance $s
    $cr = Get-WcagContrastRatio $faintLight $s
    $status = $(if ($cr -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL (< 4.5:1)" })
    Write-Host ("  vs {0,-7}: #{1:X2}{2:X2}{3:X2} Lum={4:F4} -> Contrast={5:F2}:1 [{6}]" -f $name, $s.R, $s.G, $s.B, $lum, $cr, $status)
}

# --- 1b. KitInk.Faint in Dark Mode against surfaces ---
Write-Host "`n[1b] KitInk.Faint in Dark Mode"
Reset-TepiTheme -Light $false
$faintDark = Get-TepiStaticProperty "KitInk" "Faint"
$lumFaintDark = Get-WcagLuminance $faintDark
Write-Host ("  KitInk.Faint: R={0} G={1} B={2} (Hex=#{0:X2}{1:X2}{2:X2}) Lum={3:F4}" -f $faintDark.R, $faintDark.G, $faintDark.B, $lumFaintDark)

$surfacesDark = [ordered]@{
    "Window" = (Get-TepiStaticProperty "KitInk" "Window")
    "Side"   = (Get-TepiStaticProperty "KitInk" "Side")
    "Group"  = (Get-TepiStaticProperty "KitInk" "Group")
    "Hover"  = (Get-TepiStaticProperty "KitInk" "Hover")
    "Line"   = (Get-TepiStaticProperty "KitInk" "Line")
}

foreach ($name in $surfacesDark.Keys) {
    $s = $surfacesDark[$name]
    $lum = Get-WcagLuminance $s
    $cr = Get-WcagContrastRatio $faintDark $s
    $status = $(if ($cr -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL (< 4.5:1)" })
    Write-Host ("  vs {0,-7}: #{1:X2}{2:X2}{3:X2} Lum={4:F4} -> Contrast={5:F2}:1 [{6}]" -f $name, $s.R, $s.G, $s.B, $lum, $cr, $status)
}

# --- 2. MenuLook.Sub in Light Mode & Dark Mode ---
Write-Host "`n[2] MenuLook.Sub Contrast"
$menuLookType = Get-TepiType "MenuLook"
$subProp = $menuLookType.GetProperty("Sub", [System.Reflection.BindingFlags]'NonPublic,Static')
$bgProp  = $menuLookType.GetProperty("Bg", [System.Reflection.BindingFlags]'NonPublic,Static')

Reset-TepiTheme -Light $true
$menuSubLight = $subProp.GetValue($null, $null)
$menuBgLight  = $bgProp.GetValue($null, $null)
$crMenuLight  = Get-WcagContrastRatio $menuSubLight $menuBgLight
$statusML = $(if ($crMenuLight -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL (< 4.5:1)" })
Write-Host ("  Light Mode: Sub=#{0:X2}{1:X2}{2:X2} (Lum={3:F4}) vs Bg=#{4:X2}{5:X2}{6:X2} (Lum={7:F4}) -> Contrast={8:F2}:1 [{9}]" -f `
    $menuSubLight.R, $menuSubLight.G, $menuSubLight.B, (Get-WcagLuminance $menuSubLight), `
    $menuBgLight.R, $menuBgLight.G, $menuBgLight.B, (Get-WcagLuminance $menuBgLight), `
    $crMenuLight, $statusML)

Reset-TepiTheme -Light $false
$menuSubDark = $subProp.GetValue($null, $null)
$menuBgDark  = $bgProp.GetValue($null, $null)
$crMenuDark  = Get-WcagContrastRatio $menuSubDark $menuBgDark
$statusMD = $(if ($crMenuDark -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL (< 4.5:1)" })
Write-Host ("  Dark Mode:  Sub=#{0:X2}{1:X2}{2:X2} (Lum={3:F4}) vs Bg=#{4:X2}{5:X2}{6:X2} (Lum={7:F4}) -> Contrast={8:F2}:1 [{9}]" -f `
    $menuSubDark.R, $menuSubDark.G, $menuSubDark.B, (Get-WcagLuminance $menuSubDark), `
    $menuBgDark.R, $menuBgDark.G, $menuBgDark.B, (Get-WcagLuminance $menuBgDark), `
    $crMenuDark, $statusMD)

# --- 3. Ink.Base.Negative Semantic Token ---
Write-Host "`n[3] Ink.Base.Negative Semantic Token"
Reset-TepiTheme -Light $true
$negLight = (Get-TepiStaticField "Ink" "Base").Negative
$winLight = Get-TepiStaticProperty "KitInk" "Window"
$grpLight = Get-TepiStaticProperty "KitInk" "Group"
$crNegWinLight = Get-WcagContrastRatio $negLight $winLight
$crNegGrpLight = Get-WcagContrastRatio $negLight $grpLight
$statusNWL = $(if ($crNegWinLight -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL" })
$statusNGL = $(if ($crNegGrpLight -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL" })
Write-Host ("  Light Mode: Negative=#{0:X2}{1:X2}{2:X2} (Lum={3:F4})" -f $negLight.R, $negLight.G, $negLight.B, (Get-WcagLuminance $negLight))
Write-Host ("    vs Window: #{0:X2}{1:X2}{2:X2} -> Contrast={3:F2}:1 [{4}]" -f $winLight.R, $winLight.G, $winLight.B, $crNegWinLight, $statusNWL)
Write-Host ("    vs Group:  #{0:X2}{1:X2}{2:X2} -> Contrast={3:F2}:1 [{4}]" -f $grpLight.R, $grpLight.G, $grpLight.B, $crNegGrpLight, $statusNGL)

Reset-TepiTheme -Light $false
$negDark = (Get-TepiStaticField "Ink" "Base").Negative
$winDark = Get-TepiStaticProperty "KitInk" "Window"
$grpDark = Get-TepiStaticProperty "KitInk" "Group"
$crNegWinDark = Get-WcagContrastRatio $negDark $winDark
$crNegGrpDark = Get-WcagContrastRatio $negDark $grpDark
$statusNWD = $(if ($crNegWinDark -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL" })
$statusNGD = $(if ($crNegGrpDark -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL" })
Write-Host ("  Dark Mode:  Negative=#{0:X2}{1:X2}{2:X2} (Lum={3:F4})" -f $negDark.R, $negDark.G, $negDark.B, (Get-WcagLuminance $negDark))
Write-Host ("    vs Window: #{0:X2}{1:X2}{2:X2} -> Contrast={3:F2}:1 [{4}]" -f $winDark.R, $winDark.G, $winDark.B, $crNegWinDark, $statusNWD)
Write-Host ("    vs Group:  #{0:X2}{1:X2}{2:X2} -> Contrast={3:F2}:1 [{4}]" -f $grpDark.R, $grpDark.G, $grpDark.B, $crNegGrpDark, $statusNGD)

# --- 4. KitRow.MarkGlyph Contrast ---
Write-Host "`n[4] KitRow.MarkGlyph Pill & Dot Contrast"
Reset-TepiTheme -Light $true
$pillLight = Get-TepiStaticProperty "KitInk" "Text"
$dotLight  = Get-TepiStaticProperty "KitInk" "Window"
$crGlyphLight = Get-WcagContrastRatio $pillLight $dotLight
$statusGL = $(if ($crGlyphLight -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL" })
Write-Host ("  Light Mode: Pill=#{0:X2}{1:X2}{2:X2} vs Dot=#{3:X2}{4:X2}{5:X2} -> Contrast={6:F2}:1 [{7}]" -f `
    $pillLight.R, $pillLight.G, $pillLight.B, $dotLight.R, $dotLight.G, $dotLight.B, $crGlyphLight, $statusGL)

Reset-TepiTheme -Light $false
$pillDark = Get-TepiStaticProperty "KitInk" "Text"
$dotDark  = Get-TepiStaticProperty "KitInk" "Window"
$crGlyphDark = Get-WcagContrastRatio $pillDark $dotDark
$statusGD = $(if ($crGlyphDark -ge 4.5) { "PASS (>= 4.5:1)" } else { "FAIL" })
Write-Host ("  Dark Mode:  Pill=#{0:X2}{1:X2}{2:X2} vs Dot=#{3:X2}{4:X2}{5:X2} -> Contrast={6:F2}:1 [{7}]" -f `
    $pillDark.R, $pillDark.G, $pillDark.B, $dotDark.R, $dotDark.G, $dotDark.B, $crGlyphDark, $statusGD)

# --- 5. KitSlider Disabled Thumb Contrast ---
Write-Host "`n[5] KitSlider Disabled Thumb Contrast"
Reset-TepiTheme -Light $true
$disLight = Get-TepiStaticProperty "KitInk" "Disabled"
$winLight = Get-TepiStaticProperty "KitInk" "Window"
$lineLight = Get-TepiStaticProperty "KitInk" "Line"
Write-Host ("  Light Mode: Disabled=#{0:X2}{1:X2}{2:X2} (Lum={3:F4})" -f $disLight.R, $disLight.G, $disLight.B, (Get-WcagLuminance $disLight))
Write-Host ("    vs Window:       Contrast={0:F2}:1" -f (Get-WcagContrastRatio $disLight $winLight))
Write-Host ("    vs Line (track): Contrast={0:F2}:1" -f (Get-WcagContrastRatio $disLight $lineLight))

Reset-TepiTheme -Light $false
$disDark = Get-TepiStaticProperty "KitInk" "Disabled"
$winDark = Get-TepiStaticProperty "KitInk" "Window"
$lineDark = Get-TepiStaticProperty "KitInk" "Line"
Write-Host ("  Dark Mode:  Disabled=#{0:X2}{1:X2}{2:X2} (Lum={3:F4})" -f $disDark.R, $disDark.G, $disDark.B, (Get-WcagLuminance $disDark))
Write-Host ("    vs Window:       Contrast={0:F2}:1" -f (Get-WcagContrastRatio $disDark $winDark))
Write-Host ("    vs Line (track): Contrast={0:F2}:1" -f (Get-WcagContrastRatio $disDark $lineDark))
