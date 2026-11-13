$srcFiles = Get-ChildItem -Path d:\PROJECT\Other\tepi\src -Filter *.cs -Recurse

Write-Output "=== SEARCHING FOR HARDCODED FONT NAMES ==="
foreach ($file in $srcFiles) {
    $lines = Get-Content $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '"Segoe|"Consolas|"Courier|"Cascadia|"Arial|"Tahoma|"Microsoft Sans Serif') {
            Write-Output "$($file.Name):$($i+1): $line"
        }
    }
}
