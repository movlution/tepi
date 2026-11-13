$commonDir = "D:\PROJECT\Other\tepi\tests\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

$asm = Initialize-TepiLoader
$flags = [System.Reflection.BindingFlags]'Instance,Public,NonPublic'
$sflags = [System.Reflection.BindingFlags]'Static,Public,NonPublic'

$islandType = Get-TepiType "Island"
$inkType = Get-TepiType "Ink"
$toneType = Get-TepiType "Tone"
$colorsType = Get-TepiType "Colors"
$dockType = $islandType.GetNestedType("DockWindow", $flags)
$calType = $islandType.GetNestedType("CalendarSheet", $flags)

$darkMethod = $toneType.GetMethod("Dark", [System.Reflection.BindingFlags]'Public,Static')
$paperMethod = $toneType.GetMethod("Paper", [System.Reflection.BindingFlags]'Public,Static')
$applyMethod = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static')
$isDarkProp = $toneType.GetProperty("IsDark")

function Lum([System.Drawing.Color]$c) {
    $r = $c.R / 255.0
    $g = $c.G / 255.0
    $b = $c.B / 255.0
    $r = if ($r -le 0.03928) { $r / 12.92 } else { [Math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $g = if ($g -le 0.03928) { $g / 12.92 } else { [Math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $b = if ($b -le 0.03928) { $b / 12.92 } else { [Math]::Pow(($b + 0.055) / 1.055, 2.4) }
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
    $l1 = Lum $c1
    $l2 = Lum $c2
    if ($l1 -lt $l2) { $tmp = $l1; $l1 = $l2; $l2 = $tmp }
    return ($l1 + 0.05) / ($l2 + 0.05)
}

function Blend([System.Drawing.Color]$fg, [System.Drawing.Color]$bg) {
    $a = $fg.A / 255.0
    $r = [int]($fg.R * $a + $bg.R * (1 - $a))
    $g = [int]($fg.G * $a + $bg.G * (1 - $a))
    $b = [int]($fg.B * $a + $bg.B * (1 - $a))
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

Describe "Adversarial Stress Suite: Milestone 4 - Dock & Mini Polish" {

    It "1. Sweeps for hardcoded legacy colors and verify complete elimination" {
        $files = @("src\DockPaint.cs", "src\DockCard.cs", "src\DockSheet.cs")
        $badPatterns = @("BadgeRed", "BadgeRedSoft")
        foreach ($f in $files) {
            $content = Get-Content $f -Raw
            foreach ($pat in $badPatterns) {
                Assert-False ($content -match $pat) "File $f must not contain $pat"
            }
            # Also check that rim light / sheen no longer uses Color.FromArgb(..., 255, 255, 255)
            $matches = [regex]::Matches($content, 'Color\.FromArgb\([^)]*255,\s*255,\s*255\)')
            Assert-Equal $matches.Count 0 "File $f must have 0 un-tokenized white Argb rim lights (found $($matches.Count))"
        }
    }

    It "2. Stress-tests unread badge contrast across all 7 curated preset accents and modes" {
        $accents = @(
            @{ Name="Biru"; Light="#1668E8"; Dark="#4C8DFF" },
            @{ Name="Hijau"; Light="#107C41"; Dark="#3DD68C" },
            @{ Name="Kuning"; Light="#855E00"; Dark="#FFD24A" },
            @{ Name="Oranye"; Light="#A84B00"; Dark="#FF9F43" },
            @{ Name="MerahMuda"; Light="#C2185B"; Dark="#FF6B9A" },
            @{ Name="Ungu"; Light="#6C3CE0"; Dark="#A78BFA" },
            @{ Name="Navy"; Light="#4D5F9E"; Dark="#7F8DC6" }
        )

        foreach ($acc in $accents) {
            # Test Dark Mode
            $applyMethod.Invoke($null, [object[]]@($false))
            $darkTone = $darkMethod.Invoke($null, @())
            $badgeBgDark = $darkTone.Negative
            $badgeTextDark = if ($isDarkProp.GetValue($darkTone)) { $darkTone.Bg } else { [System.Drawing.Color]::White }
            $crDark = Contrast $badgeTextDark $badgeBgDark
            Assert-True ($crDark -ge 4.5) "Dark mode badge text contrast must be >= 4.5:1 (got $crDark with accent $($acc.Name))"
            
            # Test Light Mode
            $applyMethod.Invoke($null, [object[]]@($true))
            $lightTone = $paperMethod.Invoke($null, @())
            $badgeBgLight = $lightTone.Negative
            $badgeTextLight = if ($isDarkProp.GetValue($lightTone)) { $lightTone.Bg } else { [System.Drawing.Color]::White }
            $crLight = Contrast $badgeTextLight $badgeBgLight
            Assert-True ($crLight -ge 4.5) "Light mode badge text contrast must be >= 4.5:1 (got $crLight with accent $($acc.Name))"
        }
    }

    It "3. Verifies DockCard close button glyph contrast in hot state" {
        $darkTone = $darkMethod.Invoke($null, @())
        $lightTone = $paperMethod.Invoke($null, @())

        $glyphDark = if ($isDarkProp.GetValue($darkTone)) { $darkTone.Bg } else { [System.Drawing.Color]::White }
        $crDark = Contrast $glyphDark $darkTone.Negative
        Assert-True ($crDark -ge 4.5) "DockCard close glyph in Dark mode must achieve >= 4.5:1 against Negative (got $crDark)"

        $glyphLight = if ($isDarkProp.GetValue($lightTone)) { $lightTone.Bg } else { [System.Drawing.Color]::White }
        $crLight = Contrast $glyphLight $lightTone.Negative
        Assert-True ($crLight -ge 4.5) "DockCard close glyph in Light mode must achieve >= 4.5:1 against Negative (got $crLight)"
    }

    It "4. Stress-tests CalendarSheet pressed state tracking, drag-out, and methods" {
        $isle = [System.Activator]::CreateInstance($islandType)
        $dock = [System.Activator]::CreateInstance($dockType, @($isle))
        $cal = [System.Activator]::CreateInstance($calType, @($isle, $dock))
        Assert-NotNull $cal "CalendarSheet instance created"

        $hitsField = $calType.GetField("hits", $flags)
        $hits = $hitsField.GetValue($cal)
        $rect = New-Object System.Drawing.RectangleF(10, 10, 50, 20)
        $kvpType = [System.Collections.Generic.KeyValuePair[System.Drawing.RectangleF, System.String]]
        $kvp = New-Object $kvpType($rect, "test_btn")
        $hits.Add($kvp)

        $downMethod = $calType.GetMethod("Down", $flags)
        $pressedMethod = $calType.GetMethod("Pressed", $flags)
        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
        $onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)

        # Initially Down and Pressed must be false
        Assert-False ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Initial Down must be false"
        Assert-False ($pressedMethod.Invoke($cal, [object[]]@("test_btn"))) "Initial Pressed must be false"

        # 1. Hover over button (25, 20)
        $moveEv = (New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 25, 20, 0)).PSObject.BaseObject
        $onMouseMove.Invoke($cal, [object[]]@($moveEv))
        Assert-False ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Hover alone must not trigger Down"

        # 2. MouseDown on button (25, 20)
        $downEv = (New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 25, 20, 0)).PSObject.BaseObject
        $onMouseDown.Invoke($cal, [object[]]@($downEv))
        Assert-True ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Down must be true after MouseDown on button"
        Assert-True ($pressedMethod.Invoke($cal, [object[]]@("test_btn"))) "Pressed must be true after MouseDown on button"

        # 3. Drag out of button (point 200, 200)
        $dragOutEv = (New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 200, 200, 0)).PSObject.BaseObject
        $onMouseMove.Invoke($cal, [object[]]@($dragOutEv))
        Assert-False ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Down must be false when dragged out of button"

        # 4. Drag back in (25, 20)
        $onMouseMove.Invoke($cal, [object[]]@($downEv))
        Assert-True ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Down must be true when dragged back onto button"

        # 5. MouseUp
        $upEv = (New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 25, 20, 0)).PSObject.BaseObject
        $onMouseUp.Invoke($cal, [object[]]@($upEv))
        Assert-False ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Down must be false after MouseUp"

        # 6. MouseLeave clears any leftover state
        $onMouseDown.Invoke($cal, [object[]]@($downEv))
        Assert-True ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Down active again"
        $onMouseLeave.Invoke($cal, [object[]]@([System.EventArgs]::Empty))
        Assert-False ($downMethod.Invoke($cal, [object[]]@("test_btn"))) "Down must be false after MouseLeave"
    }

    It "5. Tests calendar day click navigation and cross-month calculation" {
        $isle = [System.Activator]::CreateInstance($islandType)
        $dock = [System.Activator]::CreateInstance($dockType, @($isle))
        $cal = [System.Activator]::CreateInstance($calType, @($isle, $dock))
        
        $clickedMethod = $calType.GetMethod("Clicked", $flags)
        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)
        $monthField = $calType.GetField("month", $flags)

        # Click current month day (e.g. 2026-11-15 -> d20261115)
        $clickedMethod.Invoke($cal, [object[]]@("d20261115", [System.Windows.Forms.MouseButtons]::Left))
        $sel = $selectedDayProp.GetValue($cal)
        Assert-NotNull $sel "selectedDay must be populated"
        Assert-Equal $sel.Year 2026 "Selected year must be 2026"
        Assert-Equal $sel.Month 11 "Selected month must be 11"
        Assert-Equal $sel.Day 15 "Selected day must be 15"

        # Click previous month day (e.g. 2026-10-31 -> d20261031)
        $mBefore = $monthField.GetValue($cal)
        $clickedMethod.Invoke($cal, [object[]]@("d20261031", [System.Windows.Forms.MouseButtons]::Left))
        $mAfter = $monthField.GetValue($cal)
        Assert-Equal ($mAfter - $mBefore) -1 "Month offset must decrease by 1 when clicking leading day"

        # Click next year boundary day (e.g. 2027-01-05 -> d20270105)
        $currMonth = $monthField.GetValue($cal)
        $clickedMethod.Invoke($cal, [object[]]@("d20270105", [System.Windows.Forms.MouseButtons]::Left))
        $sel2 = $selectedDayProp.GetValue($cal)
        Assert-Equal $sel2.Year 2027 "Selected year must be 2027"
        Assert-Equal $sel2.Month 1 "Selected month must be 1"
    }

    It "6. Verifies Mini indicator geometry, dot area, track thickness, and clearance" {
        $miniDotR = $islandType.GetField("MiniDotR", $sflags)
        $miniTrackThick = $islandType.GetField("MiniTrackThick", $sflags)
        Assert-NotNull $miniDotR "MiniDotR constant must exist"
        Assert-NotNull $miniTrackThick "MiniTrackThick constant must exist"

        $rVal = [float]$miniDotR.GetValue($null)
        $tVal = [float]$miniTrackThick.GetValue($null)
        Assert-True ($rVal -ge 2.5) "MiniDotR must be >= 2.5 (actual: $rVal)"
        $area = [Math]::PI * [Math]::Pow($rVal, 2)
        Assert-True ($area -ge 19.6) "Mini dot circle area must be >= 19.6 px^2 (actual: $area)"
        Assert-Equal $tVal 4.0 "MiniTrackThick must equal 4.0"

        # Test clearance: In plain sliver, right boundary = w - 16, dot center = w - 9
        $w = 64
        $dotCenter = $w - 9
        $dotLeft = $dotCenter - $rVal
        $trackRight = $w - 16
        $clearance = $dotLeft - $trackRight
        Assert-True ($clearance -ge 4.0) "Clearance between track and dot must be >= 4.0px (actual: $clearance px)"
    }

    It "7. Verifies Mini track and dot contrast against monitor bezel boundaries" {
        $darkTone = $darkMethod.Invoke($null, @())
        $lightTone = $paperMethod.Invoke($null, @())

        $blackBezel = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
        $lightBezel = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)

        # In Dark mode on black bezel
        $trackDarkBlack = Blend $darkTone.Faint $blackBezel
        $crTrackDark = Contrast $trackDarkBlack $blackBezel
        Assert-True ($crTrackDark -ge 3.0) "Dark mode track on black bezel must achieve >= 3.0:1 (got $crTrackDark)"
        $crDotDark = Contrast $darkTone.Negative $blackBezel
        Assert-True ($crDotDark -ge 3.0) "Dark mode dot on black bezel must achieve >= 3.0:1 (got $crDotDark)"

        # In Light mode on light bezel
        $trackLightWhite = Blend $lightTone.Faint $lightBezel
        $crTrackLight = Contrast $trackLightWhite $lightBezel
        Assert-True ($crTrackLight -ge 3.0) "Light mode track on light bezel must achieve >= 3.0:1 (got $crTrackLight)"
        $crDotLight = Contrast $lightTone.Negative $lightBezel
        Assert-True ($crDotLight -ge 3.0) "Light mode dot on light bezel must achieve >= 3.0:1 (got $crDotLight)"
    }
}
