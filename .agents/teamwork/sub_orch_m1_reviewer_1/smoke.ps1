$p = Start-Process -FilePath "D:\PROJECT\Other\tepi\Tepi.exe" -PassThru
Start-Sleep -Milliseconds 1500
if (-not $p.HasExited) {
    Stop-Process -Id $p.Id -Force
    Write-Host "Tepi.exe started and ran cleanly without crashing"
} else {
    Write-Host "Tepi.exe exited prematurely with code: $($p.ExitCode)"
}
