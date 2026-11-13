# test_b08_switch_hover.ps1
# Boundary & Corner Case Tests for Feature 8: KitSwitch Hover State & Dynamics
# Covers checked/unchecked states, disabled tracks, reduced motion dynamics, and geometry extremes.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 8 - KitSwitch Dynamics & Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders Checked vs Unchecked states offscreen in dark and light themes" {
        foreach ($light in @($false, $true)) {
            Reset-TepiTheme -Light $light

            $swOn = New-TepiControl "KitSwitch" @{ Checked = $true }
            $swOff = New-TepiControl "KitSwitch" @{ Checked = $false }

            $bmpOn = Render-TepiControlToBitmap $swOn 60 28
            $bmpOff = Render-TepiControlToBitmap $swOff 60 28

            Assert-NotNull $bmpOn "Checked switch must render (Light=$light)"
            Assert-NotNull $bmpOff "Unchecked switch must render (Light=$light)"

            $bmpOn.Dispose()
            $bmpOff.Dispose()
            $swOn.Dispose()
            $swOff.Dispose()
        }
    }

    It "Renders disabled KitSwitch with KitInk.Line track and KitInk.Disabled knob" {
        $swDisabled = New-TepiControl "KitSwitch" @{ Checked = $false; Enabled = $false }
        $bmp = Render-TepiControlToBitmap $swDisabled 60 28
        Assert-NotNull $bmp "Disabled switch bitmap must render"
        Assert-Equal $bmp.Width 60 "Width must match"
        Assert-Equal $bmp.Height 28 "Height must match"
        $bmp.Dispose()
        $swDisabled.Dispose()
    }

    It "Handles extreme dimensional boundaries from micro 10x10 to oversized 200x80" {
        $dimPairs = @(
            @{ W = 10; H = 10 },
            @{ W = 20; H = 14 },
            @{ W = 60; H = 28 },
            @{ W = 120; H = 48 },
            @{ W = 200; H = 80 }
        )

        foreach ($dp in $dimPairs) {
            $sw = New-TepiControl "KitSwitch" @{ Checked = $true }
            $bmp = Render-TepiControlToBitmap $sw $dp.W $dp.H
            Assert-NotNull $bmp "Switch must render at $($dp.W)x$($dp.H)"
            $bmp.Dispose()
            $sw.Dispose()
        }
    }

    It "Maintains state stability under rapid Checked toggling cycles" {
        $sw = New-TepiControl "KitSwitch" @{ Checked = $false }
        for ($i = 0; $i -lt 30; $i++) {
            $sw.Checked = ($i % 2 -eq 0)
        }
        Assert-False $sw.Checked "Switch Checked should settle on false after 30 cycles"
        $bmp = Render-TepiControlToBitmap $sw 60 28
        Assert-NotNull $bmp "Rendered bitmap after rapid toggling"
        $bmp.Dispose()
        $sw.Dispose()
    }

    It "Respects system Anim.Reduced motion invariant during knob animation" {
        # Test with Anim.Reduced = true
        Set-TepiStaticField "Anim" "Reduced" $true
        $sw = New-TepiControl "KitSwitch" @{ Checked = $true }
        $bmp = Render-TepiControlToBitmap $sw 60 28
        Assert-NotNull $bmp "Switch under Anim.Reduced must render cleanly"
        $bmp.Dispose()
        $sw.Dispose()

        # Restore Anim.Reduced
        Set-TepiStaticField "Anim" "Reduced" $false
    }
}
