param([Parameter(Mandatory)][string]$Id)
# Re-keys a translation to the KJV verse numbering the app uses, so every column lines up.
# neutral/<id>.json (the source's own numbering) -> aligned/<id>.json
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
Add-Type -TypeDefinition ([IO.File]::ReadAllText("$PSScriptRoot\Aligner.cs")) -Language CSharp
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."; New-Item -ItemType Directory -Force "$root\aligned" | Out-Null
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$grp = @{}; foreach ($b in $script:BookRows) { $grp[$b.id] = $b.group }

function VNum($v) { if ($v -match '^\d+') { [int]$Matches[0] } else { 0 } }
function Flatten($chapters) {   # -> list of @{k='c:v'; c; v; t}
  $out = New-Object System.Collections.ArrayList
  foreach ($c in ($chapters.Keys | Sort-Object { [int]$_ })) { foreach ($v in ($chapters[$c].Keys | Sort-Object { VNum $_ })) { [void]$out.Add(@{ k = "${c}:${v}"; c = $c; v = $v; t = [string]$chapters[$c][$v] }) } }
  , $out
}

# ---- references: the app's KJV (Old/New Testament) and the KJV Apocrypha ----
$ref = @{}
foreach ($ln in [IO.File]::ReadAllLines("$root\reports\kjv-bible.tsv", [Text.Encoding]::UTF8)) {
  $p = $ln.Split("`t", 4); if ($p.Count -lt 4) { continue }
  if (-not $ref.ContainsKey($p[0])) { $ref[$p[0]] = [ordered]@{} }
  if (-not $ref[$p[0]].Contains($p[1])) { $ref[$p[0]][$p[1]] = [ordered]@{} }
  $ref[$p[0]][$p[1]][$p[2]] = $p[3]
}
$kj = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\kjv.json"))
foreach ($b in $kj['books'].Keys) { if ($grp[$b] -eq 'apoc') { $ref[$b] = $kj['books'][$b] } }

# ---- the source translation, with the Vulgate-style additions moved to their Apocrypha books ----
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\$Id.json")); $meta = $j['meta']; $src = $j['books']
$notes = New-Object System.Collections.ArrayList
function MoveVerses($fromBook, [scriptblock]$pick, $toBook, [scriptblock]$newKey) {
  if (-not $src.ContainsKey($fromBook)) { return }
  if (-not $src.ContainsKey($toBook)) { $src[$toBook] = New-Object 'System.Collections.Generic.Dictionary[string,object]' }
  $moved = 0
  foreach ($c in @($src[$fromBook].Keys)) {
    foreach ($v in @($src[$fromBook][$c].Keys)) {
      if (& $pick ([int]$c) (VNum $v)) {
        $nk = & $newKey ([int]$c) (VNum $v) $v; $nc = [string]$nk[0]; $nv = [string]$nk[1]
        if (-not $src[$toBook].ContainsKey($nc)) { $src[$toBook][$nc] = New-Object 'System.Collections.Generic.Dictionary[string,object]' }
        $src[$toBook][$nc][$nv] = $src[$fromBook][$c][$v]; [void]$src[$fromBook][$c].Remove($v); $moved++
      }
    }
    if ($src[$fromBook][$c].Count -eq 0) { [void]$src[$fromBook].Remove($c) }
  }
  [void]$notes.Add("moved $moved verses from $fromBook to $toBook")
}
if ($meta['numbering'] -eq 'vulgate') {
  MoveVerses 'esth' { param($c, $v) $c -ge 11 -or ($c -eq 10 -and $v -ge 4) } 'addesth' { param($c, $v, $raw) , @($c, $raw) }
  MoveVerses 'dan' { param($c, $v) $c -eq 3 -and $v -ge 24 -and $v -le 90 } 'sg3' { param($c, $v, $raw) , @(1, ($v - 23)) }
  MoveVerses 'dan' { param($c, $v) $c -eq 13 } 'sus' { param($c, $v, $raw) , @(1, $raw) }
  MoveVerses 'dan' { param($c, $v) $c -eq 14 } 'bel' { param($c, $v, $raw) , @(1, $raw) }
  MoveVerses '2chr' { param($c, $v) $c -eq 37 } 'prman' { param($c, $v, $raw) , @(1, $raw) }
  MoveVerses 'epjer' { param($c, $v) $true } 'bar' { param($c, $v, $raw) , @(6, $raw) }
  if ($src.ContainsKey('epjer') -and $src['epjer'].Count -eq 0) { [void]$src.Remove('epjer') }
}

