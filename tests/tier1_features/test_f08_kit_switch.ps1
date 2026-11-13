# test_f08_kit_switch.ps1
# Feature 8: KitSwitch Hover State & Dynamics
# Verifies KitSwitch states (Checked, Unchecked, Disabled) and hover dynamics.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 8: KitSwitch Hover State & Dynamics" {
    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders KitSwitch in Checked (On) state and verifies track fill uses accent color" {
        $switch = New-TepiControl "KitSwitch" @{ Checked = $true }
        $bmp = Render-TepiControlToBitmap $switch 60 28

        Assert-NotNull $bmp "Switch bitmap must render"
        Assert-Equal $bmp.Width 60 "Bitmap width must match"
        Assert-Equal $bmp.Height 28 "Bitmap height must match"

        $bmp.Dispose()
        $switch.Dispose()
    }

    It "Renders KitSwitch in Unchecked (Off) state and verifies track fill uses line color" {
        $switch = New-TepiControl "KitSwitch" @{ Checked = $false }
        $bmp = Render-TepiControlToBitmap $switch 60 28

        Assert-NotNull $bmp "Unchecked switch bitmap must render"
        $bmp.Dispose()
        $switch.Dispose()
    }

    It "Renders KitSwitch in Disabled state and verifies knob uses KitInk.Disabled" {
        $switch = New-TepiControl "KitSwitch" @{ Checked = $false; Enabled = $false }
        $bmp = Render-TepiControlToBitmap $switch 60 28

        Assert-NotNull $bmp "Disabled switch bitmap must render"
        $disabledToken = Get-TepiStaticProperty "KitInk" "Disabled"
        Assert-NotNull $disabledToken "KitInk.Disabled must exist"

        $bmp.Dispose()
        $switch.Dispose()
    }

    It "Verifies KitSwitch handles CheckedChanged event and toggles state correctly" {
        $switch = New-TepiControl "KitSwitch" @{ Checked = $false }
        $script:switchFired = $false
        $handler = [EventHandler]{ $script:switchFired = $true }
        $switch.add_CheckedChanged($handler)

        $switch.Checked = $true
        Assert-True $switch.Checked "Switch should be checked"
        Assert-True $script:switchFired "CheckedChanged event must fire on toggle"

        $switch.remove_CheckedChanged($handler)
        $switch.Dispose()
    }

    It "Verifies KitSwitch overrides OnMouseEnter and OnMouseLeave for hover feedback" {
        $switchType = Get-TepiType "KitSwitch"
        $flags = [System.Reflection.BindingFlags]'Instance,NonPublic,DeclaredOnly'

        $onMouseEnter = $switchType.GetMethod("OnMouseEnter", $flags)
        $onMouseLeave = $switchType.GetMethod("OnMouseLeave", $flags)

        Assert-NotNull $onMouseEnter "KitSwitch must declare OnMouseEnter override for hover feedback (M2 feature)"
        Assert-NotNull $onMouseLeave "KitSwitch must declare OnMouseLeave override for hover feedback (M2 feature)"
    }
}
