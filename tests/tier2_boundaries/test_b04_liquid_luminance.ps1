# test_b04_liquid_luminance.ps1
# Boundary & Corner Case Tests for Feature 4: Liquid Glass Color Space Blending
# Covers sRGB LUT conversion, clamping boundaries, monotonic progression, and luminance invariants.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 4 - Liquid Glass Color Space Boundaries" {

    It "Clamps lower bound ToSrgb(0.0) and negative values strictly to 0" {
        $bZero = Invoke-TepiStaticMethod "Island" "ToSrgb" @([float]0.0)
        Assert-Equal $bZero ([byte]0) "ToSrgb(0.0) must equal byte 0"

        $negatives = @(-0.001, -0.1, -1.0, -100.0)
        foreach ($neg in $negatives) {
            $bNeg = Invoke-TepiStaticMethod "Island" "ToSrgb" @([float]$neg)
            Assert-Equal $bNeg ([byte]0) "ToSrgb($neg) must clamp to byte 0"
        }
    }

    It "Clamps upper bound ToSrgb(1.0) and positive overflow values strictly to 255" {
        $bOne = Invoke-TepiStaticMethod "Island" "ToSrgb" @([float]1.0)
        Assert-Equal $bOne ([byte]255) "ToSrgb(1.0) must equal byte 255"

        $overflows = @(1.001, 1.5, 2.0, 50.0)
        foreach ($ovf in $overflows) {
            $bOvf = Invoke-TepiStaticMethod "Island" "ToSrgb" @([float]$ovf)
            Assert-Equal $bOvf ([byte]255) "ToSrgb($ovf) must clamp to byte 255"
        }
    }

    It "Validates monotonic non-decreasing progression across 0.0 to 1.0" {
        $prev = [byte]0
        for ($i = 0; $i -le 100; $i++) {
            $lin = [float]($i / 100.0)
            $curr = Invoke-TepiStaticMethod "Island" "ToSrgb" @($lin)
            Assert-True ($curr -ge $prev) "ToSrgb must be monotonically non-decreasing at lin=$lin ($curr >= $prev)"
            $prev = $curr
        }
    }

    It "Verifies Linear luminance lookup table has 256 elements mapping 0 to 0.0 and 255 to 1.0" {
        $linearTable = Get-TepiStaticField "Island" "Linear"
        Assert-NotNull $linearTable "Linear lookup table must not be null"
        Assert-Equal $linearTable.Length 256 "Linear table must have exactly 256 entries"
        Assert-Equal ([double]$linearTable[0]) 0.0 "Linear[0] must equal 0.0"
        Assert-Equal ([Math]::Round([double]$linearTable[255], 3)) 1.0 "Linear[255] must equal 1.0"
    }

    It "Evaluates Luma calculation on boundary pure colors" {
        $lumaBlack = Invoke-TepiStaticMethod "Island" "Luma" @([System.Drawing.Color]::Black)
        $lumaWhite = Invoke-TepiStaticMethod "Island" "Luma" @([System.Drawing.Color]::White)
        $lumaRed = Invoke-TepiStaticMethod "Island" "Luma" @([System.Drawing.Color]::FromArgb(255, 255, 0, 0))
        $lumaGreen = Invoke-TepiStaticMethod "Island" "Luma" @([System.Drawing.Color]::FromArgb(255, 0, 255, 0))
        $lumaBlue = Invoke-TepiStaticMethod "Island" "Luma" @([System.Drawing.Color]::FromArgb(255, 0, 0, 255))

        Assert-Equal ([double]$lumaBlack) 0.0 "Luma of Black must be 0.0"
        Assert-Equal ([Math]::Round([double]$lumaWhite, 3)) 1.0 "Luma of White must be 1.0"
        # Green has highest luminance coefficient (~0.7152), Blue lowest (~0.0722)
        Assert-True ($lumaGreen -gt $lumaRed) "Green luma ($lumaGreen) must exceed Red luma ($lumaRed)"
        Assert-True ($lumaRed -gt $lumaBlue) "Red luma ($lumaRed) must exceed Blue luma ($lumaBlue)"
    }
}
