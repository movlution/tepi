$tier1 = Get-ChildItem "d:\PROJECT\Other\tepi\tests\tier1_features\*.ps1"
$tier2 = Get-ChildItem "d:\PROJECT\Other\tepi\tests\tier2_boundaries\*.ps1"

$allTests = @($tier1) + @($tier2)
$passed = 0
$failed = 0

Write-Host "Running $($allTests.Count) test suites..."

foreach ($t in $allTests) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $output = powershell -ExecutionPolicy Bypass -File $t.FullName 2>&1
    $exitCode = $LASTEXITCODE
    $sw.Stop()

    $failLines = $output | Where-Object { $_ -match "\[FAIL\]" -or $_ -match "Error:" }

    if ($exitCode -ne 0 -or $failLines) {
        $failed++
        Write-Host ("[FAIL] {0} ({1}ms, code {2})" -f $t.Name, $sw.ElapsedMilliseconds, $exitCode) -ForegroundColor Red
        foreach ($l in $failLines) { Write-Host ("       " + $l) -ForegroundColor DarkRed }
    } else {
        $passed++
        Write-Host ("[PASS] {0} ({1}ms)" -f $t.Name, $sw.ElapsedMilliseconds) -ForegroundColor Green
    }
}

Write-Host "`n========================================================"
Write-Host ("Summary: Total={0}, Passed={1}, Failed={2}" -f $allTests.Count, $passed, $failed)
Write-Host "========================================================"
