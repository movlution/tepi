Add-Type -AssemblyName System.Drawing
$asm = [System.Reflection.Assembly]::LoadFrom((Resolve-Path "D:\PROJECT\Other\tepi\Tepi.exe"))

# Find internal classes via reflection
$inkType = $asm.GetType("Tepi.Ink")
$islandType = $asm.GetType("Tepi.Island")

Write-Host "=== TEST 1: Fonts ==="
$inkType.GetMethod("Init", [System.Reflection.BindingFlags]"Public,Static").Invoke($null, @())
$menuFamily = $inkType.GetProperty("MenuFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$iconFamily = $inkType.GetProperty("IconFamily", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$hero = $inkType.GetProperty("Hero", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$title1 = $inkType.GetProperty("Title1", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$headline = $inkType.GetProperty("Headline", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
$caption = $inkType.GetProperty("Caption", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)

Write-Host "MenuFamily: $menuFamily"
Write-Host "IconFamily: $iconFamily"
Write-Host "Hero: $($hero.FontFamily.Name)"
Write-Host "Title1: $($title1.FontFamily.Name)"
Write-Host "Headline: $($headline.FontFamily.Name)"
Write-Host "Caption: $($caption.FontFamily.Name)"

Write-Host "`n=== TEST 2: Presets & Light Contrast Calibration ==="
$setAccent = $inkType.GetMethod("SetAccent", [System.Reflection.BindingFlags]"Public,Static")
$apply = $inkType.GetMethod("Apply", [System.Reflection.BindingFlags]"Public,Static")
$contrast = $islandType.GetMethod("Contrast", [System.Reflection.BindingFlags]"Public,Static")
$hexOf = $islandType.GetMethod("HexOf", [System.Reflection.BindingFlags]"Public,Static")

$presets = @(
    @{ Name = "Biru"; Dark = "#4C8DFF"; ExpectedLight = "#1668E8" },
    @{ Name = "Hijau"; Dark = "#3DD68C"; ExpectedLight = "#107C41" },
    @{ Name = "Kuning"; Dark = "#FFD24A"; ExpectedLight = "#855E00" },
    @{ Name = "Oranye"; Dark = "#FF9F43"; ExpectedLight = "#A84B00" },
    @{ Name = "Merah muda"; Dark = "#FF6B9A"; ExpectedLight = "#C2185B" },
    @{ Name = "Ungu"; Dark = "#A78BFA"; ExpectedLight = "#6C3CE0" },
    @{ Name = "Navy"; Dark = "#7F8DC6"; ExpectedLight = "#4D5F9E" }
)

foreach ($p in $presets) {
    $setAccent.Invoke($null, @($p.Dark))
    $apply.Invoke($null, @($true))
    $baseTone = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
    $actLight = $hexOf.Invoke($null, @($baseTone.Accent))
    $crLight = $contrast.Invoke($null, @($baseTone.Accent, $baseTone.Bg))
    $onAccentCr = $contrast.Invoke($null, @($baseTone.OnAccent, $baseTone.Accent))
    
    $apply.Invoke($null, @($false))
    $baseToneDark = $inkType.GetField("Base", [System.Reflection.BindingFlags]"Public,Static").GetValue($null)
    $actDark = $hexOf.Invoke($null, @($baseToneDark.Accent))
    $crDark = $contrast.Invoke($null, @($baseToneDark.Accent, $baseToneDark.Bg))

    $passLight = ($actLight -eq $p.ExpectedLight) -and ($crLight -ge 4.5) -and ($onAccentCr -ge 4.5)
    $passDark = ($actDark -eq $p.Dark) -and ($crDark -ge 4.5)
    Write-Host "$($p.Name): Light=$actLight (CR=$([math]::Round($crLight, 2)):1, OnAccent=$([math]::Round($onAccentCr, 2)):1) Dark=$actDark (CR=$([math]::Round($crDark, 2)):1) -> Pass=$( $passLight -and $passDark )"
}

Write-Host "`n=== TEST 3: DerivePalette Contrast Floors ==="
$derivePalette = $islandType.GetMethod("DerivePalette", [System.Reflection.BindingFlags]"Public,Static")

$testCases = @(
    @{ Name = "Low Contrast Dark"; Bg = [System.Drawing.Color]::FromArgb(255, 34, 34, 34); Text = [System.Drawing.Color]::FromArgb(255, 51, 51, 51); Accent = [System.Drawing.Color]::FromArgb(255, 68, 68, 68) },
    @{ Name = "White on White"; Bg = [System.Drawing.Color]::FromArgb(255, 255, 255, 255); Text = [System.Drawing.Color]::FromArgb(255, 245, 239, 230); Accent = [System.Drawing.Color]::FromArgb(255, 255, 210, 74) },
    @{ Name = "Identical Gray"; Bg = [System.Drawing.Color]::FromArgb(255, 128, 128, 128); Text = [System.Drawing.Color]::FromArgb(255, 128, 128, 128); Accent = [System.Drawing.Color]::FromArgb(255, 128, 128, 128) }
)

foreach ($tc in $testCases) {
    $pal = $derivePalette.Invoke($null, @($tc.Bg, $tc.Text, $tc.Accent))
    $bgCol = [System.Drawing.ColorTranslator]::FromHtml($pal["bg"])
    $textCol = [System.Drawing.ColorTranslator]::FromHtml($pal["text"])
    $subCol = [System.Drawing.ColorTranslator]::FromHtml($pal["sub"])
    $faintCol = [System.Drawing.ColorTranslator]::FromHtml($pal["faint"])
    $accCol = [System.Drawing.ColorTranslator]::FromHtml($pal["accent"])
    $onAccCol = [System.Drawing.ColorTranslator]::FromHtml($pal["onAccent"])

    $crText = $contrast.Invoke($null, @($textCol, $bgCol))
    $crSub = $contrast.Invoke($null, @($subCol, $bgCol))
    $crFaint = $contrast.Invoke($null, @($faintCol, $bgCol))
    $crAcc = $contrast.Invoke($null, @($accCol, $bgCol))
    $crOnAcc = $contrast.Invoke($null, @($onAccCol, $accCol))

    Write-Host "$($tc.Name):"
    Write-Host "  Text: $($pal['text']) (CR=$([math]::Round($crText, 2)):1) >= 4.5 -> $( $crText -ge 4.5 )"
    Write-Host "  Sub: $($pal['sub']) (CR=$([math]::Round($crSub, 2)):1) >= 4.5 -> $( $crSub -ge 4.5 )"
    Write-Host "  Faint: $($pal['faint']) (CR=$([math]::Round($crFaint, 2)):1) >= 3.0 -> $( $crFaint -ge 3.0 )"
    Write-Host "  Accent: $($pal['accent']) (CR=$([math]::Round($crAcc, 2)):1) >= 3.5 -> $( $crAcc -ge 3.5 )"
    Write-Host "  OnAccent: $($pal['onAccent']) (CR=$([math]::Round($crOnAcc, 2)):1) >= 4.5 -> $( $crOnAcc -ge 4.5 )"
}
