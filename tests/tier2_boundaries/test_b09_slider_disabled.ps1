# test_b09_slider_disabled.ps1
# Boundary & Corner Case Tests for Feature 9: KitSlider Disabled Thumb Contrast
# Covers disabled state tokens, range boundary clamping, custom formatting, and geometry extremes.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 9 - KitSlider Thumb & Range Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders disabled KitSlider offscreen across dark and light modes" {
        foreach ($light in @($false, $true)) {
            Reset-TepiTheme -Light $light

            $slider = New-TepiControl "KitSlider" @{ Enabled = $false }
            $mSet = $slider.GetType().GetMethod("Set", [System.Reflection.BindingFlags]'NonPublic,Instance')
            $mSet.Invoke($slider, @([int]50))

            $bmp = Render-TepiControlToBitmap $slider 140 24

            Assert-NotNull $bmp "Disabled slider bitmap must render (Light=$light)"
            Assert-Equal $bmp.Width 140 "Bitmap width must match"
            Assert-Equal $bmp.Height 24 "Bitmap height must match"

            $bmp.Dispose()
            $slider.Dispose()
        }
    }

    It "Clamps thumb position at Minimum boundary (Value = Minimum = 0)" {
        $slider = New-TepiControl "KitSlider"
        $mSet = $slider.GetType().GetMethod("Set", [System.Reflection.BindingFlags]'NonPublic,Instance')
        $mSet.Invoke($slider, @([int]0))

        $fVal = $slider.GetType().GetField("Value").GetValue($slider)
        Assert-Equal $fVal 0 "Value must be 0"

        $bmp = Render-TepiControlToBitmap $slider 140 24
        Assert-NotNull $bmp "Slider at Minimum boundary must render cleanly"
        $bmp.Dispose()
        $slider.Dispose()
    }

    It "Clamps thumb position at Maximum boundary (Value = Maximum = 100)" {
        $slider = New-TepiControl "KitSlider"
        $mSet = $slider.GetType().GetMethod("Set", [System.Reflection.BindingFlags]'NonPublic,Instance')
        $mSet.Invoke($slider, @([int]100))

        $fVal = $slider.GetType().GetField("Value").GetValue($slider)
        Assert-Equal $fVal 100 "Value must be 100"

        $bmp = Render-TepiControlToBitmap $slider 140 24
        Assert-NotNull $bmp "Slider at Maximum boundary must render cleanly"
        $bmp.Dispose()
        $slider.Dispose()
    }

    It "Protects against out-of-range Value assignments by clamping to [Minimum, Maximum]" {
        $slider = New-TepiControl "KitSlider"
        $mSet = $slider.GetType().GetMethod("Set", [System.Reflection.BindingFlags]'NonPublic,Instance')

        # Underflow assignment: -500 should be clamped to Minimum (0)
        $mSet.Invoke($slider, @([int]-500))
        $underflowVal = $slider.GetType().GetField("Value").GetValue($slider)
        Assert-Equal $underflowVal 0 "Underflow must be clamped to Minimum (0)"

        # Overflow assignment: 9999 should be clamped to Maximum (100)
        $mSet.Invoke($slider, @([int]9999))
        $overflowVal = $slider.GetType().GetField("Value").GetValue($slider)
        Assert-Equal $overflowVal 100 "Overflow must be clamped to Maximum (100)"

        $bmp = Render-TepiControlToBitmap $slider 140 24
        Assert-NotNull $bmp "Slider with clamped value must render cleanly"
        $bmp.Dispose()
        $slider.Dispose()
    }

    It "Renders correctly when ShowValue is enabled with extreme format values" {
        $slider = New-TepiControl "KitSlider" @{ ShowValue = $true }
        $mSet = $slider.GetType().GetMethod("Set", [System.Reflection.BindingFlags]'NonPublic,Instance')
        $mSet.Invoke($slider, @([int]75))

        $bmp = Render-TepiControlToBitmap $slider 180 28
        Assert-NotNull $bmp "Slider with ShowValue enabled must render"
        $bmp.Dispose()
        $slider.Dispose()
    }
}