if ($meta['numbering'] -eq 'vulgate') {
  foreach ($ln in (Get-Content "$PSScriptRoot\swaps.csv" | ? { $_ -and $_ -notmatch '^#' })) {
    $p = $ln.Split(','); $bk = $p[0]; $k1 = $p[1].Split(':'); $k2 = $p[2].Split(':')
    if ($src.ContainsKey($bk) -and $src[$bk].ContainsKey($k1[0]) -and $src[$bk][$k1[0]].ContainsKey($k1[1]) -and $src[$bk][$k2[0]].ContainsKey($k2[1])) {
      $tmp = $src[$bk][$k1[0]][$k1[1]]; $src[$bk][$k1[0]][$k1[1]] = $src[$bk][$k2[0]][$k2[1]]; $src[$bk][$k2[0]][$k2[1]] = $tmp; [void]$notes.Add("swapped source verses $bk $($p[1]) and $($p[2]) (Vulgate order)")
    }
  }
}foreach ($k in @($src.Keys)) { if ($src[$k].Count -eq 0) { [void]$src.Remove($k) } }   # moves can leave an empty target book
# ---- align book by book ----
$out = [ordered]@{}; $report = New-Object System.Collections.ArrayList; $summary = @()
foreach ($bid in ($src.Keys | Sort-Object { $order[$_] })) {
  if (-not $ref.ContainsKey($bid)) { $out[$bid] = $src[$bid]; [void]$report.Add("$bid : no KJV counterpart, kept with its own numbering"); continue }
  $S = Flatten $src[$bid]; $R = Flatten $ref[$bid]
  try { $segs = [Aligner]::Align([string[]]($S | % { $_.k }), [string[]]($S | % { $_.t }), [string[]]($R | % { $_.k }), [string[]]($R | % { $_.t })) } catch { "ALIGN FAILED $bid : $($_.Exception.InnerException.Message) :: $($_.Exception.InnerException.StackTrace)"; throw }
  $bookOut = [ordered]@{}; $merged = 0; $split = 0; $dropped = 0; $empty = 0; $swapped = 0
  $put = { param($rk, $text) $c, $v = $rk.Split(':'); if (-not $bookOut.Contains($c)) { $bookOut[$c] = [ordered]@{} }; $bookOut[$c][$v] = $text }
  foreach ($sg in $segs) {
    $si = $sg[0]; $p = $sg[1]; $ri = $sg[2]; $q = $sg[3]
    if ($q -eq 0) { $dropped += $p; for ($x = 0; $x -lt $p; $x++) { [void]$report.Add("$bid : source verse $($S[$si + $x].k) has no KJV counterpart (dropped): $($S[$si + $x].t.Substring(0, [Math]::Min(70, $S[$si + $x].t.Length)))") }; continue }
    if ($p -eq 0) { $empty += $q; continue }
    if ($sg[4] -eq 1) { & $put $R[$ri].k $S[$si + 1].t; & $put $R[$ri + 1].k $S[$si].t; $swapped++; [void]$report.Add("$bid : source $($S[$si].k) and $($S[$si + 1].k) are in the opposite order to KJV $($R[$ri].k), $($R[$ri + 1].k)"); continue }
    if ($p -eq $q) { for ($x = 0; $x -lt $p; $x++) { & $put $R[$ri + $x].k $S[$si + $x].t }; if ($p -gt 1) { $merged++ }; continue }
    if ($q -eq 1) { & $put $R[$ri].k (($S[$si..($si + $p - 1)] | % { $_.t }) -join ' '); $merged++; [void]$report.Add("$bid : source $($S[$si].k)..$($S[$si + $p - 1].k) merged into KJV $($R[$ri].k)"); continue }
    # one source verse covers several KJV verses: text goes in the first, the rest point back to it
    $first = $R[$ri]; & $put $first.k ((($S[$si..($si + $p - 1)]) | % { $_.t }) -join ' ')
    for ($x = 1; $x -lt $q; $x++) { $t = $R[$ri + $x]; $ptr = if ($t.c -eq $first.c) { '^' + $first.v } else { '^' + $first.k }; & $put $t.k $ptr }
    $split++; [void]$report.Add("$bid : source $($S[$si].k) covers KJV $($first.k)..$($R[$ri + $q - 1].k)")
  }
  $out[$bid] = $bookOut
  $summary += ("{0,-8} source {1,5} ref {2,5}  merges {3,3} splits {4,3} dropped {5,3} ref-only {6,3} swaps {7,3}" -f $bid, $S.Count, $R.Count, $merged, $split, $dropped, $empty, $swapped)
}
$m2 = [ordered]@{}; foreach ($k in $meta.Keys) { $m2[$k] = $meta[$k] }; $m2['numbering'] = 'kjv'; $m2['alignedFrom'] = $meta['numbering']
Write-NeutralJson "$root\aligned\$Id.json" $m2 $out
$summary | Set-Content "$root\reports\$Id-alignment-summary.txt" -Encoding UTF8
@($notes) + @($report) | Set-Content "$root\reports\$Id-alignment.txt" -Encoding UTF8
$summary; "$($report.Count) notes in reports\$Id-alignment.txt"; $notes
