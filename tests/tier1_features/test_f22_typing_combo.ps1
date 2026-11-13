# test_f22_typing_combo.ps1
# Feature 22: Gamified Typing Combo (Arcade Hit Counter, Rank Tiers, Particles & Menu Integration)
# Verifies typing combo mechanics, rank progression, localization, settings portability, and GDI+ rendering.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 22: Gamified Typing Combo & Menu Integration" {
    $islandType = Get-TepiType "Island"
    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Verifies View.Combo exists in Tepi.View enum" {
        $viewType = Get-TepiType "View"
        Assert-NotNull $viewType "View enum must exist"
        $names = [System.Enum]::GetNames($viewType)
        Assert-True ($names -contains "Combo") "View enum must contain 'Combo'"
    }

    It "Verifies ComboTierFor maps hit counts to arcade tiers 0..6" {
        $t0 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]0)
        $t0b = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]2)
        $t1 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]3)
        $t2 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]10)
        $t3 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]25)
        $t4 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]50)
        $t5 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]100)
        $t6 = Invoke-TepiStaticMethod "Island" "ComboTierFor" @([int]200)

        Assert-Equal $t0 0 "0 hits -> Tier 0 (warmup)"
        Assert-Equal $t0b 0 "2 hits -> Tier 0 (warmup)"
        Assert-Equal $t1 1 "3 hits -> Tier 1 (COMBO)"
        Assert-Equal $t2 2 "10 hits -> Tier 2 (NICE!)"
        Assert-Equal $t3 3 "25 hits -> Tier 3 (GREAT!!)"
        Assert-Equal $t4 4 "50 hits -> Tier 4 (AWESOME!)"
        Assert-Equal $t5 5 "100 hits -> Tier 5 (ULTRA!!)"
        Assert-Equal $t6 6 "200 hits -> Tier 6 (GODLIKE!!!)"
    }

    It "Verifies ComboRankLabel and ComboTierColor return valid labels and opaque colors for all tiers" {
        $expectedLabels = @{
            1 = "COMBO"
            2 = "NICE!"
            3 = "GREAT!!"
            4 = "AWESOME!"
            5 = "ULTRA!!"
            6 = "GODLIKE!!!"
        }

        foreach ($tier in 1..6) {
            $label = Invoke-TepiStaticMethod "Island" "ComboRankLabel" @([int]$tier)
            Assert-Equal $label $expectedLabels[$tier] "Tier $tier rank label must match"

            $col = Invoke-TepiStaticMethod "Island" "ComboTierColor" @([int]$tier, [double]1.25)
            Assert-NotNull $col "Tier $tier color must not be null"
            Assert-Equal $col.A 255 "Tier $tier color must be fully opaque"

            $sub = Invoke-TepiStaticMethod "Island" "ComboRankSubtitle" @([int]$tier)
            Assert-True ($sub.Length -gt 0) "Tier $tier subtitle must be non-empty"
        }
    }

    It "Verifies keys.combo and keys.combo.sound are included in SettingsIO.Portable" {
        $portable = Get-TepiStaticField "Island" "Portable"
        Assert-NotNull $portable "Island.Portable HashSet must exist"
        Assert-True ($portable.Contains("keys.combo")) "Portable settings must include keys.combo"
        Assert-True ($portable.Contains("keys.combo.sound")) "Portable settings must include keys.combo.sound"
    }

    It "Verifies Indonesian and English localization for Combo Ketikan menu and subtitles" {
        $langType = Get-TepiType "Lang"
        $enProp = $langType.GetField("English", [System.Reflection.BindingFlags]'Public,Static')
        $prevEn = $enProp.GetValue($null)
        try {
            $enProp.SetValue($null, $true)
            $tMenu = Invoke-TepiStaticMethod "Lang" "T" @("Combo Ketikan")
            $tGod = Invoke-TepiStaticMethod "Lang" "T" @("Dewa Ketik!")
            Assert-Equal $tMenu "Typing Combo" "Combo Ketikan must translate to Typing Combo in English"
            Assert-Equal $tGod "Typing God!" "Dewa Ketik! must translate to Typing God! in English"
        }
        finally {
            $enProp.SetValue($null, $prevEn)
        }
    }

    It "Verifies Combo Ketikan row glyph is registered in PrefsWindow.RowGlyphs" {
        $prefsType = Get-TepiType "PrefsWindow"
        Assert-NotNull $prefsType "PrefsWindow type must exist"
        $glyphFor = $prefsType.GetMethod("GlyphFor", [System.Reflection.BindingFlags]'NonPublic,Public,Static')
        Assert-NotNull $glyphFor "GlyphFor method must exist"
        $gCombo = [char]$glyphFor.Invoke($null, @("Combo Ketikan"))
        Assert-Equal ([int]$gCombo) 0xE7FC "Combo Ketikan must use game controller glyph 0xE7FC"
    }

    It "Simulates fast typing burst on Island instance, activates View.Combo, and renders DrawCombo offscreen" {
        $isle = [Activator]::CreateInstance($islandType)
        $settingsField = $islandType.GetField("settings", $flags)
        $settings = $settingsField.GetValue($isle)
        $setMethod = $settings.GetType().GetMethod("Set", [Type[]]@([string], [string]))
        $getMethod = $settings.GetType().GetMethod("Get", [Type[]]@([string], [string]))
        $prevCombo = $getMethod.Invoke($settings, @("keys.combo", "0"))

        $bmp = New-Object System.Drawing.Bitmap 420, 60
        $gr = [System.Drawing.Graphics]::FromImage($bmp)
        $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        try {
            [void]$setMethod.Invoke($settings, @("keys.combo", "1"))
            $isle.ResetCombo()

            # Bind offscreen Graphics to Island.g and Island.p.G
            $gField = $islandType.GetField("g", $flags)
            $pField = $islandType.GetField("p", $flags)
            $painter = $pField.GetValue($isle)
            $gField.SetValue($isle, $gr)
            $painter.GetType().GetField("G", $flags).SetValue($painter, $gr)

            # 2 hits: still warming up (< 3 hits)
            Assert-True ($isle.RegisterComboKeystroke(0x41)) "1st keystroke (A) accepted"
            $isle.ReleaseComboKey(0x41)
            Assert-False $isle.ComboShowing "Not yet showing after 1 hit"

            Assert-True ($isle.RegisterComboKeystroke(0x53)) "2nd keystroke (S) accepted"
            $isle.ReleaseComboKey(0x53)
            Assert-False $isle.ComboShowing "Not yet showing after 2 hits"

            # 3rd hit: activates ComboShowing!
            Assert-True ($isle.RegisterComboKeystroke(0x44)) "3rd keystroke (D) accepted"
            $isle.ReleaseComboKey(0x44)
            Assert-True $isle.ComboShowing "ComboShowing becomes true at 3 hits"
            Assert-Equal $isle.ComboCount 3 "ComboCount equals 3"
            Assert-Equal $isle.ComboTier 1 "ComboTier equals 1 (COMBO)"

            # Pump up to 30 hits (Tier 3: GREAT!!)
            for ($i = 4; $i -le 30; $i++) {
                $vk = 0x41 + ($i % 26)
                [void]$isle.RegisterComboKeystroke($vk)
                $isle.ReleaseComboKey($vk)
            }
            Assert-Equal $isle.ComboCount 30 "ComboCount reaches 30"
            Assert-Equal $isle.ComboTier 3 "ComboTier reaches 3 (GREAT!!)"
            Assert-True ($isle.ComboWpm -ge 15) "ComboWpm is calculated (>= 15)"

            # Verify DesiredView returns View.Combo
            $desiredMethod = $islandType.GetMethod("DesiredView", $flags)
            $desired = $desiredMethod.Invoke($isle, @())
            Assert-Equal ($desired.ToString()) "Combo" "DesiredView() must return View.Combo while ComboShowing is active"

            # Render DrawCombo offscreen and verify pixels are drawn
            $gr.Clear([System.Drawing.Color]::FromArgb(255, 16, 18, 22))
            $drawCombo = $islandType.GetMethod("DrawCombo", $flags)
            [void]$drawCombo.Invoke($isle, @([float]360.0, [float]48.0, [DateTime]::UtcNow))

            $nonBgPixels = 0
            for ($x = 15; $x -lt 345; $x += 6) {
                $px = $bmp.GetPixel($x, 22)
                if ($px.R -ne 16 -or $px.G -ne 18 -or $px.B -ne 22) {
                    $nonBgPixels++
                }
            }
            Assert-True ($nonBgPixels -gt 5) "DrawCombo must render visible HUD elements onto the canvas (changed samples: $nonBgPixels)"
        }
        finally {
            [void]$setMethod.Invoke($settings, @("keys.combo", $prevCombo))
            $isle.ResetCombo()
            $gr.Dispose()
            $bmp.Dispose()
            $isle.Dispose()
        }
    }
}
