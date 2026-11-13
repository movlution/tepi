# test_b05_palette_floors.ps1
# Boundary & Corner Case Tests for Feature 5: Custom Palette Contrast Floor
# Covers identical color inputs, low-contrast pairs, and palette floor contrast guarantees.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 5 - Custom Palette Contrast Floor Boundaries" {

    It "Enforces contrast floor when background and text are identical pure white #FFFFFF" {
        $white = [System.Drawing.Color]::White
        $pal = Invoke-TepiStaticMethod "Island" "DerivePalette" @($white, $white, [System.Drawing.Color]::Blue)
        Assert-NotNull $pal "Palette must be generated"

        $derivedText = [System.Drawing.ColorTranslator]::FromHtml($pal["text"])
        $ratio = Get-WcagContrastRatio $derivedText $white
        Assert-True ($ratio -ge 4.5) "Identical white inputs must enforce text contrast >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Enforces contrast floor when background and text are identical pure black #000000" {
        $black = [System.Drawing.Color]::Black
        $pal = Invoke-TepiStaticMethod "Island" "DerivePalette" @($black, $black, [System.Drawing.Color]::Green)
        Assert-NotNull $pal "Palette must be generated"

        $derivedText = [System.Drawing.ColorTranslator]::FromHtml($pal["text"])
        $ratio = Get-WcagContrastRatio $derivedText $black
        Assert-True ($ratio -ge 4.5) "Identical black inputs must enforce text contrast >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Enforces accent contrast floor on low-contrast mid-grey background #808080" {
        $grey = [System.Drawing.Color]::FromArgb(255, 128, 128, 128)
        $lowAccent = [System.Drawing.Color]::FromArgb(255, 130, 130, 130)

        $pal = Invoke-TepiStaticMethod "Island" "DerivePalette" @($grey, [System.Drawing.Color]::White, $lowAccent)
        $derivedAccent = [System.Drawing.ColorTranslator]::FromHtml($pal["accent"])
        $ratio = Get-WcagContrastRatio $derivedAccent $grey
        Assert-True ($ratio -ge 3.0) "Mid-grey low contrast accent must be enforced >= 3.0:1 (actual: ${ratio}:1)"
    }

    It "Guarantees derived sub and faint maintain hierarchical readability floors" {
        $bg = [System.Drawing.Color]::FromArgb(255, 24, 24, 28)
        $text = [System.Drawing.Color]::FromArgb(255, 250, 250, 252)
        $accent = [System.Drawing.Color]::FromArgb(255, 80, 140, 255)

        $pal = Invoke-TepiStaticMethod "Island" "DerivePalette" @($bg, $text, $accent)
        $sub = [System.Drawing.ColorTranslator]::FromHtml($pal["sub"])
        $faint = [System.Drawing.ColorTranslator]::FromHtml($pal["faint"])

        $subRatio = Get-WcagContrastRatio $sub $bg
        $faintRatio = Get-WcagContrastRatio $faint $bg

        Assert-True ($subRatio -ge 4.0) "Derived sub contrast must be >= 4.0:1 (actual: ${subRatio}:1)"
        Assert-True ($faintRatio -ge 2.8) "Derived faint contrast must be >= 2.8:1 (actual: ${faintRatio}:1)"
    }

    It "Verifies card palette symmetry on inverted surfaces" {
        $darkBg = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
        $lightText = [System.Drawing.Color]::FromArgb(255, 240, 240, 245)
        $accent = [System.Drawing.Color]::FromArgb(255, 60, 160, 240)

        $pal = Invoke-TepiStaticMethod "Island" "DerivePalette" @($darkBg, $lightText, $accent)

        $cardBg = [System.Drawing.ColorTranslator]::FromHtml($pal["card.bg"])
        $cardText = [System.Drawing.ColorTranslator]::FromHtml($pal["card.text"])
        $cardSub = [System.Drawing.ColorTranslator]::FromHtml($pal["card.sub"])

        $textRatio = Get-WcagContrastRatio $cardText $cardBg
        $subRatio = Get-WcagContrastRatio $cardSub $cardBg

        Assert-True ($textRatio -ge 4.5) "Card text vs card bg contrast must be >= 4.5:1 (actual: ${textRatio}:1)"
        Assert-True ($subRatio -ge 3.0) "Card sub vs card bg contrast must be >= 3.0:1 (actual: ${subRatio}:1)"
    }
}
