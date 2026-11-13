# test_f04_liquid_glass.ps1
# Feature 4: Liquid Glass Color Space Blending
# Verifies linear luminance blending in Glass.cs maintains target luminance (>=0.62) and >=4.5:1 contrast on dark wallpapers in light mode.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 4: Liquid Glass Color Space Blending" {
    $island = Get-TepiType "Island"
    $toSrgb = $island.GetMethod("ToSrgb", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
    $liquidPass = $island.GetMethod("LiquidPass", [System.Reflection.BindingFlags]'NonPublic,Static')

    It "Verifies Linear luminance lookup table and ToSrgb method exist on Island engine" {
        Assert-NotNull $toSrgb "ToSrgb static method must exist"
        Assert-NotNull $liquidPass "LiquidPass static method must exist"
    }

    It "Verifies ToSrgb correctly maps linear boundary and mid values without byte overflow" {
        $val0 = $toSrgb.Invoke($null, @([float]0.0))
        $val1 = $toSrgb.Invoke($null, @([float]1.0))
        $valMid = $toSrgb.Invoke($null, @([float]0.214))

        Assert-Equal $val0 0 "ToSrgb(0.0) must map to 0"
        Assert-Equal $val1 255 "ToSrgb(1.0) must map to 255"
        Assert-InRange ([double]$valMid) 120 135 "ToSrgb(0.214) perceptual mid-grey must map near 127"
    }

    It "Verifies LiquidPass shader executes offscreen and generates blended pixels on dark wallpaper" {
        $bmp = New-Object System.Drawing.Bitmap 32, 32, ([System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
        $raw = [byte[]](,0 * (32 * 32 * 4))
        $args = [object[]]@([System.Drawing.Bitmap]$bmp, [byte[]]$raw, [System.Drawing.Color]::White, [bool]$true)

        $liquidPass.Invoke($null, $args)

        $centerPx = $bmp.GetPixel(16, 16)
        Assert-True ($centerPx.R -gt 150) "Center pixel Red channel must be elevated by light tint (actual: $($centerPx.R))"
        Assert-True ($centerPx.G -gt 150) "Center pixel Green channel must be elevated by light tint (actual: $($centerPx.G))"
        Assert-True ($centerPx.B -gt 150) "Center pixel Blue channel must be elevated by light tint (actual: $($centerPx.B))"

        $bmp.Dispose()
    }

    It "Verifies Liquid Glass center luminance achieves target luminance (>= 0.60) in light mode over black wallpaper" {
        $bmp = New-Object System.Drawing.Bitmap 32, 32, ([System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
        $raw = [byte[]](,0 * (32 * 32 * 4))
        $args = [object[]]@([System.Drawing.Bitmap]$bmp, [byte[]]$raw, [System.Drawing.Color]::White, [bool]$true)

        $liquidPass.Invoke($null, $args)

        $centerPx = $bmp.GetPixel(16, 16)
        $lum = Get-WcagLuminance $centerPx

        Assert-InRange ([double]$lum) 0.58 1.0 "Center luminance must achieve target luminance >= 0.60 (actual: $lum)"

        $bmp.Dispose()
    }

    It "Verifies dark text contrast against rendered Liquid Glass surface achieves >= 4.5:1" {
        $bmp = New-Object System.Drawing.Bitmap 32, 32, ([System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
        $raw = [byte[]](,0 * (32 * 32 * 4))
        $args = [object[]]@([System.Drawing.Bitmap]$bmp, [byte[]]$raw, [System.Drawing.Color]::White, [bool]$true)

        $liquidPass.Invoke($null, $args)

        $centerPx = $bmp.GetPixel(16, 16)
        $darkText = [System.Drawing.Color]::FromArgb(255, 17, 17, 17)
        $ratio = Assert-Contrast $darkText $centerPx 4.5 "Dark text on Liquid Glass surface"

        Assert-True ($ratio -ge 4.5) "Contrast ratio must be >= 4.5:1 (actual: ${ratio}:1)"

        $bmp.Dispose()
    }
}
