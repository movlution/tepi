Add-Type -AssemblyName System.Drawing

$names = @(
    "Segoe UI Variable Display Semib",
    "Segoe UI Variable Display",
    "Segoe UI Variable Text Semibold",
    "Segoe UI Variable Text",
    "Segoe UI Variable Small Semibol",
    "Segoe UI Variable Small"
)

foreach ($name in $names) {
    try {
        $ff = New-Object System.Drawing.FontFamily($name)
        Write-Output "FontFamily: '$($ff.Name)'"
        Write-Output "  IsStyleAvailable(Regular): $($ff.IsStyleAvailable([System.Drawing.FontStyle]::Regular))"
        Write-Output "  IsStyleAvailable(Bold): $($ff.IsStyleAvailable([System.Drawing.FontStyle]::Bold))"
        Write-Output "  IsStyleAvailable(Italic): $($ff.IsStyleAvailable([System.Drawing.FontStyle]::Italic))"
        $ff.Dispose()
    } catch {
        Write-Output "FontFamily '$name' not found: $($_.Exception.Message)"
    }
}
