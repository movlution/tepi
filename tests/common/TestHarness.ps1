# TestHarness.ps1
# Pure PowerShell & .NET 4.8 E2E Test Assertion and Execution Framework
# Zero external dependencies.

Add-Type -AssemblyName System.Drawing

# Global test context state
if ($null -eq $global:TestContext) {
    $global:TestContext = @{
        CurrentSuite = ""
        SuiteStack   = New-Object System.Collections.ArrayList
        Passed       = 0
        Failed       = 0
        Total        = 0
        Results      = New-Object System.Collections.ArrayList
        Stopwatch    = New-Object System.Diagnostics.Stopwatch
        BeforeHooks  = New-Object System.Collections.ArrayList
        AfterHooks   = New-Object System.Collections.ArrayList
        Verbose      = $false
    }
}

function Reset-TestHarness {
    $global:TestContext = @{
        CurrentSuite = ""
        SuiteStack   = New-Object System.Collections.ArrayList
        Passed       = 0
        Failed       = 0
        Total        = 0
        Results      = New-Object System.Collections.ArrayList
        Stopwatch    = New-Object System.Diagnostics.Stopwatch
        BeforeHooks  = New-Object System.Collections.ArrayList
        AfterHooks   = New-Object System.Collections.ArrayList
        Verbose      = $false
    }
}

function Set-TestVerbose {
    param([bool]$Enable = $true)
    $global:TestContext.Verbose = $Enable
}

function BeforeEach {
    param([scriptblock]$Hook)
    [void]$global:TestContext.BeforeHooks.Add($Hook)
}

function AfterEach {
    param([scriptblock]$Hook)
    [void]$global:TestContext.AfterHooks.Add($Hook)
}

function Describe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )

    $parentSuite = $global:TestContext.CurrentSuite
    [void]$global:TestContext.SuiteStack.Add($Name)
    $global:TestContext.CurrentSuite = ($global:TestContext.SuiteStack -join " > ")

    $indent = "  " * ($global:TestContext.SuiteStack.Count - 1)
    Write-Host "$indent`n[SUITE] $Name" -ForegroundColor Cyan

    try {
        & $Body
    }
    finally {
        if ($global:TestContext.SuiteStack.Count -gt 0) {
            $global:TestContext.SuiteStack.RemoveAt($global:TestContext.SuiteStack.Count - 1)
        }
        $global:TestContext.CurrentSuite = $parentSuite
    }
}

function Context {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )
    Describe $Name $Body
}

function It {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Test
    )

    $global:TestContext.Total++
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $indent = "  " * [Math]::Max(1, $global:TestContext.SuiteStack.Count)
    $pass = $false
    $err = $null

    try {
        # Run before-each hooks
        foreach ($hook in $global:TestContext.BeforeHooks) {
            & $hook
        }

        # Run test block
        & $Test
        $pass = $true
    }
    catch {
        $pass = $false
        $err = $_
    }
    finally {
        # Run after-each hooks
        foreach ($hook in $global:TestContext.AfterHooks) {
            try { & $hook } catch { }
        }
        $sw.Stop()
    }

    $durationMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
    $result = [PSCustomObject]@{
        Suite      = $global:TestContext.CurrentSuite
        Name       = $Name
        Status     = if ($pass) { "PASS" } else { "FAIL" }
        DurationMs = $durationMs
        Error      = if ($err) { $err.Exception.Message } else { $null }
    }
    [void]$global:TestContext.Results.Add($result)

    if ($pass) {
        $global:TestContext.Passed++
        Write-Host "$indent  [PASS] $Name (${durationMs}ms)" -ForegroundColor Green
    }
    else {
        $global:TestContext.Failed++
        Write-Host "$indent  [FAIL] $Name (${durationMs}ms)" -ForegroundColor Red
        Write-Host "$indent         Error: $($err.Exception.Message)" -ForegroundColor DarkRed
        if ($global:TestContext.Verbose -and $err.ScriptStackTrace) {
            Write-Host "$indent         Trace: $($err.ScriptStackTrace)" -ForegroundColor DarkGray
        }
    }
}

# ---------------- Assertions ----------------

