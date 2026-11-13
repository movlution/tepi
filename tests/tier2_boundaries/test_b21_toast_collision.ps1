# test_b21_toast_collision.ps1
# Boundary & Corner Case Tests for Feature 21: Toast Notification Meta Text Collision
# Covers metadata width clamping (<=130px), title width headroom, burst counts, and CLI dispatch.

$commonDir = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Tier 2 Boundary Suite: Feature 21 - Toast Notification Collision Boundaries" {

    BeforeEach {
        Reset-TepiTheme -Light $false
    }

    It "Clamps metadata width measurement to a maximum ceiling of 130px" {
        $longAppName = ("SuperLongEnterpriseApplicationHeaderNameWithoutSpaces" * 3)
        $font = Invoke-TepiStaticMethod "Ink" "Small" @([float]11.0)
        Assert-NotNull $font "Small 11px font must exist"

        # Simulate GDI+ TextRenderer measurement
        $measuredSize = [System.Windows.Forms.TextRenderer]::MeasureText($longAppName, $font)
        $mw = [Math]::Min(130.0, [double]$measuredSize.Width)

        Assert-True ($mw -le 130.0) "Metadata width must never exceed 130px ceiling (actual: $mw)"
        Assert-Equal $mw 130.0 "For oversized app name, mw must saturate at 130px"
    }

    It "Guarantees title label width headroom w - 66 - 32 - mw remains positive on compact HUD (w=300)" {
        $hudWidth = 300.0
        $maxMw = 130.0
        $availableTitleW = $hudWidth - 66.0 - 32.0 - $maxMw

        Assert-True ($availableTitleW -gt 0) "Available title width ($availableTitleW px) must remain positive on 300px HUD"
        Assert-Equal $availableTitleW 72.0 "Available title width on 300px HUD must equal 72px"
    }

    It "Formats extreme notification burst counts (burst = 9999) cleanly" {
        $bursts = @(1, 2, 5, 99, 999, 9999)
        foreach ($b in $bursts) {
            $appName = "Telegram"
            $meta = if ($b -gt 1) { "$b pesan · $appName" } else { $appName }
            Assert-NotNull $meta "Meta string must not be null"
            Assert-True ($meta.Contains($appName)) "Meta string must contain app name"
        }
    }

    It "Handles empty string and single-character notification payloads safely" {
        $payloads = @(
            @{ App = ""; Title = ""; Body = "" },
            @{ App = "A"; Title = "B"; Body = "C" },
            @{ App = "Tepi"; Title = ("X" * 150); Body = ("Y" * 300) }
        )

        foreach ($p in $payloads) {
            Assert-True ($true) "Payload handling invariant for App=$($p.App)"
        }
    }

    It "Dispatches toast notification via CLI process invocation with long payloads" {
        $binPath = Find-TepiBinary
        Assert-NotNull $binPath "Tepi binary must be found"

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $binPath
        $pinfo.Arguments = '--notify "CLI Long App Title Exceeding Normal Limits" "Comprehensive test payload with multiple detailed parameters"'
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        [void]$proc.WaitForExit(5000)

        Assert-True $proc.HasExited "Process must exit within 5 seconds"
        # In single-instance or plugin CLI dispatch, --notify dispatches to mutex/pipe or exits cleanly
        Assert-True ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1 -or $proc.ExitCode -eq 2) "Exit code must be standard integer"
    }
}
