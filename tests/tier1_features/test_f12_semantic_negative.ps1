# test_f12_semantic_negative.ps1
# Feature 12: Eliminate Hardcoded Semantic Red
# Verifies semantic negative token replaces hardcoded IndianRed / ad-hoc red and maintains >= 4.5:1 contrast.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 12: Eliminate Hardcoded Semantic Red" {
    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Verifies Ink.Base.Negative token exists and is a valid opaque Color" {
        $base = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $base "Ink.Base must not be null"

        $prop = $base.GetType().GetProperty("Negative")
        if (-not $prop) { $prop = $base.GetType().GetField("Negative") }
        Assert-NotNull $prop "Negative property/field must exist on Tone"

        $neg = if ($prop -is [System.Reflection.PropertyInfo]) { $prop.GetValue($base, $null) } else { $prop.GetValue($base) }
        Assert-NotNull $neg "Negative color must not be null"
        Assert-Equal $neg.A 255 "Negative token must be fully opaque"
    }

    It "Verifies Ink.Base.Negative contrast in Dark Mode achieves >= 4.5:1 against Ink.Base.Bg" {
        Reset-TepiTheme -Light $false
        $base = Get-TepiStaticField "Ink" "Base"
        $neg = $base.Negative
        $bg = $base.Bg

        $ratio = Assert-Contrast $neg $bg 4.5 "Dark Mode Negative vs Bg"
        Assert-True ($ratio -ge 4.5) "Contrast in Dark Mode must achieve >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Verifies Ink.Base.Negative contrast in Light Mode achieves >= 4.5:1 against Ink.Base.Bg" {
        Reset-TepiTheme -Light $true
        $base = Get-TepiStaticField "Ink" "Base"
        $neg = $base.Negative
        $bg = $base.Bg

        $ratio = Assert-Contrast $neg $bg 4.5 "Light Mode Negative vs Bg"
        Assert-True ($ratio -ge 4.5) "Contrast in Light Mode must achieve >= 4.5:1 (actual: ${ratio}:1)"
    }

    It "Verifies Ink.Base.Negative contrast against KitInk.Window achieves >= 4.5:1 in both themes" {
        # Dark theme
        Reset-TepiTheme -Light $false
        $negDark = (Get-TepiStaticField "Ink" "Base").Negative
        $winDark = Get-TepiStaticProperty "KitInk" "Window"
        $rDark = Assert-Contrast $negDark $winDark 4.5 "Dark KitInk.Window vs Negative"
        Assert-True ($rDark -ge 4.5) "Dark window contrast >= 4.5:1"

        # Light theme
        Reset-TepiTheme -Light $true
        $negLight = (Get-TepiStaticField "Ink" "Base").Negative
        $winLight = Get-TepiStaticProperty "KitInk" "Window"
        $rLight = Assert-Contrast $negLight $winLight 4.5 "Light KitInk.Window vs Negative"
        Assert-True ($rLight -ge 4.5) "Light window contrast >= 4.5:1"
    }

    It "Verifies TaskEditor and WorkWindow source files do not contain hardcoded IndianRed" {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $taskEditorPath = Join-Path $projectRoot "src\TaskEditor.cs"
        $workWindowPath = Join-Path $projectRoot "src\WorkWindow.cs"

        if (Test-Path $taskEditorPath) {
            $taskContent = Get-Content $taskEditorPath -Raw
            Assert-False ($taskContent -match "Color\.IndianRed") "TaskEditor.cs must not contain hardcoded Color.IndianRed"
        }
        if (Test-Path $workWindowPath) {
            $workContent = Get-Content $workWindowPath -Raw
            Assert-False ($workContent -match "Color\.IndianRed") "WorkWindow.cs must not contain hardcoded Color.IndianRed"
            Assert-False ($workContent -match "Color\.FromArgb\(224,\s*96,\s*84\)") "WorkWindow.cs must not contain ad-hoc Color.FromArgb(224, 96, 84)"
        }
    }
}
