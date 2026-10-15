param([Parameter(Mandatory)][string]$Id, [switch]$RestrictToSourceChapters, [switch]$Idf, [string]$RefTsv = '', [double]$KeyBonus = -1, [switch]$ChapterBlocks, [switch]$GapsOnly)   # -ChapterBlocks: see below. -GapsOnly (with -ChapterBlocks): a chapter whose verse numbers are all KJV verse numbers maps by number even if the source leaves some verses out (BSB, NRSVue)   # -KeyBonus: how strongly to trust identical chapter:verse numbers (default 0.15; 0 with -Idf). Use about 0.5 with -Idf for a source that is nearly in KJV numbering   # -RefTsv: align to this tsv (book, chapter, verse, text) instead of the KJV; a ...-pointers.tsv beside it restores its merged-verse pointers. For a Latin source, the Clementine Vulgate   # -Idf: the source is not English, so weight rare character trigrams (names, numbers) higher   # -Restrict...: for partly transcribed texts, align only against the KJV chapters the source has
# Re-keys a translation to the KJV verse numbering the app uses, so every column lines up.
# neutral/<id>.json (the source's own numbering) -> aligned/<id>.json
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
Add-Type -TypeDefinition ([IO.File]::ReadAllText("$PSScriptRoot\Aligner.cs")) -Language CSharp
[Aligner]::UseIdf = [bool]$Idf; if ($Idf) { [Aligner]::OpPenalty = 0.35 }
[Aligner]::KeyBonus = if ($KeyBonus -ge 0) { $KeyBonus } elseif ($Idf) { 0 } else { 0.15 }
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
$refFile = if ($RefTsv) { $RefTsv } else { "$root\reports\kjv-bible.tsv" }
foreach ($ln in [IO.File]::ReadAllLines($refFile, [Text.Encoding]::UTF8)) {
  $p = $ln.Split("`t", 4); if ($p.Count -lt 4) { continue }
  if (-not $ref.ContainsKey($p[0])) { $ref[$p[0]] = [ordered]@{} }
  if (-not $ref[$p[0]].Contains($p[1])) { $ref[$p[0]][$p[1]] = [ordered]@{} }
  $ref[$p[0]][$p[1]][$p[2]] = $p[3]
}
$kj = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\kjv.json"))
foreach ($b in $kj['books'].Keys) { if ($grp[$b] -eq 'apoc') { $ref[$b] = $kj['books'][$b] } }
$refPtr = @{}; $pf = $refFile -replace '\.tsv$', '-pointers.tsv'
if ($RefTsv -and (Test-Path $pf)) { foreach ($ln in [IO.File]::ReadAllLines($pf, [Text.Encoding]::UTF8)) { $q = $ln.Split("`t", 4); if (-not $refPtr.ContainsKey($q[0])) { $refPtr[$q[0]] = New-Object System.Collections.ArrayList }; [void]$refPtr[$q[0]].Add($q) } }

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
if ($meta['numbering'] -eq 'synodal') {   # Daniel holds the Greek additions: the Song of the Three (3:24-90), Susanna (13) and Bel (14), which go to their Apocrypha books; the rest of chapter 3 follows on
  MoveVerses 'dan' { param($c, $v) $c -eq 3 -and $v -ge 24 -and $v -le 90 } 'sg3' { param($c, $v, $raw) , @(1, ($v - 23)) }
  MoveVerses 'dan' { param($c, $v) $c -eq 13 } 'sus' { param($c, $v, $raw) , @(1, $raw) }
  MoveVerses 'dan' { param($c, $v) $c -eq 14 } 'bel' { param($c, $v, $raw) , @(1, $raw) }
  MoveVerses 'dan' { param($c, $v) $c -eq 3 -and $v -ge 91 } 'dan' { param($c, $v, $raw) , @(3, ($v - 67)) }
  # Synodal 3:31-33 are KJV 4:1-3, so chapter 4 starts three verses earlier
  MoveVerses 'dan' { param($c, $v) $c -eq 4 } 'dan' { param($c, $v, $raw) , @(40, ($v + 3)) }
  MoveVerses 'dan' { param($c, $v) $c -eq 3 -and $v -ge 31 } 'dan' { param($c, $v, $raw) , @(40, ($v - 30)) }
  MoveVerses 'dan' { param($c, $v) $c -eq 40 } 'dan' { param($c, $v, $raw) , @(4, $raw) }
}
if ($meta['numbering'] -eq 'synodal') { MoveVerses 'ps' { param($c, $v) $c -eq 151 } 'ps151' { param($c, $v, $raw) , @(1, $raw) }; MoveVerses 'epjer' { param($c, $v) $true } 'bar' { param($c, $v, $raw) , @(6, $raw) }; if ($src.ContainsKey('epjer') -and $src['epjer'].Count -eq 0) { [void]$src.Remove('epjer') } }
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
}# Synodal and Vulgate Psalms use the Greek (Septuagint) psalm numbers: bring the chapters to the Hebrew numbers the KJV uses (9 holds Hebrew 9 and 10, 113 holds 114 and 115, 114 and 115 are one psalm, 146 and 147 are one psalm); a chapter that holds two Hebrew psalms is aligned against both
if (@('synodal', 'vulgate') -contains $meta['numbering'] -and $src.ContainsKey('ps')) {
  $old = $src['ps']; $nw = [ordered]@{}
  $add = { param($to, $from, $offset) if (-not $nw.Contains($to)) { $nw[$to] = [ordered]@{} }; foreach ($v in @($old[$from].Keys | Sort-Object { [int]$_ })) { $nw[$to][[string]([int]$v + $offset)] = $old[$from][$v] } }
  foreach ($c in @($old.Keys | Sort-Object { [int]$_ })) {
    $n = [int]$c
    if ($n -eq 9 -or $n -eq 113) {   # two Hebrew psalms in one: 9 holds Hebrew 9 (21 verses with its title) and 10; 113 holds 114 (8 verses) and 115
      $cut = if ($n -eq 9) { 21 } else { 8 }; $h1 = if ($n -eq 9) { '9' } else { '114' }; $h2 = if ($n -eq 9) { '10' } else { '115' }
      foreach ($h in $h1, $h2) { if (-not $nw.Contains($h)) { $nw[$h] = [ordered]@{} } }
      foreach ($v in @($old[$c].Keys | Sort-Object { [int]$_ })) { if ([int]$v -le $cut) { $nw[$h1][$v] = $old[$c][$v] } else { $nw[$h2][[string]([int]$v - $cut)] = $old[$c][$v] } }
    }
    elseif ($n -le 8 -or $n -ge 148) { & $add ([string]$n) $c 0 }
    elseif ($n -le 112) { & $add ([string]($n + 1)) $c 0 }
    elseif ($n -eq 114) { & $add '116' $c 0 }
    elseif ($n -eq 115) { $off = if ($nw.Contains('116')) { $nw['116'].Count } else { 0 }; & $add '116' $c $off }
    elseif ($n -le 145) { & $add ([string]($n + 1)) $c 0 }
    elseif ($n -eq 146) { & $add '147' $c 0 }
    elseif ($n -eq 147) { $off = if ($nw.Contains('147')) { $nw['147'].Count } else { 0 }; & $add '147' $c $off }
    else { & $add ([string]$n) $c 0 }
  }
  $src['ps'] = $nw; [void]$notes.Add('Psalm chapters renumbered from the Greek to the Hebrew numbering')
}
# German (Luther) Psalms count the title as verse 1 (or 1 and 2): fold the title verses into the first verse, so that the rest follow the KJV verse for verse
if (@('german', 'synodal', 'hebrew', 'vulgate') -contains $meta['numbering'] -and $src.ContainsKey('ps')) {
  $kc = @{}; foreach ($c in $ref['ps'].Keys) { $kc[$c] = $ref['ps'][$c].Count }
  foreach ($c in @($src['ps'].Keys)) {
    if ($null -eq $kc[$c] ) { continue }
    $d = $src['ps'][$c].Count - $kc[$c]; if ($d -lt 1) { continue }
    $vs = @($src['ps'][$c].Keys | Sort-Object { [int]$_ }); $first = ($vs[0..$d] | % { $src['ps'][$c][$_] }) -join ' '
    $new = [ordered]@{}; $new['1'] = $first; for ($x = $d + 1; $x -lt $vs.Count; $x++) { $new[[string]($x - $d + 1)] = $src['ps'][$c][$vs[$x]] }
    $src['ps'][$c] = $new; [void]$notes.Add("Psalm $c : the first $($d + 1) source verses (title) folded into verse 1")
  }
}
foreach ($k in @($src.Keys)) { if ($src[$k].Count -eq 0) { [void]$src.Remove($k) } }   # moves can leave an empty target book
# ---- align book by book ----
$out = [ordered]@{}; $report = New-Object System.Collections.ArrayList; $summary = @()
foreach ($bid in ($src.Keys | Sort-Object { $order[$_] })) {
  if (-not $ref.ContainsKey($bid)) { $out[$bid] = $src[$bid]; [void]$report.Add("$bid : no KJV counterpart, kept with its own numbering"); continue }
  [Aligner]::UseIdf = ([bool]$Idf -or ([bool]$RefTsv -and $grp[$bid] -eq 'apoc')); [Aligner]::OpPenalty = if ([Aligner]::UseIdf) { 0.35 } else { 0 }
  if ($RefTsv -and $grp[$bid] -eq 'apoc' -and $KeyBonus -lt 0 -and -not $Idf) { [Aligner]::KeyBonus = 0 } elseif ($RefTsv -and $grp[$bid] -ne 'apoc' -and $KeyBonus -lt 0) { [Aligner]::KeyBonus = 0.15 }   # a Latin source against the English KJV Apocrypha is a cross-language alignment
  $S = Flatten $src[$bid]; $R = Flatten $ref[$bid]
  if ($RestrictToSourceChapters) { $have = @{}; foreach ($cc in $src[$bid].Keys) { $have[[string]$cc] = 1 }; $R = @($R | ? { $have.ContainsKey([string]$_.c) }); if ($R.Count -eq 0) { continue } }
  try {
    if (-not $ChapterBlocks) { $segs = [Aligner]::Align([string[]]($S | % { $_.k }), [string[]]($S | % { $_.t }), [string[]]($R | % { $_.k }), [string[]]($R | % { $_.t })) }
    else {
      # a source that is nearly in KJV numbering: chapters with the same verse numbers as the KJV map one to one; only the chapters that differ (with one neighbour on each side) are aligned, so a slip stays inside them
      $sCh = @{}; for ($i = 0; $i -lt $S.Count; $i++) { $c = [int]$S[$i].c; if (-not $sCh.ContainsKey($c)) { $sCh[$c] = @($i, $i) } else { $sCh[$c][1] = $i } }
      $rCh = @{}; for ($i = 0; $i -lt $R.Count; $i++) { $c = [int]$R[$i].c; if (-not $rCh.ContainsKey($c)) { $rCh[$c] = @($i, $i) } else { $rCh[$c][1] = $i } }
      $chs = @(@($sCh.Keys) + @($rCh.Keys) | Sort-Object -Unique)
      $same = @{}
      foreach ($c in $chs) { $ok = $sCh.ContainsKey($c) -and $rCh.ContainsKey($c) -and ($sCh[$c][1] - $sCh[$c][0]) -eq ($rCh[$c][1] - $rCh[$c][0]); if ($ok) { for ($x = 0; $x -le $sCh[$c][1] - $sCh[$c][0]; $x++) { if ($S[$sCh[$c][0] + $x].v -ne $R[$rCh[$c][0] + $x].v) { $ok = $false; break } } }; if ($GapsOnly -and $sCh.ContainsKey($c) -and $rCh.ContainsKey($c)) { $rv = @{}; for ($i = $rCh[$c][0]; $i -le $rCh[$c][1]; $i++) { $rv[[string]$R[$i].v] = $i }; $ok = $true; $nn = $sCh[$c][1] - $sCh[$c][0] + 1; $contig = $true; for ($i = $sCh[$c][0]; $i -le $sCh[$c][1]; $i++) { if (-not $rv.ContainsKey([string]$S[$i].v)) { $ok = $false; break }; if ([int]$S[$i].v -ne ($i - $sCh[$c][0] + 1)) { $contig = $false } }
    # numbers 1..n with n below the KJV count: a source that merged verses (everything after the merge is renumbered, so align it) unless a long stretch is missing (the text is cut short, so map by number)
    if ($ok -and $contig -and $nn -lt $rv.Count -and ($rv.Count - $nn) -lt 10) { $ok = $false } }; $same[$c] = $ok }
      $inBlock = @{}; for ($k = 0; $k -lt $chs.Count; $k++) { $c = $chs[$k]; $inBlock[$c] = (-not $same[$c]) -or ($k -gt 0 -and -not $same[$chs[$k - 1]]) -or ($k -lt $chs.Count - 1 -and -not $same[$chs[$k + 1]]) }
      $segs = New-Object System.Collections.ArrayList; $k = 0
      while ($k -lt $chs.Count) {
        $c = $chs[$k]
        if (-not $inBlock[$c]) {
          if ($GapsOnly) { $rv = @{}; for ($i = $rCh[$c][0]; $i -le $rCh[$c][1]; $i++) { $rv[[string]$R[$i].v] = $i }; for ($i = $sCh[$c][0]; $i -le $sCh[$c][1]; $i++) { [void]$segs.Add([int[]]@($i, 1, $rv[[string]$S[$i].v], 1, 0)) } }
          else { for ($x = 0; $x -le $sCh[$c][1] - $sCh[$c][0]; $x++) { [void]$segs.Add([int[]]@(($sCh[$c][0] + $x), 1, ($rCh[$c][0] + $x), 1, 0)) } }
          $k++; continue }
        $e = $k; while ($e + 1 -lt $chs.Count -and $inBlock[$chs[$e + 1]]) { $e++ }
        $sa = $null; $sb = $null; $ra = $null; $rb = $null
        for ($m = $k; $m -le $e; $m++) { $cc = $chs[$m]; if ($sCh.ContainsKey($cc)) { if ($null -eq $sa) { $sa = $sCh[$cc][0] }; $sb = $sCh[$cc][1] }; if ($rCh.ContainsKey($cc)) { if ($null -eq $ra) { $ra = $rCh[$cc][0] }; $rb = $rCh[$cc][1] } }
        if ($null -eq $sa) { $k = $e + 1; continue }
        if ($null -eq $ra) { for ($x = $sa; $x -le $sb; $x++) { [void]$segs.Add([int[]]@($x, 1, $R.Count, 0, 0)) }; $k = $e + 1; continue }
        $SS = @($S[$sa..$sb]); $RR = @($R[$ra..$rb])
        $sub = [Aligner]::Align([string[]]($SS | % { $_.k }), [string[]]($SS | % { $_.t }), [string[]]($RR | % { $_.k }), [string[]]($RR | % { $_.t }))
        foreach ($sg in $sub) { [void]$segs.Add([int[]]@(($sg[0] + $sa), $sg[1], ($sg[2] + $ra), $sg[3], $sg[4])) }
        $k = $e + 1
      }
    }
  } catch { "ALIGN FAILED $bid : $($_.Exception.Message) :: $($_.Exception.InnerException.Message)"; throw }
  $bookOut = [ordered]@{}; $merged = 0; $split = 0; $dropped = 0; $empty = 0; $swapped = 0
  $lastKey = $null
  $put = { param($rk, $text) $c, $v = $rk.Split(':'); if (-not $bookOut.Contains($c)) { $bookOut[$c] = [ordered]@{} }; $bookOut[$c][$v] = $text; if (-not "$text".StartsWith('^')) { $script:lastKey = $rk } }
  foreach ($sg in $segs) {
    $si = $sg[0]; $p = $sg[1]; $ri = $sg[2]; $q = $sg[3]
    if ($q -eq 0) {
      $dropped += $p
      for ($x = 0; $x -lt $p; $x++) {
        $dv = $S[$si + $x]; $where = 'dropped'
        if ($lastKey) { $lc, $lv = $lastKey.Split(':'); $cur = [string]$bookOut[$lc][$lv]; if ($cur -and -not $cur.StartsWith('^')) { $bookOut[$lc][$lv] = $cur + ' ' + $dv.t; $where = "added to the end of KJV $lastKey" } }   # the text is kept: it joins the verse before it
        [void]$report.Add("$bid : source verse $($dv.k) has no KJV counterpart ($where): $($dv.t.Substring(0, [Math]::Min(70, $dv.t.Length)))")
      }
      continue
    }
    if ($p -eq 0) { $empty += $q; continue }
    if ($sg[4] -eq 1) { & $put $R[$ri].k $S[$si + 1].t; & $put $R[$ri + 1].k $S[$si].t; $swapped++; [void]$report.Add("$bid : source $($S[$si].k) and $($S[$si + 1].k) are in the opposite order to KJV $($R[$ri].k), $($R[$ri + 1].k)"); continue }
    if ($p -eq $q) { for ($x = 0; $x -lt $p; $x++) { & $put $R[$ri + $x].k $S[$si + $x].t }; if ($p -gt 1) { $merged++ }; continue }
    if ($q -eq 1) { & $put $R[$ri].k (($S[$si..($si + $p - 1)] | % { $_.t }) -join ' '); $merged++; [void]$report.Add("$bid : source $($S[$si].k)..$($S[$si + $p - 1].k) merged into KJV $($R[$ri].k)"); continue }
    # one source verse covers several KJV verses: text goes in the first, the rest point back to it
    $first = $R[$ri]; & $put $first.k ((($S[$si..($si + $p - 1)]) | % { $_.t }) -join ' ')
    for ($x = 1; $x -lt $q; $x++) { $t = $R[$ri + $x]; $ptr = if ($t.c -eq $first.c) { '^' + $first.v } else { '^' + $first.k }; & $put $t.k $ptr }
    $split++; [void]$report.Add("$bid : source $($S[$si].k) covers KJV $($first.k)..$($R[$ri + $q - 1].k)")
  }
  if ($refPtr.ContainsKey($bid)) { foreach ($q in $refPtr[$bid]) { if (-not $bookOut.Contains($q[1]) -or -not $bookOut[$q[1]].Contains($q[2])) { & $put "$($q[1]):$($q[2])" $q[3] } } }   # merged verses of the reference stay merged
  $out[$bid] = $bookOut
  $summary += ("{0,-8} source {1,5} ref {2,5}  merges {3,3} splits {4,3} dropped {5,3} ref-only {6,3} swaps {7,3}" -f $bid, $S.Count, $R.Count, $merged, $split, $dropped, $empty, $swapped)
}
$m2 = [ordered]@{}; foreach ($k in $meta.Keys) { $m2[$k] = $meta[$k] }; $m2['numbering'] = 'kjv'; $m2['alignedFrom'] = $meta['numbering']
Write-NeutralJson "$root\aligned\$Id.json" $m2 $out
$summary | Set-Content "$root\reports\$Id-alignment-summary.txt" -Encoding UTF8
@($notes) + @($report) | Set-Content "$root\reports\$Id-alignment.txt" -Encoding UTF8
$summary; "$($report.Count) notes in reports\$Id-alignment.txt"; $notes
