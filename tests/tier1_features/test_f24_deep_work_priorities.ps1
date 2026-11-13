# test_f24_deep_work_priorities.ps1
# Feature 24: Quest-Driven Deep Work & Top-3 Daily Priorities

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 24: Quest-Driven Deep Work & Top-3 Daily Priorities" {
    $islandType = Get-TepiType "Island"
    $prefsType = Get-TepiType "PrefsWindow"
    $langType = Get-TepiType "Lang"
    $timerKindType = Get-TepiType "TimerKind"
    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static,Instance'

    $settingsType = Get-TepiType "Settings"
    $settingsDir = $settingsType.GetField("Dir", $flags).GetValue($null)
    $settingsFile = Join-Path $settingsDir "settings.ini"
    $backupContent = $null
    $hadFile = Test-Path $settingsFile
    if ($hadFile) {
        $backupContent = [System.IO.File]::ReadAllText($settingsFile, [System.Text.Encoding]::UTF8)
    }

    function Reset-CleanSettings {
        if (Test-Path $settingsFile) {
            Remove-Item $settingsFile -Force
        }
    }

    try {
        BeforeEach {
            Reset-TepiTheme -Light $false
            Reset-CleanSettings
        }

        It "1. Top-3 Priorities: Add, Escaping, Persistence Across Fresh Island, Toggle XP/Badge/Celebrate, Rollover, Remove" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                Assert-True ($isle.AddPriority("Task A | 1; \2")) "First priority should add"
                Assert-True ($isle.AddPriority("Task B")) "Second priority should add"
                Assert-True ($isle.AddPriority("Task C")) "Third priority should add"
                Assert-Equal $isle.PriorityCount 3 "PriorityCount should be 3"
                Assert-False ($isle.AddPriority("Task D")) "4th priority should be rejected"
            } finally {
                $isle.Dispose()
            }

            # Fresh Island instance reading from settings.ini
            $isle2 = [Activator]::CreateInstance($islandType)
            try {
                Assert-Equal $isle2.PriorityCount 3 "Fresh Island should reload 3 priorities"
                $t0 = ""; $d0 = $false
                $ok0 = $isle2.GetPriority(0, [ref]$t0, [ref]$d0)
                Assert-True $ok0 "GetPriority(0) should succeed"
                Assert-Equal $t0 "Task A | 1; \2" "Escaped |, ;, \ must round-trip"
                Assert-False $d0 "Task 0 should start undone"

                $xp0 = $isle2.ComboXp
                Assert-True ($isle2.TogglePriority(0)) "TogglePriority(0) should succeed"
                Assert-Equal $isle2.ComboXp ($xp0 + 35) "Completing priority 0 should award +35 XP"

                Assert-True ($isle2.TogglePriority(1)) "TogglePriority(1) should succeed"
                Assert-Equal $isle2.ComboXp ($xp0 + 70) "Completing priority 1 should award +35 XP"

                $celBefore = $islandType.GetField("celebrateUtc", $flags).GetValue($isle2)
                Assert-True ($isle2.TogglePriority(2)) "TogglePriority(2) should succeed"
                Assert-True $isle2.PrioritiesAllDone "All 3 priorities should be done"
                Assert-Equal $isle2.ComboXp ($xp0 + 105 + 50) "3/3 sweep should award +35 + 50 bonus XP"
                Assert-True ($isle2.HasComboBadge("priority_sweep")) "priority_sweep badge should be unlocked"
                $celAfter = $islandType.GetField("celebrateUtc", $flags).GetValue($isle2)
                Assert-True ($celAfter -gt $celBefore) "celebrateUtc should update on 3/3 sweep"

                $isle2.RemovePriority(1)
                Assert-Equal $isle2.PriorityCount 2 "RemovePriority should reduce count to 2"
            } finally {
                $isle2.Dispose()
            }

            # Rollover test: yesterday's date with 1 done + 1 undone
            $isle3 = [Activator]::CreateInstance($islandType)
            try {
                $s3 = $islandType.GetField("settings", $flags).GetValue($isle3)
                $yesterday = [DateTime]::Today.AddDays(-1).ToString("yyyy-MM-dd")
                $s3.Set("priorities.date", $yesterday)
                $s3.Set("priorities.items", "1|DoneYesterday;0|CarryMeOver")
                $s3.Save()
            } finally {
                $isle3.Dispose()
            }

            $isle4 = [Activator]::CreateInstance($islandType)
            try {
                Assert-Equal $isle4.PriorityCount 1 "Rollover should drop done item and carry over 1 undone item"
                $rt = ""; $rd = $false
                $isle4.GetPriority(0, [ref]$rt, [ref]$rd) | Out-Null
                Assert-Equal $rt "CarryMeOver" "Carried over item title must match"
                Assert-False $rd "Carried over item must be undone"
            } finally {
                $isle4.Dispose()
            }
        }

        It "2. Quest-Driven Deep Work: FocusTask Persistence, RecordFocusCompletion, Streak, TimerTick, RecordTaskDoneXp, Reset" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $isle.SetFocusTask("Write API")
                Assert-Equal $isle.FocusTaskTitle "Write API" "FocusTaskTitle should be set"
            } finally {
                $isle.Dispose()
            }

            $isle2 = [Activator]::CreateInstance($islandType)
            try {
                Assert-Equal $isle2.FocusTaskTitle "Write API" "FocusTaskTitle should persist across fresh Island"
                $isle2.ClearFocusTask()
                Assert-Equal $isle2.FocusTaskTitle "" "ClearFocusTask should clear title"

                $xp0 = $isle2.ComboXp
                $isle2.RecordFocusCompletion(25)
                Assert-Equal $isle2.ComboXp ($xp0 + 100) "25m focus should grant +100 XP"
                Assert-Equal $isle2.FocusMinToday 25 "FocusMinToday should be 25"
                Assert-Equal $isle2.FocusSessionsToday 1 "FocusSessionsToday should be 1"
                Assert-Equal $isle2.FocusTotalMin 25 "FocusTotalMin should be 25"
                Assert-Equal $isle2.FocusWeekTotalMin 25 "FocusWeekTotalMin should be 25"
                $bars = $isle2.FocusWeekBars()
                Assert-Equal $bars.Length 7 "FocusWeekBars should have 7 elements"
                Assert-Equal $bars[6] 25 "Today bar (index 6) should be 25"
                Assert-Equal $isle2.FocusStreakDays 1 "FocusStreakDays should be 1"
                Assert-True ($isle2.HasComboBadge("deep_focus")) "deep_focus badge should be unlocked"

                $isle2.RecordTaskDoneXp(35)
                Assert-Equal $isle2.FocusTasksDone 1 "FocusTasksDone should increment to 1"
                Assert-Equal $isle2.ComboXp ($xp0 + 135) "RecordTaskDoneXp(35) should grant +35 XP"

                $isle2.ResetFocusStats()
                Assert-Equal $isle2.FocusMinToday 0 "ResetFocusStats should zero FocusMinToday"
                Assert-Equal $isle2.FocusSessionsToday 0 "ResetFocusStats should zero FocusSessionsToday"
                Assert-Equal $isle2.FocusTotalMin 0 "ResetFocusStats should zero FocusTotalMin"
                Assert-Equal $isle2.FocusStreakDays 0 "ResetFocusStats should zero FocusStreakDays"
                Assert-Equal $isle2.FocusTasksDone 0 "ResetFocusStats should zero FocusTasksDone"
            } finally {
                $isle2.Dispose()
            }

            # Streak continuation from yesterday
            $isle3 = [Activator]::CreateInstance($islandType)
            try {
                $s3 = $islandType.GetField("settings", $flags).GetValue($isle3)
                $yesterday = [DateTime]::Today.AddDays(-1).ToString("yyyy-MM-dd")
                $s3.Set("focus.last_date", $yesterday)
                $s3.Set("focus.streak_days", "2")
                $s3.Save()
            } finally {
                $isle3.Dispose()
            }

            $isle4 = [Activator]::CreateInstance($islandType)
            try {
                $isle4.RecordFocusCompletion(15)
                Assert-Equal $isle4.FocusStreakDays 3 "Consecutive day focus should increment streak from 2 to 3"

                # Simulate TimerTick completion when timerKind == Focus
                $focusVal = [Enum]::Parse($timerKindType, "Focus")
                $breakVal = [Enum]::Parse($timerKindType, "Break")
                $islandType.GetField("timerKind", $flags).SetValue($isle4, $focusVal)
                $islandType.GetField("timerPaused", $flags).SetValue($isle4, $false)
                $now = [DateTime]::UtcNow
                $islandType.GetField("timerStartUtc", $flags).SetValue($isle4, $now.AddMinutes(-20))
                $islandType.GetField("timerEndUtc", $flags).SetValue($isle4, $now.AddSeconds(-1))

                $tickMethod = $islandType.GetMethod("TimerTick", $flags)
                $tickMethod.Invoke($isle4, @($now)) | Out-Null
                $kindAfter = $islandType.GetField("timerKind", $flags).GetValue($isle4)
                Assert-Equal $kindAfter $breakVal "TimerTick on finished Focus should transition to Break"
                Assert-Equal $isle4.FocusMinToday 35 "TimerTick should record 20m focus completion (15 + 20 = 35)"
            } finally {
                $isle4.Dispose()
            }
        }

        It "3. Offscreen Rendering, PrefsWindow, Portable Allowlist, and Lang.T" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $isle.SetFocusTask("Ship Feature 24")
                $focusVal = [Enum]::Parse($timerKindType, "Focus")
                $islandType.GetField("timerKind", $flags).SetValue($isle, $focusVal)
                $islandType.GetField("timerStartUtc", $flags).SetValue($isle, [DateTime]::UtcNow.AddMinutes(-5))
                $islandType.GetField("timerEndUtc", $flags).SetValue($isle, [DateTime]::UtcNow.AddMinutes(20))

                $pField = $islandType.GetField("p", $flags)
                $gField = $islandType.GetField("g", $flags)
                $pObj = $pField.GetValue($isle)

                $bmp = New-Object System.Drawing.Bitmap 480, 320
                $gfx = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $gfx.Clear([System.Drawing.Color]::FromArgb(255, 18, 18, 22))
                    $gField.SetValue($isle, $gfx)
                    $pObj.G = $gfx
                    if ($null -eq $pObj.T) { $pObj.T = (Get-TepiType "Theme").GetField("Dark", $flags).GetValue($null) }

                    # DrawTimer
                    $drawTimer = $islandType.GetMethod("DrawTimer", $flags)
                    $drawTimer.Invoke($isle, @([float]280, [float]38, [DateTime]::UtcNow)) | Out-Null

                    $islandType.GetMethod("ControlActs", $flags).Invoke($isle, $null) | Out-Null
                    # DrawTimerModule (active)
                    $drawTm = $islandType.GetMethod("DrawTimerModule", $flags)
                    $rectTm = New-Object System.Drawing.RectangleF 10, 44, 440, 96
                    $drawTm.Invoke($isle, @($rectTm, [DateTime]::UtcNow, $false)) | Out-Null

                    # DrawPrioritiesCard (0 items)
                    $drawPrio = $islandType.GetMethod("DrawPrioritiesCard", $flags)
                    $rectPrio = New-Object System.Drawing.RectangleF 10, 146, 210, 110
                    $drawPrio.Invoke($isle, @($rectPrio)) | Out-Null

                    # DrawPrioritiesCard (3 items, 1 done)
                    $isle.AddPriority("Alpha") | Out-Null
                    $isle.AddPriority("Beta") | Out-Null
                    $isle.TogglePriority(0) | Out-Null
                    $drawPrio.Invoke($isle, @($rectPrio)) | Out-Null

                    # DrawFocusCard
                    $isle.RecordFocusCompletion(25)
                    $drawFocus = $islandType.GetMethod("DrawFocusCard", $flags)
                    $rectFocus = New-Object System.Drawing.RectangleF 230, 146, 220, 110
                    $drawFocus.Invoke($isle, @($rectFocus)) | Out-Null

                    # DrawTimerCard
                    $drawTimerCard = $islandType.GetMethod("DrawTimerCard", $flags)
                    $rectTc = New-Object System.Drawing.RectangleF 10, 260, 210, 50
                    $drawTimerCard.Invoke($isle, @($rectTc, [DateTime]::UtcNow)) | Out-Null

                } finally {
                    $gfx.Dispose()
                }

                # Verify non-background pixels were drawn
                $nonBg = 0
                for ($x = 0; $x -lt 480; $x += 8) {
                    for ($y = 0; $y -lt 320; $y += 8) {
                        $c = $bmp.GetPixel($x, $y)
                        if ($c.R -ne 18 -or $c.G -ne 18 -or $c.B -ne 22) { $nonBg++ }
                    }
                }
                $bmp.Dispose()
                Assert-True ($nonBg -gt 20) "Offscreen cards and timer must render visible pixels"

                # PrefsWindow.Go("work") + Relayout + GlyphFor
                $prefs = [Activator]::CreateInstance($prefsType, @($isle))
                try {
                    $goMethod = $prefsType.GetMethod("Go", $flags)
                    $goMethod.Invoke($prefs, @("work")) | Out-Null
                    $relayout = $prefsType.GetMethod("Relayout", $flags)
                    $relayout.Invoke($prefs, $null) | Out-Null
                } finally {
                    $prefs.Dispose()
                }

                $glyphFor = $prefsType.GetMethod("GlyphFor", $flags)
                $gPrio = $glyphFor.Invoke($null, @("3 Prioritas Hari Ini"))
                $gFocus = $glyphFor.Invoke($null, @("Statistik Fokus"))
                Assert-True ($gPrio -ne [char]0xE713) "GlyphFor('3 Prioritas Hari Ini') must return custom icon"
                Assert-True ($gFocus -ne [char]0xE713) "GlyphFor('Statistik Fokus') must return custom icon"

                # Portable allowlist
                $portable = $islandType.GetField("Portable", $flags).GetValue($null)
                $portList = New-Object System.Collections.Generic.List[string] (,[string[]]$portable)
                Assert-True ($portList.Contains("focus.hold")) "Portable must include focus.hold"
                Assert-False ($portList.Contains("focus.total_min")) "Portable must exclude focus.total_min"
                Assert-False ($portList.Contains("priorities.items")) "Portable must exclude priorities.items"

                # Lang.T translation check
                $engField = $langType.GetField("English", $flags)
                $prevEng = $engField.GetValue($null)
                try {
                    $engField.SetValue($null, $true)
                    $tr1 = $langType.GetMethod("T", $flags).Invoke($null, @("Prioritas hari ini tuntas!"))
                    $tr2 = $langType.GetMethod("T", $flags).Invoke($null, @("Pilih tugas fokus…"))
                    Assert-True ($tr1 -ne "Prioritas hari ini tuntas!") "Lang.T should translate 'Prioritas hari ini tuntas!'"
                    Assert-True ($tr2 -ne "Pilih tugas fokus…") "Lang.T should translate 'Pilih tugas fokus…'"
                } finally {
                    $engField.SetValue($null, $prevEng)
                }
            } finally {
                $isle.Dispose()
            }
        }

        It "4. HomeQuiet Preserved With Zero Priorities & ResetComboStats Decoupled From Focus Stats" {
            $isle = [Activator]::CreateInstance($islandType)
            try {
                $homeLayout = $islandType.GetMethod("HomeLayout", $flags)
                $islandType.GetMethod("LoadHome", $flags).Invoke($isle, $null) | Out-Null
                $homeQuietProp = $islandType.GetProperty("HomeQuiet", $flags)

                $homeLayout.Invoke($isle, @([float]500)) | Out-Null
                Assert-True ($homeQuietProp.GetValue($isle, $null)) "HomeQuiet should be true on clean Island with 0 priorities"

                $isle.AddPriority("First Goal") | Out-Null
                $homeLayout.Invoke($isle, @([float]500)) | Out-Null
                Assert-False ($homeQuietProp.GetValue($isle, $null)) "HomeQuiet should become false after AddPriority"

                # Verify ResetComboStats does NOT reset FocusMinToday or FocusStreakDays
                $isle.RecordFocusCompletion(25)
                Assert-Equal $isle.FocusMinToday 25 "FocusMinToday should be 25 before ResetComboStats"
                Assert-Equal $isle.FocusStreakDays 1 "FocusStreakDays should be 1 before ResetComboStats"

                $islandType.GetMethod("EnsureComboStatsLoaded", $flags).Invoke($isle, $null) | Out-Null
                $islandType.GetField("comboXp", $flags).SetValue($isle, 150)
                $islandType.GetField("comboAllTimeBest", $flags).SetValue($isle, 42)
                $isle.ResetComboStats()

                Assert-Equal $isle.ComboXp 0 "ResetComboStats should reset ComboXp to 0"
                Assert-Equal $isle.ComboAllTimeBest 0 "ResetComboStats should reset ComboAllTimeBest to 0"
                Assert-Equal $isle.FocusMinToday 25 "ResetComboStats must NOT reset FocusMinToday"
                Assert-Equal $isle.FocusStreakDays 1 "ResetComboStats must NOT reset FocusStreakDays"
            } finally {
                $isle.Dispose()
            }
        }
    } finally {
        if ($hadFile -and $null -ne $backupContent) {
            [System.IO.File]::WriteAllText($settingsFile, $backupContent, [System.Text.Encoding]::UTF8)
        } elseif (-not $hadFile -and (Test-Path $settingsFile)) {
            Remove-Item $settingsFile -Force
        }
    }
}
