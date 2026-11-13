# test_f14_kit_ask.ps1
# Feature 14: KitAsk Universal Title & Localization
# Verifies KitAsk title is dynamic / parameter-driven and buttons use Lang.T localization.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 14: KitAsk Universal Title & Localization" {
    $kitAskType = Get-TepiType "KitAsk"
    $kitWindowType = Get-TepiType "KitWindow"

    It "Verifies KitAsk inherits from KitWindow" {
        Assert-NotNull $kitAskType "KitAsk type must exist"
        Assert-True ($kitWindowType.IsAssignableFrom($kitAskType)) "KitAsk must inherit from KitWindow"
    }

    It "Verifies KitAsk contains yes, no, ok action buttons of type KitButton" {
        $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
        $yesField = $kitAskType.GetField("yes", $flags)
        $noField = $kitAskType.GetField("no", $flags)
        $okField = $kitAskType.GetField("ok", $flags)

        Assert-NotNull $yesField "yes button field must exist"
        Assert-NotNull $noField "no button field must exist"
        Assert-NotNull $okField "ok button field must exist"

        Assert-Equal $yesField.FieldType.Name "KitButton" "yes button must be KitButton"
        Assert-Equal $noField.FieldType.Name "KitButton" "no button must be KitButton"
        Assert-Equal $okField.FieldType.Name "KitButton" "ok button must be KitButton"
    }

    It "Verifies KitAsk Confirm static method signature" {
        $confirmMethod = $kitAskType.GetMethod("Confirm", [System.Reflection.BindingFlags]'Public,Static')
        Assert-NotNull $confirmMethod "KitAsk.Confirm method must exist"

        $params = $confirmMethod.GetParameters()
        Assert-True ($params.Length -ge 2) "Confirm must take at least owner and message parameters"
    }

    It "Verifies KitAsk Notice static method signature" {
        $noticeMethod = $kitAskType.GetMethod("Notice", [System.Reflection.BindingFlags]'Public,Static')
        Assert-NotNull $noticeMethod "KitAsk.Notice method must exist"
    }

    It "Verifies KitAsk title is parameter-driven rather than hardcoded to 'Tugas dan catatan'" {
        # Inspect constructor or Confirm overloads for title parameter
        $ctors = $kitAskType.GetConstructors([System.Reflection.BindingFlags]'Instance,NonPublic,Public')
        $hasTitleParam = $false
        foreach ($c in $ctors) {
            foreach ($p in $c.GetParameters()) {
                if ($p.Name -eq "title") { $hasTitleParam = $true }
            }
        }
        # In M2, title should be parameter-driven
        Assert-True $hasTitleParam "KitAsk constructor must accept dynamic title parameter (M2 feature)"
    }
}
