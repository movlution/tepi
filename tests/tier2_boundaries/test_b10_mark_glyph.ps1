# test_b10_mark_glyph.ps1
# Boundary & Corner Case Tests for Feature 10: KitRow.MarkGlyph Contrast Fix
# Covers MarkGlyph icon rendering, theme compatibility, row geometry boundaries, and text extremes.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 10 - KitRow MarkGlyph & Geometry Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders KitRow with MarkGlyph in Dark Mode offscreen" {
        $row = New-TepiControl "KitRow" @{
            Title = "Tepi System Mark"
            Detail = "MarkGlyph rendering verification"
            Glyph = [char]1
        }

        $bmp = Render-TepiControlToBitmap $row 240 48
        Assert-NotNull $bmp "MarkGlyph row must render in Dark Mode"
        Assert-Equal $bmp.Width 240 "Width must match"
        Assert-Equal $bmp.Height 48 "Height must match"

        $bmp.Dispose()
        $row.Dispose()
    }

    It "Renders KitRow with MarkGlyph in Light Mode offscreen" {
        Reset-TepiTheme -Light $true

        $row = New-TepiControl "KitRow" @{
            Title = "Tepi System Mark (Light)"
            Detail = "Light theme contrast verification"
            Glyph = [char]1
        }

        $bmp = Render-TepiControlToBitmap $row 240 48
        Assert-NotNull $bmp "MarkGlyph row must render in Light Mode"

        $bmp.Dispose()
        $row.Dispose()
    }

    It "Renders disabled KitRow with MarkGlyph safely" {
        $row = New-TepiControl "KitRow" @{
            Title = "Disabled Item"
            Detail = "Grayed out state"
            Glyph = [char]1
            Enabled = $false
        }

        $bmp = Render-TepiControlToBitmap $row 240 48
        Assert-NotNull $bmp "Disabled MarkGlyph row must render safely"

        $bmp.Dispose()
        $row.Dispose()
    }

    It "Handles text payload extremes: empty strings and 300-character descriptions" {
        $payloads = @(
            @{ Title = ""; Detail = "" },
            @{ Title = "Short"; Detail = "" },
            @{ Title = ""; Detail = "Detail only" },
            @{ Title = ("T" * 200); Detail = ("D" * 200) }
        )

        foreach ($p in $payloads) {
            $row = New-TepiControl "KitRow" @{
                Title = $p.Title
                Detail = $p.Detail
                Glyph = [char]1
            }

            $bmp = Render-TepiControlToBitmap $row 260 52
            Assert-NotNull $bmp "Row with Title len $($p.Title.Length) must render cleanly"

            $bmp.Dispose()
            $row.Dispose()
        }
    }

    It "Adapts tile geometry across row height boundaries from compact 24px to tall 120px" {
        $heights = @(24, 36, 48, 80, 100, 120)
        foreach ($h in $heights) {
            $row = New-TepiControl "KitRow" @{
                Title = "Height Test $h"
                Glyph = [char]1
            }

            $bmp = Render-TepiControlToBitmap $row 220 $h
            Assert-NotNull $bmp "Row must render at height $h px"
            Assert-Equal $bmp.Height $h "Bitmap height must equal $h"

            $bmp.Dispose()
            $row.Dispose()
        }
    }
}
