# test_b22_typing_combo_boundaries.ps1
# Boundary & Corner Case Tests for Feature 22: Gamified Typing Combo
# Covers key-repeat filtering, modifier rejection, VK boundaries, warmup timeout, drain decay, finisher transition, and SideCombo rendering.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 22 - Typing Combo Boundaries & Edge Cases" {
    $islandType = Get-TepiType "Island"
    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Filters out out-of-range VKs (-1, 0, 256, 999) and modifier/lock keys in IsTypingKey" {
        $invalidVks = @(-1, 0, 256, 999, 0x10, 0x11, 0x12, 0x14, 0x1B, 0x5B, 0x5C, 0x90, 0x91, 0xA0, 0xA2, 0xA4, 0x70, 0x7B)
        foreach ($vk in $invalidVks) {
            $ok = Invoke-TepiStaticMethod "Island" "IsTypingKey" @([int]$vk)
            Assert-False $ok "VK $vk must not be classified as a typing key"
        }
    }

    It "Accepts letters, digits, numpad, space, enter, backspace, and OEM punctuation in IsTypingKey" {
        $validVks = @(0x41, 0x5A, 0x30, 0x39, 0x60, 0x69, 0x20, 0x0D, 0x08, 0x09, 0xBA, 0xBF, 0xDB, 0xDE)
        foreach ($vk in $validVks) {
            $ok = Invoke-TepiStaticMethod "Island" "IsTypingKey" @([int]$vk)
            Assert-True $ok "VK $vk must be classified as a typing key"
        }
    }

    It "Formats KeyCapLabel cleanly for letters, digits, numpad operators, special keys, IME, and unknown VKs" {
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x41)) "A" "0x41 -> A"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x35)) "5" "0x35 -> 5"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x67)) "7" "Numpad 7 -> 7"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x6A)) "*" "Numpad * -> *"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x6B)) "+" "Numpad + -> +"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x20)) "SPC" "Space -> SPC"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0x0D)) ([string][char]0x23CE) "Enter -> return symbol"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0xE7)) "IME" "VK_PACKET -> IME"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "KeyCapLabel" @([int]0xFF)) "KEY" "Unknown VK -> KEY fallback"
    }

    It "Handles negative and extreme hit counts (-100, 0, 100000) in ComboTierFor without throwing" {
        Assert-Equal (Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]-100)) 0 "Negative hits -> Tier 0"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]0)) 0 "Zero hits -> Tier 0"
        Assert-Equal (Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]100000)) 6 "100,000 hits -> Tier 6"
    }

    It "Cycles rainbow color smoothly across arbitrary negative, zero, and large time values in Tier 6" {
        foreach ($t in @(-5.5, 0.0, 0.33, 1.75, 1000.4)) {
            $c = Invoke-TepiStaticMethod "Island" "ComboTierColor" @([int]6, [double]$t)
            Assert-NotNull $c "Rainbow color at t=$t must not be null"
            Assert-Equal $c.A 255 "Rainbow color at t=$t must be fully opaque"
        }
    }

    It "Rejects auto-repeat key-down events until ReleaseComboKey is called, and enforces timer decay + finisher state" {
        $isle = [Activator]::CreateInstance($islandType)
        $settingsField = $islandType.GetField("settings", $flags)
        $settings = $settingsField.GetValue($isle)
        $setMethod = $settings.GetType().GetMethod("Set", [Type[]]@([string], [string]))
        $getMethod = $settings.GetType().GetMethod("Get", [Type[]]@([string], [string]))
        $prevCombo = $getMethod.Invoke($settings, @("keys.combo", "0"))

        $bmp = New-Object System.Drawing.Bitmap 80, 100
        $gr = [System.Drawing.Graphics]::FromImage($bmp)

        try {
            [void]$setMethod.Invoke($settings, @("keys.combo", "1"))
            $isle.ResetCombo()

            # Holding 'A' down repeatedly without key-up only counts once!
            Assert-True ($isle.RegisterComboKeystroke(0x41)) "Initial press of A counts"
            Assert-False ($isle.RegisterComboKeystroke(0x41)) "Held auto-repeat 1 of A is ignored"
            Assert-False ($isle.RegisterComboKeystroke(0x41)) "Held auto-repeat 2 of A is ignored"
            Assert-Equal $isle.ComboCount 1 "ComboCount must remain 1 while key is held down"

            $isle.ReleaseComboKey(0x41)
            Assert-True ($isle.RegisterComboKeystroke(0x41)) "Press after ReleaseComboKey counts"
            $isle.ReleaseComboKey(0x41)
            Assert-Equal $isle.ComboCount 2 "ComboCount increments to 2 after release and re-press"

            # Build up to 12 hits (Tier 2) so Finisher will trigger when timer drains
            for ($i = 3; $i -le 12; $i++) {
                [void]$isle.RegisterComboKeystroke(0x42)
                $isle.ReleaseComboKey(0x42)
            }
            Assert-Equal $isle.ComboCount 12 "ComboCount reaches 12"
            Assert-True $isle.ComboShowing "ComboShowing is true"

            # Step 2.5 seconds -> active combo expires, transitions into Finisher hold (1.35s)
            $stepCombo = $islandType.GetMethod("StepCombo", $flags)
            [void]$stepCombo.Invoke($isle, @([float]2.5))
            Assert-Equal $isle.ComboCount 0 "Active comboCount resets to 0 on drain timeout"
            Assert-True $isle.ComboShowing "ComboShowing stays true during Finisher summary period"

            # Render upright SideCombo during Finisher state to verify vertical edge layout
            $gField = $islandType.GetField("g", $flags)
            $pField = $islandType.GetField("p", $flags)
            $painter = $pField.GetValue($isle)
            $gField.SetValue($isle, $gr)
            $painter.GetType().GetField("G", $flags).SetValue($painter, $gr)
            $sideCombo = $islandType.GetMethod("SideCombo", $flags)
            [void]$sideCombo.Invoke($isle, @([float]40.0, [float]84.0, [DateTime]::UtcNow))

            # Step another 1.5 seconds -> Finisher expires, ComboShowing becomes false
            [void]$stepCombo.Invoke($isle, @([float]1.5))
            Assert-False $isle.ComboShowing "ComboShowing becomes false after Finisher summary completes"

            # Verify comboPop, comboRing, and comboShake springs settle promptly (< 0.6s) so ComboAnimating becomes false
            $comboAnimating = $islandType.GetMethod("ComboAnimating", $flags)
            Assert-False ([bool]$comboAnimating.Invoke($isle, @())) "ComboAnimating must settle to false after finisher completes"
        }
        finally {
            [void]$setMethod.Invoke($settings, @("keys.combo", $prevCombo))
            $isle.ResetCombo()
            $gr.Dispose()
            $bmp.Dispose()
            $isle.Dispose()
        }
    }

    It "Ignores Ctrl/Alt/Win shortcut chords while allowing Shift and AltGr, resets on SetDormant, and respects urgent toasts" {
        $isle = [Activator]::CreateInstance($islandType)
        $settingsField = $islandType.GetField("settings", $flags)
        $settings = $settingsField.GetValue($isle)
        $setMethod = $settings.GetType().GetMethod("Set", [Type[]]@([string], [string]))
        $getMethod = $settings.GetType().GetMethod("Get", [Type[]]@([string], [string]))
        $prevCombo = $getMethod.Invoke($settings, @("keys.combo", "0"))

        $bmp = New-Object System.Drawing.Bitmap 360, 60
        $gr = [System.Drawing.Graphics]::FromImage($bmp)

        try {
            [void]$setMethod.Invoke($settings, @("keys.combo", "1"))
            $isle.ResetCombo()

            # Ctrl+C (0x11 held + 0x43) must be rejected as a shortcut chord
            [void]$isle.RegisterComboKeystroke(0x11)
            Assert-False ($isle.RegisterComboKeystroke(0x43)) "Ctrl+C must not count as typing"
            $isle.ReleaseComboKey(0x43)
            $isle.ReleaseComboKey(0x11)
            Assert-Equal $isle.ComboCount 0 "ComboCount remains 0 after Ctrl+C"

            # Win+L (0x5B held + 0x4C) must be rejected
            [void]$isle.RegisterComboKeystroke(0x5B)
            Assert-False ($isle.RegisterComboKeystroke(0x4C)) "Win+L must not count as typing"
            $isle.ReleaseComboKey(0x4C)
            $isle.ReleaseComboKey(0x5B)
            Assert-Equal $isle.ComboCount 0 "ComboCount remains 0 after Win+L"

            # Shift+A (0x10 held + 0x41) and AltGr+E (0x11 + 0x12 + 0x45) and Space (0x20) MUST count
            [void]$isle.RegisterComboKeystroke(0x10)
            Assert-True ($isle.RegisterComboKeystroke(0x41)) "Shift+A counts as typing"
            $isle.ReleaseComboKey(0x41)
            $isle.ReleaseComboKey(0x10)

            [void]$isle.RegisterComboKeystroke(0x11)
            [void]$isle.RegisterComboKeystroke(0x12)
            Assert-True ($isle.RegisterComboKeystroke(0x45)) "AltGr (Ctrl+Alt)+E counts as typing"
            $isle.ReleaseComboKey(0x45)
            $isle.ReleaseComboKey(0x12)
            $isle.ReleaseComboKey(0x11)

            Assert-True ($isle.RegisterComboKeystroke(0x20)) "3rd key activates ComboShowing"
            $isle.ReleaseComboKey(0x20)
            Assert-True $isle.ComboShowing "ComboShowing is active at 3 hits"

            # Verify urgent/interactive toast takes priority over View.Combo in DesiredView()
            $toastType = Get-TepiType "Toast"
            $viewType = Get-TepiType "View"
            $urgentToast = [Activator]::CreateInstance($toastType)
            $urgentToast.GetType().GetField("View").SetValue($urgentToast, [System.Enum]::Parse($viewType, "Otp"))
            $urgentToast.GetType().GetField("Priority").SetValue($urgentToast, 3)
            $urgentToast.GetType().GetField("Interactive").SetValue($urgentToast, $true)
            $islandType.GetField("toast", $flags).SetValue($isle, $urgentToast)

            $desiredMethod = $islandType.GetMethod("DesiredView", $flags)
            Assert-Equal ($desiredMethod.Invoke($isle, @()).ToString()) "Otp" "Urgent/Interactive toast must override View.Combo"
            $islandType.GetField("toast", $flags).SetValue($isle, $null)
            Assert-Equal ($desiredMethod.Invoke($isle, @()).ToString()) "Combo" "View.Combo resumes once urgent toast clears"

            # Render in Light Mode and at small mid-morph dimensions (40x10 and 8x30) without throwing
            Reset-TepiTheme -Light $true
            $gField = $islandType.GetField("g", $flags)
            $pField = $islandType.GetField("p", $flags)
            $painter = $pField.GetValue($isle)
            $gField.SetValue($isle, $gr)
            $painter.GetType().GetField("G", $flags).SetValue($painter, $gr)
            $inkType = Get-TepiType "Ink"
            $baseTone = $inkType.GetField("Base", $flags).GetValue($null)
            $painter.GetType().GetField("T", $flags).SetValue($painter, $baseTone)

            $drawCombo = $islandType.GetMethod("DrawCombo", $flags)
            $sideCombo = $islandType.GetMethod("SideCombo", $flags)
            [void]$drawCombo.Invoke($isle, @([float]40.0, [float]10.0, [DateTime]::UtcNow))
            [void]$sideCombo.Invoke($isle, @([float]8.0, [float]30.0, [DateTime]::UtcNow))

            # SetDormant(true, false) must reset active combo
            $setDormant = $islandType.GetMethod("SetDormant", $flags)
            [void]$setDormant.Invoke($isle, @($true, $false))
            Assert-False $isle.ComboShowing "SetDormant(true) resets active combo"
            Assert-Equal $isle.ComboCount 0 "ComboCount resets to 0 on SetDormant"
            [void]$setDormant.Invoke($isle, @($false, $false))
        }
        finally {
            Reset-TepiTheme -Light $false
            [void]$setMethod.Invoke($settings, @("keys.combo", $prevCombo))
            $isle.ResetCombo()
            $gr.Dispose()
            $bmp.Dispose()
            $isle.Dispose()
        }
    }
}
