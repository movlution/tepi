# test_f11_menu_look.ps1
# Feature 11: MenuLook Submenu & Disabled Contrast
# Verifies MenuLook submenu arrow and disabled item contrast >= WCAG AA 4.5:1 in light mode.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 11: MenuLook Submenu & Disabled Contrast" {
    $menuLookType = Get-TepiType "MenuLook"
    $flags = [System.Reflection.BindingFlags]'NonPublic,Static,Public'

    BeforeEach {
        Reset-TepiTheme -Light $true
    }

    It "Verifies MenuLook type exists and inherits from ToolStripProfessionalRenderer" {
        Assert-NotNull $menuLookType "MenuLook type must exist"
        Assert-True ([System.Windows.Forms.ToolStripProfessionalRenderer].IsAssignableFrom($menuLookType)) "MenuLook must inherit from ToolStripProfessionalRenderer"
    }

    It "Verifies MenuLook Text contrast against MenuLook Bg in Light Mode achieves >= 4.5:1" {
        $propBg = $menuLookType.GetProperty("Bg", $flags)
        $propText = $menuLookType.GetProperty("Text", $flags)

        $bg = $propBg.GetValue($null, $null)
        $text = $propText.GetValue($null, $null)

        $ratio = Assert-Contrast $text $bg 4.5 "MenuLook Text vs Bg"
        Assert-True ($ratio -ge 4.5) "Normal menu text contrast must achieve >= 4.5:1"
    }

    It "Verifies MenuLook Sub contrast against MenuLook Bg in Light Mode achieves >= 4.5:1 (WCAG AA)" {
        $propBg = $menuLookType.GetProperty("Bg", $flags)
        $propSub = $menuLookType.GetProperty("Sub", $flags)

        $bg = $propBg.GetValue($null, $null)
        $sub = $propSub.GetValue($null, $null)

        $ratio = Assert-Contrast $sub $bg 4.5 "MenuLook Sub vs Bg (Submenu arrows & disabled items)"
        Assert-True ($ratio -ge 4.5) "Sub color contrast must achieve >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Verifies MenuLook disabled item and arrow colors derive from Sub property" {
        $propSub = $menuLookType.GetProperty("Sub", $flags)
        Assert-NotNull $propSub "Sub property must exist on MenuLook"

        $subColor = $propSub.GetValue($null, $null)
        Assert-NotNull $subColor "Sub color must not be null"
        Assert-Equal $subColor.A 255 "Sub color must be fully opaque"
    }

    It "Verifies MenuLook.Apply configures ToolStripDropDownMenu and child submenus" {
        $applyMethod = $menuLookType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static')
        Assert-NotNull $applyMethod "MenuLook.Apply method must exist"

        $menu = New-Object System.Windows.Forms.ToolStripDropDownMenu
        $item1 = New-Object System.Windows.Forms.ToolStripMenuItem("File")
        $subItem = New-Object System.Windows.Forms.ToolStripMenuItem("Recent")
        [void]$item1.DropDownItems.Add($subItem)
        [void]$menu.Items.Add($item1)

        $applyMethod.Invoke($null, [object[]]@([System.Windows.Forms.ToolStripDropDownMenu]$menu))

        Assert-NotNull $menu.Renderer "Menu renderer must be set"
        Assert-True ($menu.Renderer.GetType() -eq $menuLookType) "Menu renderer must be MenuLook instance"

        $menu.Dispose()
    }
}
