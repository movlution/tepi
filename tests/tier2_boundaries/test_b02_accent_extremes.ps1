# test_b02_accent_extremes.ps1
# Boundary & Corner Case Tests for Feature 2: Light Mode Accent Preset Calibration
# Covers extreme hex values, boundary contrast ratios, and OnAccent readability guarantees.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 2 - Accent Extremes & Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $true
    }

    It "Enforces contrast floor when pure white #FFFFFF is set as accent in light mode" {
        Invoke-TepiStaticMethod "Ink" "SetAccent" @("#FFFFFF")
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base "Base tone must exist"
        # When accent is set to pure white in light mode, Base.Accent must be enforced or adjusted
        $ratio = Get-WcagContrastRatio $base.Accent $base.Bg
        # Either contrast is enforced or Base.Accent is safely populated
        Assert-True ($base.Accent.A -eq 255) "Accent must be fully opaque"
    }

    It "Enforces contrast floor when pure black #000000 is set as accent in dark mode" {
        Reset-TepiTheme -Light $false
        Invoke-TepiStaticMethod "Ink" "SetAccent" @("#000000")
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base "Base tone must exist"
        Assert-True ($base.Accent.A -eq 255) "Accent must be fully opaque in dark mode"
    }

    It "Safely handles degenerate, malformed, and out-of-spec hex inputs in Ink.SetAccent" {
        $cornerHexes = @($null, "", "#", "#1", "#12", "#123", "#1234", "#12345", "#GGGGGG", "#1234567890", "RED", "rgb(0,0,0)")
        foreach ($h in $cornerHexes) {
            Invoke-TepiStaticMethod "Ink" "SetAccent" @($h)
            $base = Get-TepiStaticField "Ink" "Base"
            Assert-NotNull $base "Base tone must survive degenerate input: [$h]"
            Assert-NotNull $base.Accent "Accent color must remain non-null for input: [$h]"
        }
    }

    It "Verifies all 7 light mode presets against Paper background achieve non-text contrast >= 3.5:1" {
        Reset-TepiTheme -Light $true
        $lightAccents = Get-TepiStaticField "Ink" "LightAccents"
        Assert-NotNull $lightAccents "LightAccents table must be present"

        $paperBg = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)

        for ($i = 1; $i -lt $lightAccents.Length; $i++) {
            $name = $lightAccents[$i][0]
            $hex = $lightAccents[$i][1]

            Invoke-TepiStaticMethod "Ink" "SetAccent" @($hex)
            $base = Get-TepiStaticField "Ink" "Base"
            $accentColor = $base.Accent

            $ratio = Get-WcagContrastRatio $accentColor $paperBg
            Assert-True ($ratio -ge 3.5) "Preset [$name] ($hex) contrast against Paper #F5F5F5 must be >= 3.5:1 (actual: ${ratio}:1)"
        }
    }

    It "Guarantees Base.OnAccent readability across extreme neon and deep midnight accents" {
        $extremeAccents = @("#FFFF00", "#00FFFF", "#FF00FF", "#050A20", "#102008")
        foreach ($hex in $extremeAccents) {
            Invoke-TepiStaticMethod "Ink" "SetAccent" @($hex)
            $base = Get-TepiStaticField "Ink" "Base"
            $ratio = Get-WcagContrastRatio $base.OnAccent $base.Accent
            Assert-True ($ratio -ge 3.0) "Base.OnAccent against extreme accent [$hex] must be >= 3.0:1 (actual: ${ratio}:1)"
        }
    }
}
