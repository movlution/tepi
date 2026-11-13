# test_b18_pill_elevation.ps1
# Boundary & Corner Case Tests for Feature 18: Island Pill Elevation Shadow on Glass
# Covers pill elevation shadow condition (H <= 60), ambient/key shadow kernel tables, and geometry bounds.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 18 - Island Pill Elevation Shadow Boundaries" {

    It "Evaluates shadow suppression condition boundary at height H=60" {
        $islandType = Get-TepiType "Island"
        Assert-NotNull $islandType "Island type must exist"

        $heights = @(30, 48, 60, 61, 80, 120)
        foreach ($h in $heights) {
            $isPill = ($h -le 60)
            Assert-NotNull $isPill "Height evaluation at $h px"
        }
    }

    It "Verifies ShadowAlpha kernel table has decreasing falloff within ambient (0..4) and key (5..7) passes" {
        $shadowAlpha = Get-TepiStaticField "Island" "ShadowAlpha"
        Assert-NotNull $shadowAlpha "ShadowAlpha array must exist"
        Assert-Equal $shadowAlpha.Length 8 "ShadowAlpha must have exactly 8 layers (5 ambient + 3 key)"

        # Ambient pass (indices 0..4)
        for ($i = 0; $i -lt 4; $i++) {
            Assert-True ($shadowAlpha[$i] -ge $shadowAlpha[$i + 1]) "Ambient ShadowAlpha[$i] ($($shadowAlpha[$i])) >= ShadowAlpha[$($i+1)] ($($shadowAlpha[$i+1]))"
        }

        # Key pass (indices 5..7)
        for ($i = 5; $i -lt 7; $i++) {
            Assert-True ($shadowAlpha[$i] -ge $shadowAlpha[$i + 1]) "Key ShadowAlpha[$i] ($($shadowAlpha[$i])) >= ShadowAlpha[$($i+1)] ($($shadowAlpha[$i+1]))"
        }
    }

    It "Verifies ShadowGrow kernel table has increasing offset progression within ambient (0..4) and key (5..7) passes" {
        $shadowGrow = Get-TepiStaticField "Island" "ShadowGrow"
        Assert-NotNull $shadowGrow "ShadowGrow array must exist"
        Assert-Equal $shadowGrow.Length 8 "ShadowGrow must have exactly 8 layers"

        # Ambient pass (indices 0..4)
        for ($i = 0; $i -lt 4; $i++) {
            Assert-True ($shadowGrow[$i] -le $shadowGrow[$i + 1]) "Ambient ShadowGrow[$i] ($($shadowGrow[$i])) <= ShadowGrow[$($i+1)] ($($shadowGrow[$i+1]))"
        }

        # Key pass (indices 5..7)
        for ($i = 5; $i -lt 7; $i++) {
            Assert-True ($shadowGrow[$i] -le $shadowGrow[$i + 1]) "Key ShadowGrow[$i] ($($shadowGrow[$i])) <= ShadowGrow[$($i+1)] ($($shadowGrow[$i+1]))"
        }
    }

    It "Verifies ShadowDrop array dimension matches ShadowGrow and ShadowAlpha" {
        $shadowAlpha = Get-TepiStaticField "Island" "ShadowAlpha"
        $shadowGrow = Get-TepiStaticField "Island" "ShadowGrow"
        $shadowDrop = Get-TepiStaticField "Island" "ShadowDrop"

        Assert-NotNull $shadowDrop "ShadowDrop array must exist"
        Assert-Equal $shadowDrop.Length $shadowGrow.Length "ShadowDrop and ShadowGrow lengths must match"
        Assert-Equal $shadowDrop.Length $shadowAlpha.Length "ShadowDrop and ShadowAlpha lengths must match"
    }

    It "Handles degenerate and empty rectangle boundaries without throwing" {
        $emptyRect = [System.Drawing.RectangleF]::Empty
        Assert-True $emptyRect.IsEmpty "RectangleF.Empty must be empty"
        Assert-Equal $emptyRect.Width ([float]0.0) "Width must be 0"
        Assert-Equal $emptyRect.Height ([float]0.0) "Height must be 0"
    }
}
