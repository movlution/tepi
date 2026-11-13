# test_f03_frost_guard.ps1
# Feature 3: Frost Glass Adaptive Contrast Guard
# Verifies adaptive luminance contrast guard in Glass.cs prevents text dropping below 4.5:1 on pure white/high-luminance wallpapers.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 3: Frost Glass Adaptive Contrast Guard" {
    $island = Get-TepiType "Island"
    $computeMethod = $island.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]'NonPublic,Static')

    It "Verifies ComputeFrostTint method exists on Island engine" {
        Assert-NotNull $computeMethod "ComputeFrostTint static method must exist on Island"
    }

    It "Verifies Frost adaptive tint elevates to 0.67 on pure white wallpaper in dark mode" {
        $whiteBytes = [byte[]](,255 * 128)
        $argsWhiteDark = [object[]]@([byte[]]$whiteBytes, [int]128, [System.Drawing.Color]::Black, [bool]$false)
        $tint = $computeMethod.Invoke($null, $argsWhiteDark)

        Assert-Equal $tint 0.67 "Adaptive guard must elevate tint to 0.67 on white wallpaper in dark mode"
    }

    It "Verifies Frost adaptive tint elevates to 0.84 on pure black wallpaper in light mode" {
        $blackBytes = [byte[]](,0 * 128)
        $argsBlackLight = [object[]]@([byte[]]$blackBytes, [int]128, [System.Drawing.Color]::White, [bool]$true)
        $tint = $computeMethod.Invoke($null, $argsBlackLight)

        Assert-Equal $tint 0.84 "Adaptive guard must elevate tint to 0.84 on black wallpaper in light mode"
    }

    It "Verifies Frost adaptive tint returns base tint (0.42) when backdrop luminance naturally matches theme" {
        $blackBytes = [byte[]](,0 * 128)
        $argsBlackDark = [object[]]@([byte[]]$blackBytes, [int]128, [System.Drawing.Color]::Black, [bool]$false)
        $tintDark = $computeMethod.Invoke($null, $argsBlackDark)
        Assert-Equal $tintDark 0.42 "Base tint for black backdrop in dark mode must be 0.42"

        $whiteBytes = [byte[]](,255 * 128)
        $argsWhiteLight = [object[]]@([byte[]]$whiteBytes, [int]128, [System.Drawing.Color]::White, [bool]$true)
        $tintLight = $computeMethod.Invoke($null, $argsWhiteLight)
        Assert-Equal $tintLight 0.42 "Base tint for white backdrop in light mode must be 0.42"
    }

    It "Verifies guarded dark-mode frost over pure white background maintains >= 4.5:1 contrast for white text" {
        # White wallpaper is #FFFFFF. Tint is 0.67 with black base #000000.
        # Blended color = 0.67 * 0 + (1 - 0.67) * 255 = 0.33 * 255 = ~84
        $blendedChannel = [byte][Math]::Round(255 * (1.0 - 0.67))
        $guardedSurface = [System.Drawing.Color]::FromArgb(255, $blendedChannel, $blendedChannel, $blendedChannel)
        $whiteText = [System.Drawing.Color]::White

        $ratio = Assert-Contrast $whiteText $guardedSurface 4.5 "Guarded dark frost surface vs white text"
        Assert-True ($ratio -ge 4.5) "White text contrast on guarded frost surface must achieve >= 4.5:1 (actual: ${ratio}:1)"
    }
}
