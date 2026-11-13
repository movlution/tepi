# test_f15_kulia_login.ps1
# Feature 15: KuliaLogin Tokenization & Modernization
# Verifies KuliaLogin inherits KitWindow, adopts KitButton, and uses KitInk tokens.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 15: KuliaLogin Tokenization & Modernization" {
    $kuliaLoginType = Get-TepiType "KuliaLogin"
    $kitWindowType = Get-TepiType "KitWindow"
    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'

    It "Verifies KuliaLogin type exists in Tepi assembly" {
        Assert-NotNull $kuliaLoginType "KuliaLogin type must exist"
    }

    It "Verifies KuliaLogin inherits from KitWindow" {
        Assert-True ($kitWindowType.IsAssignableFrom($kuliaLoginType)) "KuliaLogin must inherit from KitWindow (M2 feature)"
    }

    It "Verifies KuliaLogin primary action button is an instance of KitButton" {
        $primaryField = $kuliaLoginType.GetField("primary", $flags)
        Assert-NotNull $primaryField "primary button field must exist"
        Assert-Equal $primaryField.FieldType.Name "KitButton" "primary button must be KitButton (M2 feature)"
    }

    It "Verifies KuliaLogin back button is an instance of KitButton" {
        $backField = $kuliaLoginType.GetField("back", $flags)
        Assert-NotNull $backField "back button field must exist"
        Assert-Equal $backField.FieldType.Name "KitButton" "back button must be KitButton (M2 feature)"
    }

    It "Verifies KuliaLogin does not use ad-hoc Color.FromArgb for background and text" {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $kuliaPath = Join-Path $projectRoot "src\Kulia.cs"
        if (Test-Path $kuliaPath) {
            $content = Get-Content $kuliaPath -Raw
            # In M2, ad-hoc Color.FromArgb(245, 245, 245) and (10, 10, 10) should be replaced with KitInk tokens
            $hasAdHoc = $content -match "Color\.FromArgb\(245,\s*245,\s*245\)"
            Assert-False $hasAdHoc "KuliaLogin must use KitInk tokens instead of ad-hoc Color.FromArgb (M2 feature)"
        }
    }
}