function Assert-True {
    param(
        $Actual,
        [string]$Message = ""
    )
    if (-not $Actual) {
        $msg = "Assert-True failed. Expected `$true, but got: [$Actual]."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

function Assert-False {
    param(
        $Actual,
        [string]$Message = ""
    )
    if ($Actual) {
        $msg = "Assert-False failed. Expected `$false, but got: [$Actual]."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message = ""
    )

    $match = $false
    if ($null -eq $Actual -and $null -eq $Expected) {
        $match = $true
    }
    elseif ($null -eq $Actual -or $null -eq $Expected) {
        $match = $false
    }
    elseif ($Actual -is [System.Drawing.Color] -and $Expected -is [System.Drawing.Color]) {
        $match = ($Actual.ToArgb() -eq $Expected.ToArgb())
    }
    elseif ($Actual -is [double] -or $Actual -is [float] -or $Expected -is [double] -or $Expected -is [float]) {
        $actNum = [double]$Actual
        $expNum = [double]$Expected
        $match = ([Math]::Abs($actNum - $expNum) -lt 0.0001)
    }
    else {
        $match = ($Actual -eq $Expected)
    }

    if (-not $match) {
        $actStr = if ($null -eq $Actual) { "<null>" } else { $Actual.ToString() }
        $expStr = if ($null -eq $Expected) { "<null>" } else { $Expected.ToString() }
        $msg = "Assert-Equal failed. Expected: [$expStr], but got: [$actStr]."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

function Assert-NotEqual {
    param(
        $Actual,
        $Expected,
        [string]$Message = ""
    )

    $match = $false
    if ($null -eq $Actual -and $null -eq $Expected) {
        $match = $true
    }
    elseif ($null -eq $Actual -or $null -eq $Expected) {
        $match = $false
    }
    elseif ($Actual -is [System.Drawing.Color] -and $Expected -is [System.Drawing.Color]) {
        $match = ($Actual.ToArgb() -eq $Expected.ToArgb())
    }
    else {
        $match = ($Actual -eq $Expected)
    }

    if ($match) {
        $msg = "Assert-NotEqual failed. Value should not equal: [$Actual]."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

function Assert-NotNull {
    param(
        $Actual,
        [string]$Message = ""
    )
    if ($null -eq $Actual) {
        $msg = "Assert-NotNull failed. Value is `$null."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

function Assert-Null {
    param(
        $Actual,
        [string]$Message = ""
    )
    if ($null -ne $Actual) {
        $msg = "Assert-Null failed. Expected `$null, but got: [$Actual]."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

function Assert-InRange {
    param(
        [double]$Actual,
        [double]$Min,
        [double]$Max,
        [string]$Message = ""
    )
    if ($Actual -lt $Min -or $Actual -gt $Max) {
        $msg = "Assert-InRange failed. Value [$Actual] is outside expected range [$Min, $Max]."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }
}

# WCAG 2.1 relative luminance and contrast assertion
function Get-WcagLuminance {
    param([System.Drawing.Color]$Color)

    $calcLinear = {
        param([byte]$channel)
        $c = $channel / 255.0
        if ($c -le 0.03928) {
            return $c / 12.92
        } else {
            return [Math]::Pow(($c + 0.055) / 1.055, 2.4)
        }
    }

    $rLin = & $calcLinear $Color.R
    $gLin = & $calcLinear $Color.G
    $bLin = & $calcLinear $Color.B

    return (0.2126 * $rLin + 0.7152 * $gLin + 0.0722 * $bLin)
}

function Get-WcagContrastRatio {
    param(
        $ColorA,
        $ColorB
    )

    $toColor = {
        param($c)
        if ($c -is [System.Drawing.Color]) { return $c }
        if ($c -is [string]) {
            if ($c.StartsWith("#")) {
                return [System.Drawing.ColorTranslator]::FromHtml($c)
            }
            return [System.Drawing.Color]::FromName($c)
        }
        throw "Cannot convert input of type [$($c.GetType().FullName)] to System.Drawing.Color."
    }

    $ca = & $toColor $ColorA
    $cb = & $toColor $ColorB

    $l1 = Get-WcagLuminance $ca
    $l2 = Get-WcagLuminance $cb

    $max = [Math]::Max($l1, $l2)
    $min = [Math]::Min($l1, $l2)

    return [Math]::Round(($max + 0.05) / ($min + 0.05), 2)
}

function Assert-Contrast {
    param(
        $ColorA,
        $ColorB,
        [double]$MinRatio,
        [string]$Message = ""
    )

    $ratio = Get-WcagContrastRatio $ColorA $ColorB
    if ($ratio -lt $MinRatio) {
        $toHex = {
            param($c)
            if ($c -is [System.Drawing.Color]) {
                return "#" + $c.R.ToString("X2") + $c.G.ToString("X2") + $c.B.ToString("X2")
            }
            return $c.ToString()
        }
        $hexA = & $toHex $ColorA
        $hexB = & $toHex $ColorB
        $msg = "Assert-Contrast failed. Contrast between [$hexA] and [$hexB] is ${ratio}:1, which is below the minimum required ${MinRatio}:1."
        if ($Message) { $msg += " Context: $Message" }
        throw $msg
    }

    return $ratio
}

# ---------------- Summary & Reporting ----------------

function Get-TestSummary {
    $duration = 0.0
    foreach ($r in $global:TestContext.Results) {
        $duration += $r.DurationMs
    }

    return [PSCustomObject]@{
        Total      = $global:TestContext.Total
        Passed     = $global:TestContext.Passed
        Failed     = $global:TestContext.Failed
        DurationMs = [Math]::Round($duration, 2)
        Results    = $global:TestContext.Results
        Success    = ($global:TestContext.Failed -eq 0 -and $global:TestContext.Total -gt 0)
    }
}

function Format-TestReport {
    param($Summary = (Get-TestSummary))

    Write-Host "`n========================================================" -ForegroundColor Gray
    Write-Host "                TEST EXECUTION SUMMARY                  " -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Gray
    Write-Host "  Total Tests Run : $($Summary.Total)"
    Write-Host "  Passed          : $($Summary.Passed)" -ForegroundColor Green
    Write-Host "  Failed          : $($Summary.Failed)" -ForegroundColor $(if ($Summary.Failed -gt 0) { "Red" } else { "Green" })
    Write-Host "  Duration        : $($Summary.DurationMs) ms"
    Write-Host "  Status          : $(if ($Summary.Success) { 'ALL TESTS PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($Summary.Success) { 'Green' } else { 'Red' })
    Write-Host "========================================================`n" -ForegroundColor Gray
}

# Export functions if loaded as module
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function Describe, Context, It, BeforeEach, AfterEach,
                                 Assert-True, Assert-False, Assert-Equal, Assert-NotEqual,
                                 Assert-NotNull, Assert-Null, Assert-InRange, Assert-Contrast,
                                 Get-WcagLuminance, Get-WcagContrastRatio,
                                 Get-TestSummary, Format-TestReport, Reset-TestHarness, Set-TestVerbose -ErrorAction SilentlyContinue
}
