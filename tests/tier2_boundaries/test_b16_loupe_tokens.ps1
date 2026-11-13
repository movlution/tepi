# test_b16_loupe_tokens.ps1
# Boundary & Corner Case Tests for Feature 16: ColorPicker Loupe Token Alignment
# Covers loupe offscreen rendering, extreme pixel color sampling, coordinate boundaries, and HexOf formatting.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 16 - ColorPicker Loupe & Pixel Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Resolves PickerOverlay+Loupe type and creates instance offscreen" {
        $loupeType = Get-TepiType "PickerOverlay+Loupe"
        Assert-NotNull $loupeType "PickerOverlay+Loupe type must be resolvable"

        $loupe = [Activator]::CreateInstance($loupeType)
        Assert-NotNull $loupe "Loupe instance must allocate"
        Assert-True ($loupe.Width -gt 0) "Loupe width must be positive"
        Assert-True ($loupe.Height -gt 0) "Loupe height must be positive"

        $loupe.Dispose()
    }

    It "Renders Loupe offscreen when sampling pure black #000000 pixel" {
        $loupeType = Get-TepiType "PickerOverlay+Loupe"
        $loupe = [Activator]::CreateInstance($loupeType)

        $sampleBmp = New-Object System.Drawing.Bitmap 11, 11
        $g = [System.Drawing.Graphics]::FromImage($sampleBmp)
        $g.Clear([System.Drawing.Color]::Black)
        $g.Dispose()

        $showMethod = $loupeType.GetMethods() | Where-Object { $_.Name -eq 'Show' -and $_.GetParameters().Length -eq 4 } | Select-Object -First 1
        $p = [object[]]::new(4)
        $p[0] = $sampleBmp.psobject.BaseObject
        $p[1] = [System.Drawing.Color]::Black
        $p[2] = (New-Object System.Drawing.Point 100, 100).psobject.BaseObject
        $p[3] = 8
        $showMethod.Invoke($loupe, $p)

        $renderBmp = Render-TepiControlToBitmap $loupe $loupe.Width $loupe.Height
        Assert-NotNull $renderBmp "Rendered loupe bitmap for pure black sample"

        $renderBmp.Dispose()
        $sampleBmp.Dispose()
        $loupe.Dispose()
    }

    It "Renders Loupe offscreen when sampling pure white #FFFFFF pixel" {
        $loupeType = Get-TepiType "PickerOverlay+Loupe"
        $loupe = [Activator]::CreateInstance($loupeType)

        $sampleBmp = New-Object System.Drawing.Bitmap 11, 11
        $g = [System.Drawing.Graphics]::FromImage($sampleBmp)
        $g.Clear([System.Drawing.Color]::White)
        $g.Dispose()

        $showMethod = $loupeType.GetMethods() | Where-Object { $_.Name -eq 'Show' -and $_.GetParameters().Length -eq 4 } | Select-Object -First 1
        $p = [object[]]::new(4)
        $p[0] = $sampleBmp.psobject.BaseObject
        $p[1] = [System.Drawing.Color]::White
        $p[2] = (New-Object System.Drawing.Point 100, 100).psobject.BaseObject
        $p[3] = 8
        $showMethod.Invoke($loupe, $p)

        $renderBmp = Render-TepiControlToBitmap $loupe $loupe.Width $loupe.Height
        Assert-NotNull $renderBmp "Rendered loupe bitmap for pure white sample"

        $renderBmp.Dispose()
        $sampleBmp.Dispose()
        $loupe.Dispose()
    }

    It "Handles screen edge and extreme negative coordinate boundaries safely" {
        $loupeType = Get-TepiType "PickerOverlay+Loupe"
        $loupe = [Activator]::CreateInstance($loupeType)
        $sampleBmp = New-Object System.Drawing.Bitmap 11, 11
        $showMethod = $loupeType.GetMethods() | Where-Object { $_.Name -eq 'Show' -and $_.GetParameters().Length -eq 4 } | Select-Object -First 1

        $extremePoints = @(
            (New-Object System.Drawing.Point 0, 0),
            (New-Object System.Drawing.Point -1000, -1000),
            (New-Object System.Drawing.Point 10000, 10000)
        )

        foreach ($pt in $extremePoints) {
            $p = [object[]]::new(4)
            $p[0] = $sampleBmp.psobject.BaseObject
            $p[1] = [System.Drawing.Color]::Red
            $p[2] = $pt.psobject.BaseObject
            $p[3] = 8
            $showMethod.Invoke($loupe, $p)
            Assert-NotNull $loupe.Location "Loupe location must resolve cleanly for coordinate ($($pt.X), $($pt.Y))"
        }

        $sampleBmp.Dispose()
        $loupe.Dispose()
    }

    It "Validates Island.HexOf color serialization format invariants" {
        $testColors = @(
            @{ C = [System.Drawing.Color]::Black; Expected = "#000000" },
            @{ C = [System.Drawing.Color]::White; Expected = "#FFFFFF" },
            @{ C = [System.Drawing.Color]::FromArgb(255, 255, 0, 0); Expected = "#FF0000" },
            @{ C = [System.Drawing.Color]::FromArgb(255, 0, 255, 0); Expected = "#00FF00" },
            @{ C = [System.Drawing.Color]::FromArgb(255, 0, 0, 255); Expected = "#0000FF" }
        )

        foreach ($tc in $testColors) {
            $hex = Invoke-TepiStaticMethod "Island" "HexOf" @($tc.C)
            Assert-Equal $hex.ToUpperInvariant() $tc.Expected "HexOf for $($tc.C) must equal $($tc.Expected)"
        }
    }
}
