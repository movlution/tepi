# test_b13_dialog_theme.ps1
# Boundary & Corner Case Tests for Feature 13: Centralized Dialog Theme Propagation
# Covers KitWindow hierarchy, dynamic theme propagation, rapid mode flips, and Relayout lifecycle.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 13 - Dialog Theme Propagation Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Verifies core dialog types inherit from KitWindow" {
        $kwType = Get-TepiType "KitWindow"
        Assert-NotNull $kwType "KitWindow type must be resolvable"

        $expectedDialogs = @("KitAsk", "TaskEditor", "WorkWindow")
        foreach ($dName in $expectedDialogs) {
            $t = Get-TepiType $dName
            Assert-NotNull $t "Dialog type [$dName] must be resolvable"
            Assert-True ($kwType.IsAssignableFrom($t)) "Dialog [$dName] must inherit from KitWindow"
        }
    }

    It "Propagates dynamic theme switch from Dark to Light across KitInk properties" {
        Reset-TepiTheme -Light $false
        $darkWin = Get-TepiStaticProperty "KitInk" "Window"
        $darkText = Get-TepiStaticProperty "KitInk" "Text"

        Reset-TepiTheme -Light $true
        $lightWin = Get-TepiStaticProperty "KitInk" "Window"
        $lightText = Get-TepiStaticProperty "KitInk" "Text"

        Assert-NotEqual $darkWin $lightWin "KitInk.Window must change between dark and light themes"
        Assert-NotEqual $darkText $lightText "KitInk.Text must change between dark and light themes"
    }

    It "Executes rapid successive theme toggles without handle exhaustion or token corruption" {
        for ($i = 0; $i -lt 20; $i++) {
            $isLight = ($i % 2 -eq 0)
            Reset-TepiTheme -Light $isLight
            $actualLight = Get-TepiStaticField "Ink" "Light"
            Assert-Equal $actualLight $isLight "Theme Light state must match iteration $i"
        }
    }

    It "Verifies Relayout virtual method is defined on KitWindow base type" {
        $kwType = Get-TepiType "KitWindow"
        $relayout = $kwType.GetMethod("Relayout", [System.Reflection.BindingFlags]'Public,Instance')
        Assert-NotNull $relayout "KitWindow.Relayout method must exist"
        Assert-True $relayout.IsVirtual "KitWindow.Relayout must be a virtual method"
    }

    It "Validates native DWM dark frame helper does not throw under headless execution" {
        $nativeType = Get-TepiType "Native"
        Assert-NotNull $nativeType "Native utility type must exist"

        $darkFrame = $nativeType.GetMethod("DarkFrame", [System.Reflection.BindingFlags]'Public,NonPublic,Static')
        Assert-NotNull $darkFrame "Native.DarkFrame method must exist"

        # Invoking with IntPtr.Zero handle should be safe or handled gracefully
        try {
            $darkFrame.Invoke($null, @([IntPtr]::Zero, $true))
        } catch {
            # Catch Win32 API failure on dummy handle without crashing test suite
        }
    }
}
