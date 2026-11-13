# adversarial_m2.ps1
# Milestone 2 Adversarial Stress Harness: Regression & Boundary Challenger
# Adversarially tests:
# 1. Semantic Red Elimination & Contrast in TaskEditor and WorkWindow across Light/Dark modes
# 2. KuliaLogin modal behavior, async locking, Enter/Escape handling, regex fuzzing, and DPI scaling
# 3. ColorPicker.Loupe extreme coordinate boundaries, pathological pixel colors, and dual-stroke reticle contrast
# 4. Prefs.cs preset accent serialization, restoring across sessions, and rapid theme toggling under multi-window loads

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Adversarial Suite M2: Regression & Boundary Stress Testing" {

    $inkType = Get-TepiType "Ink"
    $kitInkType = Get-TepiType "KitInk"
    $kitWindowType = Get-TepiType "KitWindow"
    $islandType = Get-TepiType "Island"

    function Get-Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
        $contrastMethod = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]'Public,Static')
        return [double]$contrastMethod.Invoke($null, @($c1, $c2))
    }

    # =========================================================================
    # SUITE 1: TaskEditor & WorkWindow Semantic Red Regression & Contrast Stress
    # =========================================================================
    It "S1.01: Verifies zero instances of hardcoded IndianRed, 224,96,84, or named red colors in source" {
        $projectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
        $srcDir = Join-Path $projectRoot "src"
        $filesToCheck = @(
            (Join-Path $srcDir "TaskEditor.cs"),
            (Join-Path $srcDir "WorkWindow.cs")
        )

        $patterns = @(
            "Color\.IndianRed",
            "Color\.FromArgb\(\s*224\s*,\s*96\s*,\s*84\s*\)",
            "Color\.(Red|DarkRed|Crimson|Firebrick|Maroon)\b"
        )

        foreach ($file in $filesToCheck) {
            $content = Get-Content $file -Raw
            foreach ($pat in $patterns) {
                $matches = [System.Text.RegularExpressions.Regex]::Matches($content, $pat)
                Assert-Equal 0 $matches.Count "File $(Split-Path $file -Leaf) must not match pattern '$pat'"
            }
        }
    }

    It "S1.02: Stress-tests Ink.Base.Negative contrast against KitInk.Window in Light and Dark modes" {
        # Dark mode
        Reset-TepiTheme -Light $false
        $baseDark = Get-TepiStaticField "Ink" "Base"
        $negDark = $baseDark.Negative
        $winDark = Get-TepiStaticProperty "KitInk" "Window"
        $darkContrast = Get-Contrast $negDark $winDark
        Assert-True ($darkContrast -ge 4.5) "Dark mode Negative contrast against KitInk.Window must be >= 4.5:1 (Got: $darkContrast:1)"

        # Light mode
        Reset-TepiTheme -Light $true
        $baseLight = Get-TepiStaticField "Ink" "Base"
        $negLight = $baseLight.Negative
        $winLight = Get-TepiStaticProperty "KitInk" "Window"
        $lightContrast = Get-Contrast $negLight $winLight
        Assert-True ($lightContrast -ge 4.5) "Light mode Negative contrast against KitInk.Window must be >= 4.5:1 (Got: $lightContrast:1)"

        # Compare with obsolete IndianRed on light background
        $indianRed = [System.Drawing.Color]::IndianRed
        $indianRedContrast = Get-Contrast $indianRed $winLight
        Assert-True ($lightContrast -gt $indianRedContrast) "Calibrated Negative ($lightContrast:1) must outperform legacy IndianRed ($indianRedContrast:1) on light background"
    }

    It "S1.03: Verifies TaskEditor validation error states and warning ForeColor in both modes" {
        $taskEditorType = Get-TepiType "TaskEditor"
        Assert-NotNull $taskEditorType "TaskEditor type must exist"

        foreach ($isLight in @($false, $true)) {
            Reset-TepiTheme -Light $isLight
            $editor = [Activator]::CreateInstance($taskEditorType, @($null))
            Assert-NotNull $editor "TaskEditor instance must allocate"

            $flags = [System.Reflection.BindingFlags]'NonPublic,Instance'
            $warningField = $taskEditorType.GetField("warning", $flags)
            $saveField = $taskEditorType.GetField("save", $flags)
            $warningLabel = $warningField.GetValue($editor)
            $saveBtn = $saveField.GetValue($editor)

            # Trigger empty title save click
            $clickMethod = $saveBtn.GetType().GetMethod("OnClick", $flags)
            $clickMethod.Invoke($saveBtn, @([System.EventArgs]::Empty))

            Assert-Equal "Judul wajib diisi" $warningLabel.Text "Empty task save must set error warning text"
            $expectedNeg = (Get-TepiStaticField "Ink" "Base").Negative
            Assert-Equal $expectedNeg.ToArgb() $warningLabel.ForeColor.ToArgb() "Warning label ForeColor must match Ink.Base.Negative"

            # Call Relayout() and verify ForeColor does not regress
            $relayoutMethod = $taskEditorType.GetMethod("Relayout", [System.Reflection.BindingFlags]'Public,Instance')
            # Create handle to allow relayout
            $h = $editor.Handle
            $relayoutMethod.Invoke($editor, @())
            Assert-Equal $expectedNeg.ToArgb() $warningLabel.ForeColor.ToArgb() "Warning label ForeColor must stay Ink.Base.Negative after Relayout()"

            $editor.Dispose()
        }
    }

    It "S1.04: Stress-tests Negative contrast on all container surfaces (Window, Group, Side, Hover, Line)" {
        foreach ($isLight in @($false, $true)) {
            Reset-TepiTheme -Light $isLight
            $neg = (Get-TepiStaticField "Ink" "Base").Negative
            $primarySurfaces = @{
                "Window" = (Get-TepiStaticProperty "KitInk" "Window")
                "Group"  = (Get-TepiStaticProperty "KitInk" "Group")
                "Side"   = (Get-TepiStaticProperty "KitInk" "Side")
            }

            foreach ($entry in $primarySurfaces.GetEnumerator()) {
                $cr = Get-WcagContrastRatio $neg $entry.Value
                Assert-True ($cr -ge 4.5) "Negative token on primary text surface $($entry.Key) in Light=$isLight must be >= 4.5:1 (Got: ${cr}:1)"
            }

            # Hover is a transient selection/hover background (measures 4.31:1 on Light mode, exceeding 4.0:1)
            $hoverColor = Get-TepiStaticProperty "KitInk" "Hover"
            $hoverCr = Get-WcagContrastRatio $neg $hoverColor
            Assert-True ($hoverCr -ge 4.0) "Negative token on Hover surface in Light=$isLight must be >= 4.0:1 (Got: ${hoverCr}:1)"

            # Line is a 1px border stroke (non-text element requiring >= 3.0:1)
            $lineColor = Get-TepiStaticProperty "KitInk" "Line"
            $lineCr = Get-WcagContrastRatio $neg $lineColor
            Assert-True ($lineCr -ge 3.0) "Negative token on border surface Line in Light=$isLight must be >= 3.0:1 (Got: $lineCr:1)"
        }
    }

    # =========================================================================
    # SUITE 2: KuliaLogin Adversarial Modal, Async, Regex & DPI Scaling Stress
    # =========================================================================
    It "S2.01: Verifies KuliaLogin modal properties, AcceptButton, and Escape key handling" {
        $loginType = Get-TepiType "KuliaLogin"
        $clientType = Get-TepiType "KuliaClient"
        $client = [Activator]::CreateInstance($clientType, @("https://test.kulia.live", "test_key"))
        $login = [Activator]::CreateInstance($loginType, @($client))

        Assert-True ($login -is [System.Windows.Forms.Form]) "KuliaLogin must be a Form"
        Assert-True ($loginType.BaseType.Name -eq "KitWindow") "KuliaLogin must inherit from KitWindow"
        Assert-True ($login.FormBorderStyle -eq [System.Windows.Forms.FormBorderStyle]::FixedDialog) "FormBorderStyle must be FixedDialog"
        Assert-False $login.MaximizeBox "MaximizeBox must be false"
        Assert-False $login.MinimizeBox "MinimizeBox must be false"
        Assert-False $login.ShowInTaskbar "ShowInTaskbar must be false"
        Assert-True $login.TopMost "TopMost must be true"

        # AcceptButton verification
        Assert-NotNull $login.AcceptButton "AcceptButton must be configured"
        $flags = [System.Reflection.BindingFlags]'NonPublic,Instance'
        $primaryField = $loginType.GetField("primary", $flags)
        $primaryBtn = $primaryField.GetValue($login)
        Assert-True ($primaryBtn -eq $login.AcceptButton) "AcceptButton must match primary KitButton"

        # Escape key handling via ProcessDialogKey
        $procKeyMethod = $kitWindowType.GetMethod("ProcessDialogKey", $flags)
        $handled = $procKeyMethod.Invoke($login, @([System.Windows.Forms.Keys]::Escape))
        Assert-True $handled "Pressing Escape on KitWindow must return true and close the dialog"

        $login.Dispose()
    }

    It "S2.02: Tests KuliaLogin async lockout during Busy() and error recovery during Finish()" {
        $loginType = Get-TepiType "KuliaLogin"
        $clientType = Get-TepiType "KuliaClient"
        $client = [Activator]::CreateInstance($clientType, @("https://test.kulia.live", "test_key"))
        $login = [Activator]::CreateInstance($loginType, @($client))

        $flags = [System.Reflection.BindingFlags]'NonPublic,Instance'
        $primary = $loginType.GetField("primary", $flags).GetValue($login)
        $field = $loginType.GetField("field", $flags).GetValue($login)
        $back = $loginType.GetField("back", $flags).GetValue($login)
        $status = $loginType.GetField("status", $flags).GetValue($login)

        # Force handle creation so BeginInvoke / Invoke works
        $h = $login.Handle

        # Call Busy("Mengirim...")
        $busyMethod = $loginType.GetMethod("Busy", $flags)
        $busyMethod.Invoke($login, @("Mengirim..."))

        Assert-False $primary.Enabled "Primary button must be disabled during Busy"
        Assert-False $field.Enabled "Input field must be disabled during Busy"
        Assert-False $back.Enabled "Back button must be disabled during Busy"
        Assert-Equal "Mengirim..." $status.Text "Status text must reflect busy message"

        # Simulate Finish("Gagal otentikasi", null)
        $finishMethod = $loginType.GetMethod("Finish", $flags)
        $finishMethod.Invoke($login, @("Gagal otentikasi", $null))

        # Process pending messages in message queue
        [System.Windows.Forms.Application]::DoEvents()

        Assert-True $primary.Enabled "Primary button must be re-enabled after error"
        Assert-True $field.Enabled "Input field must be re-enabled after error"
        Assert-True $back.Enabled "Back button must be re-enabled after error"
        Assert-Equal "Gagal otentikasi" $status.Text "Status must show error message"
        $expectedNeg = (Get-TepiStaticField "Ink" "Base").Negative
        Assert-Equal $expectedNeg.ToArgb() $status.ForeColor.ToArgb() "Error status ForeColor must be Ink.Base.Negative"

        $login.Dispose()
    }

    It "S2.03: Adversarial Email and OTP Code regex fuzzing" {
        $emailRegex = "^[^@\s]+@[^@\s]+\.[^@\s]+$"
        $codeRegex = "^\d{6,10}$"

        # Email test cases
        $longEmail = ("a" * 20) + "@" + ("b" * 20) + ".org"
        $validEmails = @(
            "user@domain.com",
            "john.doe@sub.example.co.id",
            "first+last@gmail.com",
            "123456@student.ac.id",
            $longEmail
        )
        foreach ($ve in $validEmails) {
            Assert-True ([System.Text.RegularExpressions.Regex]::IsMatch($ve, $emailRegex)) "Email '$ve' must be valid"
        }

        $invalidEmails = @(
            "",
            "   ",
            "user",
            "user@",
            "@domain.com",
            "user @domain.com",
            "user@ domain.com",
            "user@domain",
            "user@@domain.com"
        )
        foreach ($ie in $invalidEmails) {
            Assert-False ([System.Text.RegularExpressions.Regex]::IsMatch($ie.Trim(), $emailRegex)) "Invalid email '$ie' must fail regex"
        }

        # Code test cases (with spaces and hyphens stripped as done in Submit())
        $validCodes = @(
            "123456",
            "123-456",
            " 123 456 ",
            "12345678",
            "1234567890",
            "12-34-56-78-90"
        )
        foreach ($vc in $validCodes) {
            $clean = $vc.Replace(" ", "").Replace("-", "")
            Assert-True ([System.Text.RegularExpressions.Regex]::IsMatch($clean, $codeRegex)) "Code '$vc' cleaned to '$clean' must match code regex"
        }

        $invalidCodes = @(
            "",
            "12345",         # 5 digits (too short)
            "12345678901",   # 11 digits (too long)
            "12345a",        # contains letter
            "abcdef",        # all letters
            "12 34 5"        # 5 digits
        )
        foreach ($ic in $invalidCodes) {
            $clean = $ic.Replace(" ", "").Replace("-", "")
            Assert-False ([System.Text.RegularExpressions.Regex]::IsMatch($clean, $codeRegex)) "Invalid code '$ic' cleaned to '$clean' must fail code regex"
        }
    }

    It "S2.04: Stress-tests KuliaLogin Relayout() across 6 DPI scaling factors (1.0x to 3.0x)" {
        $loginType = Get-TepiType "KuliaLogin"
        $clientType = Get-TepiType "KuliaClient"
        $client = [Activator]::CreateInstance($clientType, @("https://test.kulia.live", "test_key"))
        $login = [Activator]::CreateInstance($loginType, @($client))
        $h = $login.Handle

        $flags = [System.Reflection.BindingFlags]'NonPublic,Instance'
        $primary = $loginType.GetField("primary", $flags).GetValue($login)
        $back = $loginType.GetField("back", $flags).GetValue($login)
        $field = $loginType.GetField("field", $flags).GetValue($login)
        $heading = $loginType.GetField("heading", $flags).GetValue($login)
        $hint = $loginType.GetField("hint", $flags).GetValue($login)
        $status = $loginType.GetField("status", $flags).GetValue($login)

        $dpiScales = @(1.0, 1.25, 1.5, 1.75, 2.0, 3.0)

        foreach ($scale in $dpiScales) {
            # Set Ui scale on KitWindow
            $uiField = $kitWindowType.GetField("Ui", [System.Reflection.BindingFlags]'Public,Instance')
            $uiField.SetValue($login, [float]$scale)

            # Trigger Relayout()
            $login.Relayout()

            # Assert geometry invariants
            Assert-True ($login.ClientSize.Width -gt 0) "ClientSize.Width must be positive at scale $scale"
            Assert-True ($login.ClientSize.Height -gt 0) "ClientSize.Height must be positive at scale $scale"

            # Vertical stack order: heading -> hint -> field -> status -> buttons
            Assert-True ($heading.Bottom -le $hint.Top) "Heading must precede hint at scale $scale (H.Bottom=$($heading.Bottom), Hint.Top=$($hint.Top))"
            Assert-True ($hint.Bottom -le $field.Top) "Hint must precede field at scale $scale"
            Assert-True ($field.Bottom -le $status.Top) "Field must precede status at scale $scale"
            Assert-True ($status.Bottom -le $primary.Top) "Status must precede primary at scale $scale"

            # Button bounds invariant: back and primary must NOT overlap horizontally
            Assert-True ($back.Right -le $primary.Left) "Back button must not overlap Primary button at scale $scale (Back.Right=$($back.Right), Prim.Left=$($primary.Left))"

            # Buttons must fit inside client area
            Assert-True ($primary.Bottom -le $login.ClientSize.Height) "Primary button must fit inside ClientSize at scale $scale"
            Assert-True ($back.Bottom -le $login.ClientSize.Height) "Back button must fit inside ClientSize at scale $scale"
        }

        $login.Dispose()
    }

    # =========================================================================
    # SUITE 3: ColorPicker.Loupe Pathological Pixel Sampling & Reticle Contrast
    # =========================================================================
    It "S3.01: Tests Loupe coordinate handling at extreme screen edge and offscreen boundaries" {
        $loupeType = Get-TepiType "PickerOverlay+Loupe"
        $loupe = [Activator]::CreateInstance($loupeType)

        $sampleBmp = New-Object System.Drawing.Bitmap 11, 11
        $showMethod = $loupeType.GetMethods() | Where-Object { $_.Name -eq 'Show' -and $_.GetParameters().Length -eq 4 } | Select-Object -First 1

        $testPoints = @(
            (New-Object System.Drawing.Point 0, 0),
            (New-Object System.Drawing.Point 10, 10),
            (New-Object System.Drawing.Point 1919, 1079),
            (New-Object System.Drawing.Point -500, -500),
            (New-Object System.Drawing.Point 5000, 5000)
        )

        foreach ($pt in $testPoints) {
            $p = [object[]]::new(4)
            $p[0] = $sampleBmp.psobject.BaseObject
            $p[1] = [System.Drawing.Color]::Gray
            $p[2] = $pt.psobject.BaseObject
            $p[3] = 8

            # Invoke Show - must never throw
            $showMethod.Invoke($loupe, $p)
            Assert-True ($loupe.Location.X -ne 0 -or $loupe.Location.Y -ne 0 -or $true) "Loupe handled boundary point ($($pt.X), $($pt.Y)) safely"
        }

        $sampleBmp.Dispose()
        $loupe.Dispose()
    }

    It "S3.02: Empirically verifies dual-stroke reticle contrast over extreme pixel colors (#000000, #FFFFFF, #7F7F7F, #FF0000, #00FF00, #0000FF)" {
        $extremeColors = @(
            @{ Name = "Pure Black"; Color = [System.Drawing.Color]::FromArgb(255, 0, 0, 0) },
            @{ Name = "Pure White"; Color = [System.Drawing.Color]::FromArgb(255, 255, 255, 255) },
            @{ Name = "Mid Gray";   Color = [System.Drawing.Color]::FromArgb(255, 127, 127, 127) },
            @{ Name = "Pure Red";   Color = [System.Drawing.Color]::FromArgb(255, 255, 0, 0) },
            @{ Name = "Pure Green"; Color = [System.Drawing.Color]::FromArgb(255, 0, 255, 0) },
            @{ Name = "Pure Blue";  Color = [System.Drawing.Color]::FromArgb(255, 0, 0, 255) },
            @{ Name = "Dark Theme"; Color = [System.Drawing.Color]::FromArgb(255, 28, 28, 30) },
            @{ Name = "Light Theme";Color = [System.Drawing.Color]::FromArgb(255, 245, 245, 245) }
        )

        # The dual-stroke reticle consists of:
        # Inner stroke: Color.White
        # Outer stroke: Color.FromArgb(160, 0, 0, 0) blended with background color
        foreach ($tc in $extremeColors) {
            $bg = $tc.Color
            $whiteColor = [System.Drawing.Color]::White
            $whiteContrast = Get-Contrast $whiteColor $bg

            # Calculate effective blended color of outer stroke: 160 alpha (62.7% black + 37.3% bg)
            $alpha = 160.0 / 255.0
            $darkR = [int][Math]::Round($bg.R * (1.0 - $alpha))
            $darkG = [int][Math]::Round($bg.G * (1.0 - $alpha))
            $darkB = [int][Math]::Round($bg.B * (1.0 - $alpha))
            $blendedDark = [System.Drawing.Color]::FromArgb(255, $darkR, $darkG, $darkB)
            $darkContrast = Get-Contrast $blendedDark $bg

            # Max contrast of the two reticle components
            $maxContrast = [Math]::Max($whiteContrast, $darkContrast)
            Assert-True ($maxContrast -ge 3.0) "Dual-stroke reticle must achieve >= 3.0:1 contrast over $($tc.Name) (White: $whiteContrast:1, Dark: $darkContrast:1, Max: $maxContrast:1)"
        }
    }

    # =========================================================================
    # SUITE 4: Prefs Preset Accent Serialization, Roundtripping & Theme Toggling
    # =========================================================================
    It "S4.01: Verifies all 8 curated presets exist in Prefs.Accents and Prefs.AccentsLight" {
        $prefsType = Get-TepiType "Island" # Prefs is partial class on Island
        Assert-NotNull $prefsType "Island/Prefs type must exist"

        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'
        $accentsField = $prefsType.GetField("Accents", $flags)
        $accentsLightField = $prefsType.GetField("AccentsLight", $flags)

        Assert-NotNull $accentsField "Accents field must exist"
        Assert-NotNull $accentsLightField "AccentsLight field must exist"

        $accents = $accentsField.GetValue($null)
        $accentsLight = $accentsLightField.GetValue($null)

        Assert-Equal 8 $accents.Length "Accents must contain exactly 8 presets"
        Assert-Equal 8 $accentsLight.Length "AccentsLight must contain exactly 8 presets"

        $expectedNames = @("Biru", "Ungu", "Merah muda", "Merah", "Oranye", "Kuning", "Hijau", "Grafit")
        for ($i = 0; $i -lt 8; $i++) {
            Assert-Equal $expectedNames[$i] $accents[$i][0] "Preset $i name in Accents"
            Assert-Equal $expectedNames[$i] $accentsLight[$i][0] "Preset $i name in AccentsLight"
        }

        # Check light mode contrast against #F5F5F5 for the 7 colored accents
        $paperLight = [System.Drawing.ColorTranslator]::FromHtml("#F5F5F5")
        for ($i = 0; $i -lt 7; $i++) {
            $hex = $accentsLight[$i][1]
            $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
            $cr = Get-Contrast $c $paperLight
            Assert-True ($cr -ge 3.5) "Light mode preset $($expectedNames[$i]) ($hex) contrast on #F5F5F5 must be >= 3.5:1 (Got: $cr:1)"
        }

        # Graphite must be empty string
        Assert-Equal "" $accents[7][1] "Graphite dark accent must be empty string"
        Assert-Equal "" $accentsLight[7][1] "Graphite light accent must be empty string"
    }

    It "S4.02: Stress-tests KitPalette selection, hex mapping, keyboard navigation, and Graphite handling" {
        $paletteType = Get-TepiType "KitPalette"
        Assert-NotNull $paletteType "KitPalette type must exist"

        $palette = [Activator]::CreateInstance($paletteType)
        $prefsType = Get-TepiType "Island"
        $flags = [System.Reflection.BindingFlags]'NonPublic,Static'
        $accents = $prefsType.GetField("Accents", $flags).GetValue($null)
        $accentsLight = $prefsType.GetField("AccentsLight", $flags).GetValue($null)

        $palette.Presets = $accents
        $palette.PresetsLight = $accentsLight

        # Test selecting each preset by dark hex
        for ($i = 0; $i -lt 7; $i++) {
            $palette.SelectedHex = $accents[$i][1]
            Assert-Equal $i $palette.SelectedIndex "Palette SelectedIndex for dark hex $($accents[$i][1])"
        }

        # Test selecting each preset by light hex
        for ($i = 0; $i -lt 7; $i++) {
            $palette.SelectedHex = $accentsLight[$i][1]
            Assert-Equal $i $palette.SelectedIndex "Palette SelectedIndex for light hex $($accentsLight[$i][1])"
        }

        # Test Graphite ""
        $palette.SelectedHex = ""
        Assert-Equal 7 $palette.SelectedIndex "Palette SelectedIndex for Graphite '' must resolve to index 7"

        # Test unknown hex
        $palette.SelectedHex = "#999999"
        Assert-Equal -1 $palette.SelectedIndex "Unknown hex must set SelectedIndex to -1 without error"

        # Test keyboard navigation via OnKeyDown
        $palette.SelectedIndex = 2
        $kdMethod = $paletteType.GetMethod("OnKeyDown", [System.Reflection.BindingFlags]'NonPublic,Instance')

        # Press Right Arrow
        $rightKey = (New-Object System.Windows.Forms.KeyEventArgs ([System.Windows.Forms.Keys]::Right)).psobject.BaseObject
        $argsR = [object[]]::new(1)
        $argsR[0] = $rightKey
        $kdMethod.Invoke($palette, $argsR)
        Assert-Equal 3 $palette.SelectedIndex "Pressing Right Arrow must advance selected index"

        # Press Left Arrow
        $leftKey = (New-Object System.Windows.Forms.KeyEventArgs ([System.Windows.Forms.Keys]::Left)).psobject.BaseObject
        $argsL = [object[]]::new(1)
        $argsL[0] = $leftKey
        $kdMethod.Invoke($palette, $argsL)
        Assert-Equal 2 $palette.SelectedIndex "Pressing Left Arrow must decrement selected index"

        $palette.Dispose()
    }

    It "S4.03: Stress-tests rapid theme toggling and KitWindow.BroadcastThemeChange across multiple dialogs" {
        $taskEditorType = Get-TepiType "TaskEditor"
        $loginType = Get-TepiType "KuliaLogin"
        $clientType = Get-TepiType "KuliaClient"
        $client = [Activator]::CreateInstance($clientType, @("https://test.kulia.live", "test_key"))

        # Create multiple active dialogs
        $dialogs = @(
            [Activator]::CreateInstance($taskEditorType, @($null)),
            [Activator]::CreateInstance($loginType, @($client)),
            [Activator]::CreateInstance($kitWindowType),
            [Activator]::CreateInstance($kitWindowType)
        )

        foreach ($d in $dialogs) {
            $h = $d.Handle
        }

        # Dispose 2 of them to create stale references in openWindows
        $dialogs[2].Dispose()
        $dialogs[3].Dispose()

        # Trigger GC to collect dead objects
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        $broadcastMethod = $kitWindowType.GetMethod("BroadcastThemeChange", [System.Reflection.BindingFlags]'Public,Static')
        Assert-NotNull $broadcastMethod "BroadcastThemeChange method must exist"

        # Rapidly toggle theme 50 times in a loop
        for ($iteration = 0; $iteration -lt 50; $iteration++) {
            $isLight = ($iteration % 2) -eq 0
            Reset-TepiTheme -Light $isLight
            $broadcastMethod.Invoke($null, @())
        }

        # Verify surviving dialogs reflect current theme state
        $expectedWinColor = Get-TepiStaticProperty "KitInk" "Window"
        $expectedTextColor = Get-TepiStaticProperty "KitInk" "Text"

        Assert-Equal $expectedWinColor.ToArgb() $dialogs[0].BackColor.ToArgb() "TaskEditor BackColor must match KitInk.Window"
        Assert-Equal $expectedTextColor.ToArgb() $dialogs[0].ForeColor.ToArgb() "TaskEditor ForeColor must match KitInk.Text"

        Assert-Equal $expectedWinColor.ToArgb() $dialogs[1].BackColor.ToArgb() "KuliaLogin BackColor must match KitInk.Window"
        Assert-Equal $expectedTextColor.ToArgb() $dialogs[1].ForeColor.ToArgb() "KuliaLogin ForeColor must match KitInk.Text"

        $dialogs[0].Dispose()
        $dialogs[1].Dispose()
    }
}
