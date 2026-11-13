# TepiLoader.ps1
# Assembly Reflection, Architecture Validation, and Offscreen Control Helpers
# Zero external dependencies.

# Ensure System assemblies are loaded
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# 1. Architecture Validation
function Assert-TepiArchitecture {
    if ([IntPtr]::Size -ne 8) {
        throw "Tepi E2E Test Runner requires 64-bit PowerShell ([IntPtr]::Size == 8). You are currently running in a 32-bit (x86) process. Please launch 64-bit PowerShell (e.g. C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe)."
    }
}

# Run architecture assertion immediately upon dot-sourcing
Assert-TepiArchitecture

# 2. Assembly Loading & Caching
if ($null -eq $global:TepiAssembly) {
    $global:TepiAssembly = $null
    $global:TepiAssemblyPath = ""
}

function Find-TepiBinary {
    param([string]$ExplicitPath = "")

    if ($ExplicitPath -and (Test-Path $ExplicitPath)) {
        return (Resolve-Path $ExplicitPath).Path
    }

    $candidateLocations = @(
        (Join-Path $PSScriptRoot "..\..\Tepi.exe"),
        (Join-Path (Get-Location) "Tepi.exe"),
        "d:\PROJECT\Other\tepi\Tepi.exe"
    )

    foreach ($loc in $candidateLocations) {
        if (Test-Path $loc) {
            return (Resolve-Path $loc).Path
        }
    }

    return $null
}

function Initialize-TepiLoader {
    param(
        [string]$Path = "",
        [switch]$ForceReload
    )

    if ($global:TepiAssembly -and (-not $ForceReload)) {
        return $global:TepiAssembly
    }

    $binPath = Find-TepiBinary $Path
    if (-not $binPath) {
        throw "Tepi.exe not found. Please run 'build.cmd' at the project root to compile Tepi.exe before running tests."
    }

    # Load assembly bytes or direct assembly via LoadFrom
    $global:TepiAssemblyPath = $binPath
    $global:TepiAssembly = [System.Reflection.Assembly]::LoadFrom($binPath)
    return $global:TepiAssembly
}

# Auto-initialize loader if Tepi.exe exists
try {
    [void](Initialize-TepiLoader)
} catch {
    # If binary doesn't exist yet, defer until explicit initialization or rebuild
}

# 3. Reflection Helpers

function Get-TepiType {
    param([Parameter(Mandatory = $true)][string]$TypeName)

    if (-not $global:TepiAssembly) {
        [void](Initialize-TepiLoader)
    }

    # Check exact name
    $t = $global:TepiAssembly.GetType($TypeName)
    if ($t) { return $t }

    # Check prefixed with Tepi.
    $t = $global:TepiAssembly.GetType("Tepi.$TypeName")
    if ($t) { return $t }

    # Check case-insensitive / partial match among all loaded types
    $all = $global:TepiAssembly.GetTypes()
    foreach ($candidate in $all) {
        if ($candidate.Name -ieq $TypeName -or $candidate.FullName -ieq $TypeName -or $candidate.FullName -ieq "Tepi.$TypeName") {
            return $candidate
        }
    }

    # Also search nested types (e.g. Island+GlassSheet)
    foreach ($candidate in $all) {
        if ($candidate.FullName -like "*+$TypeName") {
            return $candidate
        }
    }

    return $null
}

function Invoke-TepiStaticMethod {
    param(
        [Parameter(Mandatory = $true)][string]$TypeName,
        [Parameter(Mandatory = $true)][string]$MethodName,
        [object[]]$Parameters = @()
    )

    $t = Get-TepiType $TypeName
    if (-not $t) {
        throw "Invoke-TepiStaticMethod: Type [$TypeName] not found in Tepi assembly."
    }

    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static'
    
    # Try direct method resolution
    $m = $t.GetMethod($MethodName, $flags)
    if (-not $m) {
        # Try matching among all methods with same name and parameter count
        $methods = $t.GetMethods($flags) | Where-Object { $_.Name -eq $MethodName }
        if ($methods) {
            foreach ($candidate in $methods) {
                if ($candidate.GetParameters().Length -eq $Parameters.Length) {
                    $m = $candidate
                    break
                }
            }
        }
    }

    if (-not $m) {
        throw "Invoke-TepiStaticMethod: Method [$MethodName] with $($Parameters.Length) parameters not found on type [$($t.FullName)]."
    }

    return $m.Invoke($null, $Parameters)
}

