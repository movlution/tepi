# Reviewer 2 Independent Verification Script
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function Get-Luminance([System.Drawing.Color]$c) {
    $channels = @($c.R, $c.G, $c.B) | ForEach-Object {
        $s = $_ / 255.0
        if ($s -le 0.03928) { $s / 12.92 } else { [Math]::Pow(($s + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
}

function Get-Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
    $l1 = Get-Luminance $c1
    $l2 = Get-Luminance $c2
    $max = [Math]::Max($l1, $l2)
    $min = [Math]::Min($l1, $l2)
    return ($max + 0.05) / ($min + 0.05)
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "TEST 1: LIGHT ACCENT PRESETS AGAINST PAPER #F5F5F5" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$paper = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
$darkInk = [System.Drawing.Color]::FromArgb(255, 10, 10, 10)
$lightInk = [System.Drawing.Color]::FromArgb(255, 250, 250, 250)

$presets = @(
    @{ Name = "Biru"; Hex = "#1668E8" },
    @{ Name = "Hijau"; Hex = "#107C41" },
    @{ Name = "Kuning"; Hex = "#855E00" },
    @{ Name = "Oranye"; Hex = "#A84B00" },
    @{ Name = "Merah muda"; Hex = "#C2185B" },
    @{ Name = "Ungu"; Hex = "#6C3CE0" },
    @{ Name = "Navy"; Hex = "#4D5F9E" }
)

$allPresetsPass = $true
foreach ($p in $presets) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($p.Hex)
    $crPaper = Get-Contrast $c $paper
    $crDark = Get-Contrast $c $darkInk
    $crLight = Get-Contrast $c $lightInk
    $chosenOnAccent = if ($crDark -ge $crLight) { "darkInk (#0A0A0A)" } else { "lightInk (#FAFAFA)" }
    $onAccentCR = [Math]::Max($crDark, $crLight)

    $passNonText = $crPaper -ge 3.5
    $passText = $crPaper -ge 4.5
    $passOnAccent = $onAccentCR -ge 4.5

    $status = if ($passNonText -and $passText -and $passOnAccent) { "PASS" } else { "FAIL" }
    if ($status -eq "FAIL") { $allPresetsPass = $false }

    Write-Host ("[{0}] {1,-12} ({2}) : vs Paper = {3:F2}:1 (>=3.5 non-text: {4}, >=4.5 text: {5}) | onAccent ({6}) = {7:F2}:1 (>=4.5: {8})" -f `
        $status, $p.Name, $p.Hex, $crPaper, $passNonText, $passText, $chosenOnAccent, $onAccentCR, $passOnAccent)
}
Write-Host "All presets meet >= 3.5:1 non-text and >= 4.5:1 text vs Paper: $allPresetsPass" -ForegroundColor $(if ($allPresetsPass) { "Green" } else { "Red" })

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "TEST 2: SYSTEM INSTALLED FONT FAMILIES (GDI TRUNCATION)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$fc = New-Object System.Drawing.Text.InstalledFontCollection
$segoeVars = $fc.Families | Where-Object { $_.Name -like "*Segoe UI Variable*" }
Write-Host "Segoe UI Variable families found in InstalledFontCollection:"
foreach ($f in $segoeVars) {
    Write-Host ("  Len={0,2}: '{1}'" -f $f.Name.Length, $f.Name)
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "TEST 3: INK REFLECTION VERIFICATION FROM TEPI.EXE" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$tepiPath = Resolve-Path "Tepi.exe"
$asm = [System.Reflection.Assembly]::LoadFrom($tepiPath)
$inkType = $asm.GetType("Tepi.Ink")

# Verify static constructor execution and MenuFamily
$menuFamily = [string]$inkType.GetProperty("MenuFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null, $null)
$iconFamily = [string]$inkType.GetProperty("IconFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null, $null)
Write-Host "MenuFamily: '$menuFamily'"
Write-Host "IconFamily: '$iconFamily'"

# Inspect internal families array
$familiesField = $inkType.GetField("families", [System.Reflection.BindingFlags]"NonPublic,Static")
$families = [string[]]$familiesField.GetValue($null)
$roleNames = @("FDisplay", "FText", "FSemi", "FSmall", "FMono", "FIcons", "FSmallSemi")
for ($i = 0; $i -lt $families.Length; $i++) {
    Write-Host ("  Family[{0}] ({1,-10}): '{2}' (Len={3})" -f $i, $roleNames[$i], $families[$i], $families[$i].Length)
}

# Test font instantiations
$displayFont = $inkType.GetMethod("Display", [System.Reflection.BindingFlags]"Public,Static").Invoke($null, @([float]18.0))
$textFont = $inkType.GetMethod("Text", [System.Reflection.BindingFlags]"Public,Static").Invoke($null, @([float]14.0))
$semiFont = $inkType.GetMethod("Semi", [System.Reflection.BindingFlags]"Public,Static").Invoke($null, @([float]14.0))
Write-Host "Instantiated Display font: Name='$($displayFont.Name)', Size=$($displayFont.Size)"
Write-Host "Instantiated Text font:    Name='$($textFont.Name)', Size=$($textFont.Size)"
Write-Host "Instantiated Semi font:    Name='$($semiFont.Name)', Size=$($semiFont.Size)"

# Test static constructor ordering
$hasStaticCtor = $inkType.TypeInitializer -ne $null
Write-Host "Ink has static constructor (.cctor): $hasStaticCtor" -ForegroundColor $(if ($hasStaticCtor) { "Green" } else { "Red" })

# Test Pick logic simulation
function Pick-Sim([System.Collections.Generic.HashSet[string]]$have, [string[]]$names) {
    foreach ($n in $names) {
        if ($have.Contains($n)) { return $n }
        if ($n.Length -gt 31 -and $have.Contains($n.Substring(0, 31))) { return $n.Substring(0, 31) }
    }
    return "MessageBoxDefault"
}

# Scenario 1: GDI truncated collection
$haveGdi = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$haveGdi.Add("Segoe UI Variable Display Semib") | Out-Null
$haveGdi.Add("Segoe UI Variable Small Semibol") | Out-Null
$haveGdi.Add("Segoe UI Semibold") | Out-Null
$haveGdi.Add("Segoe UI") | Out-Null

$resDisplay = Pick-Sim $haveGdi @("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
$resSmallSemi = Pick-Sim $haveGdi @("Segoe UI Variable Small Semibold", "Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI")
$passPickGdi = ($resDisplay -eq "Segoe UI Variable Display Semib") -and ($resSmallSemi -eq "Segoe UI Variable Small Semibol")
Write-Host "Pick simulation (GDI truncated): $passPickGdi (FDisplay='$resDisplay', FSmallSemi='$resSmallSemi')"

# Scenario 2: Canonical names
$haveCanon = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$haveCanon.Add("Segoe UI Variable Display Semibold") | Out-Null
$haveCanon.Add("Segoe UI Variable Small Semibold") | Out-Null
$resDisplayCanon = Pick-Sim $haveCanon @("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
$passPickCanon = ($resDisplayCanon -eq "Segoe UI Variable Display Semibold")
Write-Host "Pick simulation (Canonical): $passPickCanon ('$resDisplayCanon')"

# Scenario 3: Windows 10 fallback
$haveWin10 = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$haveWin10.Add("Segoe UI Semibold") | Out-Null
$haveWin10.Add("Segoe UI") | Out-Null
$resDisplayWin10 = Pick-Sim $haveWin10 @("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
$passWin10 = ($resDisplayWin10 -eq "Segoe UI Semibold")
Write-Host "Pick simulation (Win10 fallback): $passWin10 ('$resDisplayWin10')"

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "TEST 4: DERIVEPALETTE CONTRAST FLOOR EDGE CASES" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$islandType = $asm.GetType("Tepi.Island")
$deriveMethod = $islandType.GetMethod("DerivePalette", [System.Reflection.BindingFlags]"Public,Static")

function Parse-HexColor([string]$hex) {
    if ($hex.StartsWith("#")) {
        $n = [System.Convert]::ToInt32($hex.Substring(1), 16)
        if ($hex.Length -eq 7) {
            return [System.Drawing.Color]::FromArgb(255, ($n -shr 16) -band 255, ($n -shr 8) -band 255, $n -band 255)
        }
    }
    return [System.Drawing.Color]::Black
}

$edgeCases = @(
    @{ Name = "Pure Black Trio"; Bg = "#000000"; Text = "#000000"; Accent = "#000000" },
    @{ Name = "Pure White Trio"; Bg = "#FFFFFF"; Text = "#FFFFFF"; Accent = "#FFFFFF" },
    @{ Name = "Mid-Gray Trio (L~0.18 minimax)"; Bg = "#7F7F7F"; Text = "#7F7F7F"; Accent = "#7F7F7F" },
    @{ Name = "Near Black Low Contrast"; Bg = "#1C1C1E"; Text = "#202022"; Accent = "#222225" },
    @{ Name = "Near White Low Contrast"; Bg = "#F5F5F5"; Text = "#EFEFEF"; Accent = "#E0E0E0" },
    @{ Name = "Deep Blue on Black"; Bg = "#000000"; Text = "#000022"; Accent = "#000044" },
    @{ Name = "Pale Yellow on White"; Bg = "#FFFFFF"; Text = "#FFFFEE"; Accent = "#FFFFCC" },
    @{ Name = "Pure Gray #808080"; Bg = "#808080"; Text = "#808080"; Accent = "#808080" },
    @{ Name = "Inverted White on Black"; Bg = "#000000"; Text = "#FFFFFF"; Accent = "#3DD68C" },
    @{ Name = "Inverted Black on White"; Bg = "#FFFFFF"; Text = "#000000"; Accent = "#1668E8" },
    @{ Name = "Paper default"; Bg = "#F5F5F5"; Text = "#0C0C0E"; Accent = "#855E00" }
)

$allPalettePass = $true

foreach ($ec in $edgeCases) {
    $cBg = [System.Drawing.ColorTranslator]::FromHtml($ec.Bg)
    $cText = [System.Drawing.ColorTranslator]::FromHtml($ec.Text)
    $cAccent = [System.Drawing.ColorTranslator]::FromHtml($ec.Accent)

    $dict = [System.Collections.Generic.Dictionary[string, string]]$deriveMethod.Invoke($null, @($cBg, $cText, $cAccent))

    $outBg = Parse-HexColor $dict["bg"]
    $outText = Parse-HexColor $dict["text"]
    $outSub = Parse-HexColor $dict["sub"]
    $outFaint = Parse-HexColor $dict["faint"]
    $outAccent = Parse-HexColor $dict["accent"]
    $outOnAccent = Parse-HexColor $dict["onAccent"]

    $outCardBg = Parse-HexColor $dict["card.bg"]
    $outCardText = Parse-HexColor $dict["card.text"]
    $outCardSub = Parse-HexColor $dict["card.sub"]
    $outCardFaint = Parse-HexColor $dict["card.faint"]
    $outCardAccent = Parse-HexColor $dict["card.accent"]
    $outCardOnAccent = Parse-HexColor $dict["card.onAccent"]

    $crText = Get-Contrast $outText $outBg
    $crSub = Get-Contrast $outSub $outBg
    $crFaint = Get-Contrast $outFaint $outBg
    $crAccent = Get-Contrast $outAccent $outBg
    $crOnAccent = Get-Contrast $outOnAccent $outAccent

    $crCardText = Get-Contrast $outCardText $outCardBg
    $crCardSub = Get-Contrast $outCardSub $outCardBg
    $crCardFaint = Get-Contrast $outCardFaint $outCardBg
    $crCardAccent = Get-Contrast $outCardAccent $outCardBg
    $crCardOnAccent = Get-Contrast $outCardOnAccent $outCardAccent

    $passCase = ($crText -ge 4.5) -and ($crSub -ge 4.5) -and ($crFaint -ge 3.0) -and ($crAccent -ge 3.5) -and ($crOnAccent -ge 4.5) -and `
                ($crCardText -ge 4.5) -and ($crCardSub -ge 4.5) -and ($crCardFaint -ge 3.0) -and ($crCardAccent -ge 3.5) -and ($crCardOnAccent -ge 4.5)

    if (-not $passCase) { $allPalettePass = $false }

    $statusStr = if ($passCase) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] {1,-26}: Text={2:F2} Sub={3:F2} Faint={4:F2} Accent={5:F2} OnAccent={6:F2} | Card: Text={7:F2} Sub={8:F2} Faint={9:F2} Accent={10:F2} OnAccent={11:F2}" -f `
        $statusStr, $ec.Name, $crText, $crSub, $crFaint, $crAccent, $crOnAccent, $crCardText, $crCardSub, $crCardFaint, $crCardAccent, $crCardOnAccent)
}

Write-Host "Edge cases palette contrast floors pass: $allPalettePass" -ForegroundColor $(if ($allPalettePass) { "Green" } else { "Red" })

# 50 random adversarial triplets
Write-Host "`nRunning 50 random adversarial color triplets..."
$rand = New-Object System.Random(42)
$randomPass = $true
for ($i = 0; $i -lt 50; $i++) {
    $rBg = [System.Drawing.Color]::FromArgb(255, $rand.Next(256), $rand.Next(256), $rand.Next(256))
    $rText = [System.Drawing.Color]::FromArgb(255, $rand.Next(256), $rand.Next(256), $rand.Next(256))
    $rAccent = [System.Drawing.Color]::FromArgb(255, $rand.Next(256), $rand.Next(256), $rand.Next(256))

    $dict = [System.Collections.Generic.Dictionary[string, string]]$deriveMethod.Invoke($null, @($rBg, $rText, $rAccent))
    $outBg = Parse-HexColor $dict["bg"]
    $outText = Parse-HexColor $dict["text"]
    $outSub = Parse-HexColor $dict["sub"]
    $outFaint = Parse-HexColor $dict["faint"]
    $outAccent = Parse-HexColor $dict["accent"]
    $outOnAccent = Parse-HexColor $dict["onAccent"]
    $outCardBg = Parse-HexColor $dict["card.bg"]
    $outCardText = Parse-HexColor $dict["card.text"]
    $outCardSub = Parse-HexColor $dict["card.sub"]
    $outCardFaint = Parse-HexColor $dict["card.faint"]
    $outCardAccent = Parse-HexColor $dict["card.accent"]
    $outCardOnAccent = Parse-HexColor $dict["card.onAccent"]

    $p1 = (Get-Contrast $outText $outBg) -ge 4.5
    $p2 = (Get-Contrast $outSub $outBg) -ge 4.5
    $p3 = (Get-Contrast $outFaint $outBg) -ge 3.0
    $p4 = (Get-Contrast $outAccent $outBg) -ge 3.5
    $p5 = (Get-Contrast $outOnAccent $outAccent) -ge 4.5
    $p6 = (Get-Contrast $outCardText $outCardBg) -ge 4.5
    $p7 = (Get-Contrast $outCardSub $outCardBg) -ge 4.5
    $p8 = (Get-Contrast $outCardFaint $outCardBg) -ge 3.0
    $p9 = (Get-Contrast $outCardAccent $outCardBg) -ge 3.5
    $p10 = (Get-Contrast $outCardOnAccent $outCardAccent) -ge 4.5

    if (-not ($p1 -and $p2 -and $p3 -and $p4 -and $p5 -and $p6 -and $p7 -and $p8 -and $p9 -and $p10)) {
        $randomPass = $false
        Write-Host ("Failed on random triplet {0}" -f $i) -ForegroundColor Red
        break
    }
}
Write-Host "50/50 Random Adversarial Triplets Passed: $randomPass" -ForegroundColor $(if ($randomPass) { "Green" } else { "Red" })

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "TEST 5: GLASS LINEAR-TO-SRGB LUT PRECISION" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$toSrgbMethod = $islandType.GetMethod("ToSrgb", [System.Reflection.BindingFlags]"Public,NonPublic,Static")
$maxErr = 0
for ($i = 0; $i -le 255; $i++) {
    $s = $i / 255.0
    $lin = if ($s -le 0.04045) { $s / 12.92 } else { [Math]::Pow(($s + 0.055) / 1.055, 2.4) }
    $b = [byte]$toSrgbMethod.Invoke($null, @([float]$lin))
    $diff = [Math]::Abs($b - $i)
    if ($diff -gt $maxErr) { $maxErr = $diff }
}
Write-Host "Max roundtrip byte error across all 256 channels: $maxErr (tolerance <= 1 byte)"
$lutPass = $maxErr -le 1
Write-Host "ToSrgb LUT precision test pass: $lutPass" -ForegroundColor $(if ($lutPass) { "Green" } else { "Red" })
