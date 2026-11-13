# test_f23_typing_gamification.ps1
# Feature 23: Typing Combo Gamification (Audio Synth, Overdrive/Fever, Backspace Penalty, Enter Finisher, RPG/Quest/Badges, 30s Sprint, Overview & Prefs)

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 23: Typing Combo Gamification & Settings" {
    $islandType = Get-TepiType "Island"
    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'

    $settingsType = Get-TepiType "Settings"
    $settingsDir = $settingsType.GetField("Dir", $flags).GetValue($null)
    $settingsFile = Join-Path $settingsDir "settings.ini"
    $backupContent = $null
    $hadFile = Test-Path $settingsFile
    if ($hadFile) {
        $backupContent = [System.IO.File]::ReadAllText($settingsFile, [System.Text.Encoding]::UTF8)
    }

    try {
        BeforeEach {
            Reset-TepiTheme -Light $false
        }

        It "1. In-memory Audio Synthesizer builds RIFF/WAVE buffers, switches profiles, and frees pinned handles" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $settingsField = $islandType.GetField("settings", $flags)
                $s = $settingsField.GetValue($isle)
                $s.Set("keys.combo", "1")
                $s.Set("keys.combo.sound", "1")

                $ensureMethod = $islandType.GetMethod("EnsureComboAudio", $flags)
                $ensureMethod.Invoke($isle, $null) | Out-Null

                $blips = $islandType.GetField("comboArcadeBlips", $flags).GetValue($isle)
                $thocks = $islandType.GetField("comboThockVariants", $flags).GetValue($isle)
                $clicks = $islandType.GetField("comboClickVariants", $flags).GetValue($isle)
                $pianoNotes = $islandType.GetField("comboPianoNotes", $flags).GetValue($isle)
                $chimes = $islandType.GetField("comboTierChimes", $flags).GetValue($isle)
                $pb = $islandType.GetField("comboPbFanfareWav", $flags).GetValue($isle)
                $crit = $islandType.GetField("comboCriticalWav", $flags).GetValue($isle)
                $broken = $islandType.GetField("comboBrokenWav", $flags).GetValue($isle)
                $crack = $islandType.GetField("comboShieldCrackWav", $flags).GetValue($isle)

                Assert-Equal $blips.Length 50 "Should pre-build 50 arcade blips"
                Assert-Equal $thocks.Length 6 "Should pre-build 6 thock variants"
                Assert-Equal $clicks.Length 6 "Should pre-build 6 click variants"
                Assert-Equal $pianoNotes.Length 11 "Should pre-build 11 piano notes"
                Assert-Equal $chimes.Length 5 "Should pre-build 5 tier chimes"
                Assert-NotNull $pb "PB fanfare WAV must be non-null"
                Assert-NotNull $crit "Critical WAV must be non-null"
                Assert-NotNull $broken "Broken WAV must be non-null"
                Assert-NotNull $crack "Shield crack WAV must be non-null"

                # Verify RIFF/WAVE headers and non-zero PCM sample bytes
                $dataField = $blips[0].GetType().GetField("Data", $flags)
                $samplesField = $blips[0].GetType().GetField("Samples", $flags)
                foreach ($pw in @($blips[0], $thocks[0], $clicks[0], $pianoNotes[0], $chimes[0], $pb, $crit, $broken, $crack)) {
                    $bytes = $dataField.GetValue($pw)
                    Assert-True ($bytes.Length -gt 44) "WAV buffer must exceed 44-byte header"
                    $riff = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
                    $wave = [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4)
                    Assert-Equal $riff "RIFF" "Header must start with RIFF"
                    Assert-Equal $wave "WAVE" "Header must contain WAVE"
                    $hasNonZero = $false
                    for ($i = 44; $i -lt [Math]::Min($bytes.Length, 200); $i++) {
                        if ($bytes[$i] -ne 0) { $hasNonZero = $true; break }
                    }
                    Assert-True $hasNonZero "WAV buffer must contain non-zero PCM samples"
                    $samples = $samplesField.GetValue($pw)
                    $lastSample = $samples[$samples.Length - 1]
                    Assert-True ([Math]::Abs($lastSample) -le 32) "Last sample must be near zero to prevent tail clicks (got $lastSample)"
                }

                foreach ($prof in @("arcade", "thocky", "clicky", "piano", "classic")) {
                    $s.Set("keys.combo.sound.profile", $prof)
                    Assert-Equal $isle.ComboSoundProfile $prof "ComboSoundProfile should reflect setting"
                    $isle.PlayComboTestSound()
                }
                # Verify warmup hits 1-2 play audio while ComboShowing stays false, and polyphony mixes concurrent voices
                $s.Set("keys.combo.sound.profile", "clicky")
                $isle.RegisterComboKeystroke(0x41) | Out-Null
                $isle.ReleaseComboKey(0x41)
                Assert-False $isle.ComboShowing "Warmup hit 1 must not activate ComboShowing"
                $voicesField = $islandType.GetField("comboVoices", $flags)
                $playedField = $islandType.GetField("mixerHasPlayed", $flags)
                Assert-True ($playedField.GetValue($isle)) "Warmup hit 1 must trigger audio mixer"

                $isleType = $islandType
                $isleType.GetMethod("PlayComboPbFanfare", $flags).Invoke($isle, $null) | Out-Null
                $isleType.GetMethod("PlayComboTierUpSound", $flags).Invoke($isle, @([int]3)) | Out-Null
                $isleType.GetMethod("PlayComboKeySound", $flags).Invoke($isle, @([int]4, $false)) | Out-Null
                $activeVoices = @($voicesField.GetValue($isle) | Where-Object { $_.Active }).Count
                Assert-True ($activeVoices -ge 3) "Polyphonic mixer must keep >= 3 concurrent voices active (got $activeVoices)"

                $s.Set("keys.combo.sound.profile", "piano")
                for ($k = 1; $k -le 15; $k++) {
                    $isleType.GetMethod("PlayComboKeySound", $flags).Invoke($isle, @([int]$k, $false)) | Out-Null
                }
                $pianoVoices = @($voicesField.GetValue($isle) | Where-Object { $_.Active }).Count
                Assert-True ($pianoVoices -ge 3) "Rapid piano keystrokes must keep multiple overlapping voices active (got $pianoVoices)"

                $isle.StopComboAudio()
                $allList = $islandType.GetField("comboAudioAll", $flags).GetValue($isle)
                Assert-Equal $allList.Count 0 "StopComboAudio must free and clear all pinned handles"
                $mtAfter = $islandType.GetField("mixerThread", $flags).GetValue($isle)
                Assert-True ($null -eq $mtAfter) "StopComboAudio must stop and clear mixerThread"
            }
            finally {
                $isle.Dispose()
            }
        }

        It "2. Overdrive / Fever Mode activates at Tier 5+, triggers EdgeMoving, and renders DrawCombo + DrawEdgeLight" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $settingsField = $islandType.GetField("settings", $flags)
                $s = $settingsField.GetValue($isle)
                $s.Set("keys.combo", "1")
                $s.Set("keys.combo.fever", "1")
                $s.Set("edge.light", "1")
                $isle.ResetComboStats()

                for ($i = 0; $i -lt 105; $i++) {
                    $vk = 0x41 + ($i % 26)
                    $isle.RegisterComboKeystroke($vk) | Out-Null
                    $isle.ReleaseComboKey($vk)
                }

                Assert-Equal $isle.ComboTier 5 "105 hits -> Tier 5 (ULTRA!!)"
                Assert-True $isle.ComboFeverActive "ComboFeverActive should be true at Tier 5 with keys.combo.fever=1"

                $s.Set("keys.combo.fever", "0")
                Assert-False $isle.ComboFeverActive "ComboFeverActive should be false when keys.combo.fever=0"
                $s.Set("keys.combo.fever", "1")

                # Set View.Combo and test EdgeMoving + DrawCombo + DrawEdgeLight
                $viewType = Get-TepiType "View"
                $viewCombo = [Enum]::Parse($viewType, "Combo")
                $islandType.GetField("current", $flags).SetValue($isle, $viewCombo)

                $edgeMoving = $islandType.GetMethod("EdgeMoving", $flags)
                $moving = $edgeMoving.Invoke($isle, @([DateTime]::UtcNow))
                Assert-True $moving "EdgeMoving must return true during Fever Mode on View.Combo"

                $bmp = New-Object System.Drawing.Bitmap(440, 72)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $g.Clear([System.Drawing.Color]::FromArgb(255, 16, 18, 22))
                    $pField = $islandType.GetField("p", $flags)
                    $painter = $pField.GetValue($isle)
                    $painter.GetType().GetField("G", $flags).SetValue($painter, $g)
                    $islandType.GetField("g", $flags).SetValue($isle, $g)

                    $islandType.GetMethod("DrawCombo", $flags).Invoke($isle, @([float]380, [float]48, [DateTime]::UtcNow)) | Out-Null
                    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                    $rect = New-Object System.Drawing.RectangleF(0, 0, 380, 48)
                    $path.AddRectangle($rect)
                    $islandType.GetMethod("DrawEdgeLight", $flags).Invoke($isle, @([DateTime]::UtcNow, [System.Drawing.Drawing2D.GraphicsPath]$path, [System.Drawing.RectangleF]$rect)) | Out-Null
                    $path.Dispose()

                    $nonBg = 0
                    for ($x = 10; $x -lt 370; $x += 8) {
                        $c = $bmp.GetPixel($x, 24)
                        if ($c.R -gt 22 -or $c.G -gt 24 -or $c.B -gt 28) { $nonBg++ }
                    }
                    Assert-True ($nonBg -gt 3) "DrawCombo + DrawEdgeLight must render visible pixels"
                }
                finally {
                    $g.Dispose()
                    $bmp.Dispose()
                }
            }
            finally {
                $isle.Dispose()
            }
        }

        It "3. Backspace penalty (shield, drain, off), PERFECT CHAIN 25+, and BreakCombo shatter" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $settingsField = $islandType.GetField("settings", $flags)
                $s = $settingsField.GetValue($isle)
                $s.Set("keys.combo", "1")
                $s.Set("keys.combo.penalty", "shield")
                $isle.ResetComboStats()

                # Activate combo (3 hits)
                for ($i = 0; $i -lt 3; $i++) {
                    $isle.RegisterComboKeystroke(0x41 + $i) | Out-Null
                    $isle.ReleaseComboKey(0x41 + $i)
                }
                $shieldsField = $islandType.GetField("comboShields", $flags)
                $crackField = $islandType.GetField("comboShieldCrack", $flags)
                $activeField = $islandType.GetField("comboActive", $flags)
                Assert-Equal $shieldsField.GetValue($isle) 1 "Combo activation in shield mode starts with 1 shield"

                # Press Backspace (0x08) -> absorbs with shield
                $isle.RegisterComboKeystroke(0x08) | Out-Null
                $isle.ReleaseComboKey(0x08)
                Assert-Equal $isle.ComboCount 3 "Backspace must not increment ComboCount"
                Assert-True $activeField.GetValue($isle) "Combo must remain active when shield absorbs Backspace"
                Assert-Equal $shieldsField.GetValue($isle) 0 "Shield count must drop to 0"
                Assert-True ($crackField.GetValue($isle) -gt 0) "comboShieldCrack must be > 0"

                # Pump 25 clean hits -> PERFECT CHAIN! + shield replenish
                for ($i = 0; $i -lt 25; $i++) {
                    $vk = 0x41 + ($i % 26)
                    $isle.RegisterComboKeystroke($vk) | Out-Null
                    $isle.ReleaseComboKey($vk)
                }
                $cleanField = $islandType.GetField("comboCleanStreak", $flags)
                $goldField = $islandType.GetField("comboGoldFlash", $flags)
                Assert-Equal $cleanField.GetValue($isle) 25 "comboCleanStreak should be 25"
                Assert-True ($goldField.GetValue($isle) -gt 0) "comboGoldFlash should trigger on PERFECT CHAIN!"
                Assert-Equal $shieldsField.GetValue($isle) 1 "Shield should replenish to 1 on 25x clean streak"

                # Exhaust shield + repeated Backspaces -> BreakCombo()
                for ($b = 0; $b -lt 8; $b++) {
                    if (-not $activeField.GetValue($isle)) { break }
                    $isle.RegisterComboKeystroke(0x08) | Out-Null
                    $isle.ReleaseComboKey(0x08)
                }
                $brokenField = $islandType.GetField("comboBrokenLeft", $flags)
                Assert-False $activeField.GetValue($isle) "Combo must break after exhausting shield and draining timer"
                Assert-Equal $isle.ComboCount 0 "ComboCount must reset to 0 on break"
                Assert-True ($brokenField.GetValue($isle) -gt 0) "comboBrokenLeft must be > 0 on break"

                # Test drain mode (no shields)
                $isle.ResetCombo()
                $s.Set("keys.combo.penalty", "drain")
                for ($i = 0; $i -lt 3; $i++) {
                    $isle.RegisterComboKeystroke(0x41 + $i) | Out-Null
                    $isle.ReleaseComboKey(0x41 + $i)
                }
                Assert-Equal $shieldsField.GetValue($isle) 0 "Drain mode starts with 0 shields"
                $tBefore = $islandType.GetField("comboTimeLeft", $flags).GetValue($isle)
                $isle.RegisterComboKeystroke(0x08) | Out-Null
                $isle.ReleaseComboKey(0x08)
                $tAfter = $islandType.GetField("comboTimeLeft", $flags).GetValue($isle)
                Assert-True ($tAfter -lt $tBefore) "Drain mode must reduce comboTimeLeft on Backspace"

                # Test off mode (does not break)
                $isle.ResetCombo()
                $s.Set("keys.combo.penalty", "off")
                for ($i = 0; $i -lt 3; $i++) {
                    $isle.RegisterComboKeystroke(0x41 + $i) | Out-Null
                    $isle.ReleaseComboKey(0x41 + $i)
                }
                $isle.RegisterComboKeystroke(0x08) | Out-Null
                $isle.ReleaseComboKey(0x08)
                Assert-True $activeField.GetValue($isle) "Off mode must not break combo on Backspace"
            }
            finally {
                $isle.Dispose()
            }
        }

        It "4. Enter (0x0D) Critical Finish triggers at 25+ hits when enabled, and skips below 25 or when disabled" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $settingsField = $islandType.GetField("settings", $flags)
                $s = $settingsField.GetValue($isle)
                $s.Set("keys.combo", "1")
                $s.Set("keys.combo.enter", "1")
                $isle.ResetComboStats()

                # Below 25 hits -> should NOT trigger
                for ($i = 0; $i -lt 10; $i++) {
                    $vk = 0x41 + ($i % 26)
                    $isle.RegisterComboKeystroke($vk) | Out-Null
                    $isle.ReleaseComboKey($vk)
                }
                $isle.RegisterComboKeystroke(0x0D) | Out-Null
                $isle.ReleaseComboKey(0x0D)
                $smashField = $islandType.GetField("comboEnterSmash", $flags)
                Assert-Equal ([float]$smashField.GetValue($isle)) ([float]0) "Enter below 25 hits must not trigger comboEnterSmash"

                # Disabled -> should NOT trigger at 25+
                $s.Set("keys.combo.enter", "0")
                for ($i = 0; $i -lt 20; $i++) {
                    $vk = 0x41 + ($i % 26)
                    $isle.RegisterComboKeystroke($vk) | Out-Null
                    $isle.ReleaseComboKey($vk)
                }
                $isle.RegisterComboKeystroke(0x0D) | Out-Null
                $isle.ReleaseComboKey(0x0D)
                Assert-Equal ([float]$smashField.GetValue($isle)) ([float]0) "Enter with keys.combo.enter=0 must not trigger comboEnterSmash"

                # Enabled at 25+ -> triggers CRITICAL FINISH!
                $s.Set("keys.combo.enter", "1")
                $xpBefore = $isle.ComboXp
                $isle.RegisterComboKeystroke(0x0D) | Out-Null
                $isle.ReleaseComboKey(0x0D)
                $ring2Field = $islandType.GetField("comboRing2", $flags)
                Assert-Equal ([float]$smashField.GetValue($isle)) ([float]1) "Enter at 25+ hits must set comboEnterSmash=1"
                Assert-True ($ring2Field.GetValue($isle) -gt 0) "Enter finisher must trigger comboRing2"
                Assert-True ($isle.HasComboBadge("critical_finisher")) "Must unlock critical_finisher badge"
                Assert-True ($isle.ComboXp -gt $xpBefore) "Must award bonus XP"
            }
            finally {
                $isle.Dispose()
            }
        }

        It "5. RPG Level, XP, Daily Quest, Badges, SettingsIO.Portable, and ResetComboStats" {
            $portable = Get-TepiStaticField "Island" "Portable"
            foreach ($k in @("keys.combo.sound.profile", "keys.combo.fever", "keys.combo.penalty", "keys.combo.enter", "keys.combo.rpg", "keys.combo.quest.chars", "keys.combo.quest.combos")) {
                Assert-True ($portable.Contains($k)) "Portable settings must include $k"
            }
            foreach ($pKey in @("combo.xp", "combo.best", "combo.badges", "combo.daily.chars")) {
                Assert-False ($portable.Contains($pKey)) "Portable settings must NOT include personal stat $pKey"
            }

            $lv0 = Invoke-TepiStaticMethod "Island" "ComboLevelFor" @([int]0)
            $lv1 = Invoke-TepiStaticMethod "Island" "ComboLevelFor" @([int]500)
            $lv2 = Invoke-TepiStaticMethod "Island" "ComboLevelFor" @([int]2500)
            Assert-Equal $lv0 1 "0 XP -> Level 1"
            Assert-True ($lv1 -gt $lv0 -and $lv2 -gt $lv1) "Level must increase monotonically with XP"

            $prog = Invoke-TepiStaticMethod "Island" "ComboLevelProgressFor" @([int]50)
            Assert-True ($prog -ge 0 -and $prog -lt 1) "ComboLevelProgressFor must be in [0, 1)"

            $isle = [Activator]::CreateInstance($islandType)
            try {
                $isle.ResetComboStats()
                $settingsField = $islandType.GetField("settings", $flags)
                $s = $settingsField.GetValue($isle)
                $s.Set("keys.combo.quest.chars", "100")
                $s.Set("keys.combo.quest.combos", "1")
                $islandType.GetField("comboDailyChars", $flags).SetValue($isle, 100)
                $islandType.GetField("comboDaily100x", $flags).SetValue($isle, 1)
                $xpBefore = $isle.ComboXp
                $islandType.GetMethod("CheckDailyQuest", $flags).Invoke($isle, $null) | Out-Null
                Assert-True $isle.ComboDailyQuestDone "Daily quest should complete when goals are met"
                Assert-Equal $isle.ComboXp ($xpBefore + 150) "Daily quest completion must award +150 XP"

                $isle.ResetComboStats()
                Assert-Equal $isle.ComboXp 0 "ResetComboStats must zero XP"
                Assert-Equal $isle.ComboAllTimeBest 0 "ResetComboStats must zero AllTimeBest"
                Assert-Equal $isle.ComboDailyChars 0 "ResetComboStats must zero DailyChars"
                Assert-Equal $isle.ComboBadgesCount 0 "ResetComboStats must clear badges"
            }
            finally {
                $isle.Dispose()
            }
        }

        It "6. Overview HomeCard.Combo, 30s Sprint, PrefsWindow combo tab, and Lang.cs translations" {
            $homeCardType = Get-TepiType "HomeCard"
            $names = [Enum]::GetNames($homeCardType)
            Assert-True ($names -contains "Combo") "HomeCard enum must contain Combo"
            $homeIds = Get-TepiStaticField "Island" "HomeIds"
            $homeNames = Get-TepiStaticField "Island" "HomeNames"
            Assert-True ($homeIds -contains "combo") "HomeIds must contain combo"
            Assert-True ($homeNames -contains "Combo Ketikan") "HomeNames must contain Combo Ketikan"

            $isle = [Activator]::CreateInstance($islandType)
            try {
                $isle.ResetComboStats()
                $isle.StartTypingSprint()
                Assert-True $isle.TypingSprintActive "StartTypingSprint must activate sprint"
                Assert-Equal ([int]$isle.TypingSprintLeft) 30 "TypingSprintLeft must start at 30"

                for ($i = 0; $i -lt 220; $i++) {
                    $vk = 0x41 + ($i % 26)
                    $isle.RegisterComboKeystroke($vk) | Out-Null
                    $isle.ReleaseComboKey($vk)
                }
                $stepMethod = $islandType.GetMethod("StepCombo", $flags)
                $stepMethod.Invoke($isle, @([float]30.5)) | Out-Null
                Assert-False $isle.TypingSprintActive "Sprint must finish after 30.5s"
                Assert-True ($isle.ComboSprintBestWpm -ge 80) "220 chars in 30s should yield >= 80 WPM"
                Assert-True ($isle.HasComboBadge("sprint_pro")) "Sprint >= 80 WPM must unlock sprint_pro badge"

                $isle.StartTypingSprint()
                $isle.StopTypingSprint()
                Assert-False $isle.TypingSprintActive "StopTypingSprint must cancel active sprint"

                # PrefsWindow "combo" tab & GlyphFor
                $prefsType = Get-TepiType "PrefsWindow"
                $glyphFor = $prefsType.GetMethod("GlyphFor", $flags)
                # DrawComboCard offscreen rendering
                $cardBmp = New-Object System.Drawing.Bitmap(260, 92)
                $cardG = [System.Drawing.Graphics]::FromImage($cardBmp)
                try {
                    $cardG.Clear([System.Drawing.Color]::FromArgb(255, 16, 18, 22))
                    $painter = $islandType.GetField("p", $flags).GetValue($isle)
                    $painter.GetType().GetField("G", $flags).SetValue($painter, $cardG)
                    $islandType.GetField("g", $flags).SetValue($isle, $cardG)
                    $cardRect = New-Object System.Drawing.RectangleF(0, 0, 260, 92)
                    $islandType.GetMethod("DrawComboCard", $flags).Invoke($isle, @([System.Drawing.RectangleF]$cardRect)) | Out-Null
                    $cardPixels = 0
                    for ($x = 12; $x -lt 248; $x += 8) {
                        for ($y = 12; $y -lt 80; $y += 8) {
                            $c = $cardBmp.GetPixel($x, $y)
                            if ($c.R -gt 22 -or $c.G -gt 24 -or $c.B -gt 28) { $cardPixels++ }
                        }
                    }
                    Assert-True ($cardPixels -gt 5) "DrawComboCard must render visible pixels"
                }
                finally {
                    $cardG.Dispose()
                    $cardBmp.Dispose()
                }

                foreach ($lbl in @("Overdrive / Fever Mode", "Finisher tombol Enter", "Profil suara", "Mode penalti", "Typing Sprint 30 Detik")) {
                    $gChar = $glyphFor.Invoke($null, @($lbl))
                    Assert-True ([int]$gChar -ne 0xE713) "GlyphFor('$lbl') must return a custom icon, not fallback 0xE713"
                }

                $prefsWin = [Activator]::CreateInstance($prefsType, $flags, $null, @($isle), $null)
                try {
                    $prefsType.GetMethod("Go", $flags).Invoke($prefsWin, @("combo")) | Out-Null
                    $prefsType.GetMethod("Relayout", $flags).Invoke($prefsWin, $null) | Out-Null
                    Assert-True ($prefsWin.Controls.Count -gt 0) "PrefsWindow 'combo' tab must populate controls"
                }
                finally {
                    $prefsWin.Dispose()
                }

                # Lang.cs English translations
                $langType = Get-TepiType "Lang"
                $engField = $langType.GetField("English", $flags)
                $prevEng = $engField.GetValue($null)
                try {
                    $engField.SetValue($null, $true)
                    Assert-Equal (Invoke-TepiStaticMethod "Lang" "T" @("Finisher tombol Enter")) "Enter key finisher" "English translation for Finisher tombol Enter"
                    Assert-Equal (Invoke-TepiStaticMethod "Lang" "T" @("Mulai Sprint")) "Start Sprint" "English translation for Mulai Sprint"
                    Assert-Equal (Invoke-TepiStaticMethod "Lang" "T" @("Pemula")) "Beginner" "English translation for Pemula"
                }
                finally {
                    $engField.SetValue($null, $prevEng)
                }
            }
            finally {
                $isle.Dispose()
            }
        }
        It "7. Regression checks for Fever multiplier, penalty off, BreakCombo reset, CanExpand, and Sprint DrawComboCard" {
            $isle = [Activator]::CreateInstance($islandType)
            $flags = [System.Reflection.BindingFlags]"Instance,NonPublic,Public,Static"
            $settings = $islandType.GetField("settings", $flags).GetValue($isle)
            try {
                $isle.ResetComboStats()
                $settings.Set("keys.combo", "1")
                $settings.Set("keys.combo.rpg", "1")

                # 1) keys.combo.fever = "0" disables 2x XP multiplier at Tier 5
                $settings.Set("keys.combo.fever", "0")
                $islandType.GetField("comboCount", $flags).SetValue($isle, 100)
                $islandType.GetField("comboActive", $flags).SetValue($isle, $true)
                $xpBefore = $isle.ComboXp
                $isle.RegisterComboKeystroke(0x41) | Out-Null
                $isle.ReleaseComboKey(0x41)
                Assert-Equal ($isle.ComboXp - $xpBefore) 1 "Fever off at Tier 5 must grant +1 XP"

                $settings.Set("keys.combo.fever", "1")
                $xpBefore2 = $isle.ComboXp
                $isle.RegisterComboKeystroke(0x42) | Out-Null
                $isle.ReleaseComboKey(0x42)
                Assert-Equal ($isle.ComboXp - $xpBefore2) 2 "Fever on at Tier 5 must grant +2 XP"

                # 2) keys.combo.penalty = "off" keeps comboActive = true and does NOT increment ComboCount on Backspace
                $settings.Set("keys.combo.penalty", "off")
                $countBeforeBs = $isle.ComboCount
                $isle.RegisterComboKeystroke(0x08) | Out-Null
                $isle.ReleaseComboKey(0x08)
                Assert-True ($islandType.GetField("comboActive", $flags).GetValue($isle)) "Penalty off must keep comboActive = true on Backspace"
                Assert-Equal $isle.ComboCount $countBeforeBs "Penalty off must NOT increment ComboCount on Backspace"

                # 3) StepCombo(1.5f) after BreakCombo() resets comboBrokenLeft, comboWpm, and comboPeakWpm to 0
                $islandType.GetMethod("BreakCombo", $flags).Invoke($isle, $null) | Out-Null
                $islandType.GetMethod("StepCombo", $flags).Invoke($isle, @([float]1.5)) | Out-Null
                Assert-Equal ([float]$islandType.GetField("comboBrokenLeft", $flags).GetValue($isle)) ([float]0) "comboBrokenLeft must reset to 0"
                Assert-Equal $isle.ComboWpm 0 "comboWpm must reset to 0 after BreakCombo expires"
                Assert-Equal ([int]$islandType.GetField("comboPeakWpm", $flags).GetValue($isle)) 0 "comboPeakWpm must reset to 0 after BreakCombo expires"

                # 3b) Immediate restart after BreakCombo() without waiting for comboBrokenLeft to expire must NOT carry over prior comboWpm / comboPeakWpm
                $islandType.GetField("comboCount", $flags).SetValue($isle, 10)
                $islandType.GetField("comboActive", $flags).SetValue($isle, $true)
                $islandType.GetMethod("BreakCombo", $flags).Invoke($isle, $null) | Out-Null
                Assert-Equal $isle.ComboWpm 0 "comboWpm must reset to 0 immediately in BreakCombo"
                Assert-Equal ([int]$islandType.GetField("comboPeakWpm", $flags).GetValue($isle)) 0 "comboPeakWpm must reset to 0 immediately in BreakCombo"
                $islandType.GetField("comboWpm", $flags).SetValue($isle, 250)
                $islandType.GetField("comboPeakWpm", $flags).SetValue($isle, 250)
                foreach ($vk in @(0x41, 0x42, 0x43)) {
                    $isle.RegisterComboKeystroke($vk) | Out-Null
                    $isle.ReleaseComboKey($vk)
                }
                $newPeak = [int]$islandType.GetField("comboPeakWpm", $flags).GetValue($isle)
                Assert-Equal $newPeak $isle.ComboWpm "Immediate 3-hit restart during comboBrokenLeft must reset comboPeakWpm to new run's ComboWpm"
                Assert-True ($newPeak -lt 250) "Immediate 3-hit restart must NOT carry over stale 250 PeakWPM"

                # 4) CanExpand() returns $false while TypingSprintActive is $true
                $isle.StartTypingSprint()
                Assert-True $isle.TypingSprintActive "TypingSprintActive must be true"
                $canExpand = $islandType.GetMethod("CanExpand", $flags).Invoke($isle, $null)
                Assert-True (-not $canExpand) "CanExpand() must return false during active Typing Sprint"

                # 5) DrawComboCard renders visible pixels during TypingSprintActive even when ComboOn = false and ComboXp = 0
                $settings.Set("keys.combo", "0")
                $islandType.GetField("comboXp", $flags).SetValue($isle, 0)
                $islandType.GetField("comboAllTimeBest", $flags).SetValue($isle, 0)
                $cardBmp = New-Object System.Drawing.Bitmap(260, 100)
                $cardG = [System.Drawing.Graphics]::FromImage($cardBmp)
                try {
                    $cardG.Clear([System.Drawing.Color]::FromArgb(255, 16, 18, 22))
                    $p = $islandType.GetField("p", $flags).GetValue($isle)
                    $p.G = $cardG
                    $p.T = (Get-TepiType "Ink").GetField("Base", $flags).GetValue($null)
                    $rect = New-Object System.Drawing.RectangleF(0, 0, 260, 100)
                    $islandType.GetMethod("DrawComboCard", $flags).Invoke($isle, @($rect)) | Out-Null
                    $cardPixels = 0
                    for ($x = 12; $x -lt 248; $x += 8) {
                        $px = $cardBmp.GetPixel($x, 50)
                        if ($px.R -ne 16 -or $px.G -ne 18 -or $px.B -ne 22) { $cardPixels++ }
                    }
                    Assert-True ($cardPixels -gt 5) "DrawComboCard must render visible pixels during Sprint even when ComboOn=false and ComboXp=0"
                }
                finally {
                    $cardG.Dispose()
                    $cardBmp.Dispose()
                }

                # 6) SpawnComboCallout 4 times in a row places 4 non-colliding callouts (|a.Y - b.Y| >= 8.5)
                $animType = Get-TepiType "Anim"
                $reducedField = $animType.GetField("Reduced", $flags)
                $prevReduced = $reducedField.GetValue($null)
                $reducedField.SetValue($null, $false)
                try {
                    $calloutsField = $islandType.GetField("comboCallouts", $flags)
                    $callouts = $calloutsField.GetValue($isle)
                    $callouts.Clear()
                    $spawnCallout = $islandType.GetMethod("SpawnComboCallout", $flags)
                    for ($k = 0; $k -lt 4; $k++) {
                        $spawnCallout.Invoke($isle, @("CALLOUT_$k", [System.Drawing.Color]::White)) | Out-Null
                    }
                    Assert-Equal $callouts.Count 4 "4 consecutive SpawnComboCallout calls must keep 4 callouts"
                    for ($i = 0; $i -lt $callouts.Count; $i++) {
                        for ($j = $i + 1; $j -lt $callouts.Count; $j++) {
                            $dy = [Math]::Abs($callouts[$i].Y - $callouts[$j].Y)
                            Assert-True ($dy -ge 8.5) ("Callouts $i and $j must not collide vertically (dy=$dy)")
                        }
                    }
                }
                finally {
                    $reducedField.SetValue($null, $prevReduced)
                }
            }
            finally {
                $isle.Dispose()
            }
        }

        It "8. Typing Combo Confetti physics, reduced-motion guard, and rendering" {
            $isle = [Activator]::CreateInstance($islandType)
            $flags = [System.Reflection.BindingFlags] "Public,NonPublic,Instance"
            $animType = Get-TepiType "Anim"
            $reducedField = $animType.GetField("Reduced", [System.Reflection.BindingFlags] "Public,NonPublic,Static")
            $prevReduced = $reducedField.GetValue($null)
            $reducedField.SetValue($null, $false)
            try {
                $isle.ResetComboStats()
                $settingsField = $islandType.GetField("settings", $flags)
                $sObj = $settingsField.GetValue($isle)
                $sObj.Set("keys.combo", "1")

                $confettiField = $islandType.GetField("comboConfetti", $flags)
                $confettiList = $confettiField.GetValue($isle)
                $confettiList.Clear()

                $onKey = $islandType.GetMethod("OnComboKeystroke", $flags)
                for ($i = 0; $i -lt 10; $i++) {
                    $onKey.Invoke($isle, @(65 + ($i % 26))) | Out-Null
                }
                Assert-True ($confettiList.Count -gt 0) "Reaching Tier 2 (10x) must spawn comboConfetti"

                $firstX = $confettiList[0].X
                $firstFlutter = $confettiList[0].Flutter
                $stepCombo = $islandType.GetMethod("StepCombo", $flags)
                $comboAnim = $islandType.GetMethod("ComboAnimating", $flags)
                $stepCombo.Invoke($isle, @([float]0.2)) | Out-Null
                Assert-True ($confettiList.Count -gt 0) "Confetti must remain active after 0.2s"
                Assert-True ($confettiList[0].X -ne $firstX -or $confettiList[0].Flutter -ne $firstFlutter) "StepCombo(0.2f) must update confetti position/flutter"
                Assert-True ([bool]$comboAnim.Invoke($isle, $null)) "ComboAnimating() must be true while confetti is active"

                # Render DrawCombo with active confetti
                $bmp = New-Object System.Drawing.Bitmap(400, 60)
                $gfx = [System.Drawing.Graphics]::FromImage($bmp)
                $gfx.Clear([System.Drawing.Color]::FromArgb(255, 16, 18, 22))
                $pField = $islandType.GetField("p", $flags)
                $pObj = $pField.GetValue($isle)
                $pType = $pObj.GetType()
                $gField = $islandType.GetField("g", $flags)
                $gField.SetValue($isle, $gfx)
                $pGField = $pType.GetField("G", $flags)
                $pGField.SetValue($pObj, $gfx)
                $drawCombo = $islandType.GetMethod("DrawCombo", $flags)
                $drawCombo.Invoke($isle, @([float]350, [float]48, [DateTime]::UtcNow)) | Out-Null
                $nonBg = 0
                for ($px = 8; $px -lt 342; $px += 8) {
                    for ($py = 6; $py -lt 44; $py += 6) {
                        $c = $bmp.GetPixel($px, $py)
                        if ($c.R -ne 16 -or $c.G -ne 18 -or $c.B -ne 22) { $nonBg++ }
                    }
                }
                Assert-True ($nonBg -gt 3) "DrawCombo with active confetti must render visible non-background pixels"
                $gfx.Dispose()
                $bmp.Dispose()

                # Step past MaxLife (1.6s) to clear expired confetti
                $stepCombo.Invoke($isle, @([float]1.6)) | Out-Null
                Assert-Equal $confettiList.Count 0 "Stepping past MaxLife must clear expired confetti"

                # With Anim.Reduced = true, SpawnComboConfetti must not spawn
                $reducedField.SetValue($null, $true)
                $spawnConfetti = $islandType.GetMethod("SpawnComboConfetti", $flags)
                $spawnConfetti.Invoke($isle, @(20, [float]150, [float]24, [float]300, $false, $false)) | Out-Null
                Assert-Equal $confettiList.Count 0 "SpawnComboConfetti must not spawn when Anim.Reduced is true"
                $reducedField.SetValue($null, $false)

                # Side-docked Sprint confetti: OnSide origin/spread & SideCombo rendering
                $prevPlace = $sObj.Get("place", "top")
                try {
                    $sObj.Set("place", "left")
                    $islandType.GetMethod("LoadPlace", $flags).Invoke($isle, $null) | Out-Null
                    $isle.ResetComboStats()
                    $confettiList.Clear()
                    $isle.StartTypingSprint()
                    for ($i = 0; $i -lt 50; $i++) {
                        $vk = 0x41 + ($i % 26)
                        $isle.RegisterComboKeystroke($vk) | Out-Null
                        $isle.ReleaseComboKey($vk)
                    }
                    $stepCombo.Invoke($isle, @([float]30.5)) | Out-Null
                    Assert-True ($confettiList.Count -gt 0) "Side-docked Sprint completion must spawn comboConfetti"
                    foreach ($cf in $confettiList) {
                        Assert-True ($cf.X -ge 0 -and $cf.X -le 40) ("Side confetti X must be within [0, 40], got " + $cf.X)
                        Assert-True ([Math]::Abs($cf.Vx) -le 35) ("Side confetti |Vx| must be <= 35, got " + $cf.Vx)
                    }
                    $sideBmp = New-Object System.Drawing.Bitmap(40, 84)
                    $sideGfx = [System.Drawing.Graphics]::FromImage($sideBmp)
                    try {
                        $sideGfx.Clear([System.Drawing.Color]::FromArgb(255, 16, 18, 22))
                        $gField.SetValue($isle, $sideGfx)
                        $pGField.SetValue($pObj, $sideGfx)
                        $sideCombo = $islandType.GetMethod("SideCombo", $flags)
                        $sideCombo.Invoke($isle, @([float]40, [float]84, [DateTime]::UtcNow)) | Out-Null
                        $sideNonBg = 0
                        for ($px = 4; $px -lt 36; $px += 4) {
                            for ($py = 4; $py -lt 80; $py += 4) {
                                $c = $sideBmp.GetPixel($px, $py)
                                if ($c.R -ne 16 -or $c.G -ne 18 -or $c.B -ne 22) { $sideNonBg++ }
                            }
                        }
                        Assert-True ($sideNonBg -gt 3) "SideCombo(40, 84) with sprint confetti must render visible non-background pixels"
                    }
                    finally {
                        $sideGfx.Dispose()
                        $sideBmp.Dispose()
                    }
                }
                finally {
                    $sObj.Set("place", $prevPlace)
                    $islandType.GetMethod("LoadPlace", $flags).Invoke($isle, $null) | Out-Null
                }
            }
            finally {
                $reducedField.SetValue($null, $prevReduced)
                $isle.Dispose()
            }
        }
    }
    finally {
        if ($hadFile) {
            [System.IO.File]::WriteAllText($settingsFile, $backupContent, [System.Text.Encoding]::UTF8)
        }
        elseif (Test-Path $settingsFile) {
            Remove-Item $settingsFile -Force
        }
    }
}
