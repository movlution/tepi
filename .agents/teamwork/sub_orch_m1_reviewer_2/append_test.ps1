# Append Test 4 to test_reviewer_2.ps1
$testCode = @'

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

# Now run 50 random adversarial triplets
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
        Write-Host "Failed on random triplet $i: Bg=$($dict['bg']) Text=$($dict['text']) Accent=$($dict['accent'])" -ForegroundColor Red
        break
    }
}
Write-Host "50/50 Random Adversarial Triplets Passed: $randomPass" -ForegroundColor $(if ($randomPass) { "Green" } else { "Red" })
'@

Add-Content -Path "d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1_reviewer_2\test_reviewer_2.ps1" -Value $testCode
