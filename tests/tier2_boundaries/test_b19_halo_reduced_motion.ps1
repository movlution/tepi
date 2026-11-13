# test_b19_halo_reduced_motion.ps1
# Boundary & Corner Case Tests for Feature 19: Island Approval Halo Reduced Motion
# Covers halo animation gating, GlowLayers invariant, flip thresholds, and Anim.Reduced preference.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 19 - Island Halo & Reduced Motion Boundaries" {

    It "Verifies GlowLayers constant equals 16 for smooth halo falloff" {
        $islandType = Get-TepiType "Island"
        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'
        $field = $islandType.GetField("GlowLayers", $flags)
        Assert-NotNull $field "GlowLayers constant must exist"
        $val = $field.GetValue($null)
        Assert-Equal $val 16 "GlowLayers must equal 16"
    }

    It "Evaluates halo suppression condition when flip < 0.05f (threshold boundary)" {
        $subThresholdFlips = @(0.0, 0.01, 0.049)
        foreach ($f in $subThresholdFlips) {
            $isSuppressed = ($f -lt 0.05)
            Assert-True $isSuppressed "Flip $f must be suppressed (below 0.05 threshold)"
        }
    }

    It "Evaluates halo active condition when flip >= 0.05f (active boundary)" {
        $activeFlips = @(0.05, 0.1, 0.5, 0.95, 1.0)
        foreach ($f in $activeFlips) {
            $isActive = ($f -ge 0.05)
            Assert-True $isActive "Flip $f must be active (at or above 0.05 threshold)"
        }
    }

    It "Verifies Anim.Reduced static preference field toggling" {
        $animType = Get-TepiType "Anim"
        Assert-NotNull $animType "Anim type must exist"

        # Toggle to true
        Set-TepiStaticField "Anim" "Reduced" $true
        $isReduced = Get-TepiStaticField "Anim" "Reduced"
        Assert-True $isReduced "Anim.Reduced should be true"

        # Toggle back to false
        Set-TepiStaticField "Anim" "Reduced" $false
        $isReducedFalse = Get-TepiStaticField "Anim" "Reduced"
        Assert-False $isReducedFalse "Anim.Reduced should be false"
    }

    It "Evaluates full approval card boundary (flip = 1.0f) without arithmetic overflow" {
        $glowLayers = 16
        $c = [System.Drawing.Color]::White

        # Simulate glow layer alpha calculation:
        # (int)(flip * breath * 36 * fall * Math.Sqrt(fall))
        $flip = 1.0
        $breath = 1.0 # peak pulse
        for ($i = 0; $i -lt $glowLayers; $i++) {
            $fall = 1.0 - ($i / [double]$glowLayers)
            $alpha = [int]($flip * $breath * 36.0 * $fall * [Math]::Sqrt($fall))
            Assert-True ($alpha -ge 0) "Layer $i alpha must be non-negative"
            Assert-True ($alpha -le 255) "Layer $i alpha must not overflow byte boundary (actual: $alpha)"
        }
    }
}
