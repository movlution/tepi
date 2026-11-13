Add-Type -AssemblyName System.Drawing

$testCases = @(
    "Segoe UI Variable Display Semibold",
    "Segoe UI Variable Display Semib",
    "Segoe UI Variable Small Semibold",
    "Segoe UI Variable Small Semibol"
)

foreach ($name in $testCases) {
    try {
        $fam = New-Object System.Drawing.FontFamily($name)
        Write-Output "new FontFamily('$name') SUCCEEDED: Name='$($fam.Name)'"
        $fam.Dispose()
    } catch {
        Write-Output "new FontFamily('$name') FAILED: $($_.Exception.Message)"
    }
}
