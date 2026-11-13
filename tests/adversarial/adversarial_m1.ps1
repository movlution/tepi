# adversarial_m1.ps1
# Milestone 1 Adversarial Stress Harness for Colors.DerivePalette and Ink.Apply
# Tests pathological inputs: identical colors (#808080), low contrast darks (#202020/#242424),
# extreme pastels, zero luminance, and random color fuzzing.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Adversarial Suite M1: Colors.DerivePalette & Ink.Apply Stress Testing" {

    $islandType = Get-TepiType "Island"
    $inkType = Get-TepiType "Ink"
    $toneType = Get-TepiType "Tone"

    $deriveMethod = $islandType.GetMethod("DerivePalette", [System.Reflection.BindingFlags]'Public,Static')
    $contrastMethod = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]'Public,Static')
    $enforceContrastMethod = $islandType.GetMethod("EnforceContrast", [System.Reflection.BindingFlags]'Public,Static')
    $applyMethod = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static', $null, @([bool]), $null)
    $setAccentMethod = $inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]'Public,Static')

    $dictType = [System.Type]::GetType("System.Collections.Generic.Dictionary``2[[System.String],[System.String]]")
    $setPackMethod = $inkType.GetMethod("SetPack", [System.Reflection.BindingFlags]'Public,Static', $null, @($dictType), $null)

    $baseField = $inkType.GetField("Base", [System.Reflection.BindingFlags]'Public,Static')
    $flipField = $inkType.GetField("Flip", [System.Reflection.BindingFlags]'Public,Static')

    function Get-Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
        return [double]$contrastMethod.Invoke($null, @($c1, $c2))
    }

    function Parse-Hex([string]$hex) {
        return [System.Drawing.ColorTranslator]::FromHtml($hex)
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 1: Identical Colors #808080 for All Inputs
    # -------------------------------------------------------------
    It "P01: Stress-tests identical middle grey (#808080 for bg, text, accent)" {
        $gray = [System.Drawing.Color]::FromArgb(255, 128, 128, 128)
        $pal = $deriveMethod.Invoke($null, @($gray, $gray, $gray))
        Assert-NotNull $pal "Palette must be generated for identical #808080"

        $bg = Parse-Hex $pal["bg"]
        $text = Parse-Hex $pal["text"]
        $sub = Parse-Hex $pal["sub"]
        $faint = Parse-Hex $pal["faint"]
        $accent = Parse-Hex $pal["accent"]
        $onAccent = Parse-Hex $pal["onAccent"]

        $cText = Get-Contrast $text $bg
        $cSub = Get-Contrast $sub $bg
        $cFaint = Get-Contrast $faint $bg
        $cAccent = Get-Contrast $accent $bg
        $cOnAccent = Get-Contrast $onAccent $accent

        Write-Host "  P01 [Identical #808080]: text=$($pal['text']) (CR=$([math]::Round($cText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($cSub, 2))), faint=$($pal['faint']) (CR=$([math]::Round($cFaint, 2))), accent=$($pal['accent']) (CR=$([math]::Round($cAccent, 2))), onAccent=$($pal['onAccent']) (CR=$([math]::Round($cOnAccent, 2)))" -ForegroundColor Cyan

        Assert-True ($cText -ge 4.5) "Text contrast against #808080 must be >= 4.5:1 (actual: $cText)"
        Assert-True ($cSub -ge 4.5) "Subtext contrast against #808080 must be >= 4.5:1 (actual: $cSub)"
        Assert-True ($cFaint -ge 3.0) "Faint contrast against #808080 must be >= 3.0:1 (actual: $cFaint)"
        Assert-True ($cAccent -ge 3.5) "Accent contrast against #808080 must be >= 3.5:1 (actual: $cAccent)"
        Assert-True ($cOnAccent -ge 4.5) "OnAccent contrast against accent must be >= 4.5:1 (actual: $cOnAccent)"

        # Card palette checks
        $cardBg = Parse-Hex $pal["card.bg"]
        $cardText = Parse-Hex $pal["card.text"]
        $cardSub = Parse-Hex $pal["card.sub"]
        $cCardText = Get-Contrast $cardText $cardBg
        $cCardSub = Get-Contrast $cardSub $cardBg
        Assert-True ($cCardText -ge 4.5) "Card text contrast against card.bg must be >= 4.5:1 (actual: $cCardText)"
        Assert-True ($cCardSub -ge 4.5) "Card sub contrast against card.bg must be >= 4.5:1 (actual: $cCardSub)"
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 2: Low-Contrast Darks (#202020 and #242424)
    # -------------------------------------------------------------
    It "P02: Stress-tests low-contrast dark inputs (#202020 bg, #242424 text, #222222 accent)" {
        $bg = Parse-Hex "#202020"
        $textIn = Parse-Hex "#242424"
        $accentIn = Parse-Hex "#222222"

        $pal = $deriveMethod.Invoke($null, @($bg, $textIn, $accentIn))
        Assert-NotNull $pal "Palette must be generated for low-contrast darks"

        $outBg = Parse-Hex $pal["bg"]
        $outText = Parse-Hex $pal["text"]
        $outSub = Parse-Hex $pal["sub"]
        $outFaint = Parse-Hex $pal["faint"]
        $outAccent = Parse-Hex $pal["accent"]
        $outOnAccent = Parse-Hex $pal["onAccent"]

        $cText = Get-Contrast $outText $outBg
        $cSub = Get-Contrast $outSub $outBg
        $cFaint = Get-Contrast $outFaint $outBg
        $cAccent = Get-Contrast $outAccent $outBg
        $cOnAccent = Get-Contrast $outOnAccent $outAccent

        Write-Host "  P02 [Low Dark #202020]: text=$($pal['text']) (CR=$([math]::Round($cText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($cSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($cAccent, 2)))" -ForegroundColor Cyan

        Assert-True ($cText -ge 7.0) "Text contrast must meet 7.0:1 floor for dark background (actual: $cText)"
        Assert-True ($cSub -ge 4.5) "Subtext contrast must meet 4.5:1 floor (actual: $cSub)"
        Assert-True ($cFaint -ge 3.0) "Faint contrast must meet 3.0:1 floor (actual: $cFaint)"
        Assert-True ($cAccent -ge 3.5) "Accent contrast must meet 3.5:1 floor (actual: $cAccent)"
        Assert-True ($cOnAccent -ge 4.5) "OnAccent contrast must meet 4.5:1 floor (actual: $cOnAccent)"
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 3: Zero Luminance (#000000 for All Inputs)
    # -------------------------------------------------------------
    It "P03: Stress-tests zero luminance (#000000 bg, #000000 text, #000000 accent)" {
        $black = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
        $pal = $deriveMethod.Invoke($null, @($black, $black, $black))
        Assert-NotNull $pal "Palette must be generated for pure black"

        $outBg = Parse-Hex $pal["bg"]
        $outText = Parse-Hex $pal["text"]
        $outSub = Parse-Hex $pal["sub"]
        $outFaint = Parse-Hex $pal["faint"]
        $outAccent = Parse-Hex $pal["accent"]
        $outOnAccent = Parse-Hex $pal["onAccent"]

        $cText = Get-Contrast $outText $outBg
        $cSub = Get-Contrast $outSub $outBg
        $cFaint = Get-Contrast $outFaint $outBg
        $cAccent = Get-Contrast $outAccent $outBg
        $cOnAccent = Get-Contrast $outOnAccent $outAccent

        Write-Host "  P03 [Zero Lum #000000]: text=$($pal['text']) (CR=$([math]::Round($cText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($cSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($cAccent, 2)))" -ForegroundColor Cyan

        Assert-True ($cText -ge 7.0) "Text contrast on #000000 must reach >= 7.0:1 (actual: $cText)"
        Assert-True ($cSub -ge 4.5) "Subtext contrast on #000000 must reach >= 4.5:1 (actual: $cSub)"
        Assert-True ($cFaint -ge 3.0) "Faint contrast on #000000 must reach >= 3.0:1 (actual: $cFaint)"
        Assert-True ($cAccent -ge 3.5) "Accent contrast on #000000 must reach >= 3.5:1 (actual: $cAccent)"
        Assert-True ($cOnAccent -ge 4.5) "OnAccent contrast must reach >= 4.5:1 (actual: $cOnAccent)"
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 4: Extreme Pastels on Light Backgrounds
    # -------------------------------------------------------------
    It "P04: Stress-tests extreme pastels against light backgrounds (#FFFDD0 cream, #FFFFE0 light yellow)" {
        $bg = Parse-Hex "#FFFFFF"
        $pastel1 = Parse-Hex "#FFFDD0" # Cream
        $pastel2 = Parse-Hex "#FFFFE0" # Light yellow
        $pastel3 = Parse-Hex "#E6E6FA" # Lavender

        $testCases = @(
            @{ Name = "Cream"; Text = $pastel1; Accent = $pastel2 },
            @{ Name = "LightYellow"; Text = $pastel2; Accent = $pastel3 },
            @{ Name = "Lavender"; Text = $pastel3; Accent = $pastel1 }
        )

        foreach ($tc in $testCases) {
            $pal = $deriveMethod.Invoke($null, @($bg, $tc.Text, $tc.Accent))
            $outText = Parse-Hex $pal["text"]
            $outSub = Parse-Hex $pal["sub"]
            $outFaint = Parse-Hex $pal["faint"]
            $outAccent = Parse-Hex $pal["accent"]
            $outOnAccent = Parse-Hex $pal["onAccent"]

            $cText = Get-Contrast $outText $bg
            $cSub = Get-Contrast $outSub $bg
            $cFaint = Get-Contrast $outFaint $bg
            $cAccent = Get-Contrast $outAccent $bg
            $cOnAccent = Get-Contrast $outOnAccent $outAccent

            Write-Host "  P04 [Pastel $($tc.Name)]: text=$($pal['text']) (CR=$([math]::Round($cText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($cSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($cAccent, 2)))" -ForegroundColor Cyan

            Assert-True ($cText -ge 7.0) "Pastel text on white must enforce >= 7.0:1 (actual: $cText)"
            Assert-True ($cSub -ge 4.5) "Pastel sub on white must enforce >= 4.5:1 (actual: $cSub)"
            Assert-True ($cFaint -ge 3.0) "Pastel faint on white must enforce >= 3.0:1 (actual: $cFaint)"
            Assert-True ($cAccent -ge 3.5) "Pastel accent on white must enforce >= 3.5:1 (actual: $cAccent)"
            Assert-True ($cOnAccent -ge 4.5) "OnAccent on pastel accent must enforce >= 4.5:1 (actual: $cOnAccent)"
        }
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 5: Worst-Case Luminance Backgrounds (L ~ 0.179)
    # -------------------------------------------------------------
    It "P05: Stress-tests worst-case background luminance (#757575, #767676, #777777)" {
        $worstHaxes = @("#757575", "#767676", "#777777", "#787878")
        foreach ($hex in $worstHaxes) {
            $bg = Parse-Hex $hex
            $pal = $deriveMethod.Invoke($null, @($bg, $bg, $bg))

            $outText = Parse-Hex $pal["text"]
            $outSub = Parse-Hex $pal["sub"]
            $outFaint = Parse-Hex $pal["faint"]
            $outAccent = Parse-Hex $pal["accent"]
            $outOnAccent = Parse-Hex $pal["onAccent"]

            $cText = Get-Contrast $outText $bg
            $cSub = Get-Contrast $outSub $bg
            $cFaint = Get-Contrast $outFaint $bg
            $cAccent = Get-Contrast $outAccent $bg
            $cOnAccent = Get-Contrast $outOnAccent $outAccent

            Write-Host "  P05 [Worst-Case $hex]: text=$($pal['text']) (CR=$([math]::Round($cText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($cSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($cAccent, 2)))" -ForegroundColor Cyan

            Assert-True ($cText -ge 4.5) "Worst-case bg $hex text must achieve >= 4.5:1 (actual: $cText)"
            Assert-True ($cSub -ge 4.5) "Worst-case bg $hex sub must achieve >= 4.5:1 (actual: $cSub)"
            Assert-True ($cFaint -ge 3.0) "Worst-case bg $hex faint must achieve >= 3.0:1 (actual: $cFaint)"
            Assert-True ($cAccent -ge 3.5) "Worst-case bg $hex accent must achieve >= 3.5:1 (actual: $cAccent)"
            Assert-True ($cOnAccent -ge 4.5) "Worst-case bg $hex onAccent must achieve >= 4.5:1 (actual: $cOnAccent)"
        }
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 6: Ink.Apply Presets and Contrast Guarantees
    # -------------------------------------------------------------
    It "P06: Verifies Ink.Apply calibrated presets in both Light and Dark modes" {
        $darkAccentsField = $inkType.GetField("DarkAccents", [System.Reflection.BindingFlags]'Public,Static')
        $darkAccents = $darkAccentsField.GetValue($null)

        foreach ($item in $darkAccents) {
            $name = $item[0]
            $hex = $item[1]
            if ([string]::IsNullOrEmpty($hex)) { continue }

            $setAccentMethod.Invoke($null, @($hex))

            # 1. Test Light Mode
            $applyMethod.Invoke($null, @($true))
            $baseTone = $baseField.GetValue($null)
            $paperBg = $baseTone.Bg
            $accentLight = $baseTone.Accent
            $onAccentLight = $baseTone.OnAccent
            $textLight = $baseTone.Text
            $subLight = $baseTone.Sub

            $crAccentLight = Get-Contrast $accentLight $paperBg
            $crOnAccentLight = Get-Contrast $onAccentLight $accentLight
            $crTextLight = Get-Contrast $textLight $paperBg
            $crSubLight = Get-Contrast $subLight $paperBg

            Write-Host "  P06 [Preset $name Light]: Accent=$([System.Drawing.ColorTranslator]::ToHtml($accentLight)) (CR=$([math]::Round($crAccentLight, 2))), OnAccent=$([System.Drawing.ColorTranslator]::ToHtml($onAccentLight)) (CR=$([math]::Round($crOnAccentLight, 2)))" -ForegroundColor Green

            Assert-True ($crAccentLight -ge 3.5) "Light mode preset $name accent must achieve >= 3.5:1 against paper bg (actual: $crAccentLight)"
            Assert-True ($crOnAccentLight -ge 4.5) "Light mode preset $name onAccent must achieve >= 4.5:1 against accent (actual: $crOnAccentLight)"
            Assert-True ($crTextLight -ge 7.0) "Light mode preset $name text must achieve >= 7.0:1 (actual: $crTextLight)"

            # 2. Test Dark Mode
            $applyMethod.Invoke($null, @($false))
            $baseToneDark = $baseField.GetValue($null)
            $darkBg = $baseToneDark.Bg
            $accentDark = $baseToneDark.Accent
            $onAccentDark = $baseToneDark.OnAccent

            $crAccentDark = Get-Contrast $accentDark $darkBg
            $crOnAccentDark = Get-Contrast $onAccentDark $accentDark

            Write-Host "  P06 [Preset $name Dark]: Accent=$([System.Drawing.ColorTranslator]::ToHtml($accentDark)) (CR=$([math]::Round($crAccentDark, 2))), OnAccent=$([System.Drawing.ColorTranslator]::ToHtml($onAccentDark)) (CR=$([math]::Round($crOnAccentDark, 2)))" -ForegroundColor Green

            Assert-True ($crAccentDark -ge 4.5) "Dark mode preset $name accent must achieve >= 4.5:1 against dark bg (actual: $crAccentDark)"
            Assert-True ($crOnAccentDark -ge 4.5) "Dark mode preset $name onAccent must achieve >= 4.5:1 against accent (actual: $crOnAccentDark)"
        }
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 7: Ink.SetAccent Arbitrary & Extreme Inputs
    # -------------------------------------------------------------
    It "P07: Stress-tests Ink.SetAccent with arbitrary and adversarial inputs in Light Mode" {
        $adversarialAccents = @(
            "#FFFFFF", # Pure white
            "#F5F5F5", # Same as Paper bg
            "#FFFF00", # Pure yellow
            "#00FF00", # Pure green
            "#00FFFF", # Pure cyan (clamps to #008585, testing 4.5:1 dead-zone)
            "#000000", # Pure black
            "#111111", # Near black
            "#808080"  # Mid gray
        )

        foreach ($hex in $adversarialAccents) {
            $setAccentMethod.Invoke($null, @($hex))
            $applyMethod.Invoke($null, @($true))

            $baseTone = $baseField.GetValue($null)
            $paperBg = $baseTone.Bg
            $accent = $baseTone.Accent
            $onAccent = $baseTone.OnAccent

            $crAccent = Get-Contrast $accent $paperBg
            $crOnAccent = Get-Contrast $onAccent $accent

            Write-Host "  P07 [Custom Accent $hex Light]: Final Accent=$([System.Drawing.ColorTranslator]::ToHtml($accent)) (CR=$([math]::Round($crAccent, 2))), OnAccent=$([System.Drawing.ColorTranslator]::ToHtml($onAccent)) (CR=$([math]::Round($crOnAccent, 2)))" -ForegroundColor Yellow

            Assert-True ($crAccent -ge 3.5) "Custom accent $hex in light mode must enforce >= 3.5:1 against paper bg (actual: $crAccent)"
            Assert-True ($crOnAccent -ge 4.5) "OnAccent on custom accent $hex must achieve >= 4.5:1 (actual: $crOnAccent)"
        }
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 8: Tone.OnGlass Contract Verification
    # -------------------------------------------------------------
    It "P08: Verifies Tone.OnGlass contract (Sub alpha >= 189)" {
        $onGlassMethod = $toneType.GetMethod("OnGlass", [System.Reflection.BindingFlags]'Public,Instance')

        $applyMethod.Invoke($null, @($false))
        $baseTone = $baseField.GetValue($null)
        $glassTone = $onGlassMethod.Invoke($baseTone, $null)

        $subAlpha = [int]$glassTone.Sub.A
        Write-Host "  P08 [Tone.OnGlass Dark Mode]: Sub Alpha = $subAlpha (Required >= 189)" -ForegroundColor Cyan
        Assert-True ($subAlpha -ge 189) "Tone.OnGlass Sub.A must be >= 189 (actual: $subAlpha)"

        $applyMethod.Invoke($null, @($true))
        $baseToneLight = $baseField.GetValue($null)
        $glassToneLight = $onGlassMethod.Invoke($baseToneLight, $null)

        $subAlphaLight = [int]$glassToneLight.Sub.A
        Write-Host "  P08 [Tone.OnGlass Light Mode]: Sub Alpha = $subAlphaLight (Required >= 189)" -ForegroundColor Cyan
        Assert-True ($subAlphaLight -ge 189) "Tone.OnGlass Light Mode Sub.A must be >= 189 (actual: $subAlphaLight)"
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 9: Random Color Fuzzing (1,000 Random Inputs)
    # -------------------------------------------------------------
    It "P09: Executes 1,000-iteration random color fuzzing against DerivePalette" {
        $rng = New-Object System.Random(42)
        $violations = 0
        $worstTextContrast = 999.0
        $worstSubContrast = 999.0
        $worstAccentContrast = 999.0
        $worstOnAccentContrast = 999.0

        for ($i = 0; $i -lt 1000; $i++) {
            $bg = [System.Drawing.Color]::FromArgb(255, $rng.Next(256), $rng.Next(256), $rng.Next(256))
            $text = [System.Drawing.Color]::FromArgb(255, $rng.Next(256), $rng.Next(256), $rng.Next(256))
            $accent = [System.Drawing.Color]::FromArgb(255, $rng.Next(256), $rng.Next(256), $rng.Next(256))

            $pal = $deriveMethod.Invoke($null, @($bg, $text, $accent))
            $outBg = Parse-Hex $pal["bg"]
            $outText = Parse-Hex $pal["text"]
            $outSub = Parse-Hex $pal["sub"]
            $outAccent = Parse-Hex $pal["accent"]
            $outOnAccent = Parse-Hex $pal["onAccent"]

            $cText = Get-Contrast $outText $outBg
            $cSub = Get-Contrast $outSub $outBg
            $cAccent = Get-Contrast $outAccent $outBg
            $cOnAccent = Get-Contrast $outOnAccent $outAccent

            if ($cText -lt $worstTextContrast) { $worstTextContrast = $cText }
            if ($cSub -lt $worstSubContrast) { $worstSubContrast = $cSub }
            if ($cAccent -lt $worstAccentContrast) { $worstAccentContrast = $cAccent }
            if ($cOnAccent -lt $worstOnAccentContrast) { $worstOnAccentContrast = $cOnAccent }

            if ($cText -lt 4.5) { $violations++ }
            if ($cSub -lt 4.5) { $violations++ }
            if ($cAccent -lt 3.5) { $violations++ }
            if ($cOnAccent -lt 4.5) { $violations++ }
        }

        Write-Host "  P09 [Fuzzing 1,000 Colors]: Worst Text CR=$([math]::Round($worstTextContrast, 2)), Worst Sub CR=$([math]::Round($worstSubContrast, 2)), Worst Accent CR=$([math]::Round($worstAccentContrast, 2)), Worst OnAccent CR=$([math]::Round($worstOnAccentContrast, 2)), Total Violations=$violations" -ForegroundColor Magenta

        Assert-Equal $violations 0 "Zero contrast floor violations across 1,000 random fuzzing inputs"
    }

    # -------------------------------------------------------------
    # PATHOLOGICAL TEST 10: Degenerate Pack Overrides & Null Safety
    # -------------------------------------------------------------
    It "P10: Stress-tests Ink.SetPack with degenerate, partial, and malformed dictionaries" {
        # 1. Null dictionary
        $setPackMethod.Invoke($null, [object[]]@($null))
        $applyMethod.Invoke($null, @($false))
        $b1 = $baseField.GetValue($null)
        Assert-NotNull $b1 "Ink.Apply must not crash on null pack"

        # 2. Empty dictionary
        $dict = [System.Activator]::CreateInstance($dictType)
        $setPackMethod.Invoke($null, [object[]]@($dict))
        $applyMethod.Invoke($null, @($false))
        $b2 = $baseField.GetValue($null)
        Assert-NotNull $b2 "Ink.Apply must not crash on empty pack"

        # 3. Malformed values
        $dict["bg"] = "not_a_hex"
        $dict["text"] = "#12"
        $dict["accent"] = "###"
        $setPackMethod.Invoke($null, [object[]]@($dict))
        $applyMethod.Invoke($null, @($false))
        $b3 = $baseField.GetValue($null)
        Assert-NotNull $b3 "Ink.Apply must ignore malformed hex values and preserve valid defaults"

        # Cleanup: Reset pack
        $cleanDict = [System.Activator]::CreateInstance($dictType)
        $setPackMethod.Invoke($null, [object[]]@($cleanDict))
        $setAccentMethod.Invoke($null, @(""))
        $applyMethod.Invoke($null, @($false))
    }
}
