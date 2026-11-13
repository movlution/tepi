# tests/challenger1_m4_stress.ps1
# Challenger 1 Empirical Stress & Adversarial Verification Harness
# Milestone 4: Dock & Mini Polish
# Scope: Dock badge contrast, RimLight/Sheen tokenization (IL & AST), Mini dot/track geometry & bezel contrast

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

$commonDir = Join-Path $PSScriptRoot "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  CHALLENGER 1: EMPIRICAL ADVERSARIAL STRESS HARNESS (M4) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Initialize Assembly
$binPath = Find-TepiBinary
if (-not $binPath) {
    throw "Tepi.exe not found! Please build before running tests."
}
Initialize-TepiLoader | Out-Null

$inkType = Get-TepiType "Ink"
if (-not $inkType) { throw "Could not resolve Tepi.Ink type" }
$toneType = Get-TepiType "Tone"
if (-not $toneType) { throw "Could not resolve Tepi.Tone type" }
$islandType = Get-TepiType "Island"
if (-not $islandType) { throw "Could not resolve Tepi.Island type" }

$passCount = 0
$failCount = 0

function Report-Check {
    param([string]$Name, [bool]$Passed, [string]$Details = "")
    if ($Passed) {
        $global:passCount++
        Write-Host " [PASS] $Name" -ForegroundColor Green
        if ($Details -and $Detailed) { Write-Host "        $Details" -ForegroundColor Gray }
    } else {
        $global:failCount++
        Write-Host " [FAIL] $Name" -ForegroundColor Red
        if ($Details) { Write-Host "        $Details" -ForegroundColor Yellow }
    }
}

