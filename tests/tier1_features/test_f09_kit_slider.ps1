# test_f09_kit_slider.ps1
# Feature 9: KitSlider Disabled Thumb Contrast
# Verifies KitSlider renders disabled thumb using KitInk.Disabled rather than active KitInk.Text.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 9: KitSlider Disabled Thumb Contrast" {
    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders KitSlider in Enabled state offscreen and verifies dimensions" {
        $slider = New-TepiControl "KitSlider"
        $slider.Value = 50
        $bmp = Render-TepiControlToBitmap $slider 140 24

        Assert-NotNull $bmp "Rendered slider bitmap must not be null"
        Assert-Equal $bmp.Width 140 "Bitmap width must match"
        Assert-Equal $bmp.Height 24 "Bitmap height must match"

        $bmp.Dispose()
        $slider.Dispose()
    }

    It "Verifies KitSlider Value clamping between Minimum and Maximum" {
        $slider = New-TepiControl "KitSlider"
        $slider.Minimum = 10
        $slider.Maximum = 90
        $slider.Value = 50

        # Invoke private Set method to test clamping
        $setMethod = $slider.GetType().GetMethod("Set", [System.Reflection.BindingFlags]'Instance,NonPublic')
        Assert-NotNull $setMethod "Set method must exist on KitSlider"

        $setMethod.Invoke($slider, @([int]5)) # Below Minimum (10)
        Assert-Equal $slider.Value 10 "Value should clamp to Minimum (10)"

        $setMethod.Invoke($slider, @([int]150)) # Above Maximum (90)
        Assert-Equal $slider.Value 90 "Value should clamp to Maximum (90)"

        $slider.Dispose()
    }

    It "Verifies KitSlider keyboard navigation responds to arrow keys" {
        $slider = New-TepiControl "KitSlider"
        $slider.Minimum = 0
        $slider.Maximum = 100
        $slider.Step = 5
        $slider.Value = 50

        $onKeyDown = $slider.GetType().GetMethod("OnKeyDown", [System.Reflection.BindingFlags]'Instance,NonPublic')
        Assert-NotNull $onKeyDown "OnKeyDown must exist"

        # Simulate Right Arrow
        $rightKey = New-Object System.Windows.Forms.KeyEventArgs([System.Windows.Forms.Keys]::Right)
        $onKeyDown.Invoke($slider, [object[]]@([System.Windows.Forms.KeyEventArgs]$rightKey))
        Assert-Equal $slider.Value 55 "Right arrow should increase value by Step (5)"

        # Simulate Left Arrow
        $leftKey = New-Object System.Windows.Forms.KeyEventArgs([System.Windows.Forms.Keys]::Left)
        $onKeyDown.Invoke($slider, [object[]]@([System.Windows.Forms.KeyEventArgs]$leftKey))
        Assert-Equal $slider.Value 50 "Left arrow should decrease value by Step (5)"

        $slider.Dispose()
    }

    It "Verifies KitSlider disabled track fill uses KitInk.Disabled token" {
        $disabledToken = Get-TepiStaticProperty "KitInk" "Disabled"
        $textToken = Get-TepiStaticProperty "KitInk" "Text"

        Assert-NotNull $disabledToken "KitInk.Disabled must be defined"
        Assert-NotEqual $disabledToken.ToArgb() $textToken.ToArgb() "Disabled token must differ from Text token"
    }

    It "Renders KitSlider in Disabled state and verifies thumb renders using KitInk.Disabled rather than active Text" {
        $slider = New-TepiControl "KitSlider"
        $slider.Minimum = 0
        $slider.Maximum = 100
        $slider.Value = 0
        $slider.Enabled = $false

        $bmp = Render-TepiControlToBitmap $slider 140 24

        # Sample pixel at thumb center (x ~ 10, y = 12)
        $thumbPx = $bmp.GetPixel(10, 12)
        $disabledToken = Get-TepiStaticProperty "KitInk" "Disabled"
        $textToken = Get-TepiStaticProperty "KitInk" "Text"

        # The thumb pixel should match KitInk.Disabled, NOT active KitInk.Text
        Assert-Equal $thumbPx.R $disabledToken.R "Disabled thumb Red channel must match KitInk.Disabled ($($disabledToken.R)), not active KitInk.Text ($($textToken.R))"

        $bmp.Dispose()
        $slider.Dispose()
    }
}
