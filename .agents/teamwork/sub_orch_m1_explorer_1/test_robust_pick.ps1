Add-Type -AssemblyName System.Drawing

function RobustPick([System.Collections.Generic.HashSet[string]]$have, [string[]]$names) {
    foreach ($n in $names) {
        if ($have.Contains($n)) { return $n }
        if ($n.Length -gt 31 -and $have.Contains($n.Substring(0, 31))) {
            return $n.Substring(0, 31)
        }
    }
    return [System.Drawing.SystemFonts]::MessageBoxFont.FontFamily.Name
}

$fc = New-Object System.Drawing.Text.InstalledFontCollection
$have = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $fc.Families) { [void]$have.Add($f.Name) }

Write-Output "Test 1: Passing full name 'Segoe UI Variable Display Semibold'"
$res1 = RobustPick $have @("Segoe UI Variable Display Semibold", "Segoe UI Semibold", "Segoe UI")
Write-Output "Result 1: '$res1'"

Write-Output "Test 2: Passing full name 'Segoe UI Variable Small Semibold'"
$res2 = RobustPick $have @("Segoe UI Variable Small Semibold", "Segoe UI Semibold", "Segoe UI")
Write-Output "Result 2: '$res2'"

Write-Output "Test 3: Passing both full and truncated names"
$res3 = RobustPick $have @("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
Write-Output "Result 3: '$res3'"

Write-Output "Test 4: Windows 10 simulation (simulated empty have for Variable)"
$win10Have = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$win10Have.Add("Segoe UI")
[void]$win10Have.Add("Segoe UI Semibold")
$resWin10 = RobustPick $win10Have @("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
Write-Output "Result Win10 Display: '$resWin10'"
$resWin10Small = RobustPick $win10Have @("Segoe UI Variable Small Semibold", "Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI")
Write-Output "Result Win10 SmallSemi: '$resWin10Small'"