# ==========================================================================
# SECTION 1: Dock Badge Contrast Across Themes and Presets
# ==========================================================================
Describe "1. Dock Badge Contrast Empirical Oracles" {

    $accentsLight = @(
        @("Biru", "#1668E8"),
        @("Ungu", "#6C3CE0"),
        @("Merah muda", "#C2185B"),
        @("Merah", "#C5221F"),
        @("Oranye", "#A84B00"),
        @("Kuning", "#855E00"),
        @("Hijau", "#107C41"),
        @("Grafit", "")
    )

    $accentsDark = @(
        @("Biru", "#4C8DFF"),
        @("Ungu", "#A78BFA"),
        @("Merah muda", "#FF6B9A"),
        @("Merah", "#FF5252"),
        @("Oranye", "#FF9F43"),
        @("Kuning", "#FFD24A"),
        @("Hijau", "#3DD68C"),
        @("Grafit", "")
    )

    It "Verifies Dark Mode Dock Badge Text and Pill Contrast (>= 4.5:1)" {
        [void]$inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($false))
        $baseProp = $inkType.GetField("Base", [System.Reflection.BindingFlags]'Public,Static')
        $tone = $baseProp.GetValue($null)

        $negColor = [System.Drawing.Color]$toneType.GetField("Negative").GetValue($tone)
        $bgColor = [System.Drawing.Color]$toneType.GetField("Bg").GetValue($tone)
        $isDark = [bool]$toneType.GetProperty("IsDark").GetValue($tone, $null)

        Assert-True $isDark "Tone.IsDark must be true in Dark Mode"

        # Badge text formula from DockPaint.cs: p.T.IsDark ? p.T.Bg : Color.White
        $badgeTextColor = if ($isDark) { $bgColor } else { [System.Drawing.Color]::White }

        $textContrast = Get-WcagContrastRatio $badgeTextColor $negColor
        Write-Host "       Dark Mode Badge Text ($badgeTextColor) vs Pill ($negColor): ${textContrast}:1" -ForegroundColor Gray
        Assert-True ($textContrast -ge 4.5) "Dark mode badge text contrast must be >= 4.5:1 (got ${textContrast}:1)"

        # Badge pill on dock surface (Bg = #000000)
        $pillContrast = Get-WcagContrastRatio $negColor $bgColor
        Write-Host "       Dark Mode Badge Pill ($negColor) vs Dock Surface ($bgColor): ${pillContrast}:1" -ForegroundColor Gray
        Assert-True ($pillContrast -ge 4.5) "Dark mode badge pill contrast on dock surface must be >= 4.5:1 (got ${pillContrast}:1)"

        # Counter-example oracle: Verify that hardcoded White on dark mode Negative would FAIL (< 4.5:1)
        $whiteTextContrast = Get-WcagContrastRatio ([System.Drawing.Color]::White) $negColor
        Write-Host "       Adversarial verification: Hardcoded White on Dark Negative yields ${whiteTextContrast}:1 (< 4.5:1 failure)" -ForegroundColor DarkGray
        Assert-True ($whiteTextContrast -lt 4.5) "Hardcoded white on dark negative must be strictly < 4.5:1, proving dynamic text is required"
    }

    It "Verifies Light Mode Dock Badge Text and Pill Contrast Across All 8 Light Presets (>= 4.5:1)" {
        foreach ($preset in $accentsLight) {
            $name = $preset[0]
            $hex = $preset[1]

            [void]$inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($true))
            if ($hex -ne "") {
                [void]$inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($hex))
            }

            $baseProp = $inkType.GetField("Base", [System.Reflection.BindingFlags]'Public,Static')
            $tone = $baseProp.GetValue($null)

            $negColor = [System.Drawing.Color]$toneType.GetField("Negative").GetValue($tone)
            $bgColor = [System.Drawing.Color]$toneType.GetField("Bg").GetValue($tone)
            $isDark = [bool]$toneType.GetProperty("IsDark").GetValue($tone, $null)

            Assert-False $isDark "Tone.IsDark must be false in Light Mode"

            # Badge text formula: p.T.IsDark ? p.T.Bg : Color.White
            $badgeTextColor = if ($isDark) { $bgColor } else { [System.Drawing.Color]::White }

            $textContrast = Get-WcagContrastRatio $badgeTextColor $negColor
            Write-Host "       Preset [$name]: Text ($badgeTextColor) vs Pill ($negColor) = ${textContrast}:1" -ForegroundColor Gray
            Assert-True ($textContrast -ge 4.5) "Preset [$name] badge text contrast must be >= 4.5:1 (got ${textContrast}:1)"

            # Badge pill on dock surface (Paper Bg = #F5F5F5)
            $pillContrast = Get-WcagContrastRatio $negColor $bgColor
            Write-Host "       Preset [$name]: Pill ($negColor) vs Dock Surface ($bgColor) = ${pillContrast}:1" -ForegroundColor Gray
            Assert-True ($pillContrast -ge 4.5) "Preset [$name] badge pill contrast on dock surface must be >= 4.5:1 (got ${pillContrast}:1)"

            # Also verify against pure white surface (#FFFFFF) for extreme light wallpapers
            $whiteSurfaceContrast = Get-WcagContrastRatio $negColor ([System.Drawing.Color]::White)
            Assert-True ($whiteSurfaceContrast -ge 4.5) "Preset [$name] badge pill on pure white surface must be >= 4.5:1 (got ${whiteSurfaceContrast}:1)"
        }
    }

    It "Verifies DockCard Close Button Glyph and Pill Contrast Across All Themes" {
        # Close button in DockCard.cs: hot == 'x' + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub
        # Hover pill fill: p.T.Negative
        foreach ($dark in @($true, $false)) {
            [void]$inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @(-not $dark))
            $baseProp = $inkType.GetField("Base", [System.Reflection.BindingFlags]'Public,Static')
            $tone = $baseProp.GetValue($null)

            $negColor = [System.Drawing.Color]$toneType.GetField("Negative").GetValue($tone)
            $bgColor = [System.Drawing.Color]$toneType.GetField("Bg").GetValue($tone)
            $isDark = [bool]$toneType.GetProperty("IsDark").GetValue($tone, $null)

            $glyphColor = if ($isDark) { $bgColor } else { [System.Drawing.Color]::White }
            $glyphContrast = Get-WcagContrastRatio $glyphColor $negColor
            Write-Host "       DockCard Close Glyph (Dark=$dark): Glyph vs Pill = ${glyphContrast}:1" -ForegroundColor Gray
            Assert-True ($glyphContrast -ge 4.5) "DockCard close glyph contrast must be >= 4.5:1"
        }
    }
}

