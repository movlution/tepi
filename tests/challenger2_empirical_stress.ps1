# tests/challenger2_empirical_stress.ps1
# Challenger 2 Empirical Stress Test Harness
# Target: Glass.cs (Frost & Liquid), DockFrost.cs, and Font Resolution

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  CHALLENGER 2 EMPIRICAL STRESS TEST HARNESS" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load Assembly & Helpers
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$binPath = "d:\PROJECT\Other\tepi\Tepi.exe"
if (-not (Test-Path $binPath)) {
    Write-Error "Tepi.exe not found at $binPath. Run build.cmd first."
    exit 1
}

$assembly = [System.Reflection.Assembly]::LoadFrom($binPath)
$islandType = $assembly.GetType("Tepi.Island")
$inkType = $assembly.GetType("Tepi.Ink")

if (-not $islandType -or -not $inkType) {
    Write-Error "Could not resolve Tepi.Island or Tepi.Ink types."
    exit 1
}

[void]$inkType.GetMethod("Init", [System.Reflection.BindingFlags]'Public,Static').Invoke($null, @())

$failCount = 0
$passCount = 0

function Report-Result {
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

# --- SECTION 1: ToSrgb ROBUSTNESS & ARITHMETIC SAFETY ---
Write-Host "`n--- 1. Testing ToSrgb Arithmetic Safety (NaN, Inf, Clamping) ---" -ForegroundColor Yellow

$toSrgbMethod = $islandType.GetMethod("ToSrgb", [System.Reflection.BindingFlags]'Public,Static')

# 1.1 NaN safety
$nanThrew = $false
$nanExType = ""
try {
    $res = $toSrgbMethod.Invoke($null, @([float]::NaN))
} catch {
    $nanThrew = $true
    $nanExType = $_.Exception.InnerException.GetType().FullName
}

if ($nanThrew) {
    Report-Result "ToSrgb(float.NaN) exception safety" $false "CRITICAL: Threw $nanExType when passed float.NaN (IndexOutOfRangeException due to unhandled NaN cast to -2147483648)"
} else {
    Report-Result "ToSrgb(float.NaN) exception safety" $true "Handled NaN gracefully"
}

# 1.2 Positive Infinity
$posInfThrew = $false
$resPosInf = 0
try {
    $resPosInf = $toSrgbMethod.Invoke($null, @([float]::PositiveInfinity))
} catch {
    $posInfThrew = $true
}
Report-Result "ToSrgb(float.PositiveInfinity) clamps to 255" (-not $posInfThrew -and $resPosInf -eq 255) "Value: $resPosInf"

# 1.3 Negative Infinity
$negInfThrew = $false
$resNegInf = 255
try {
    $resNegInf = $toSrgbMethod.Invoke($null, @([float]::NegativeInfinity))
} catch {
    $negInfThrew = $true
}
Report-Result "ToSrgb(float.NegativeInfinity) clamps to 0" (-not $negInfThrew -and $resNegInf -eq 0) "Value: $resNegInf"

# 1.4 float.MinValue and float.MaxValue
try {
    $resMin = $toSrgbMethod.Invoke($null, @([float]::MinValue))
    $resMax = $toSrgbMethod.Invoke($null, @([float]::MaxValue))
    Report-Result "ToSrgb(float.MinValue/MaxValue) boundaries" ($resMin -eq 0 -and $resMax -eq 255) "Min: $resMin, Max: $resMax"
} catch {
    Report-Result "ToSrgb(float.MinValue/MaxValue) boundaries" $false "Threw exception: $($_.Exception.Message)"
}


# --- SECTION 2: ComputeFrostTint & TEXT CONTRAST HARNESS ---
Write-Host "`n--- 2. Testing ComputeFrostTint across Extreme Wallpapers & Backdrops ---" -ForegroundColor Yellow

$computeTintMethod = $islandType.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]'NonPublic,Static')

