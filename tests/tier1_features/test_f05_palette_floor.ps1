# test_f05_palette_floor.ps1
# Feature 5: Custom Palette Contrast Floor
# Verifies minimum contrast thresholds in Colors.DerivePalette preventing user-selected low-contrast combinations.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 5: Custom Palette Contrast Floor" {
    $island = Get-TepiType "Island"
    $derive = $island.GetMethod("DerivePalette", [System.Reflection.BindingFlags]'Public,Static')

    It "Verifies DerivePalette static method exists on Island" {
        Assert-NotNull $derive "DerivePalette method must exist"
    }

    It "Verifies DerivePalette enforces text contrast >= 7.0:1 against bg for low-contrast input on white background" {
        $bg = [System.Drawing.Color]::White
        $lowText = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0") # ~1.3:1 naturally
        $lowAccent = [System.Drawing.ColorTranslator]::FromHtml("#FFFF00") # Yellow

        $dict = $derive.Invoke($null, @($bg, $lowText, $lowAccent))
        $text = [System.Drawing.ColorTranslator]::FromHtml($dict["text"])

        $ratio = Assert-Contrast $text $bg 7.0 "Enforced text contrast on white background"
        Assert-True ($ratio -ge 7.0) "Derived text contrast must achieve >= 7.0:1 (actual: ${ratio}:1)"
    }

    It "Verifies DerivePalette enforces sub contrast >= 4.5:1 against bg" {
        $bg = [System.Drawing.Color]::White
        $lowText = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
        $lowAccent = [System.Drawing.ColorTranslator]::FromHtml("#FFFF00")

        $dict = $derive.Invoke($null, @($bg, $lowText, $lowAccent))
        $sub = [System.Drawing.ColorTranslator]::FromHtml($dict["sub"])

        $ratio = Assert-Contrast $sub $bg 4.5 "Enforced sub text contrast on white background"
        Assert-True ($ratio -ge 4.5) "Derived sub contrast must achieve >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Verifies DerivePalette enforces faint contrast >= 3.0:1 against bg" {
        $bg = [System.Drawing.Color]::White
        $lowText = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
        $lowAccent = [System.Drawing.ColorTranslator]::FromHtml("#FFFF00")

        $dict = $derive.Invoke($null, @($bg, $lowText, $lowAccent))
        $faint = [System.Drawing.ColorTranslator]::FromHtml($dict["faint"])

        $ratio = Assert-Contrast $faint $bg 3.0 "Enforced faint text contrast on white background"
        Assert-True ($ratio -ge 3.0) "Derived faint contrast must achieve >= 3.0:1 (actual: ${ratio}:1)"
    }

    It "Verifies DerivePalette enforces accent contrast >= 3.5:1 against bg and onAccent >= 4.5:1" {
        $bg = [System.Drawing.Color]::White
        $lowText = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
        $lowAccent = [System.Drawing.ColorTranslator]::FromHtml("#FFFF00")

        $dict = $derive.Invoke($null, @($bg, $lowText, $lowAccent))
        $accent = [System.Drawing.ColorTranslator]::FromHtml($dict["accent"])
        $onAccent = [System.Drawing.ColorTranslator]::FromHtml($dict["onAccent"])

        $rAccent = Assert-Contrast $accent $bg 3.5 "Enforced accent contrast"
        $rOnAccent = Assert-Contrast $onAccent $accent 4.5 "Enforced onAccent contrast"

        Assert-True ($rAccent -ge 3.5) "Accent contrast must be >= 3.5:1"
        Assert-True ($rOnAccent -ge 4.5) "OnAccent contrast must be >= 4.5:1"
    }

    It "Verifies DerivePalette enforces symmetric contrast floors on dark background inputs" {
        $darkBg = [System.Drawing.Color]::FromArgb(255, 18, 18, 20)
        $darkLowText = [System.Drawing.Color]::FromArgb(255, 30, 30, 32)
        $darkLowAccent = [System.Drawing.Color]::FromArgb(255, 25, 25, 28)

        $dict = $derive.Invoke($null, @($darkBg, $darkLowText, $darkLowAccent))

        $text = [System.Drawing.ColorTranslator]::FromHtml($dict["text"])
        $sub = [System.Drawing.ColorTranslator]::FromHtml($dict["sub"])
        $faint = [System.Drawing.ColorTranslator]::FromHtml($dict["faint"])
        $accent = [System.Drawing.ColorTranslator]::FromHtml($dict["accent"])

        Assert-Contrast $text $darkBg 7.0 "Dark bg text floor >= 7.0:1"
        Assert-Contrast $sub $darkBg 4.5 "Dark bg sub floor >= 4.5:1"
        Assert-Contrast $faint $darkBg 3.0 "Dark bg faint floor >= 3.0:1"
        Assert-Contrast $accent $darkBg 3.5 "Dark bg accent floor >= 3.5:1"
    }
}
