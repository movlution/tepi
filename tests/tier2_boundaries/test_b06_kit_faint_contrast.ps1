# test_b06_kit_faint_contrast.ps1
# Boundary & Corner Case Tests for Feature 6: Elevate KitInk.Faint Light Contrast
# Covers KitInk.Faint contrast boundaries across light/dark modes and Kit surfaces.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 6 - KitInk.Faint Contrast Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Evaluates KitInk.Faint contrast against KitInk.Window in Dark Mode" {
        Reset-TepiTheme -Light $false
        $faint = Get-TepiStaticProperty "KitInk" "Faint"
        $win = Get-TepiStaticProperty "KitInk" "Window"

        $ratio = Get-WcagContrastRatio $faint $win
        Assert-True ($ratio -ge 3.0) "Dark mode KitInk.Faint contrast vs Window must be >= 3.0:1 (actual: ${ratio}:1)"
    }

    It "Evaluates KitInk.Faint contrast against KitInk.Window in Light Mode" {
        Reset-TepiTheme -Light $true
        $faint = Get-TepiStaticProperty "KitInk" "Faint"
        $win = Get-TepiStaticProperty "KitInk" "Window"

        $ratio = Get-WcagContrastRatio $faint $win
        Assert-True ($ratio -ge 2.5) "Light mode KitInk.Faint contrast vs Window must be >= 2.5:1 (actual: ${ratio}:1)"
    }

    It "Evaluates KitInk.Faint contrast against KitInk.Side in Light Mode" {
        Reset-TepiTheme -Light $true
        $faint = Get-TepiStaticProperty "KitInk" "Faint"
        $side = Get-TepiStaticProperty "KitInk" "Side"

        $ratio = Get-WcagContrastRatio $faint $side
        Assert-True ($ratio -ge 2.5) "Light mode KitInk.Faint contrast vs Side must be >= 2.5:1 (actual: ${ratio}:1)"
    }

    It "Evaluates KitInk.Faint contrast against KitInk.Group in Light Mode" {
        Reset-TepiTheme -Light $true
        $faint = Get-TepiStaticProperty "KitInk" "Faint"
        $group = Get-TepiStaticProperty "KitInk" "Group"

        $ratio = Get-WcagContrastRatio $faint $group
        Assert-True ($ratio -ge 2.5) "Light mode KitInk.Faint contrast vs Group must be >= 2.5:1 (actual: ${ratio}:1)"
    }

    It "Evaluates KitInk.Faint contrast against KitInk.Hover in Light Mode" {
        Reset-TepiTheme -Light $true
        $faint = Get-TepiStaticProperty "KitInk" "Faint"
        $hover = Get-TepiStaticProperty "KitInk" "Hover"

        $ratio = Get-WcagContrastRatio $faint $hover
        Assert-True ($ratio -ge 2.2) "Light mode KitInk.Faint contrast vs Hover must be >= 2.2:1 (actual: ${ratio}:1)"
    }
}
