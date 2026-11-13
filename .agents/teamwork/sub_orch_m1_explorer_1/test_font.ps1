Add-Type -AssemblyName System.Drawing

$testNames = @(
    "Segoe UI Variable Display Semib",
    "Segoe UI Variable Display Semibold",
    "Segoe UI Variable Small Semibol",
    "Segoe UI Variable Small Semibold",
    "Segoe UI Variable Text Semibold",
    "Segoe UI Semibold",
    "Segoe UI"
)

$fc = New-Object System.Drawing.Text.InstalledFontCollection
$installed = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $fc.Families) {
    [void]$installed.Add($f.Name)
}

Write-Output "=== INSTALLED FONT CHECK ==="
foreach ($name in $testNames) {
    $found = $installed.Contains($name)
    Write-Output "Installed contains '$name': $found"
}

Write-Output ""
Write-Output "=== GDI+ NEW FONT OBJECT TEST ==="
foreach ($name in $testNames) {
    try {
        $font = New-Object System.Drawing.Font($name, 12.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        Write-Output "Created Font('$name') -> FontFamily.Name is '$($font.FontFamily.Name)'"
        $font.Dispose()
    } catch {
        Write-Output "Created Font('$name') -> FAILED: $($_.Exception.Message)"
    }
}
