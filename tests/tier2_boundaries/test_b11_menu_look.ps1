# test_b11_menu_look.ps1
# Boundary & Corner Case Tests for Feature 11: MenuLook Submenu & Disabled Contrast
# Covers MenuLook token resolution, disabled item contrast, submenu arrows, and offscreen menu rendering.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 11 - MenuLook Contrast & Menu Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Inspects MenuLook color tokens in Dark Mode" {
        Reset-TepiTheme -Light $false
        $menuLookType = Get-TepiType "MenuLook"
        Assert-NotNull $menuLookType "MenuLook type must be resolvable"

        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'
        $bg = $menuLookType.GetProperty("Bg", $flags).GetValue($null, $null)
        $text = $menuLookType.GetProperty("Text", $flags).GetValue($null, $null)
        $sub = $menuLookType.GetProperty("Sub", $flags).GetValue($null, $null)

        Assert-NotNull $bg "MenuLook.Bg must not be null"
        Assert-NotNull $text "MenuLook.Text must not be null"
        Assert-NotNull $sub "MenuLook.Sub must not be null"

        Assert-Equal $bg.A 255 "MenuLook.Bg must be opaque"
        Assert-Equal $text.A 255 "MenuLook.Text must be opaque"
    }

    It "Inspects MenuLook color tokens in Light Mode" {
        Reset-TepiTheme -Light $true
        $menuLookType = Get-TepiType "MenuLook"
        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'
        $bg = $menuLookType.GetProperty("Bg", $flags).GetValue($null, $null)
        $text = $menuLookType.GetProperty("Text", $flags).GetValue($null, $null)
        $sub = $menuLookType.GetProperty("Sub", $flags).GetValue($null, $null)

        Assert-NotNull $bg "MenuLook.Bg in light mode must not be null"
        Assert-NotNull $text "MenuLook.Text in light mode must not be null"
        Assert-NotNull $sub "MenuLook.Sub in light mode must not be null"
    }

    It "Verifies normal text contrast against menu background in both dark and light modes" {
        $menuLookType = Get-TepiType "MenuLook"
        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'

        foreach ($light in @($false, $true)) {
            Reset-TepiTheme -Light $light
            $bg = $menuLookType.GetProperty("Bg", $flags).GetValue($null, $null)
            $text = $menuLookType.GetProperty("Text", $flags).GetValue($null, $null)

            $ratio = Get-WcagContrastRatio $text $bg
            Assert-True ($ratio -ge 4.5) "Menu text vs bg contrast in Light=$light must be >= 4.5:1 (actual: ${ratio}:1)"
        }
    }

    It "Evaluates disabled item and arrow Sub token contrast against menu background" {
        $menuLookType = Get-TepiType "MenuLook"
        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'

        foreach ($light in @($false, $true)) {
            Reset-TepiTheme -Light $light
            $bg = $menuLookType.GetProperty("Bg", $flags).GetValue($null, $null)
            $sub = $menuLookType.GetProperty("Sub", $flags).GetValue($null, $null)

            $ratio = Get-WcagContrastRatio $sub $bg
            Assert-True ($ratio -ge 2.5) "Menu sub vs bg contrast in Light=$light must be >= 2.5:1 (actual: ${ratio}:1)"
        }
    }

    It "Applies MenuLook to ContextMenuStrip containing enabled, disabled, and separator items" {
        $cms = New-Object System.Windows.Forms.ContextMenuStrip
        $item1 = $cms.Items.Add("Enabled Action")
        $item2 = $cms.Items.Add("Disabled Action")
        $item2.Enabled = $false
        [void]$cms.Items.Add("-")
        $item3 = $cms.Items.Add("Submenu Option")

        $t = Get-TepiType "MenuLook"
        $m = $t.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static', $null, @([System.Windows.Forms.ToolStripDropDownMenu]), $null)
        $m.Invoke($null, @($cms.psobject.BaseObject))

        Assert-NotNull $cms.Renderer "MenuLook renderer must be applied to ContextMenuStrip"
        Assert-Equal $cms.Renderer.GetType().Name "MenuLook" "Renderer must be MenuLook"

        $cms.Dispose()
    }
}
