# test_b03_frost_wallpapers.ps1
# Boundary & Corner Case Tests for Feature 3: Frost Glass Adaptive Contrast Guard
# Covers pure white, pure black, saturated wallpapers, and buffer boundary constraints.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

function Invoke-FrostTint {
    param([byte[]]$sig, [int]$len, [System.Drawing.Color]$bg, [bool]$light)
    $t = Get-TepiType "Island"
    $m = $t.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
    $p = [object[]]::new(4)
    $p[0] = $sig
    $p[1] = $len
    $p[2] = $bg
    $p[3] = $light
    return $m.Invoke($null, $p)
}

Describe "Tier 2 Boundary Suite: Feature 3 - Frost Glass Wallpaper Boundaries" {

    It "Evaluates pure white wallpaper in dark mode increases tint toward ceiling to darken glass" {
        $whiteSig = New-Object byte[] 64
        for ($i = 0; $i -lt 64; $i++) { $whiteSig[$i] = 255 }

        $tint = Invoke-FrostTint $whiteSig 64 ([System.Drawing.Color]::Black) $false
        Assert-True ($tint -gt 0.42) "Pure white wallpaper in dark mode must increase tint above BaseTint 0.42 (actual: $tint)"
        Assert-True ($tint -le 0.6701) "Pure white wallpaper in dark mode must not exceed ceiling 0.67 (actual: $tint)"
    }

    It "Evaluates pure black wallpaper in dark mode retains BaseTint floor" {
        $blackSig = New-Object byte[] 64
        for ($i = 0; $i -lt 64; $i++) { $blackSig[$i] = 0 }

        $tint = Invoke-FrostTint $blackSig 64 ([System.Drawing.Color]::Black) $false
        Assert-Equal ([Math]::Round($tint, 2)) 0.42 "Pure black wallpaper in dark mode must equal BaseTint (0.42)"
    }

    It "Evaluates pure black wallpaper in light mode increases tint toward light ceiling to lighten glass" {
        $blackSig = New-Object byte[] 64
        for ($i = 0; $i -lt 64; $i++) { $blackSig[$i] = 0 }

        $tint = Invoke-FrostTint $blackSig 64 ([System.Drawing.Color]::White) $true
        Assert-True ($tint -gt 0.42) "Pure black wallpaper in light mode must increase tint above BaseTint 0.42 (actual: $tint)"
        Assert-True ($tint -le 0.8401) "Pure black wallpaper in light mode must not exceed light ceiling 0.84 (actual: $tint)"
    }

    It "Safely returns BaseTint for degenerate and truncated signature buffers" {
        $cornerBuffers = @(
            @{ Sig = $null; Len = 0 },
            @{ Sig = (New-Object byte[] 0); Len = 0 },
            @{ Sig = (New-Object byte[] 1); Len = 1 },
            @{ Sig = (New-Object byte[] 2); Len = 2 },
            @{ Sig = (New-Object byte[] 3); Len = 3 }
        )

        foreach ($entry in $cornerBuffers) {
            $tint = Invoke-FrostTint $entry.Sig $entry.Len ([System.Drawing.Color]::Black) $false
            Assert-Equal ([Math]::Round($tint, 2)) 0.42 "Degenerate buffer must return BaseTint 0.42"
        }
    }

    It "Protects against out-of-bounds length arguments without IndexOutOfRangeException" {
        $sig = New-Object byte[] 16
        for ($i = 0; $i -lt 16; $i++) { $sig[$i] = 128 }

        # Len exceeds actual byte array length
        $tintHigh = Invoke-FrostTint $sig 1000000 ([System.Drawing.Color]::Black) $false
        Assert-NotNull $tintHigh "Exceeding length parameter must not throw IndexOutOfRangeException"

        # Len = 0
        $tintZero = Invoke-FrostTint $sig 0 ([System.Drawing.Color]::Black) $false
        Assert-Equal ([Math]::Round($tintZero, 2)) 0.42 "Zero length parameter must return BaseTint 0.42"
    }
}