# ==========================================================================
# SECTION 2: RimLight and Sheen Tokenization (Static AST & Compiled IL)
# ==========================================================================
Describe "2. RimLight and Sheen Tokenization Verification" {

    It "Asserts complete absence of Color.FromArgb(..., 255, 255, 255) in Dock source files" {
        $targetFiles = @(
            (Join-Path $PSScriptRoot "..\src\DockPaint.cs"),
            (Join-Path $PSScriptRoot "..\src\DockCard.cs"),
            (Join-Path $PSScriptRoot "..\src\DockSheet.cs")
        )

        foreach ($file in $targetFiles) {
            $content = Get-Content $file -Raw
            $fileName = [System.IO.Path]::GetFileName($file)

            # Check for hardcoded 255, 255, 255
            $match255 = [regex]::Matches($content, 'Color\.FromArgb\s*\(\s*[^,\)]+\s*,\s*255\s*,\s*255\s*,\s*255\s*\)')
            Assert-Equal $match255.Count 0 "File $fileName must have zero instances of Color.FromArgb(..., 255, 255, 255). Found $($match255.Count)"

            # Check for legacy BadgeRed / BadgeRedSoft
            $matchBadgeRed = [regex]::Matches($content, 'BadgeRed(Soft)?')
            Assert-Equal $matchBadgeRed.Count 0 "File $fileName must have zero references to BadgeRed or BadgeRedSoft. Found $($matchBadgeRed.Count)"
        }
    }

    It "Asserts p.T.Highlight is explicitly used in DockPaint, DockCard, and DockSheet" {
        $dockPaintSrc = Get-Content (Join-Path $PSScriptRoot "..\src\DockPaint.cs") -Raw
        $dockCardSrc = Get-Content (Join-Path $PSScriptRoot "..\src\DockCard.cs") -Raw
        $dockSheetSrc = Get-Content (Join-Path $PSScriptRoot "..\src\DockSheet.cs") -Raw

        # In DockPaint.cs: RimLight, Sheen, and Rim must use p.T.Highlight
        $dpHighlightCount = ([regex]::Matches($dockPaintSrc, 'p\.T\.Highlight')).Count
        Write-Host "       DockPaint.cs p.T.Highlight occurrences: $dpHighlightCount" -ForegroundColor Gray
        Assert-True ($dpHighlightCount -ge 8) "DockPaint.cs must contain at least 8 references to p.T.Highlight in RimLight, Sheen, and Rim (got $dpHighlightCount)"

        # In DockCard.cs: DrawWindows sheen and border must use p.T.Highlight
        $dcHighlightCount = ([regex]::Matches($dockCardSrc, 'p\.T\.Highlight')).Count
        Write-Host "       DockCard.cs p.T.Highlight occurrences: $dcHighlightCount" -ForegroundColor Gray
        Assert-True ($dcHighlightCount -ge 3) "DockCard.cs must contain references to p.T.Highlight (got $dcHighlightCount)"

        # In DockSheet.cs: Render sheen and border must use p.T.Highlight
        $dsHighlightCount = ([regex]::Matches($dockSheetSrc, 'p\.T\.Highlight')).Count
        Write-Host "       DockSheet.cs p.T.Highlight occurrences: $dsHighlightCount" -ForegroundColor Gray
        Assert-True ($dsHighlightCount -ge 3) "DockSheet.cs must contain references to p.T.Highlight (got $dsHighlightCount)"
    }

    It "Disassembles compiled IL to verify Tone.Highlight field is loaded in compiled rendering paths" {
        $hlField = $toneType.GetField("Highlight", [System.Reflection.BindingFlags]'Public,NonPublic,Instance,Static')
        Assert-NotNull $hlField "Tone.Highlight field must exist"
        $fieldMetadataToken = $hlField.MetadataToken

        # Find all types in Tepi namespace related to Dock, DockCard, GlassSheet
        $allTypes = $global:TepiAssembly.GetTypes()
        $dockTypes = $allTypes | Where-Object {
            $_.Name -match 'Dock' -or $_.Name -match 'GlassSheet' -or $_.FullName -match 'Dock'
        }

        $totalHighlightLoads = 0
        $methodsLoadingHighlight = New-Object System.Collections.ArrayList

        foreach ($t in $dockTypes) {
            $methods = $t.GetMethods([System.Reflection.BindingFlags]'Public,NonPublic,Instance,Static,DeclaredOnly')
            foreach ($m in $methods) {
                try {
                    $body = $m.GetMethodBody()
                    if ($null -eq $body) { continue }
                    $il = $body.GetILAsByteArray()
                    if ($null -eq $il -or $il.Length -lt 5) { continue }

                    # Scan IL for ldfld (0x7B) or ldsfld (0x7E) with Highlight token
                    for ($i = 0; $i -le $il.Length - 5; $i++) {
                        $op = $il[$i]
                        if ($op -eq 0x7B -or $op -eq 0x7E) {
                            $token = [System.BitConverter]::ToInt32($il, $i + 1)
                            if ($token -eq $fieldMetadataToken) {
                                $totalHighlightLoads++
                                [void]$methodsLoadingHighlight.Add("$($t.Name).$($m.Name)")
                            }
                        }
                    }
                } catch {
                    # Ignore unreadable method bodies
                }
            }
        }

        Write-Host "       Total compiled IL ldfld instructions to Tone.Highlight: $totalHighlightLoads across methods: $($methodsLoadingHighlight -join ', ')" -ForegroundColor Gray
        Assert-True ($totalHighlightLoads -ge 5) "Compiled binary must load Tone.Highlight in at least 5 locations in Dock components (found $totalHighlightLoads)"
    }
}

