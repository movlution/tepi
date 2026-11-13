# run_adversarial.ps1
# Comprehensive Adversarial Suite for Tepi Color Science, Palette Derivation, and Ink Tokens

param([switch]$VerboseReport)

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Adversarial Stress Suite: Milestone 1 Color Science & Tokens" {

    $islandType = Get-TepiType "Island"
    $inkType = Get-TepiType "Ink"
    $toneType = Get-TepiType "Tone"

    $deriveMethod = $islandType.GetMethod("DerivePalette", [System.Reflection.BindingFlags]'Public,Static')
    $contrastMethod = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]'Public,Static')
    $applyMethod = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static', $null, @([bool]), $null)
    $setAccentMethod = $inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]'Public,Static')
    $setPackMethod = $inkType.GetMethod("SetPack", [System.Reflection.BindingFlags]'Public,Static')

    $baseField = $inkType.GetField("Base", [System.Reflection.BindingFlags]'Public,Static')
    $flipField = $inkType.GetField("Flip", [System.Reflection.BindingFlags]'Public,Static')

    function Get-CR([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
        return [double]$contrastMethod.Invoke($null, @($c1, $c2))
    }

    function Parse-Color([string]$hex) {
        return [System.Drawing.ColorTranslator]::FromHtml($hex)
    }

    # =========================================================================
    # TEST 1: Colors.DerivePalette - Identical Triplet #808080
    # =========================================================================
    It "DerivePalette: Identical middle grey #808080 for all inputs" {
        $c = Parse-Color "#808080"
        $pal = $deriveMethod.Invoke($null, @($c, $c, $c))
        Assert-NotNull $pal "Palette must be generated"

        $bg = Parse-Color $pal["bg"]
        $text = Parse-Color $pal["text"]
        $sub = Parse-Color $pal["sub"]
        $faint = Parse-Color $pal["faint"]
        $accent = Parse-Color $pal["accent"]
        $onAccent = Parse-Color $pal["onAccent"]

        $crText = Get-CR $text $bg
        $crSub = Get-CR $sub $bg
        $crFaint = Get-CR $faint $bg
        $crAccent = Get-CR $accent $bg
        $crOnAccent = Get-CR $onAccent $accent

        Write-Host "  [Identical #808080]: text=$($pal['text']) (CR=$([math]::Round($crText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($crSub, 2))), faint=$($pal['faint']) (CR=$([math]::Round($crFaint, 2))), accent=$($pal['accent']) (CR=$([math]::Round($crAccent, 2))), onAccent=$($pal['onAccent']) (CR=$([math]::Round($crOnAccent, 2)))" -ForegroundColor Cyan

        Assert-True ($crText -ge 4.5) "Text contrast must meet >= 4.5:1 floor (actual: $crText)"
        Assert-True ($crSub -ge 4.5) "Sub contrast must meet >= 4.5:1 floor (actual: $crSub)"
        Assert-True ($crFaint -ge 3.0) "Faint contrast must meet >= 3.0:1 floor (actual: $crFaint)"
        Assert-True ($crAccent -ge 3.5) "Accent contrast must meet >= 3.5:1 floor (actual: $crAccent)"
        Assert-True ($crOnAccent -ge 4.5) "OnAccent contrast must meet >= 4.5:1 floor (actual: $crOnAccent)"
    }

    # =========================================================================
    # TEST 2: Colors.DerivePalette - Low Contrast Darks (#202020 and #242424)
    # =========================================================================
    It "DerivePalette: Low contrast darks (#202020 bg, #242424 text, #222222 accent)" {
        $bg = Parse-Color "#202020"
        $text = Parse-Color "#242424"
        $accent = Parse-Color "#222222"
        $pal = $deriveMethod.Invoke($null, @($bg, $text, $accent))

        $outBg = Parse-Color $pal["bg"]
        $outText = Parse-Color $pal["text"]
        $outSub = Parse-Color $pal["sub"]
        $outFaint = Parse-Color $pal["faint"]
        $outAccent = Parse-Color $pal["accent"]
        $outOnAccent = Parse-Color $pal["onAccent"]

        $crText = Get-CR $outText $outBg
        $crSub = Get-CR $outSub $outBg
        $crFaint = Get-CR $outFaint $outBg
        $crAccent = Get-CR $outAccent $outBg
        $crOnAccent = Get-CR $outOnAccent $outAccent

        Write-Host "  [Low Dark #202020]: text=$($pal['text']) (CR=$([math]::Round($crText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($crSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($crAccent, 2)))" -ForegroundColor Cyan

        Assert-True ($crText -ge 7.0) "Text contrast on dark must meet >= 7.0:1 floor (actual: $crText)"
        Assert-True ($crSub -ge 4.5) "Sub contrast on dark must meet >= 4.5:1 floor (actual: $crSub)"
        Assert-True ($crFaint -ge 3.0) "Faint contrast on dark must meet >= 3.0:1 floor (actual: $crFaint)"
        Assert-True ($crAccent -ge 3.5) "Accent contrast on dark must meet >= 3.5:1 floor (actual: $crAccent)"
        Assert-True ($crOnAccent -ge 4.5) "OnAccent contrast must meet >= 4.5:1 floor (actual: $crOnAccent)"
    }

    # =========================================================================
    # TEST 3: Colors.DerivePalette - Zero Luminance (#000000 for All Inputs)
    # =========================================================================
    It "DerivePalette: Zero luminance (#000000 bg, text, accent)" {
        $black = Parse-Color "#000000"
        $pal = $deriveMethod.Invoke($null, @($black, $black, $black))

        $outBg = Parse-Color $pal["bg"]
        $outText = Parse-Color $pal["text"]
        $outSub = Parse-Color $pal["sub"]
        $outFaint = Parse-Color $pal["faint"]
        $outAccent = Parse-Color $pal["accent"]
        $outOnAccent = Parse-Color $pal["onAccent"]

        $crText = Get-CR $outText $outBg
        $crSub = Get-CR $outSub $outBg
        $crFaint = Get-CR $outFaint $outBg
        $crAccent = Get-CR $outAccent $outBg
        $crOnAccent = Get-CR $outOnAccent $outAccent

        Write-Host "  [Zero Lum #000000]: text=$($pal['text']) (CR=$([math]::Round($crText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($crSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($crAccent, 2)))" -ForegroundColor Cyan

        Assert-True ($crText -ge 7.0) "Text contrast on black must meet >= 7.0:1 floor (actual: $crText)"
        Assert-True ($crSub -ge 4.5) "Sub contrast on black must meet >= 4.5:1 floor (actual: $crSub)"
        Assert-True ($crFaint -ge 3.0) "Faint contrast on black must meet >= 3.0:1 floor (actual: $crFaint)"
        Assert-True ($crAccent -ge 3.5) "Accent contrast on black must meet >= 3.5:1 floor (actual: $crAccent)"
        Assert-True ($crOnAccent -ge 4.5) "OnAccent contrast must meet >= 4.5:1 floor (actual: $crOnAccent)"
    }

    # =========================================================================
    # TEST 4: Colors.DerivePalette - Extreme Pastels on Pure White
    # =========================================================================
    It "DerivePalette: Extreme pastels against pure white (#FFFFFF)" {
        $white = Parse-Color "#FFFFFF"
        $pastels = @("#FFFDD0", "#FFFFE0", "#F0FFF0", "#E6E6FA", "#FFF0F5")

        foreach ($p in $pastels) {
            $cPastel = Parse-Color $p
            $pal = $deriveMethod.Invoke($null, @($white, $cPastel, $cPastel))

            $outText = Parse-Color $pal["text"]
            $outSub = Parse-Color $pal["sub"]
            $outFaint = Parse-Color $pal["faint"]
            $outAccent = Parse-Color $pal["accent"]
            $outOnAccent = Parse-Color $pal["onAccent"]

            $crText = Get-CR $outText $white
            $crSub = Get-CR $outSub $white
            $crFaint = Get-CR $outFaint $white
            $crAccent = Get-CR $outAccent $white
            $crOnAccent = Get-CR $outOnAccent $outAccent

            Write-Host "  [Pastel $p on White]: text=$($pal['text']) (CR=$([math]::Round($crText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($crSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($crAccent, 2)))" -ForegroundColor Cyan

            Assert-True ($crText -ge 7.0) "Text on white must meet >= 7.0:1 floor (actual: $crText)"
            Assert-True ($crSub -ge 4.5) "Sub on white must meet >= 4.5:1 floor (actual: $crSub)"
            Assert-True ($crFaint -ge 3.0) "Faint on white must meet >= 3.0:1 floor (actual: $crFaint)"
            Assert-True ($crAccent -ge 3.5) "Accent on white must meet >= 3.5:1 floor (actual: $crAccent)"
            Assert-True ($crOnAccent -ge 4.5) "OnAccent on pastel accent must meet >= 4.5:1 floor (actual: $crOnAccent)"
        }
    }

    # =========================================================================
    # TEST 5: Colors.DerivePalette - Worst-Case Luminance Backgrounds (L ~ 0.179)
    # =========================================================================
    It "DerivePalette: Worst-case luminance backgrounds (#757575, #767676, #777777, #787878)" {
        $worstHaxes = @("#757575", "#767676", "#777777", "#787878")
        foreach ($hex in $worstHaxes) {
            $bg = Parse-Color $hex
            $pal = $deriveMethod.Invoke($null, @($bg, $bg, $bg))

            $outText = Parse-Color $pal["text"]
            $outSub = Parse-Color $pal["sub"]
            $outFaint = Parse-Color $pal["faint"]
            $outAccent = Parse-Color $pal["accent"]
            $outOnAccent = Parse-Color $pal["onAccent"]

            $crText = Get-CR $outText $bg
            $crSub = Get-CR $outSub $bg
            $crFaint = Get-CR $outFaint $bg
            $crAccent = Get-CR $outAccent $bg
            $crOnAccent = Get-CR $outOnAccent $outAccent

            Write-Host "  [Worst-Case $hex]: text=$($pal['text']) (CR=$([math]::Round($crText, 2))), sub=$($pal['sub']) (CR=$([math]::Round($crSub, 2))), accent=$($pal['accent']) (CR=$([math]::Round($crAccent, 2)))" -ForegroundColor Cyan

            Assert-True ($crText -ge 4.5) "Worst-case text must achieve >= 4.5:1 (actual: $crText)"
            Assert-True ($crSub -ge 4.5) "Worst-case sub must achieve >= 4.5:1 (actual: $crSub)"
            Assert-True ($crFaint -ge 3.0) "Worst-case faint must achieve >= 3.0:1 (actual: $crFaint)"
            Assert-True ($crAccent -ge 3.5) "Worst-case accent must achieve >= 3.5:1 (actual: $crAccent)"
            Assert-True ($crOnAccent -ge 4.5) "Worst-case onAccent must achieve >= 4.5:1 (actual: $crOnAccent)"
        }
    }

    # =========================================================================
    # TEST 6: Ink.Apply Presets in Light and Dark Modes
    # =========================================================================
    It "Ink.Apply: Validates all 7 calibrated presets in Light and Dark modes" {
        $darkAccentsField = $inkType.GetField("DarkAccents", [System.Reflection.BindingFlags]'Public,Static')
        $darkAccents = $darkAccentsField.GetValue($null)

        foreach ($item in $darkAccents) {
            $name = $item[0]
            $hex = $item[1]
            if ([string]::IsNullOrEmpty($hex)) { continue }

            $setAccentMethod.Invoke($null, @($hex))

            # Light Mode
            $applyMethod.Invoke($null, @($true))
            $baseToneLight = $baseField.GetValue($null)
            $crAccentLight = Get-CR $baseToneLight.Accent $baseToneLight.Bg
            $crOnAccentLight = Get-CR $baseToneLight.OnAccent $baseToneLight.Accent

            Write-Host "  [Preset $name Light]: Accent=$([System.Drawing.ColorTranslator]::ToHtml($baseToneLight.Accent)) (CR=$([math]::Round($crAccentLight, 2))), OnAccent=$([System.Drawing.ColorTranslator]::ToHtml($baseToneLight.OnAccent)) (CR=$([math]::Round($crOnAccentLight, 2)))" -ForegroundColor Green

            Assert-True ($crAccentLight -ge 3.5) "Preset $name in light mode accent must achieve >= 3.5:1 (actual: $crAccentLight)"
            Assert-True ($crOnAccentLight -ge 4.5) "Preset $name in light mode onAccent must achieve >= 4.5:1 (actual: $crOnAccentLight)"

            # Dark Mode
            $applyMethod.Invoke($null, @($false))
            $baseToneDark = $baseField.GetValue($null)
            $crAccentDark = Get-CR $baseToneDark.Accent $baseToneDark.Bg
            $crOnAccentDark = Get-CR $baseToneDark.OnAccent $baseToneDark.Accent

            Write-Host "  [Preset $name Dark]: Accent=$([System.Drawing.ColorTranslator]::ToHtml($baseToneDark.Accent)) (CR=$([math]::Round($crAccentDark, 2))), OnAccent=$([System.Drawing.ColorTranslator]::ToHtml($baseToneDark.OnAccent)) (CR=$([math]::Round($crOnAccentDark, 2)))" -ForegroundColor Green

            Assert-True ($crAccentDark -ge 4.5) "Preset $name in dark mode accent must achieve >= 4.5:1 (actual: $crAccentDark)"
            Assert-True ($crOnAccentDark -ge 4.5) "Preset $name in dark mode onAccent must achieve >= 4.5:1 (actual: $crOnAccentDark)"
        }
    }

    # =========================================================================
    # TEST 7: Ink.Apply with Arbitrary Custom Accents (Audit Vulnerabilities)
    # =========================================================================
    It "Ink.Apply: Audits custom accent behavior across light and dark modes" {
        # Check custom accent #00FFFF in light mode
        $setAccentMethod.Invoke($null, @("#00FFFF"))
        $applyMethod.Invoke($null, @($true))
        $baseTone = $baseField.GetValue($null)

        $crAccent = Get-CR $baseTone.Accent $baseTone.Bg
        $crOnAccent = Get-CR $baseTone.OnAccent $baseTone.Accent

        Write-Host "  [Custom Accent #00FFFF Light]: Accent=$([System.Drawing.ColorTranslator]::ToHtml($baseTone.Accent)) (CR=$([math]::Round($crAccent, 2))), OnAccent=$([System.Drawing.ColorTranslator]::ToHtml($baseTone.OnAccent)) (CR=$([math]::Round($crOnAccent, 2)))" -ForegroundColor Yellow

        # Check dark mode custom dark accent #101010
        $setAccentMethod.Invoke($null, @("#101010"))
        $applyMethod.Invoke($null, @($false))
        $baseToneDark = $baseField.GetValue($null)

        $crDarkAccent = Get-CR $baseToneDark.Accent $baseToneDark.Bg
        Write-Host "  [Custom Accent #101010 Dark]: Accent=$([System.Drawing.ColorTranslator]::ToHtml($baseToneDark.Accent)) (CR=$([math]::Round($crDarkAccent, 2))) against Bg=$([System.Drawing.ColorTranslator]::ToHtml($baseToneDark.Bg))" -ForegroundColor Yellow
    }

    # =========================================================================
    # TEST 8: Tone.OnGlass Contract (Sub alpha >= 189)
    # =========================================================================
    It "Tone.OnGlass: Sub alpha contract (Sub.A >= 189 / 74%)" {
        $onGlassMethod = $toneType.GetMethod("OnGlass", [System.Reflection.BindingFlags]'Public,Instance')

        $applyMethod.Invoke($null, @($false))
        $tDark = $baseField.GetValue($null)
        $gDark = $onGlassMethod.Invoke($tDark, $null)
        Assert-True ($gDark.Sub.A -ge 189) "Dark mode Tone.OnGlass Sub.A must be >= 189 (actual: $($gDark.Sub.A))"

        $applyMethod.Invoke($null, @($true))
        $tLight = $baseField.GetValue($null)
        $gLight = $onGlassMethod.Invoke($tLight, $null)
        Assert-True ($gLight.Sub.A -ge 189) "Light mode Tone.OnGlass Sub.A must be >= 189 (actual: $($gLight.Sub.A))"
    }

    # =========================================================================
    # TEST 9: Ink.SetPack Type & Null Safety
    # =========================================================================
    It "Ink.SetPack: Dictionary null and malformed safety" {
        $dictType = [System.Type]::GetType("System.Collections.Generic.Dictionary``2[[System.String],[System.String]]")
        $setPackTyped = $inkType.GetMethod("SetPack", [System.Reflection.BindingFlags]'Public,Static', $null, @($dictType), $null)

        # 1. Null pack
        $setPackTyped.Invoke($null, [object[]]@($null))
        $applyMethod.Invoke($null, @($false))
        $b1 = $baseField.GetValue($null)
        Assert-NotNull $b1 "Ink.Apply must succeed with null pack"

        # 2. Empty pack
        $dict = [System.Activator]::CreateInstance($dictType)
        $setPackTyped.Invoke($null, [object[]]@($dict))
        $applyMethod.Invoke($null, @($false))
        $b2 = $baseField.GetValue($null)
        Assert-NotNull $b2 "Ink.Apply must succeed with empty pack"

        # 3. Pack with valid overrides
        $dict["bg"] = "#1A1A1A"
        $dict["text"] = "#EEEEEE"
        $setPackTyped.Invoke($null, [object[]]@($dict))
        $applyMethod.Invoke($null, @($false))
        $b3 = $baseField.GetValue($null)
        Assert-Equal ([System.Drawing.ColorTranslator]::ToHtml($b3.Bg)) "#1A1A1A" "Bg must reflect pack override"

        # Cleanup
        $cleanDict = [System.Activator]::CreateInstance($dictType)
        $setPackTyped.Invoke($null, [object[]]@($cleanDict))
        $setAccentMethod.Invoke($null, @(""))
        $applyMethod.Invoke($null, @($false))
    }
}
