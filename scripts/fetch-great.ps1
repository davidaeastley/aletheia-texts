param([Parameter(Mandatory)][string]$OutDir, [int]$DelayMs = 350)
# Downloads the Great Bible (1539) chapter pages from textusreceptus.thekingsbible.com, one page per chapter, politely
# (one request at a time, with a pause). Existing files are skipped, so the script can be re-run to finish an interrupted download.
. "$PSScriptRoot\lib.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$canon = @($script:BookRows | ? { $_.group -ne 'apoc' } | % { $_.id })
$chapters = @{}
foreach ($ln in [IO.File]::ReadAllLines("$PSScriptRoot\..\reports\kjv-bible.tsv")) { $p = $ln.Split("`t", 4); if ($p.Count -lt 3) { continue }; $k = $p[0]; if (-not $chapters.ContainsKey($k)) { $chapters[$k] = 0 }; $c = [int]$p[1]; if ($c -gt $chapters[$k]) { $chapters[$k] = $c } }
$total = 0; foreach ($b in $canon) { $total += $chapters[$b] }
$done = 0; $failed = @()
for ($bn = 1; $bn -le 66; $bn++) {
  $bid = $canon[$bn - 1]
  for ($c = 1; $c -le $chapters[$bid]; $c++) {
    $f = Join-Path $OutDir "${bn}_${c}.html"; $done++
    if ((Test-Path $f) -and (Get-Item $f).Length -gt 2000) { continue }
    $ok = $false
    for ($try = 1; $try -le 4 -and -not $ok; $try++) {
      try { $r = Invoke-WebRequest "https://textusreceptus.thekingsbible.com/Great/$bn/$c" -UseBasicParsing -TimeoutSec 60; [IO.File]::WriteAllText($f, $r.Content, (New-Object Text.UTF8Encoding($false))); $ok = $true }
      catch { Start-Sleep -Seconds (2 * $try) }
    }
    if (-not $ok) { $failed += "$bn/$c" }
    Start-Sleep -Milliseconds $DelayMs
    if ($done % 100 -eq 0) { "progress $done / $total" }
  }
}
"finished: $done pages visited, failed: $($failed.Count) $($failed -join ' ')"
