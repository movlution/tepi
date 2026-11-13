$names = @(
    "Segoe UI Variable Display Semibold",
    "Segoe UI Variable Small Semibold",
    "Segoe UI Variable Text Semibold"
)

foreach ($n in $names) {
    $trunc = if ($n.Length -gt 31) { $n.Substring(0, 31) } else { $n }
    Write-Output "Full: '$n' (len $($n.Length)) -> Trunc: '$trunc' (len $($trunc.Length))"
}
