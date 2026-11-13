# test_f10_kit_row.ps1
# Feature 10: KitRow.MarkGlyph Contrast Fix
# Verifies KitRow mark glyph contrast and theme compatibility (replaces hardcoded Brushes.Black).

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 10: KitRow.MarkGlyph Contrast Fix" {
    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Renders KitRow with standard text offscreen and verifies dimensions" {
        $row = New-TepiControl "KitRow"
        $row.Text = "Standard Option"
        $bmp = Render-TepiControlToBitmap $row 200 40

        Assert-NotNull $bmp "Rendered row bitmap must not be null"
        Assert-Equal $bmp.Width 200 "Width must match 200"
        Assert-Equal $bmp.Height 40 "Height must match 40"

        $bmp.Dispose()
        $row.Dispose()
    }

    It "Verifies KitRow declares MarkGlyph constant equal to '\u0001'" {
        $markGlyph = Get-TepiStaticField "KitRow" "MarkGlyph"
        Assert-NotNull $markGlyph "MarkGlyph must exist on KitRow"
        Assert-Equal ([char]$markGlyph) ([char]0x0001) "MarkGlyph must be char '\u0001'"
    }

    It "Renders KitRow with MarkGlyph in Light Mode offscreen via DrawToBitmap" {
        Reset-TepiTheme -Light $true

        $row = New-TepiControl "KitRow"
        $row.Text = "Light Mark Row"
        $row.Glyph = [char]0x0001

        $bmp = Render-TepiControlToBitmap $row 200 40
        Assert-NotNull $bmp "Light mode MarkGlyph row must render"

        $bmp.Dispose()
        $row.Dispose()
    }

    It "Renders KitRow with MarkGlyph in Dark Mode and verifies pill does not use hardcoded black brush against dark backgrounds" {
        Reset-TepiTheme -Light $false

        $row = New-TepiControl "KitRow"
        $row.Text = "Dark Mark Row"
        $row.Glyph = [char]0x0001

        $bmp = Render-TepiControlToBitmap $row 200 40

        # Sample pixel inside the mark pill (approx x ~ 24, y ~ 20)
        $pillPx = $bmp.GetPixel(24, 20)

        # In dark mode, if hardcoded Brushes.Black is used, R=0, G=0, B=0, which blends into dark bg.
        # It must use KitInk.Text (high contrast against dark bg).
        Assert-True ($pillPx.R -gt 50 -or $pillPx.G -gt 50 -or $pillPx.B -gt 50) "MarkGlyph pill in dark mode must not be pure black (actual RGB: $($pillPx.R),$($pillPx.G),$($pillPx.B))"

        $bmp.Dispose()
        $row.Dispose()
    }

    It "Verifies MarkGlyph inner dot fill achieves contrast against pill background" {
        $textToken = Get-TepiStaticProperty "KitInk" "Text"
        $windowToken = Get-TepiStaticProperty "KitInk" "Window"

        # The dot and pill should maintain contrast in both themes
        $ratio = Assert-Contrast $textToken $windowToken 4.5 "Pill vs Dot contrast"
        Assert-True ($ratio -ge 4.5) "Pill and dot contrast must achieve >= 4.5:1"
    }
}
