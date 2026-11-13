# test_f02_accents.ps1
# Feature 2: Light Mode Accent Preset Calibration
# Verifies all 7 preset accents in light mode achieve >= 3.5:1 non-text contrast against #F5F5F5.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 2: Light Mode Accent Preset Calibration" {
    $paperBg = [System.Drawing.ColorTranslator]::FromHtml("#F5F5F5")

    BeforeEach {
        Reset-TepiTheme -Light $true
    }

    It "Verifies Biru (#1668E8) preset in light mode achieves >= 3.5:1 contrast against #F5F5F5" {
        $biru = [System.Drawing.ColorTranslator]::FromHtml("#1668E8")
        $ratio = Assert-Contrast $biru $paperBg 3.5 "Biru preset contrast"
        Assert-True ($ratio -ge 3.5) "Biru contrast must be >= 3.5:1 (got: ${ratio}:1)"
    }

    It "Verifies Hijau (#107C41) preset in light mode achieves >= 3.5:1 contrast against #F5F5F5" {
        $hijau = [System.Drawing.ColorTranslator]::FromHtml("#107C41")
        $ratio = Assert-Contrast $hijau $paperBg 3.5 "Hijau preset contrast"
        Assert-True ($ratio -ge 3.5) "Hijau contrast must be >= 3.5:1 (got: ${ratio}:1)"
    }

    It "Verifies Kuning (#855E00) preset in light mode achieves >= 3.5:1 contrast against #F5F5F5" {
        $kuning = [System.Drawing.ColorTranslator]::FromHtml("#855E00")
        $ratio = Assert-Contrast $kuning $paperBg 3.5 "Kuning preset contrast"
        Assert-True ($ratio -ge 3.5) "Kuning contrast must be >= 3.5:1 (got: ${ratio}:1)"
    }

    It "Verifies Oranye (#A84B00) preset in light mode achieves >= 3.5:1 contrast against #F5F5F5" {
        $oranye = [System.Drawing.ColorTranslator]::FromHtml("#A84B00")
        $ratio = Assert-Contrast $oranye $paperBg 3.5 "Oranye preset contrast"
        Assert-True ($ratio -ge 3.5) "Oranye contrast must be >= 3.5:1 (got: ${ratio}:1)"
    }

    It "Verifies Merah muda (#C2185B), Ungu (#6C3CE0), and Navy (#4D5F9E) achieve >= 3.5:1 contrast" {
        $merahMuda = [System.Drawing.ColorTranslator]::FromHtml("#C2185B")
        $ungu = [System.Drawing.ColorTranslator]::FromHtml("#6C3CE0")
        $navy = [System.Drawing.ColorTranslator]::FromHtml("#4D5F9E")

        $r1 = Assert-Contrast $merahMuda $paperBg 3.5 "Merah muda preset"
        $r2 = Assert-Contrast $ungu $paperBg 3.5 "Ungu preset"
        $r3 = Assert-Contrast $navy $paperBg 3.5 "Navy preset"

        Assert-True ($r1 -ge 3.5 -and $r2 -ge 3.5 -and $r3 -ge 3.5) "All three accents must be >= 3.5:1"
    }

    It "Verifies all 7 light mode accents registered in AccentsLight maintain >= 3.5:1 contrast" {
        $table = Get-TepiStaticField "Island" "AccentsLight"
        Assert-NotNull $table "AccentsLight field must exist on Island"

        $checkedCount = 0
        foreach ($row in $table) {
            $name = $row[0]
            $hex = $row[1]
            if ($hex.StartsWith("#")) {
                $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
                $ratio = Assert-Contrast $c $paperBg 3.5 "Accent [$name] ($hex)"
                Assert-True ($ratio -ge 3.5) "Accent [$name] contrast must be >= 3.5:1"
                $checkedCount++
            }
        }

        Assert-Equal $checkedCount 7 "Must verify all 7 color presets in AccentsLight"
    }
}
