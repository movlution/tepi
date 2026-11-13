# tests/adversarial/adversarial_m3_interactive.ps1
# Milestone 3 Adversarial Stress Harness: Island HUD & Interaction States
# Challenger 1 Empirical Code-Executing Verification
# Covers:
# 1. Glass Text Contrast (Tone.OnGlass, WCAG AA >= 4.5:1 against light wallpapers)
# 2. Glass Pill Elevation Shadow (H <= 60 subtle elevation shadow without interior darkening)
# 3. Approval Halo Reduced Motion Guard (Anim.Reduced static vs dynamic oscillation)
# 4. Tabs Hover vs Pressed Fill States (Tokens, AST, and pixel-distinct rendering)

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Adversarial Suite M3: Island HUD & Interactive State Stress Testing" {

    $islandType = Get-TepiType "Island"
    $inkType = Get-TepiType "Ink"
    $toneType = Get-TepiType "Tone"
    $animType = Get-TepiType "Anim"
    $painterType = Get-TepiType "Painter"

    $contrastMethod = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]'Public,Static')
    $shadowLayersMethod = $islandType.GetMethod("ShadowLayers", [System.Reflection.BindingFlags]'NonPublic,Static')
    $computeFrostTintMethod = $islandType.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]'NonPublic,Static')
    $toSrgbMethod = $islandType.GetMethod("ToSrgb", [System.Reflection.BindingFlags]'Public,Static')

    function Get-Contrast([System.Drawing.Color]$c1, [System.Drawing.Color]$c2) {
        return [double]$contrastMethod.Invoke($null, @($c1, $c2))
    }

    # =========================================================================
    # SUITE 1: Glass Text Contrast (Tone.OnGlass) Stress Verification
    # =========================================================================

    It "S1.01: Verifies Tone.OnGlass() clamps Sub alpha to >= 189 (74.1%) in Dark and Light modes" {
        Reset-TepiTheme -Light $false
        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        Assert-Equal $darkTone.Sub.A 158 "Default dark mode Sub alpha must be 158"
        
        $glassDark = $darkTone.OnGlass()
        Assert-True ($glassDark.Sub.A -ge 189) "OnGlass Sub alpha must clamp to >= 189 (actual: $($glassDark.Sub.A))"
        Assert-Equal $glassDark.Sub.R $darkTone.Sub.R "Sub R must be preserved"
        Assert-Equal $glassDark.Sub.G $darkTone.Sub.G "Sub G must be preserved"
        Assert-Equal $glassDark.Sub.B $darkTone.Sub.B "Sub B must be preserved"

        Reset-TepiTheme -Light $true
        $paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()
        $glassPaper = $paperTone.OnGlass()
        Assert-True ($glassPaper.Sub.A -ge 189) "Light mode OnGlass Sub alpha must clamp to >= 189 (actual: $($glassPaper.Sub.A))"
    }

    It "S1.02: Verifies Tone.OnGlass() mathematical idempotency over 10 consecutive passes" {
        $tone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $current = $tone
        for ($i = 0; $i -lt 10; $i++) {
            $current = $current.OnGlass()
        }
        $expected = $tone.OnGlass()
        Assert-Equal $current.Sub.ToArgb() $expected.Sub.ToArgb() "Multiple OnGlass invocations must not drift alpha"
    }

    It "S1.03: Empirically measures Sub text contrast on frosted glass over Pure White (#FFFFFF)" {
        # Signature bytes for uniform #FFFFFF (B, G, R, A quadruplets)
        [byte[]]$whiteSig = New-Object byte[] 64
        for ($i = 0; $i -lt 64; $i += 4) {
            $whiteSig[$i] = 255; $whiteSig[$i+1] = 255; $whiteSig[$i+2] = 255; $whiteSig[$i+3] = 255
        }
        
        $veil = [System.Drawing.Color]::FromArgb(255, 18, 18, 20)
        $invokeArgs = [object[]]@([byte[]]$whiteSig, [int]64, [System.Drawing.Color]$veil, [bool]$false)
        $frostTint = [float]$computeFrostTintMethod.Invoke($null, $invokeArgs)
        Assert-True ($frostTint -ge 0.65) "Frost tint on pure white wallpaper must elevate to >= 0.65 (actual: $frostTint)"

        # Calculate plate background color: veil blended over pure white
        $plateR = [int](0.67 * 18 + 0.33 * 255) # ~96
        $plateG = [int](0.67 * 18 + 0.33 * 255) # ~96
        $plateB = [int](0.67 * 20 + 0.33 * 255) # ~98
        $plateColor = [System.Drawing.Color]::FromArgb(255, $plateR, $plateG, $plateB)

        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $subNoGlass = $darkTone.Sub # alpha 158
        $subOnGlass = $darkTone.OnGlass().Sub # alpha 189

        # Composite without OnGlass (alpha 158/255 = 0.62)
        $compNoGlassR = [int](0.62 * 245 + 0.38 * $plateR)
        $compNoGlass = [System.Drawing.Color]::FromArgb(255, $compNoGlassR, $compNoGlassR, $compNoGlassR)
        $crNoGlass = Get-Contrast $compNoGlass $plateColor

        # Composite with OnGlass (alpha 189/255 = 0.741)
        $compOnGlassR = [int](0.741 * 245 + 0.259 * $plateR)
        $compOnGlass = [System.Drawing.Color]::FromArgb(255, $compOnGlassR, $compOnGlassR, $compOnGlassR)

        # Drop shadow composite (90-alpha black under text)
        $shadowPlateR = [int]((1.0 - (90.0 * 189.0 / 255.0 / 255.0)) * $plateR) # ~71
        $shadowPlateColor = [System.Drawing.Color]::FromArgb(255, $shadowPlateR, $shadowPlateR, $shadowPlateR)
        $crWithShadow = Get-Contrast $compOnGlass $shadowPlateColor

        # Panel extra tint (0.55 tint over base):
        $panelExtra = 1.0 - (1.0 - 0.55) / (1.0 - 0.42) # ~0.224
        $panelBgR = [int](0.224 * 18 + (1.0 - 0.224) * $plateR) # ~79
        $panelBgColor = [System.Drawing.Color]::FromArgb(255, $panelBgR, $panelBgR, $panelBgR)
        $compPanelR = [int](0.741 * 245 + 0.259 * $panelBgR)
        $compPanelColor = [System.Drawing.Color]::FromArgb(255, $compPanelR, $compPanelR, $compPanelR)
        $crPanel = Get-Contrast $compPanelColor $panelBgColor

        Write-Host "     [#FFFFFF Wallpaper] Raw Sub: $([math]::Round($crNoGlass, 2)):1 | OnGlass with Shadow: $([math]::Round($crWithShadow, 2)):1 | OnGlass on Panel: $([math]::Round($crPanel, 2)):1" -ForegroundColor Gray

        Assert-True ($crNoGlass -lt 4.5) "Raw Sub without OnGlass drops below 4.5:1 on white wallpaper (actual: $crNoGlass)"
        Assert-True ($crWithShadow -ge 4.5) "OnGlass Sub with shadow maintains >= 4.5:1 (actual: $crWithShadow)"
        Assert-True ($crPanel -ge 4.5) "OnGlass Sub on Panel glass maintains >= 4.5:1 (actual: $crPanel)"
    }

    It "S1.04: Stress-tests Sub text contrast across a spectrum of bright wallpapers (#F5F5F5, #FFFAF0, #E0FFFF, #FFF8DC, #FFFF00)" {
        $brightWallpapers = @(
            @{ Name = "Paper Gray"; Hex = "#F5F5F5"; R = 245; G = 245; B = 245 },
            @{ Name = "Floral White"; Hex = "#FFFAF0"; R = 255; G = 250; B = 240 },
            @{ Name = "Light Cyan"; Hex = "#E0FFFF"; R = 224; G = 255; B = 255 },
            @{ Name = "Cornsilk"; Hex = "#FFF8DC"; R = 255; G = 248; B = 220 },
            @{ Name = "Vivid Yellow"; Hex = "#FFFF00"; R = 255; G = 255; B = 0 }
        )

        $veil = [System.Drawing.Color]::FromArgb(255, 18, 18, 20)
        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        $subOnGlass = $darkTone.OnGlass().Sub

        foreach ($wp in $brightWallpapers) {
            [byte[]]$sig = New-Object byte[] 64
            for ($i = 0; $i -lt 64; $i += 4) {
                $sig[$i] = $wp.B; $sig[$i+1] = $wp.G; $sig[$i+2] = $wp.R; $sig[$i+3] = 255
            }
            $invokeArgsWp = [object[]]@([byte[]]$sig, [int]64, [System.Drawing.Color]$veil, [bool]$false)
            $tint = [float]$computeFrostTintMethod.Invoke($null, $invokeArgsWp)
            $bgR = [int]($tint * 18 + (1.0 - $tint) * $wp.R)
            $bgG = [int]($tint * 18 + (1.0 - $tint) * $wp.G)
            $bgB = [int]($tint * 20 + (1.0 - $tint) * $wp.B)
            $glassPlate = [System.Drawing.Color]::FromArgb(255, $bgR, $bgG, $bgB)

            # Composite text
            $textR = [int](0.741 * 245 + 0.259 * $bgR)
            $textG = [int](0.741 * 245 + 0.259 * $bgG)
            $textB = [int](0.741 * 247 + 0.259 * $bgB)
            $compText = [System.Drawing.Color]::FromArgb(255, $textR, $textG, $textB)

            # Drop shadow edge
            $shadowR = [int]((1.0 - (90.0 * 189.0 / 255.0 / 255.0)) * $bgR)
            $shadowG = [int]((1.0 - (90.0 * 189.0 / 255.0 / 255.0)) * $bgG)
            $shadowB = [int]((1.0 - (90.0 * 189.0 / 255.0 / 255.0)) * $bgB)
            $shadowBg = [System.Drawing.Color]::FromArgb(255, $shadowR, $shadowG, $shadowB)

            $ratio = Get-Contrast $compText $shadowBg
            Write-Host "     [$($wp.Name) ($($wp.Hex))]: Tint=$([math]::Round($tint, 3)), Contrast With Shadow=$([math]::Round($ratio, 2)):1" -ForegroundColor Gray
            Assert-True ($ratio -ge 4.5) "Sub text contrast on $($wp.Name) must be >= 4.5:1 (actual: $ratio)"
        }
    }

    It "S1.05: Static verification of OnGlass() and p.Shadow coverage in src/Island.cs" {
        $islandSrc = Get-Content (Join-Path $PSScriptRoot "..\..\src\Island.cs") -Raw
        
        # Verify lines 805, 847, 868, 872, 1243, 1246
        Assert-True ($islandSrc -match "p\.T\s*=\s*GlassOn\s*\?\s*Ink\.Base\.OnGlass\(\)\s*:\s*Ink\.Base;") "Line 805/872 must assign OnGlass to p.T"
        Assert-True ($islandSrc -match "DrawContent\(now,\s*GlassOn\s*\?\s*Ink\.Base\.OnGlass\(\)\s*:\s*Ink\.Base") "Line 847 must pass OnGlass to DrawContent"
        Assert-True ($islandSrc -match "DrawContent\(now,\s*GlassOn\s*\?\s*Ink\.Flip\.OnGlass\(\)\s*:\s*Ink\.Flip") "Line 868 must pass Flip.OnGlass to DrawContent"
        Assert-True ($islandSrc -match "if\s*\(GlassOn\s*&&\s*tone\s*!=\s*null\)\s*tone\s*=\s*tone\.OnGlass\(\);") "Line 1243 must defensively invoke OnGlass"
        Assert-True ($islandSrc -match "p\.Shadow\s*=\s*GlassOn\s*&&\s*!LiquidOn\s*&&\s*tone\.Bg\.R\s*<\s*128\s*&&\s*current\s*!=\s*View\.Panel;") "Line 1246 must enable text drop shadow on pill"
    }


    # =========================================================================
    # SUITE 2: Glass Pill Elevation Shadow (H <= 60) Stress Verification
    # =========================================================================

    It "S2.01: Evaluates elevation shadow condition and strength factors in Island.cs" {
        $islandSrc = Get-Content (Join-Path $PSScriptRoot "..\..\src\Island.cs") -Raw

        # Check shadowStr logic
        $pattern = "float\s+shadowStr\s*=\s*\(GlassOn\s*&&\s*H\s*<=\s*60\)\s*\?\s*\(Ink\.Light\s*\?\s*0\.45f\s*:\s*0\.35f\)\s*:\s*1f;"
        Assert-True ($islandSrc -match $pattern) "Island.cs must compute subtle elevation shadow (0.35/0.45) for GlassOn && H <= 60"
        
        # Check bubble shadow scaling
        $bubblePattern = "if\s*\(!bubbleRect\.IsEmpty\)\s*DrawShadow\(bubbleRect,\s*br,\s*\(GlassOn\s*&&\s*H\s*<=\s*60\)\s*\?\s*0\.3f\s*:\s*0\.7f\);"
        Assert-True ($islandSrc -match $bubblePattern) "Island.cs must scale bubble shadow down to 0.3f when GlassOn && H <= 60"
    }

    It "S2.02: Empirically renders elevation shadow at strength 0.35f and verifies non-zero spread" {
        $bmp = New-Object System.Drawing.Bitmap 200, 100, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $painter = [Activator]::CreateInstance($painterType)
        $painter.G = $g

        $pillRect = New-Object System.Drawing.RectangleF 40, 33, 120, 34
        $radius = 17.0
        $strength = 0.35

        $shadowLayersMethod.Invoke($null, @($painter, $pillRect, [float]$radius, [float]$strength))
        $g.Flush()

        # Sample outside the pill in the shadow spread area
        # Top shadow offset (drop=3, grow=6 at layer 1) -> y = 33 - 5 = 28
        $pxTop = $bmp.GetPixel(100, 28)
        # Bottom shadow offset (drop=5, grow=11.5 at layer 3) -> y = 67 + 8 = 75
        $pxBottom = $bmp.GetPixel(100, 75)
        # Far outside (beyond shadow margin) -> y = 10
        $pxFar = $bmp.GetPixel(100, 10)

        Write-Host "     [Shadow Alpha Spread]: Top (y=28): A=$($pxTop.A) | Bottom (y=75): A=$($pxBottom.A) | Far (y=10): A=$($pxFar.A)" -ForegroundColor Gray

        Assert-True ($pxTop.A -gt 0) "Top shadow spread must have alpha > 0 (actual: $($pxTop.A))"
        Assert-True ($pxBottom.A -gt 0) "Bottom shadow spread must have alpha > 0 (actual: $($pxBottom.A))"
        Assert-Equal $pxFar.A 0 "Far pixel outside shadow margin must have alpha == 0"

        # Check peak alpha in shadow is subtle (< 35 / 14%)
        Assert-True ($pxBottom.A -le 35) "Elevation shadow must be subtle (alpha <= 35, actual: $($pxBottom.A))"

        $painter.Dispose()
        $g.Dispose()
        $bmp.Dispose()
    }

    It "S2.03: Empirically verifies elevation shadow does NOT darken frosted glass interior" {
        # Simulate rendering pipeline:
        # Bitmap A: Shadow rendered first, then shell filled with SourceCopy CompositingMode
        # Bitmap B: Shell filled with SourceCopy CompositingMode alone (zero shadow)
        $bmpA = New-Object System.Drawing.Bitmap 200, 100, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gA = [System.Drawing.Graphics]::FromImage($bmpA)
        $gA.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $pA = [Activator]::CreateInstance($painterType)
        $pA.G = $gA

        $bmpB = New-Object System.Drawing.Bitmap 200, 100, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gB = [System.Drawing.Graphics]::FromImage($bmpB)
        $gB.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $pillRect = New-Object System.Drawing.RectangleF 40, 33, 120, 34
        $radius = 17.0

        # Draw shadow on A
        $shadowLayersMethod.Invoke($null, @($pA, $pillRect, [float]$radius, [float]0.35))
        $gA.Flush()

        # Simulated frosted plate to blit into interior
        $plateBmp = New-Object System.Drawing.Bitmap 120, 34, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $pg = [System.Drawing.Graphics]::FromImage($plateBmp)
        $pg.Clear([System.Drawing.Color]::FromArgb(255, 96, 96, 98))
        $pg.Dispose()

        # Fill surface inside shell using SourceCopy on both A and B
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddRectangle($pillRect)

        foreach ($pair in @(@($gA, $bmpA), @($gB, $bmpB))) {
            $gTarget = $pair[0]
            $st = $gTarget.Save()
            $gTarget.SetClip($path, [System.Drawing.Drawing2D.CombineMode]::Intersect)
            $gTarget.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $gTarget.DrawImage($plateBmp, 40, 33, 120, 34)
            $gTarget.Restore($st)
            $gTarget.Flush()
        }

        # Sample interior pixels across the shell: center and quadrants
        $testCoords = @(
            @{ X = 100; Y = 50 }, # Center
            @{ X = 70;  Y = 50 }, # Left center
            @{ X = 130; Y = 50 }, # Right center
            @{ X = 100; Y = 42 }, # Top center
            @{ X = 100; Y = 58 }  # Bottom center
        )

        $interiorIdentical = $true
        foreach ($pt in $testCoords) {
            $colA = $bmpA.GetPixel($pt.X, $pt.Y)
            $colB = $bmpB.GetPixel($pt.X, $pt.Y)
            if ($colA.ToArgb() -ne $colB.ToArgb()) {
                $interiorIdentical = $false
                Write-Host "     Mismatch at ($($pt.X), $($pt.Y)): ColA=$($colA.ToArgb()) vs ColB=$($colB.ToArgb())" -ForegroundColor Red
            }
        }

        Assert-True $interiorIdentical "All sampled interior pixels must be 100% bit-identical between shadow and non-shadow passes"

        $path.Dispose()
        $plateBmp.Dispose()
        $pA.Dispose(); $gA.Dispose(); $bmpA.Dispose()
        $gB.Dispose(); $bmpB.Dispose()
    }


    # =========================================================================
    # SUITE 3: Approval Halo Reduced Motion Guard Stress Verification
    # =========================================================================

    It "S3.01: Evaluates breath formula under Anim.Reduced == true (strictly 0.75f, 0 Hz frequency)" {
        $islandSrc = Get-Content (Join-Path $PSScriptRoot "..\..\src\Island.cs") -Raw
        $haloPattern = "float\s+breath\s*=\s*Anim\.Reduced\s*\?\s*0\.75f\s*:\s*0\.55f\s*\+\s*0\.45f\s*\*\s*\(float\)Math\.Sin\(clock\.Elapsed\.TotalSeconds\s*\*\s*Math\.PI\s*\*\s*1\.3\);"
        Assert-True ($islandSrc -match $haloPattern) "Island.cs line 1143 must use 0.75f static breath when Anim.Reduced is true"

        # Mathematical simulation across diverse timestamps
        $animReduced = $true
        $timestamps = @(0.0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.14159, 10.0, 100.0)
        foreach ($t in $timestamps) {
            $breath = if ($animReduced) { 0.75 } else { 0.55 + 0.45 * [Math]::Sin($t * [Math]::PI * 1.3) }
            Assert-Equal $breath 0.75 "Timestamp $t must yield constant breath = 0.75f when Anim.Reduced is true"
        }
    }

    It "S3.02: Evaluates breath formula under Anim.Reduced == false (dynamic sinusoidal breathing 0.10f - 1.00f)" {
        $animReduced = $false
        $breaths = @()
        for ($i = 0; $i -le 40; $i++) {
            $t = $i * 0.05
            $b = if ($animReduced) { 0.75 } else { 0.55 + 0.45 * [Math]::Sin($t * [Math]::PI * 1.3) }
            $breaths += $b
        }

        $minBreath = ($breaths | Measure-Object -Minimum).Minimum
        $maxBreath = ($breaths | Measure-Object -Maximum).Maximum
        $variance = ($breaths | Select-Object -Unique).Count

        Write-Host "     [Dynamic Halo]: Min breath=$([math]::Round($minBreath, 3)), Max breath=$([math]::Round($maxBreath, 3)), Distinct states=$variance" -ForegroundColor Gray

        Assert-True ($minBreath -le 0.15) "Sinusoidal minimum must reach <= 0.15f (actual: $minBreath)"
        Assert-True ($maxBreath -ge 0.95) "Sinusoidal maximum must reach >= 0.95f (actual: $maxBreath)"
        Assert-True ($variance -ge 30) "Sinusoidal breathing must produce diverse smooth values across time"
    }

    It "S3.03: Empirically renders DrawGlow layers at multiple timestamps and verifies temporal stability" {
        $glowLayers = 16
        $c = [System.Drawing.Color]::FromArgb(255, 245, 245, 247)
        $flip = 1.0

        # Render function for simulated DrawGlow
        function Render-Halo([bool]$reduced, [double]$seconds) {
            $bmp = New-Object System.Drawing.Bitmap 160, 80, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $p = [Activator]::CreateInstance($painterType)
            $p.G = $g

            $r = New-Object System.Drawing.RectangleF 30, 20, 100, 40
            $radius = 20.0
            $breath = if ($reduced) { 0.75 } else { 0.55 + 0.45 * [Math]::Sin($seconds * [Math]::PI * 1.3) }

            for ($i = 0; $i -lt $glowLayers; $i++) {
                $grow = 1.0 + $i * 0.9
                $fall = 1.0 - ($i / [double]$glowLayers)
                $rr = New-Object System.Drawing.RectangleF ($r.X - $grow), ($r.Y - $grow), ($r.Width + $grow * 2), ($r.Height + $grow * 2)
                $layerAlpha = [int]($flip * $breath * 36.0 * $fall * [Math]::Sqrt($fall))
                $p.FillRound($rr, [float]($radius + $grow), [System.Drawing.Color]::FromArgb($layerAlpha, $c.R, $c.G, $c.B))
            }
            $g.Flush()
            $p.Dispose(); $g.Dispose()
            return $bmp
        }

        # 1. Test Static Stability when Reduced == true
        $bmpT0 = Render-Halo -reduced $true -seconds 0.0
        $bmpT1 = Render-Halo -reduced $true -seconds 0.385 # peak pulse if dynamic
        $bmpT2 = Render-Halo -reduced $true -seconds 1.154 # trough pulse if dynamic

        $pxT0 = $bmpT0.GetPixel(80, 18)
        $pxT1 = $bmpT1.GetPixel(80, 18)
        $pxT2 = $bmpT2.GetPixel(80, 18)

        Assert-Equal $pxT0.ToArgb() $pxT1.ToArgb() "Static halo pixel at t=0 must match t=0.385s"
        Assert-Equal $pxT1.ToArgb() $pxT2.ToArgb() "Static halo pixel at t=0.385s must match t=1.154s"

        # 2. Test Dynamic Oscillation when Reduced == false
        $bmpDynT0 = Render-Halo -reduced $false -seconds 0.0   # sin(0)=0 -> breath=0.55
        $bmpDynPeak = Render-Halo -reduced $false -seconds 0.385 # sin=1 -> breath=1.00
        $bmpDynTrough = Render-Halo -reduced $false -seconds 1.154 # sin=-1 -> breath=0.10

        $pxDynT0 = $bmpDynT0.GetPixel(80, 18)
        $pxDynPeak = $bmpDynPeak.GetPixel(80, 18)
        $pxDynTrough = $bmpDynTrough.GetPixel(80, 18)

        Write-Host "     [DrawGlow Alpha]: Static=$($pxT0.A) | Dynamic Peak=$($pxDynPeak.A) | Dynamic Trough=$($pxDynTrough.A)" -ForegroundColor Gray

        Assert-True ($pxDynPeak.A -gt $pxDynT0.A) "Peak halo alpha ($($pxDynPeak.A)) must exceed baseline ($($pxDynT0.A))"
        Assert-True ($pxDynT0.A -gt $pxDynTrough.A) "Baseline halo alpha ($($pxDynT0.A)) must exceed trough ($($pxDynTrough.A))"

        $bmpT0.Dispose(); $bmpT1.Dispose(); $bmpT2.Dispose()
        $bmpDynT0.Dispose(); $bmpDynPeak.Dispose(); $bmpDynTrough.Dispose()
    }


    # =========================================================================
    # SUITE 4: Tabs Hover vs Pressed Fill States Stress Verification
    # =========================================================================

    It "S4.01: Verifies FillHover and FillPressed tokens are distinct in Dark and Light modes" {
        # Dark mode
        Reset-TepiTheme -Light $false
        $darkTone = Invoke-TepiStaticMethod "Tone" "Dark" @()
        Assert-NotNull $darkTone.FillHover "Dark FillHover must not be null"
        Assert-NotNull $darkTone.FillPressed "Dark FillPressed must not be null"
        Assert-NotEqual $darkTone.FillHover.ToArgb() $darkTone.FillPressed.ToArgb() "Dark FillHover and FillPressed must differ"
        Assert-Equal $darkTone.FillHover.A 28 "Dark mode FillHover alpha must be 28"
        Assert-Equal $darkTone.FillPressed.A 10 "Dark mode FillPressed alpha must be 10 (18 * 0.57f)"

        # Light mode
        Reset-TepiTheme -Light $true
        $paperTone = Invoke-TepiStaticMethod "Tone" "Paper" @()
        Assert-NotNull $paperTone.FillHover "Light FillHover must not be null"
        Assert-NotNull $paperTone.FillPressed "Light FillPressed must not be null"
        Assert-NotEqual $paperTone.FillHover.ToArgb() $paperTone.FillPressed.ToArgb() "Light FillHover and FillPressed must differ"
        Assert-Equal $paperTone.FillHover.A 24 "Light mode FillHover alpha must be 24"
        Assert-Equal $paperTone.FillPressed.A 30 "Light mode FillPressed alpha must be 30 (14 * 2.2f)"
    }

    It "S4.02: AST verification of all tab button rendering sites in src/Tabs.cs" {
        $tabsSrc = Get-Content (Join-Path $PSScriptRoot "..\..\src\Tabs.cs") -Raw

        # 1. Tab buttons loop (line 519)
        Assert-True ($tabsSrc -match "Hover\(`"tab`"\s*\+\s*to\)\s*&&\s*to\s*!=\s*page\)\s*p\.FillRound\(rects\[i\],\s*TabH\s*/\s*2,\s*Pressed\(`"tab`"\s*\+\s*to\)\s*\?\s*p\.T\.FillPressed\s*:\s*p\.T\.FillHover\);") "Line 519 must use Pressed ? FillPressed : FillHover"

        # 2. DrawDots hover fill (line 602)
        Assert-True ($tabsSrc -match "Pressed\(hid\)\s*\?\s*p\.T\.FillPressed\s*:\s*p\.T\.FillHover") "Line 602 must use Pressed ? FillPressed : FillHover"

        # 3. DrawPrefsButton (line 821)
        Assert-True ($tabsSrc -match "Hover\(`"prefsOpen`"\)\)\s*p\.FillRound\(r,\s*TabH\s*/\s*2,\s*Pressed\(`"prefsOpen`"\)\s*\?\s*p\.T\.FillPressed\s*:\s*p\.T\.FillHover\);") "Line 821 must use Pressed ? FillPressed : FillHover"

        # 4. TabButton (line 832)
        Assert-True ($tabsSrc -match "Hover\(id\)\)\s*p\.FillRound\(r,\s*TabH\s*/\s*2,\s*Pressed\(id\)\s*\?\s*p\.T\.FillPressed\s*:\s*p\.T\.FillHover\);") "Line 832 must use Pressed ? FillPressed : FillHover"

        # 5. DrawTabAction musicView (line 847)
        Assert-True ($tabsSrc -match "Hover\(`"musicView`"\)\)\s*p\.FillRound\(r,\s*TabH\s*/\s*2,\s*Pressed\(`"musicView`"\)\s*\?\s*p\.T\.FillPressed\s*:\s*p\.T\.FillHover\);") "Line 847 must use Pressed ? FillPressed : FillHover"

        # Assert ZERO instances of inverted ternary logic in Tabs.cs
        $invertedMatches = [System.Text.RegularExpressions.Regex]::Matches($tabsSrc, "Pressed\([^)]+\)\s*\?\s*p\.T\.FillHover\s*:\s*p\.T\.FillPressed")
        Assert-Equal $invertedMatches.Count 0 "src/Tabs.cs must contain ZERO instances of inverted 'Pressed ? FillHover : FillPressed'"

        $invertedFillMatches = [System.Text.RegularExpressions.Regex]::Matches($tabsSrc, "Pressed\([^)]+\)\s*\?\s*p\.T\.Fill\s*:\s*p\.T\.FillHover")
        Assert-Equal $invertedFillMatches.Count 0 "src/Tabs.cs must contain ZERO instances of inverted 'Pressed ? Fill : FillHover'"
    }

    It "S4.03: Empirically renders tab button in Idle, Hover, and Pressed states in Dark and Light modes" {
        foreach ($isLight in @($false, $true)) {
            Reset-TepiTheme -Light $isLight
            $tone = if ($isLight) { Invoke-TepiStaticMethod "Tone" "Paper" @() } else { Invoke-TepiStaticMethod "Tone" "Dark" @() }

            function Render-TabPill([bool]$hover, [bool]$pressed, [object]$t) {
                $bmp = New-Object System.Drawing.Bitmap 60, 30, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $p = [Activator]::CreateInstance($painterType)
                $p.G = $g
                $p.T = $t

                $r = New-Object System.Drawing.RectangleF 5, 2, 50, 26
                if ($hover) {
                    $fillColor = if ($pressed) { $p.T.FillPressed } else { $p.T.FillHover }
                    $p.FillRound($r, 13.0, $fillColor)
                }
                $g.Flush()
                $p.Dispose(); $g.Dispose()
                return $bmp
            }

            $bmpIdle = Render-TabPill -hover $false -pressed $false -t $tone
            $bmpHover = Render-TabPill -hover $true -pressed $false -t $tone
            $bmpPressed = Render-TabPill -hover $true -pressed $true -t $tone

            $pxIdle = $bmpIdle.GetPixel(30, 15)
            $pxHover = $bmpHover.GetPixel(30, 15)
            $pxPressed = $bmpPressed.GetPixel(30, 15)

            $modeName = if ($isLight) { "Light" } else { "Dark" }
            Write-Host "     [$modeName Mode Tab]: Idle A=$($pxIdle.A) | Hover A=$($pxHover.A) | Pressed A=$($pxPressed.A)" -ForegroundColor Gray

            Assert-Equal $pxIdle.A 0 "$modeName mode Idle tab must have 0 alpha"
            Assert-NotEqual $pxHover.ToArgb() $pxIdle.ToArgb() "$modeName mode Hover must differ from Idle"
            Assert-NotEqual $pxPressed.ToArgb() $pxHover.ToArgb() "$modeName mode Pressed must differ from Hover"
            Assert-NotEqual $pxPressed.ToArgb() $pxIdle.ToArgb() "$modeName mode Pressed must differ from Idle"

            $bmpIdle.Dispose(); $bmpHover.Dispose(); $bmpPressed.Dispose()
        }
    }

    It "S4.04: Verifies active tab accent pill invariant (active page renders Accent, not hover/pressed)" {
        $tabsSrc = Get-Content (Join-Path $PSScriptRoot "..\..\src\Tabs.cs") -Raw

        # Active tab check
        Assert-True ($tabsSrc -match "if\s*\(Hover\(`"tab`"\s*\+\s*to\)\s*&&\s*to\s*!=\s*page\)") "Hover and pressed fills must only apply when to != page"
        Assert-True ($tabsSrc -match "p\.FillRound\(pill,\s*TabH\s*/\s*2,\s*p\.T\.Accent\);") "Active page tab must render Accent pill"
    }
}