function Get-Luminance([double]$r, [double]$g, [double]$b) {
    # Convert sRGB 0-255 to linear
    $channels = @($r, $g, $b)
    $lin = for ($i = 0; $i -lt 3; $i++) {
        $c = $channels[$i] / 255.0
        if ($c -le 0.04045) { $c / 12.92 } else { [Math]::Pow(($c + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $lin[0] + 0.7152 * $lin[1] + 0.0722 * $lin[2]
}

function Get-ContrastRatio([double]$l1, [double]$l2) {
    $lighter = [Math]::Max($l1, $l2)
    $darker = [Math]::Min($l1, $l2)
    return ($lighter + 0.05) / ($darker + 0.05)
}

function Test-BackdropContrast {
    param(
        [string]$ScenarioName,
        [byte[]]$BackdropBgrx,
        [int]$Len,
        [bool]$LightMode,
        [System.Drawing.Color]$ThemeBg,
        [System.Drawing.Color]$TextColor,
        [System.Drawing.Color]$SubColor,
        [double]$MinRequiredContrast = 4.5
    )

    $tint = [float]$computeTintMethod.Invoke($null, @($BackdropBgrx, $Len, $ThemeBg, $LightMode))

    # Calculate worst-case backdrop pixel within the buffer
    $worstTextCR = 999.0
    $worstSubCR = 999.0
    $worstBackdropRgb = ""
    $worstSurfaceRgb = ""

    # Check each pixel in sample
    for ($i = 0; $i -le ($Len - 4); $i += 4) {
        $bgB = $BackdropBgrx[$i]
        $bgG = $BackdropBgrx[$i + 1]
        $bgR = $BackdropBgrx[$i + 2]

        # Surface = alpha * ThemeBg + (1 - alpha) * Backdrop
        # GDI+ SourceOver blending of brush Ink.A(job.Bg, frostTint) over backdrop:
        $surfR = [Math]::Round($tint * $ThemeBg.R + (1.0 - $tint) * $bgR)
        $surfG = [Math]::Round($tint * $ThemeBg.G + (1.0 - $tint) * $bgG)
        $surfB = [Math]::Round($tint * $ThemeBg.B + (1.0 - $tint) * $bgB)

        $surfLum = Get-Luminance $surfR $surfG $surfB
        $textLum = Get-Luminance $TextColor.R $TextColor.G $TextColor.B

        # Effective subtext on surface:
        $subA = $SubColor.A / 255.0
        $effSubR = [Math]::Round($subA * $SubColor.R + (1.0 - $subA) * $surfR)
        $effSubG = [Math]::Round($subA * $SubColor.G + (1.0 - $subA) * $surfG)
        $effSubB = [Math]::Round($subA * $SubColor.B + (1.0 - $subA) * $surfB)
        $subLum = Get-Luminance $effSubR $effSubG $effSubB

        $crText = Get-ContrastRatio $textLum $surfLum
        $crSub = Get-ContrastRatio $subLum $surfLum

        if ($crText -lt $worstTextCR) {
            $worstTextCR = $crText
            $worstBackdropRgb = "RGB($bgR,$bgG,$bgB)"
            $worstSurfaceRgb = "RGB($surfR,$surfG,$surfB)"
        }
        if ($crSub -lt $worstSubCR) {
            $worstSubCR = $crSub
        }
    }

    $textPass = $worstTextCR -ge $MinRequiredContrast
    $details = "Tint=$([Math]::Round($tint, 3)) | Worst Text CR=$([Math]::Round($worstTextCR, 2)):1 (req >= $MinRequiredContrast:1) | Worst Sub CR=$([Math]::Round($worstSubCR, 2)):1 | Backdrop=$worstBackdropRgb -> Surf=$worstSurfaceRgb"
    Report-Result $ScenarioName $textPass $details
    return @{ Tint = $tint; WorstTextCR = $worstTextCR; WorstSubCR = $worstSubCR; Pass = $textPass }
}

$darkBg = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
$darkText = [System.Drawing.Color]::FromArgb(255, 245, 245, 247)
# OnGlass Sub has alpha 189
$darkSub = [System.Drawing.Color]::FromArgb(189, 245, 245, 247)

$lightBg = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
$lightText = [System.Drawing.Color]::FromArgb(255, 12, 12, 14)
# OnGlass Sub has alpha 189
$lightSub = [System.Drawing.Color]::FromArgb(189, 12, 12, 14)

# 2.1 Pure White Wallpaper in Dark Mode
$bufWhite = New-Object byte[] 256
for ($i = 0; $i -lt 256; $i++) { $bufWhite[$i] = 255 }
Test-BackdropContrast "Pure White Wallpaper (#FFFFFF) in Dark Mode" $bufWhite 256 $false $darkBg $darkText $darkSub 4.5

# 2.2 Pure Black Wallpaper in Light Mode
$bufBlack = New-Object byte[] 256
for ($i = 0; $i -lt 256; $i++) { $bufBlack[$i] = 0 }
Test-BackdropContrast "Pure Black Wallpaper (#000000) in Light Mode" $bufBlack 256 $true $lightBg $lightText $lightSub 4.5

# 2.3 Split Luminance: 50% Pure White, 50% Pure Black (Dark Mode)
$bufSplit50Dark = New-Object byte[] 256
for ($i = 0; $i -lt 128; $i++) { $bufSplit50Dark[$i] = 255 }
for ($i = 128; $i -lt 256; $i++) { $bufSplit50Dark[$i] = 0 }
Test-BackdropContrast "Split 50% White / 50% Black in Dark Mode" $bufSplit50Dark 256 $false $darkBg $darkText $darkSub 4.5

# 2.4 Split Luminance: 50% Pure White, 50% Pure Black (Light Mode)
$bufSplit50Light = New-Object byte[] 256
for ($i = 0; $i -lt 128; $i++) { $bufSplit50Light[$i] = 255 }
for ($i = 128; $i -lt 256; $i++) { $bufSplit50Light[$i] = 0 }
Test-BackdropContrast "Split 50% White / 50% Black in Light Mode" $bufSplit50Light 256 $true $lightBg $lightText $lightSub 4.5

# 2.5 HDR White Spike: 90% Black, 10% Pure White Peak (Dark Mode)
# In this scenario, wallpaper is mostly dark, but has a small high-luminance white window or icon
$bufSpikeWhite = New-Object byte[] 256
for ($i = 0; $i -lt 256; $i++) { $bufSpikeWhite[$i] = 0 }
# Spike 4 pixels (16 bytes) at white 255
for ($i = 0; $i -lt 16; $i++) { $bufSpikeWhite[$i] = 255 }
Test-BackdropContrast "HDR White Spike (90% Black / 10% White) in Dark Mode" $bufSpikeWhite 256 $false $darkBg $darkText $darkSub 4.5

# 2.6 HDR Black Spike: 90% White, 10% Pure Black Notch (Light Mode)
$bufSpikeBlack = New-Object byte[] 256
for ($i = 0; $i -lt 256; $i++) { $bufSpikeBlack[$i] = 255 }
for ($i = 0; $i -lt 16; $i++) { $bufSpikeBlack[$i] = 0 }
Test-BackdropContrast "HDR Black Notch (90% White / 10% Black) in Light Mode" $bufSpikeBlack 256 $true $lightBg $lightText $lightSub 4.5

# 2.7 High Contrast Checkerboard Pattern (alternating pixels 0 and 255)
$bufChecker = New-Object byte[] 256
for ($i = 0; $i -lt 256; $i += 8) {
    # Pixel 0 = White
    $bufChecker[$i] = 255; $bufChecker[$i+1] = 255; $bufChecker[$i+2] = 255; $bufChecker[$i+3] = 255
    # Pixel 1 = Black
    $bufChecker[$i+4] = 0; $bufChecker[$i+5] = 0; $bufChecker[$i+6] = 0; $bufChecker[$i+7] = 255
}
Test-BackdropContrast "High Contrast Checkerboard in Dark Mode" $bufChecker 256 $false $darkBg $darkText $darkSub 4.5
Test-BackdropContrast "High Contrast Checkerboard in Light Mode" $bufChecker 256 $true $lightBg $lightText $lightSub 4.5

# 2.8 Saturated Pure Colors (Red, Green, Blue, Cyan, Yellow, Magenta)
$pureColors = @(
    @{ Name = "Pure Blue"; B=255; G=0; R=0 },
    @{ Name = "Pure Green"; B=0; G=255; R=0 },
    @{ Name = "Pure Red"; B=0; G=0; R=255 },
    @{ Name = "Pure Cyan"; B=255; G=255; R=0 },
    @{ Name = "Pure Yellow"; B=0; G=255; R=255 },
    @{ Name = "Pure Magenta"; B=255; G=0; R=255 }
)
foreach ($c in $pureColors) {
    $bufCol = New-Object byte[] 256
    for ($i = 0; $i -lt 256; $i += 4) {
        $bufCol[$i] = $c.B; $bufCol[$i+1] = $c.G; $bufCol[$i+2] = $c.R; $bufCol[$i+3] = 255
    }
    Test-BackdropContrast "$($c.Name) Wallpaper in Dark Mode" $bufCol 256 $false $darkBg $darkText $darkSub 4.5
    Test-BackdropContrast "$($c.Name) Wallpaper in Light Mode" $bufCol 256 $true $lightBg $lightText $lightSub 4.5
}


# --- SECTION 3: DockFrost.cs AUDIT & CONTRAST TEST ---
Write-Host "`n--- 3. Testing DockFrost.cs (Dock Frost & Liquid Shaders) ---" -ForegroundColor Yellow

# Inspect DockFrost.cs directly for BaseTint hardcoding
$dockFrostFile = "d:\PROJECT\Other\tepi\src\DockFrost.cs"
$dockContent = Get-Content $dockFrostFile -Raw
$dockUsesCompute = $dockContent.Contains("ComputeFrostTint")
$dockHasBaseTintFill = $dockContent.Contains("Ink.A(j.Bg, BaseTint)")

if (-not $dockUsesCompute -and $dockHasBaseTintFill) {
    # Calculate what happens to Dock Frost on pure white wallpaper in dark mode:
    # BaseTint is hardcoded at 0.42f.
    # On White wallpaper (RGB 255, 255, 255), surface = 0.42 * 0 + 0.58 * 255 = 147.9 -> 148.
    $dockSurfLum = Get-Luminance 148 148 148
    $dockTextLum = Get-Luminance $darkText.R $darkText.G $darkText.B
    $dockCR = Get-ContrastRatio $dockTextLum $dockSurfLum

    Report-Result "DockFrost.cs uses adaptive ComputeFrostTint for Frost material" $false "CRITICAL DEFECT: DockFrost.cs lines 184 still hardcodes BaseTint (0.42f). On pure white wallpaper in dark mode, Dock Frost surface luminance is L=$([Math]::Round($dockSurfLum, 4)), dropping text contrast to $([Math]::Round($dockCR, 2)):1 (FAILS WCAG AA >= 4.5:1 floor!). Worker 1 only updated Glass.cs and left DockFrost.cs unhedged."
} else {
    Report-Result "DockFrost.cs uses adaptive ComputeFrostTint for Frost material" $true "DockFrost uses adaptive tint"
}


# --- SECTION 4: LiquidPass & DockFrost.Liquid EXECUTION & BUFFER SAFETY ---
Write-Host "`n--- 4. Testing LiquidPass & DockFrost.Liquid Execution & Contrast ---" -ForegroundColor Yellow

$liquidPassMethod = $islandType.GetMethod("LiquidPass", [System.Reflection.BindingFlags]'NonPublic,Static')

function Test-LiquidExecution {
    param(
        [string]$Name,
        [int]$W,
        [int]$H,
        [byte[]]$RawPixels,
        [System.Drawing.Color]$Bg,
        [bool]$Light,
        [System.Drawing.Color]$TextColor,
        [double]$MinRequiredContrast = 4.5
    )

    $bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
    $threw = $false
    $exMsg = ""
    $minContrastFound = 999.0
    $worstSurface = ""

    try {
        $p = [object[]]@([System.Drawing.Bitmap]$bmp, [byte[]]$RawPixels, [System.Drawing.Color]$Bg, [bool]$Light)
        $liquidPassMethod.Invoke($null, $p)

        # Inspect surface pixels to verify valid range and contrast
        $textLum = Get-Luminance $TextColor.R $TextColor.G $TextColor.B
        for ($y = 0; $y -lt $H; $y++) {
            for ($x = 0; $x -lt $W; $x++) {
                $px = $bmp.GetPixel($x, $y)
                $surfLum = Get-Luminance $px.R $px.G $px.B
                $cr = Get-ContrastRatio $textLum $surfLum
                if ($cr -lt $minContrastFound) {
                    $minContrastFound = $cr
                    $worstSurface = "RGB($($px.R),$($px.G),$($px.B))"
                }
            }
        }
    } catch {
        $threw = $true
        $exMsg = $_.Exception.ToString()
    }

    $bmp.Dispose()
    $pass = (-not $threw -and $minContrastFound -ge $MinRequiredContrast)
    $details = if ($threw) { "Exception: $exMsg" } else { "Worst Surface: $worstSurface | Min CR=$([Math]::Round($minContrastFound, 2)):1 (req >= $MinRequiredContrast:1)" }
    Report-Result $Name $pass $details
}

# Test standard 16x16 with pure white in dark mode
$rawWhite = New-Object byte[] (16 * 16 * 4)
for ($i = 0; $i -lt $rawWhite.Length; $i++) { $rawWhite[$i] = 255 }
Test-LiquidExecution "LiquidPass 16x16 White Backdrop (Dark Mode)" 16 16 $rawWhite $darkBg $false $darkText 4.5

# Test standard 16x16 with pure black in light mode
$rawBlack = New-Object byte[] (16 * 16 * 4)
for ($i = 0; $i -lt $rawBlack.Length; $i++) { $rawBlack[$i] = 0 }
Test-LiquidExecution "LiquidPass 16x16 Black Backdrop (Light Mode)" 16 16 $rawBlack $lightBg $true $lightText 4.5

# Test minimum 4x4 dimension
$rawMin = New-Object byte[] (4 * 4 * 4)
for ($i = 0; $i -lt $rawMin.Length; $i++) { $rawMin[$i] = 128 }
Test-LiquidExecution "LiquidPass 4x4 Minimum Dimension" 4 4 $rawMin $darkBg $false $darkText 4.5

# Test odd dimensions: 9x7
$rawOdd = New-Object byte[] (9 * 7 * 4)
for ($i = 0; $i -lt $rawOdd.Length; $i++) { $rawOdd[$i] = 200 }
Test-LiquidExecution "LiquidPass 9x7 Odd Dimensions" 9 7 $rawOdd $darkBg $false $darkText 4.5

# Test HDR gradient
$rawGrad = New-Object byte[] (32 * 16 * 4)
for ($y = 0; $y -lt 16; $y++) {
    for ($x = 0; $x -lt 32; $x++) {
        $idx = ($y * 32 + $x) * 4
        $val = [byte]([Math]::Min(255, $x * 8))
        $rawGrad[$idx] = $val
        $rawGrad[$idx + 1] = $val
        $rawGrad[$idx + 2] = $val
        $rawGrad[$idx + 3] = 255
    }
}
Test-LiquidExecution "LiquidPass 32x16 Gradient Backdrop" 32 16 $rawGrad $darkBg $false $darkText 4.5

# Test DockFrost.Liquid method
$dockFrostType = $assembly.GetType("Tepi.Island+DockFrost")
$dockLiquidMethod = $dockFrostType.GetMethod("Liquid", [System.Reflection.BindingFlags]'NonPublic,Static')

if ($dockLiquidMethod) {
    # Test Dock Liquid over white backdrop in dark mode (text=true)
    $dockRaw = New-Object byte[] (16 * 16 * 4)
    for ($i = 0; $i -lt $dockRaw.Length; $i++) { $dockRaw[$i] = 255 }
    $dockDst = New-Object byte[] (16 * 16 * 4)
    $dp = [object[]]@([byte[]]$dockRaw, [int](16*4), [int]16, [int]16, [System.Drawing.Color]$darkBg, [bool]$true, [byte[]]$dockDst)
    $dockLiquidMethod.Invoke($null, $dp)

    $dockMinCR = 999.0
    $dockWorstSurf = ""
    $textLum = Get-Luminance $darkText.R $darkText.G $darkText.B
    for ($i = 0; $i -lt $dockDst.Length; $i += 4) {
        $lum = Get-Luminance $dockDst[$i+2] $dockDst[$i+1] $dockDst[$i]
        $cr = Get-ContrastRatio $textLum $lum
        if ($cr -lt $dockMinCR) {
            $dockMinCR = $cr
            $dockWorstSurf = "RGB($($dockDst[$i+2]),$($dockDst[$i+1]),$($dockDst[$i]))"
        }
    }
    Report-Result "DockFrost.Liquid Text Pass over Pure White Backdrop" ($dockMinCR -ge 4.5) "Worst Surface: $dockWorstSurf | Min CR=$([Math]::Round($dockMinCR, 2)):1 (req >= 4.5:1)"
} else {
    Report-Result "DockFrost.Liquid Method Lookup" $false "Could not find Island+DockFrost.Liquid method"
}


# --- SECTION 5: FONT RESOLUTION ON WINDOWS 11 ---
Write-Host "`n--- 5. Testing Font Resolution on Windows 11 ---" -ForegroundColor Yellow

$fc = New-Object System.Drawing.Text.InstalledFontCollection
$installed = @{}
foreach ($f in $fc.Families) {
    $installed[$f.Name] = $true
}

Write-Host "Installed Segoe UI Variable fonts detected in system:" -ForegroundColor Gray
$segoeVarList = $installed.Keys | Where-Object { $_ -like "*Variable*" }
foreach ($sv in $segoeVarList) {
    Write-Host "   - '$sv' (Length=$($sv.Length))" -ForegroundColor Gray
}

$familiesField = $inkType.GetField("families", [System.Reflection.BindingFlags]'NonPublic,Static')
$resolvedFamilies = $familiesField.GetValue($null)

# Indices: FDisplay = 0, FText = 1, FSemi = 2, FSmall = 3, FMono = 4, FIcons = 5, FSmallSemi = 6
$displayResolved = $resolvedFamilies[0]
$smallSemiResolved = $resolvedFamilies[6]

Write-Host "`nResolved Ink font family slots:" -ForegroundColor Gray
Write-Host "   FDisplay [0]   : '$displayResolved' (Length=$($displayResolved.Length))" -ForegroundColor Cyan
Write-Host "   FSmallSemi [6] : '$smallSemiResolved' (Length=$($smallSemiResolved.Length))" -ForegroundColor Cyan

# Test Display Semibold
$isWin11 = [System.Environment]::OSVersion.Version.Build -ge 22000
if ($isWin11) {
    # On Windows 11, Segoe UI Variable must resolve to either canonical name or 31-char truncated name
    $validDisplay = ($displayResolved -eq "Segoe UI Variable Display Semibold" -or $displayResolved -eq "Segoe UI Variable Display Semib")
    Report-Result "Win11 Display Semibold resolves to Segoe UI Variable Display" $validDisplay "Resolved: '$displayResolved'"

    $validSmallSemi = ($smallSemiResolved -eq "Segoe UI Variable Small Semibold" -or $smallSemiResolved -eq "Segoe UI Variable Small Semibol")
    Report-Result "Win11 Small Semibold resolves to Segoe UI Variable Small" $validSmallSemi "Resolved: '$smallSemiResolved'"

    # Verify GDI+ Font instantiation does not throw
    $fontDisplay = $null
    $fontDisplayThrew = $false
    try {
        $fontDisplay = New-Object System.Drawing.Font($displayResolved, 24, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    } catch {
        $fontDisplayThrew = $true
    }
    Report-Result "GDI+ Font instantiation for Display ('$displayResolved')" (-not $fontDisplayThrew -and $fontDisplay -ne $null) "Font size: $($fontDisplay.Size)"
    if ($fontDisplay) { $fontDisplay.Dispose() }

    # Check Ink.Hero and Ink.Title1 properties
    $heroFont = $inkType.GetProperty("Hero", [System.Reflection.BindingFlags]'Public,Static').GetValue($null)
    $title1Font = $inkType.GetProperty("Title1", [System.Reflection.BindingFlags]'Public,Static').GetValue($null)
    $captionFont = $inkType.GetProperty("Caption", [System.Reflection.BindingFlags]'Public,Static').GetValue($null)

    Report-Result "Ink.Hero Font instance valid" ($heroFont -ne $null -and $heroFont.Size -eq 40) "Size: $($heroFont.Size) Family: $($heroFont.FontFamily.Name)"
    Report-Result "Ink.Title1 Font instance valid" ($title1Font -ne $null -and $title1Font.Size -eq 22) "Size: $($title1Font.Size) Family: $($title1Font.FontFamily.Name)"
    Report-Result "Ink.Caption Font instance valid" ($captionFont -ne $null -and $captionFont.Size -eq 11) "Size: $($captionFont.Size) Family: $($captionFont.FontFamily.Name)"
} else {
    Write-Host " [INFO] Running on Windows 10 (Build $([System.Environment]::OSVersion.Version.Build)); verifying clean fallback to Segoe UI" -ForegroundColor Gray
    Report-Result "Win10 Display fallback to Segoe UI" ($displayResolved -like "Segoe UI*") "Resolved: $displayResolved"
}

# --- SUMMARY ---
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY: $passCount PASSED, $failCount FAILED" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan

exit $failCount
