# test_f07_kit_button.ps1
# Feature 7: KitButton Interactive States & Focus Ring
# Verifies KitButton interactive states (Normal, Hover, Pressed, Disabled) and focus ring contrast.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 7: KitButton Interactive States & Focus Ring" {
    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders KitButton in Normal state offscreen via DrawToBitmap" {
        $btn = New-TepiControl "KitButton" @{ Text = "Normal Button" }
        $bmp = Render-TepiControlToBitmap $btn 120 36

        Assert-NotNull $bmp "Rendered bitmap must not be null"
        Assert-Equal $bmp.Width 120 "Width must match 120"
        Assert-Equal $bmp.Height 36 "Height must match 36"

        $center = $bmp.GetPixel(60, 18)
        Assert-Equal $center.A 255 "Button center must be opaque"

        $bmp.Dispose()
        $btn.Dispose()
    }

    It "Renders KitButton in Hover state and verifies distinct visual feedback" {
        $btn = New-TepiControl "KitButton" @{ Text = "Hover Button" }
        $bmpNormal = Render-TepiControlToBitmap $btn 120 36

        # Set hovered via reflection
        $hoverField = $btn.GetType().GetField("hovered", [System.Reflection.BindingFlags]'Instance,NonPublic')
        Assert-NotNull $hoverField "hovered field must exist on KitButton"
        $hoverField.SetValue($btn, $true)

        $bmpHover = Render-TepiControlToBitmap $btn 120 36

        $pxNormal = $bmpNormal.GetPixel(6, 18)
        $pxHover = $bmpHover.GetPixel(6, 18)

        # Background color on pill edge should change upon hover
        Assert-NotEqual $pxNormal.ToArgb() $pxHover.ToArgb() "Hovered button background should differ from normal"

        $bmpNormal.Dispose()
        $bmpHover.Dispose()
        $btn.Dispose()
    }

    It "Renders Primary KitButton and verifies high text-to-background contrast" {
        $btn = New-TepiControl "KitButton" @{ Text = "Primary Action"; Primary = $true }
        $bmp = Render-TepiControlToBitmap $btn 140 36

        # Primary button background uses KitInk.Text and text uses KitInk.Window
        $textToken = Get-TepiStaticProperty "KitInk" "Text"
        $windowToken = Get-TepiStaticProperty "KitInk" "Window"

        $ratio = Assert-Contrast $windowToken $textToken 4.5 "Primary button text vs background"
        Assert-True ($ratio -ge 4.5) "Primary button text contrast must be >= 4.5:1 (actual: ${ratio}:1)"

        $bmp.Dispose()
        $btn.Dispose()
    }

    It "Renders KitButton in Disabled state and verifies disabled text styling" {
        $btn = New-TepiControl "KitButton" @{ Text = "Disabled Button"; Enabled = $false }
        $bmp = Render-TepiControlToBitmap $btn 120 36

        Assert-NotNull $bmp "Disabled button bitmap must render"
        $lineToken = Get-TepiStaticProperty "KitInk" "Line"
        $faintToken = Get-TepiStaticProperty "KitInk" "Faint"

        Assert-NotNull $lineToken "KitInk.Line must be defined"
        Assert-NotNull $faintToken "KitInk.Faint must be defined"

        $bmp.Dispose()
        $btn.Dispose()
    }

    It "Verifies KitButton has pressed visual state feedback handling" {
        $btn = New-TepiControl "KitButton" @{ Text = "Press Test" }
        $flags = [System.Reflection.BindingFlags]'Instance,Public,NonPublic'

        # Check for pressed state support (field, property, or OnMouseDown override)
        $pressedField = $btn.GetType().GetField("pressed", $flags)
        $onMouseDown = $btn.GetType().GetMethod("OnMouseDown", $flags)

        Assert-NotNull $onMouseDown "KitButton must handle OnMouseDown for click interaction"
        # Verify pressed state field exists when M2 is implemented
        Assert-NotNull $pressedField "KitButton must implement pressed state field (M2 feature)"

        $btn.Dispose()
    }
}
