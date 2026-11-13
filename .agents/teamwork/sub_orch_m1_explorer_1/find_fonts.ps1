$srcFiles = Get-ChildItem -Path d:\PROJECT\Other\tepi\src -Filter *.cs -Recurse

Write-Output "=== SEARCHING FOR FONT CREATION AND REFERENCES ==="

foreach ($file in $srcFiles) {
    $lines = Get-Content $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match 'new Font\(|FontFamily|InstalledFontCollection|families\[|SystemFonts|\bFont\b.*=') {
            Write-Output "$($file.Name):$($i+1): $line"
        }
    }
}
