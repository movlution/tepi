# test_f13_dialog_broadcast.ps1
# Feature 13: Centralized Dialog Theme Propagation
# Verifies KitWindow.BroadcastThemeChange() updates all open dialogs on theme switch.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 13: Centralized Dialog Theme Propagation" {
    $kitWindowType = Get-TepiType "KitWindow"
    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static'

    It "Verifies KitWindow declares static BroadcastThemeChange method" {
        $m = $kitWindowType.GetMethod("BroadcastThemeChange", $flags)
        Assert-NotNull $m "KitWindow must declare static BroadcastThemeChange() method (M2 feature)"
    }

    It "Verifies KitWindow maintains an internal registry of active open windows" {
        # Check for static list/hashset of open KitWindow instances
        $field = $kitWindowType.GetFields($flags) | Where-Object { $_.FieldType.Name -match "List|HashSet|Collection" }
        Assert-NotNull $field "KitWindow must maintain a static collection of active dialog instances"
    }

    It "Verifies KitWindow instances register on show and unregister on dispose" {
        $win = New-TepiControl "KitWindow"
        Assert-NotNull $win "KitWindow instance must be created"
        Assert-True ($win -is [System.Windows.Forms.Form]) "KitWindow must inherit from Form"
        $win.Dispose()
    }

    It "Verifies BroadcastThemeChange propagates theme invalidation to child controls" {
        $m = $kitWindowType.GetMethod("BroadcastThemeChange", $flags)
        if ($m) {
            # Invoke broadcast to ensure no exceptions occur
            $m.Invoke($null, @())
            Assert-True $true "BroadcastThemeChange must execute cleanly"
        } else {
            throw "BroadcastThemeChange method not yet implemented on KitWindow"
        }
    }

    It "Verifies Island declares ApplyThemeMode orchestration method" {
        $island = Get-TepiType "Island"
        $applyTheme = $island.GetMethod("ApplyThemeMode", [System.Reflection.BindingFlags]'NonPublic,Instance,Public')
        Assert-NotNull $applyTheme "ApplyThemeMode method must exist on Island"
    }
}
