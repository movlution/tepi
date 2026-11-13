# test_b12_semantic_red.ps1
# Boundary & Corner Case Tests for Feature 12: Eliminate Hardcoded Semantic Red
# Covers Ink.Base.Negative tokenization, contrast against light/dark surfaces, and legacy IndianRed comparison.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 12 - Semantic Negative Token Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Verifies Dark mode Tone.Negative contrast against Base.Bg exceeds 4.5:1" {
        Reset-TepiTheme -Light $false
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base.Negative "Negative token in dark mode must not be null"

        $ratio = Get-WcagContrastRatio $base.Negative $base.Bg
        Assert-True ($ratio -ge 4.5) "Dark mode Negative token contrast against Base.Bg must be >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Verifies Light mode Tone.Negative contrast against Base.Bg exceeds 4.5:1" {
        Reset-TepiTheme -Light $true
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base.Negative "Negative token in light mode must not be null"

        $ratio = Get-WcagContrastRatio $base.Negative $base.Bg
        Assert-True ($ratio -ge 4.5) "Light mode Negative token contrast against Base.Bg must be >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Compares calibrated Negative token against legacy IndianRed on light backgrounds" {
        $paperBg = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
        $legacyIndianRed = [System.Drawing.Color]::IndianRed

        $paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()
        $tokenNegative = $paperTone.Negative

        $ratioToken = Get-WcagContrastRatio $tokenNegative $paperBg
        $ratioLegacy = Get-WcagContrastRatio $legacyIndianRed $paperBg

        Assert-True ($ratioToken -gt $ratioLegacy) "Calibrated token contrast ($ratioToken) must strictly exceed legacy IndianRed contrast ($ratioLegacy)"
        Assert-True ($ratioToken -ge 4.5) "Calibrated Negative token must achieve WCAG AA >= 4.5:1 on light paper"
    }

    It "Guarantees full opacity (A=255) for Negative and Positive tokens across all modes" {
        foreach ($light in @($false, $true)) {
            Reset-TepiTheme -Light $light
            $base = Get-TepiStaticField "Ink" "Base"

            Assert-Equal $base.Negative.A 255 "Negative token must be fully opaque in Light=$light"
            Assert-Equal $base.Positive.A 255 "Positive token must be fully opaque in Light=$light"
        }
    }

    It "Enforces Negative token contrast against extreme pure white and pure black backgrounds" {
        $pureWhite = [System.Drawing.Color]::White
        $pureBlack = [System.Drawing.Color]::Black

        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()

        $darkNegOnBlack = Get-WcagContrastRatio $darkTone.Negative $pureBlack
        $paperNegOnWhite = Get-WcagContrastRatio $paperTone.Negative $pureWhite

        Assert-True ($darkNegOnBlack -ge 4.5) "Dark negative on pure black must be >= 4.5:1 (actual: ${darkNegOnBlack}:1)"
        Assert-True ($paperNegOnWhite -ge 4.5) "Light negative on pure white must be >= 4.5:1 (actual: ${paperNegOnWhite}:1)"
    }
}
