Add-Type -AssemblyName System.Drawing

function Pick([System.Collections.Generic.HashSet[string]]$have, [string[]]$names) {
    foreach ($n in $names) {
        if ($have.Contains($n)) { return $n }
    }
    return [System.Drawing.SystemFonts]::MessageBoxFont.FontFamily.Name
}

$fc = New-Object System.Drawing.Text.InstalledFontCollection
$have = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $fc.Families) { [void]$have.Add($f.Name) }

Write-Output "--- Current Ink.cs implementation ---"
$d1 = Pick $have @("Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
$ss1 = Pick $have @("Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI")
Write-Output "FDisplay picked: '$d1'"
Write-Output "FSmallSemi picked: '$ss1'"

Write-Output ""
Write-Output "--- If blindly changed to 'Display Semibold' / 'Small Semibold' ---"
$d2 = Pick $have @("Segoe UI Variable Display Semibold", "Segoe UI Semibold", "Segoe UI")
$ss2 = Pick $have @("Segoe UI Variable Small Semibold", "Segoe UI Semibold", "Segoe UI")
Write-Output "FDisplay picked: '$d2'"
Write-Output "FSmallSemi picked: '$ss2'"

Write-Output ""
Write-Output "--- If robust fallback chain with BOTH full and truncated names ---"
$d3 = Pick $have @("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI")
$ss3 = Pick $have @("Segoe UI Variable Small Semibold", "Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI")
Write-Output "FDisplay picked: '$d3'"
Write-Output "FSmallSemi picked: '$ss3'"
