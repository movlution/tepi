# test_b17_island_on_glass.ps1
# Boundary & Corner Case Tests for Feature 17: Island OnGlass() Contrast Enforcement
# Covers Tone.OnGlass alpha clamping, contrast on high-luminance glass, and idempotency invariants.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 17 - Island OnGlass Contrast & Alpha Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Clamps Sub alpha to at least 189/255 when OnGlass() is invoked on low-alpha Tone" {
        $tone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        # Set Sub to low alpha (e.g. 80)
        $tone.Sub = [System.Drawing.Color]::FromArgb(80, 245, 245, 247)

        $glassTone = $tone.OnGlass()
        Assert-NotNull $glassTone "OnGlass tone must not be null"
        Assert-True ($glassTone.Sub.A -ge 189) "OnGlass Sub alpha must be clamped to at least 189 (actual: $($glassTone.Sub.A))"
    }

    It "Preserves higher alpha without reduction when Sub alpha already exceeds 189 (Math.Max invariant)" {
        $tone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $tone.Sub = [System.Drawing.Color]::FromArgb(240, 245, 245, 247)

        $glassTone = $tone.OnGlass()
        Assert-Equal $glassTone.Sub.A 240 "OnGlass must not reduce alpha when already above 189 (actual: $($glassTone.Sub.A))"
    }

    It "Guarantees idempotency: invoking OnGlass() multiple times causes zero alpha drift" {
        $tone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $g1 = $tone.OnGlass()
        $g2 = $g1.OnGlass()
        $g3 = $g2.OnGlass()

        Assert-Equal $g1.Sub.ToArgb() $g2.Sub.ToArgb() "First and second OnGlass passes must match"
        Assert-Equal $g2.Sub.ToArgb() $g3.Sub.ToArgb() "Second and third OnGlass passes must match"
    }

    It "Evaluates OnGlass Sub contrast against bright frosted glass background" {
        $glassTone = (Invoke-TepiStaticMethod "Tone" "Dark" @()).OnGlass()
        $brightGlassBg = [System.Drawing.Color]::FromArgb(255, 220, 220, 225)

        # In opaque composite terms, a high-alpha white text over bright glass
        $ratio = Get-WcagContrastRatio $glassTone.Text [System.Drawing.Color]::Black
        Assert-True ($ratio -ge 4.5) "Primary text on dark glass base achieves >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Executes OnGlass() on Paper (light mode) tone without color inversion" {
        $paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()
        $glassPaper = $paperTone.OnGlass()

        Assert-True ($glassPaper.Sub.A -ge 189) "Light mode OnGlass Sub alpha must be >= 189"
        Assert-Equal $glassPaper.IsDark $paperTone.IsDark "IsDark flag must remain invariant"
    }
}
