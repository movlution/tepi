Add-Type -AssemblyName System.Drawing
$asm = [System.Reflection.Assembly]::LoadFrom((Resolve-Path "D:\PROJECT\Other\tepi\Tepi.exe"))
$islandType = $asm.GetType("Tepi.Island")

# Check ToSrgb
$toSrgb = $islandType.GetMethod("ToSrgb", [System.Reflection.BindingFlags]"Public,Static")
$linearField = $islandType.GetField("Linear", [System.Reflection.BindingFlags]"NonPublic,Static")
$linear = $linearField.GetValue($null)
$contrast = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]"Public,Static")

Write-Host "=== TEST 4: ToSrgb & Linear LUT Roundtrip ==="
$mismatches = 0
for ($b = 0; $b -lt 256; $b++) {
    $lin = $linear[$b]
    $back = [int]$toSrgb.Invoke($null, @($lin))
    if ([math]::Abs($back - $b) -gt 1) {
        $mismatches++
        Write-Host "Mismatch at ${b}: linear=$lin, back=$back"
    }
}
Write-Host "Linear -> ToSrgb roundtrip mismatches (>1 count): $mismatches"

# Check ComputeFrostTint via reflection
$computeFrostTint = $islandType.GetMethod("ComputeFrostTint", [System.Reflection.BindingFlags]"NonPublic,Static")

Write-Host "`n=== TEST 5: ComputeFrostTint ==="
# Synthetic white wallpaper (255, 255, 255)
[byte[]]$whiteWall = New-Object byte[] 400
for ($i = 0; $i -lt 400; $i += 4) {
    $whiteWall[$i] = 255     # B
    $whiteWall[$i+1] = 255   # G
    $whiteWall[$i+2] = 255   # R
    $whiteWall[$i+3] = 255   # A
}
$tintDarkOnWhite = [float]$computeFrostTint.Invoke($null, [object[]]@($whiteWall, 400, [System.Drawing.Color]::FromArgb(255, 0, 0, 0), $false))
Write-Host "Frost Tint on White Wall (Dark Mode): $tintDarkOnWhite (Expected: ~0.67)"

# Surface on white wallpaper with tintDarkOnWhite
$surfByteDark = [int][math]::Round(255 * (1 - $tintDarkOnWhite))
$surfColDark = [System.Drawing.Color]::FromArgb(255, $surfByteDark, $surfByteDark, $surfByteDark)
$textDark = [System.Drawing.Color]::FromArgb(255, 245, 245, 247)
$crFrostDark = [float]$contrast.Invoke($null, @($textDark, $surfColDark))
Write-Host "Surface Byte: $surfByteDark, Text Contrast: $([math]::Round($crFrostDark, 2)):1 (Required >= 4.5:1 -> $( $crFrostDark -ge 4.5 ))"

# Synthetic black wallpaper (0, 0, 0)
[byte[]]$blackWall = New-Object byte[] 400
for ($i = 0; $i -lt 400; $i += 4) {
    $blackWall[$i] = 0
    $blackWall[$i+1] = 0
    $blackWall[$i+2] = 0
    $blackWall[$i+3] = 255
}
$tintLightOnBlack = [float]$computeFrostTint.Invoke($null, [object[]]@($blackWall, 400, [System.Drawing.Color]::FromArgb(255, 245, 245, 245), $true))
Write-Host "Frost Tint on Black Wall (Light Mode): $tintLightOnBlack (Expected: ~0.84)"

# Surface on black wallpaper with tintLightOnBlack
$surfByteLight = [int][math]::Round(245 * $tintLightOnBlack)
$surfColLight = [System.Drawing.Color]::FromArgb(255, $surfByteLight, $surfByteLight, $surfByteLight)
$textLight = [System.Drawing.Color]::FromArgb(255, 12, 12, 14)
$crFrostLight = [float]$contrast.Invoke($null, @($surfColLight, $textLight))
Write-Host "Surface Byte: $surfByteLight, Text Contrast: $([math]::Round($crFrostLight, 2)):1 (Required >= 4.5:1 -> $( $crFrostLight -ge 4.5 ))"

# Dark wallpaper in dark mode -> should stay at BaseTint (0.42)
$tintDarkOnBlack = [float]$computeFrostTint.Invoke($null, [object[]]@($blackWall, 400, [System.Drawing.Color]::FromArgb(255, 0, 0, 0), $false))
Write-Host "Frost Tint on Black Wall (Dark Mode): $tintDarkOnBlack (Expected: 0.42) -> $( [math]::Abs($tintDarkOnBlack - 0.42) -lt 0.01 )"

# White wallpaper in light mode -> should stay at BaseTint (0.42)
$tintLightOnWhite = [float]$computeFrostTint.Invoke($null, [object[]]@($whiteWall, 400, [System.Drawing.Color]::FromArgb(255, 245, 245, 245), $true))
Write-Host "Frost Tint on White Wall (Light Mode): $tintLightOnWhite (Expected: 0.42) -> $( [math]::Abs($tintLightOnWhite - 0.42) -lt 0.01 )"
