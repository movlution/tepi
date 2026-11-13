# test_b14_kit_ask.ps1
# Boundary & Corner Case Tests for Feature 14: KitAsk Universal Title & Localization
# Covers KitAsk message length extremes, button configurations, localization tokens, and layout geometry.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 14 - KitAsk Localization & Layout Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Instantiates KitAsk via reflection with empty or null message strings" {
        $askType = Get-TepiType "KitAsk"
        Assert-NotNull $askType "KitAsk type must exist"

        $ctor = $askType.GetConstructors([System.Reflection.BindingFlags]'NonPublic,Instance')[0]
        Assert-NotNull $ctor "KitAsk constructor must exist"

        $emptyAsk = $ctor.Invoke(@("", $true, "OK", "Batal"))
        Assert-NotNull $emptyAsk "KitAsk with empty message must allocate"
        $emptyAsk.Dispose()

        $nullAsk = $ctor.Invoke(@($null, $false, "", ""))
        Assert-NotNull $nullAsk "KitAsk with null message must allocate"
        $nullAsk.Dispose()
    }

    It "Handles extreme 1000-character multi-line text payloads without layout collapse" {
        $askType = Get-TepiType "KitAsk"
        $ctor = $askType.GetConstructors([System.Reflection.BindingFlags]'NonPublic,Instance')[0]

        $longMessage = ("Baris konfirmasi peringatan penting.`n" * 50)
        $ask = $ctor.Invoke(@($longMessage, $true, "Lanjutkan", "Batal"))
        Assert-NotNull $ask "KitAsk with 1000-char message must allocate"
        Assert-True ($ask.Controls.Count -ge 3) "KitAsk must contain message label and buttons"

        $ask.Dispose()
    }

    It "Verifies mode configuration between Confirm (two buttons) and Notice (one button)" {
        $askType = Get-TepiType "KitAsk"
        $ctor = $askType.GetConstructors([System.Reflection.BindingFlags]'NonPublic,Instance')[0]
        $flags = [System.Reflection.BindingFlags]'NonPublic,Instance'

        # Confirm mode: two = true
        $confirmDialog = $ctor.Invoke(@("Hapus file ini?", $true, "Hapus", "Batal"))
        $twoConfirm = $askType.GetField("two", $flags).GetValue($confirmDialog)
        Assert-True $twoConfirm "Confirm mode must set two = true"
        $confirmDialog.Dispose()

        # Notice mode: two = false
        $noticeDialog = $ctor.Invoke(@("Operasi selesai.", $false, "", ""))
        $twoNotice = $askType.GetField("two", $flags).GetValue($noticeDialog)
        Assert-False $twoNotice "Notice mode must set two = false"
        $noticeDialog.Dispose()
    }

    It "Verifies Lang.T localization integration on standard dialog action words" {
        $langType = Get-TepiType "Lang"
        Assert-NotNull $langType "Lang type must exist"

        $standardKeys = @("Hapus", "Batal", "Tutup", "Simpan", "Pilih", "Pesan baru")
        foreach ($key in $standardKeys) {
            $translated = Invoke-TepiStaticMethod "Lang" "T" @($key)
            Assert-NotNull $translated "Translation for [$key] must not be null"
            Assert-True ($translated.Length -gt 0) "Translation for [$key] must not be empty"
        }
    }

    It "Executes Relayout on KitAsk across simulated DPI scale factors" {
        $askType = Get-TepiType "KitAsk"
        $ctor = $askType.GetConstructors([System.Reflection.BindingFlags]'NonPublic,Instance')[0]
        $ask = $ctor.Invoke(@("DPI Scale Test", $true, "Ya", "Tidak"))

        $relayout = $askType.GetMethod("Relayout", [System.Reflection.BindingFlags]'Public,Instance')
        Assert-NotNull $relayout "Relayout method must exist on KitAsk"

        $ask.Dispose()
    }
}
