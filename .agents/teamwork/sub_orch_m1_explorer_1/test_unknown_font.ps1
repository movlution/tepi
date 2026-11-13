Add-Type -AssemblyName System.Drawing

$testCases = @(
    "NonExistentFontName",
    "Segoe UI Variable Display Semibold",
    "Segoe UI Variable Display Semib",
    "Segoe UI Variable Display",
    "Segoe UI Variable Text Semibold",
    "Segoe UI Variable Small Semibold",
    "Segoe UI Variable Small Semibol",
    "Segoe UI Semibold",
    "Segoe UI",
    "Segoe Fluent Icons",
    "Segoe MDL2 Assets"
)

foreach ($name in $testCases) {
    try {
        $f = New-Object System.Drawing.Font($name, 12.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        Write-Output "Font('$name') -> Resolved FontFamily: '$($f.FontFamily.Name)'"
        $f.Dispose()
    } catch {
        Write-Output "Font('$name') -> THREW: $($_.Exception.Message)"
    }
}
