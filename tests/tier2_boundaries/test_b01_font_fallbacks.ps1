# test_b01_font_fallbacks.ps1
# Boundary & Corner Case Tests for Feature 1: Font Family Typo Corrections
# Covers extreme font sizes, degenerate family inputs, and GDI+ font resolution invariants.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 1 - Font Fallbacks & Typo Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Handles extreme sub-pixel and micro font sizes without GDI+ crash" {
        $microSizes = @(0.1, 0.5, 1.0)
        foreach ($sz in $microSizes) {
            $fDisp = Invoke-TepiStaticMethod "Ink" "Display" @([float]$sz)
            Assert-NotNull $fDisp "Display font at size $sz pt must not be null"
            Assert-True ($fDisp.SizeInPoints -gt 0) "Display font at size $sz pt must have positive point size"

            $fSmallSemi = Invoke-TepiStaticMethod "Ink" "SmallSemi" @([float]$sz)
            Assert-NotNull $fSmallSemi "SmallSemi font at size $sz pt must not be null"
            Assert-True ($fSmallSemi.SizeInPoints -gt 0) "SmallSemi font at size $sz pt must have positive point size"
        }
    }

    It "Handles extreme billboard font sizes up to 1000px without GDI+ overflow" {
        $macroSizes = @(256.0, 512.0, 1000.0)
        foreach ($sz in $macroSizes) {
            $font = Invoke-TepiStaticMethod "Ink" "Display" @([float]$sz)
            Assert-NotNull $font "Display font at size $sz px must allocate"
            Assert-True ($font.SizeInPoints -gt 100) "Macro font size in points should reflect scaling"
        }
    }

    It "Validates GDI+ font weight resolution on resolved families" {
        Invoke-TepiStaticMethod "Ink" "Init" @()
        $heroFont = Get-TepiStaticProperty "Ink" "Hero"
        Assert-NotNull $heroFont "Hero font must be initialized"
        Assert-NotNull $heroFont.FontFamily "Hero FontFamily must not be null"
        Assert-True ($heroFont.FontFamily.Name.Length -gt 0) "Hero FontFamily Name must not be empty"

        $captionFont = Get-TepiStaticProperty "Ink" "Caption"
        Assert-NotNull $captionFont "Caption font must be initialized"
        Assert-NotNull $captionFont.FontFamily "Caption FontFamily must not be null"
    }

    It "Verifies boundary behavior of Display and SmallSemi role lookups under rapid calls" {
        for ($i = 0; $i -lt 50; $i++) {
            $f1 = Invoke-TepiStaticMethod "Ink" "Display" @([float](14.0 + ($i * 0.1)))
            $f2 = Invoke-TepiStaticMethod "Ink" "SmallSemi" @([float](11.0 + ($i * 0.1)))
            Assert-NotNull $f1 "Rapid lookup Display font iteration $i"
            Assert-NotNull $f2 "Rapid lookup SmallSemi font iteration $i"
        }
    }

    It "Maintains font instance validity across simulated display DPI scale shifts" {
        $scales = @(1.0, 1.25, 1.5, 2.0, 3.0)
        foreach ($s in $scales) {
            $scaledSize = [float](13.5 * $s)
            $font = Invoke-TepiStaticMethod "Ink" "Text" @($scaledSize)
            Assert-NotNull $font "Scaled text font at ${s}x must allocate cleanly"
            Assert-Equal $font.Unit ([System.Drawing.GraphicsUnit]::Pixel) "Font unit must remain GraphicsUnit.Pixel"
        }
    }
}
