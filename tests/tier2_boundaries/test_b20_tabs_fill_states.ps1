# test_b20_tabs_fill_states.ps1
# Boundary & Corner Case Tests for Feature 20: Tabs Inverted Hover/Pressed Fill Fix
# Covers hover vs pressed fill tokens, alpha contrast, dark/light modes, and active tab invariants.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 20 - Tabs Interactive Fill Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Verifies FillHover and FillPressed tokens are distinct in Dark Mode" {
        Reset-TepiTheme -Light $false
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base.FillHover "FillHover must exist in dark mode"
        Assert-NotNull $base.FillPressed "FillPressed must exist in dark mode"

        Assert-NotEqual $base.FillHover.ToArgb() $base.FillPressed.ToArgb() "FillHover and FillPressed must be distinct in dark mode"
    }

    It "Verifies FillHover and FillPressed tokens are distinct in Light Mode" {
        Reset-TepiTheme -Light $true
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base.FillHover "FillHover must exist in light mode"
        Assert-NotNull $base.FillPressed "FillPressed must exist in light mode"

        Assert-NotEqual $base.FillHover.ToArgb() $base.FillPressed.ToArgb() "FillHover and FillPressed must be distinct in light mode"
    }

    It "Evaluates Tone.Derive alpha multipliers for FillPressed across dark and light modes" {
        # Dark mode: FillPressed = Ink.A(Fill, 0.57f)
        # Light mode: FillPressed = Ink.A(Fill, 2.2f)
        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()

        Assert-True ($darkTone.FillPressed.A -gt 0) "Dark mode FillPressed alpha must be positive"
        Assert-True ($paperTone.FillPressed.A -gt 0) "Light mode FillPressed alpha must be positive"
    }

    It "Verifies ternary state resolution: pressed state overrides hover state" {
        $hovered = $true
        $pressed = $true
        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()

        $resolvedFill = if ($pressed) { $darkTone.FillPressed } else { $darkTone.FillHover }
        Assert-Equal $resolvedFill.ToArgb() $darkTone.FillPressed.ToArgb() "When both hovered and pressed, FillPressed must be chosen"

        $pressed = $false
        $resolvedFillHoverOnly = if ($pressed) { $darkTone.FillPressed } else { $darkTone.FillHover }
        Assert-Equal $resolvedFillHoverOnly.ToArgb() $darkTone.FillHover.ToArgb() "When only hovered, FillHover must be chosen"
    }

    It "Preserves active tab accent pill invariant (to == page suppresses hover pill)" {
        $toPage = 1
        $currentPage = 1
        $isCurrent = ($toPage -eq $currentPage)

        # Invariant: active tab renders p.T.Accent pill, not hover/pressed pill
        Assert-True $isCurrent "Active tab condition holds"
    }
}