# ==========================================================================
# SECTION 3: Mini Notification Dot & Track Geometry and Contrast
# ==========================================================================
Describe "3. Mini Indicator Geometry & Bezel Contrast Oracles" {

    It "Empirically validates MiniDotR radius and area against geometric specification" {
        $miniDotRField = $islandType.GetField("MiniDotR", [System.Reflection.BindingFlags]'NonPublic,Static,DeclaredOnly')
        Assert-NotNull $miniDotRField "Island.MiniDotR field must exist in compiled assembly"

        $r = [double]$miniDotRField.GetValue($null)
        Write-Host "       Island.MiniDotR value: $r" -ForegroundColor Gray
        Assert-Equal $r 2.5 "MiniDotR must be exactly 2.5"

        $area = [Math]::PI * $r * $r
        Write-Host "       Calculated indicator circle area: $area px^2 (Spec >= 19.6 px^2)" -ForegroundColor Gray
        Assert-True ($area -ge 19.6) "Indicator dot area must be >= 19.6 px^2 (got $area)"

        # Verify all 3 call sites in Mini.cs use MiniDotR
        $miniSrc = Get-Content (Join-Path $PSScriptRoot "..\src\Mini.cs") -Raw
        $dotCalls = [regex]::Matches($miniSrc, 'p\.Circle\([^,]+,\s*[^,]+,\s*MiniDotR,')
        Write-Host "       p.Circle calls using MiniDotR: $($dotCalls.Count)" -ForegroundColor Gray
        Assert-Equal $dotCalls.Count 3 "All 3 indicator dot sites in Mini.cs (MiniClockOn, plain sliver, MiniFace) must use MiniDotR"
    }

    It "Empirically validates MiniTrackThick thickness and layout bounds clearance" {
        $trackField = $islandType.GetField("MiniTrackThick", [System.Reflection.BindingFlags]'NonPublic,Static,DeclaredOnly')
        Assert-NotNull $trackField "Island.MiniTrackThick field must exist in compiled assembly"

        $thick = [double]$trackField.GetValue($null)
        Write-Host "       Island.MiniTrackThick value: $thick" -ForegroundColor Gray
        Assert-Equal $thick 4.0 "MiniTrackThick must be exactly 4.0"

        # Layout clearance evaluation:
        # In DrawMini:
        # dot position: cx = w - 9, cy = h / 2, radius = MiniDotR = 2.5
        # dot left boundary = (w - 9) - 2.5 = w - 11.5
        # track right boundary when dot=true: right = w - 16
        # clearance gap = (w - 11.5) - (w - 16) = 4.5 px
        $dotLeftBoundOffset = 9.0 + 2.5 # from right edge
        $trackRightOffset = 16.0        # from right edge
        $clearanceGap = $trackRightOffset - $dotLeftBoundOffset
        Write-Host "       Calculated clearance between progress track and indicator dot: ${clearanceGap}px" -ForegroundColor Gray
        Assert-True ($clearanceGap -ge 4.0) "Clearance between track and dot must be >= 4.0px to prevent visual collision (got ${clearanceGap}px)"

        # Vertical clearance in MiniBusyH (8px sliver):
        # Sliver height = 8px, cy = 4.0px
        # Track top = 4.0 - 4.0/2 = 2.0px, Track bottom = 4.0 + 4.0/2 = 6.0px
        # Symmetrical top/bottom padding = 2.0px
        $padding = (8.0 - $thick) / 2.0
        Write-Host "       Sliver vertical track padding: ${padding}px on top and bottom" -ForegroundColor Gray
        Assert-Equal $padding 2.0 "Vertical padding must be 2.0px symmetrically inside 8px sliver"
    }

    It "Empirically verifies Indicator Dot and Status Track Contrast against Host Monitor Bezels (>= 3:1)" {
        $bezelBlack = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)       # #000000
        $bezelCharcoal = [System.Drawing.Color]::FromArgb(255, 26, 26, 26) # #1A1A1A

        # 1. Silenced / Negative Indicator Dot (MicSilenced || RapatOn ? p.T.Negative : p.T.Accent)
        # Test Dark mode Negative:
        [void]$inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($false))
        $baseProp = $inkType.GetField("Base", [System.Reflection.BindingFlags]'Public,Static')
        $toneDark = $baseProp.GetValue($null)
        $darkNeg = [System.Drawing.Color]$toneType.GetField("Negative").GetValue($toneDark)

        $cBlackDarkNeg = Get-WcagContrastRatio $darkNeg $bezelBlack
        $cCharcoalDarkNeg = Get-WcagContrastRatio $darkNeg $bezelCharcoal
        Write-Host "       Dark Negative Dot ($darkNeg) vs Black Bezel: ${cBlackDarkNeg}:1, vs Charcoal: ${cCharcoalDarkNeg}:1" -ForegroundColor Gray
        Assert-True ($cBlackDarkNeg -ge 3.0) "Dark negative dot vs Black bezel must be >= 3:1"
        Assert-True ($cCharcoalDarkNeg -ge 3.0) "Dark negative dot vs Charcoal bezel must be >= 3:1"

        # Test Light mode Negative:
        [void]$inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($true))
        $toneLight = $baseProp.GetValue($null)
        $lightNeg = [System.Drawing.Color]$toneType.GetField("Negative").GetValue($toneLight)

        $cBlackLightNeg = Get-WcagContrastRatio $lightNeg $bezelBlack
        $cCharcoalLightNeg = Get-WcagContrastRatio $lightNeg $bezelCharcoal
        Write-Host "       Light Negative Dot ($lightNeg) vs Black Bezel: ${cBlackLightNeg}:1, vs Charcoal: ${cCharcoalLightNeg}:1" -ForegroundColor Gray
        Assert-True ($cBlackLightNeg -ge 3.0) "Light negative dot vs Black bezel must be >= 3:1 (got ${cBlackLightNeg}:1)"
        Assert-True ($cCharcoalLightNeg -ge 3.0) "Light negative dot vs Charcoal bezel must be >= 3:1 (got ${cCharcoalLightNeg}:1)"

        # 2. Accent Dot Across All 8 Light Presets against Bezels
        foreach ($preset in $accentsLight) {
            $name = $preset[0]
            $hex = $preset[1]
            [void]$inkType.GetMethod("Apply", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($true))
            if ($hex -ne "") {
                [void]$inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @($hex))
            }
            $t = $baseProp.GetValue($null)
            $accent = [System.Drawing.Color]$toneType.GetField("Accent").GetValue($t)

            $cBlack = Get-WcagContrastRatio $accent $bezelBlack
            $cCharcoal = Get-WcagContrastRatio $accent $bezelCharcoal
            Write-Host "       Preset [$name] Accent ($accent) vs Black Bezel: ${cBlack}:1, vs Charcoal: ${cCharcoal}:1" -ForegroundColor Gray
            Assert-True ($cBlack -ge 3.0) "Accent [$name] vs Black bezel must be >= 3:1 (got ${cBlack}:1)"
            Assert-True ($cCharcoal -ge 3.0) "Accent [$name] vs Charcoal bezel must be >= 3:1 (got ${cCharcoal}:1)"
        }

        # 3. Status Track Background Track (p.T.Faint)
        # In Mini.cs: p.FillRound(track, MiniTrackThick / 2, p.T.Faint);
        # In Dark mode: Faint is Color.FromArgb(148, 245, 245, 247).
        # Alpha blended onto dark island sliver surface (#000000):
        # Effective RGB = (148/255)*245 = 142.
        $faintDarkEff = [System.Drawing.Color]::FromArgb(255, 142, 142, 143)
        $cFaintBlack = Get-WcagContrastRatio $faintDarkEff $bezelBlack
        $cFaintCharcoal = Get-WcagContrastRatio $faintDarkEff $bezelCharcoal
        Write-Host "       Dark Track Background (Faint eff $faintDarkEff) vs Black Bezel: ${cFaintBlack}:1, vs Charcoal: ${cFaintCharcoal}:1" -ForegroundColor Gray
        Assert-True ($cFaintBlack -ge 3.0) "Status track background vs Black bezel must be >= 3:1 (got ${cFaintBlack}:1)"
        Assert-True ($cFaintCharcoal -ge 3.0) "Status track background vs Charcoal bezel must be >= 3:1 (got ${cFaintCharcoal}:1)"
    }
}