function Get-TepiStaticField {
    param(
        [Parameter(Mandatory = $true)][string]$TypeName,
        [Parameter(Mandatory = $true)][string]$FieldName
    )

    $t = Get-TepiType $TypeName
    if (-not $t) {
        throw "Get-TepiStaticField: Type [$TypeName] not found in Tepi assembly."
    }

    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static'
    $f = $t.GetField($FieldName, $flags)
    if (-not $f) {
        throw "Get-TepiStaticField: Field [$FieldName] not found on type [$($t.FullName)]."
    }

    return $f.GetValue($null)
}

function Set-TepiStaticField {
    param(
        [Parameter(Mandatory = $true)][string]$TypeName,
        [Parameter(Mandatory = $true)][string]$FieldName,
        $Value
    )

    $t = Get-TepiType $TypeName
    if (-not $t) {
        throw "Set-TepiStaticField: Type [$TypeName] not found in Tepi assembly."
    }

    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static'
    $f = $t.GetField($FieldName, $flags)
    if (-not $f) {
        throw "Set-TepiStaticField: Field [$FieldName] not found on type [$($t.FullName)]."
    }

    $f.SetValue($null, $Value)
}

function Get-TepiStaticProperty {
    param(
        [Parameter(Mandatory = $true)][string]$TypeName,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $t = Get-TepiType $TypeName
    if (-not $t) {
        throw "Get-TepiStaticProperty: Type [$TypeName] not found in Tepi assembly."
    }

    $flags = [System.Reflection.BindingFlags]'Public,NonPublic,Static'
    $p = $t.GetProperty($PropertyName, $flags)
    if (-not $p) {
        throw "Get-TepiStaticProperty: Property [$PropertyName] not found on type [$($t.FullName)]."
    }

    return $p.GetValue($null, $null)
}

# 4. WCAG Reference Calculator via Tepi.Island.Contrast
function Get-TepiContrast {
    param(
        [Parameter(Mandatory = $true)]$ColorA,
        [Parameter(Mandatory = $true)]$ColorB
    )

    $toColor = {
        param($c)
        if ($c -is [System.Drawing.Color]) { return $c }
        if ($c -is [string]) {
            if ($c.StartsWith("#")) { return [System.Drawing.ColorTranslator]::FromHtml($c) }
            return [System.Drawing.Color]::FromName($c)
        }
        return $c
    }

    $ca = & $toColor $ColorA
    $cb = & $toColor $ColorB

    $res = Invoke-TepiStaticMethod "Island" "Contrast" @($ca, $cb)
    return [Math]::Round([double]$res, 2)
}

# 5. Deterministic State Reset
function Reset-TepiTheme {
    param([bool]$Light = $false)

    try {
        $inkType = Get-TepiType "Ink"
        if ($inkType) {
            Invoke-TepiStaticMethod "Ink" "Init" @()
            Invoke-TepiStaticMethod "Ink" "SetPack" @($null)
            Invoke-TepiStaticMethod "Ink" "SetAccent" @([string]$null)
            Set-TepiStaticField "Ink" "VeilTint" $null
            Invoke-TepiStaticMethod "Ink" "Apply" @($Light)
        }
    }
    catch {
        # Ignore if types are not loaded or methods have varied signatures across milestones
    }
}

# 6. Headless Offscreen Rendering Helper
function Render-TepiControlToBitmap {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Control,
        [int]$Width = 120,
        [int]$Height = 36
    )

    $Control.Size = New-Object System.Drawing.Size($Width, $Height)
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Width, $Height
    $Control.DrawToBitmap($bmp, $rect)
    return $bmp
}

function New-TepiControl {
    param(
        [Parameter(Mandatory = $true)][string]$TypeName,
        [hashtable]$Properties = @{}
    )

    $t = Get-TepiType $TypeName
    if (-not $t) {
        throw "New-TepiControl: Control type [$TypeName] not found in Tepi assembly."
    }

    $instance = [Activator]::CreateInstance($t)
    foreach ($entry in $Properties.GetEnumerator()) {
        $prop = $t.GetProperty($entry.Key, [System.Reflection.BindingFlags]'Public,NonPublic,Instance')
        if ($prop -and $prop.CanWrite) {
            $prop.SetValue($instance, $entry.Value, $null)
        }
    }

    return $instance
}