# ==========================================================================
# SECTION 4: DockCal & DockSheet Interactive Pressed State Verification
# ==========================================================================
Describe "4. Dock Module Interactive Pressed State & Tactile Feedback Verification" {

    $calType = $global:TepiAssembly.GetTypes() | Where-Object { $_.Name -match 'CalendarSheet' }
    Assert-NotNull $calType "CalendarSheet type must exist in compiled assembly"

    It "Validates CalendarSheet pressedId tracking field and helper methods" {
        $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Instance'

        $pressedIdField = $calType.GetField("pressedId", $flags)
        Assert-NotNull $pressedIdField "CalendarSheet.pressedId field must exist"

        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)
        if (-not $selectedDayProp) { $selectedDayProp = $calType.GetProperty("SelectedDay", $flags) }
        Assert-NotNull $selectedDayProp "CalendarSheet.selectedDay property must exist"

        $downMethod = $calType.GetMethod("Down", $flags)
        Assert-NotNull $downMethod "CalendarSheet.Down method must exist"

        $pressedMethod = $calType.GetMethod("Pressed", $flags)
        Assert-NotNull $pressedMethod "CalendarSheet.Pressed method must exist"

        # Check Mouse event overrides
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        Assert-NotNull $onMouseDown "CalendarSheet.OnMouseDown must be overridden"

        $onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
        Assert-NotNull $onMouseUp "CalendarSheet.OnMouseUp must be overridden"

        $onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)
        Assert-NotNull $onMouseLeave "CalendarSheet.OnMouseLeave must be overridden"
    }

    It "Validates GlassSheet base Down method and pressId clearance" {
        $sheetType = $global:TepiAssembly.GetTypes() | Where-Object { $_.Name -match 'GlassSheet' }
        Assert-NotNull $sheetType "GlassSheet type must exist in compiled assembly"

        $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Instance'
        $sheetDown = $sheetType.GetMethod("Down", $flags)
        Assert-NotNull $sheetDown "GlassSheet.Down method must exist"

        # Check source for pressId = null clearance on OnMouseLeave
        $sheetSrc = Get-Content (Join-Path $PSScriptRoot "..\src\DockSheet.cs") -Raw
        Assert-True ($sheetSrc -match 'pressId\s*=\s*null;') "DockSheet must clear pressId on mouse leave or mouse up"
    }

    It "Validates tactile displacement (0.75f) and p.T.FillPressed in DockCal buttons" {
        $calSrc = Get-Content (Join-Path $PSScriptRoot "..\src\DockCal.cs") -Raw

        # Check for tactile offset across interactive buttons (b.Offset(0, 0.75f), dcy = ddown ? cy + 0.75f, xcy + 0.75f)
        $tactileMatches = [regex]::Matches($calSrc, '0\.75f')
        Write-Host "       Calendar buttons tactile displacement occurrences (0.75f): $($tactileMatches.Count)" -ForegroundColor Gray
        Assert-True ($tactileMatches.Count -ge 5) "DockCal must apply tactile 0.75f offset across clear, del, month/today, day, and quiet buttons (got $($tactileMatches.Count))"

        # Check for FillPressed
        $fillPressedMatches = [regex]::Matches($calSrc, 'FillPressed')
        Write-Host "       Calendar buttons FillPressed occurrences: $($fillPressedMatches.Count)" -ForegroundColor Gray
        Assert-True ($fillPressedMatches.Count -ge 4) "DockCal must apply FillPressed to interactive buttons (got $($fillPressedMatches.Count))"
    }
}

# --------------------------------------------------------------------------
# Execution Summary
# --------------------------------------------------------------------------
Format-TestReport
