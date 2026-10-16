param([Parameter(Mandatory)][string]$Id, [string]$MapTsv = '', [string[]]$Books = @())
# Puts a text that is numbered like the Hebrew Bible (or like the Greek Old Testament in most books) into KJV numbering, with no guessing.
# The table reports/mt-to-kjv.tsv (made by map-ja-markers.ps1 from the Japanese text, which marks the English verse of every verse
# that is numbered differently) says which English verse each Hebrew-numbered verse is.
# A chapter is used only when every verse number in it is a verse number the table knows for that chapter; any other chapter
# (a text with its own chapter divisions, or another order) is left out and listed in the report.
# neutral/<id>.json -> aligned/<id>.json
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."
if (-not $MapTsv) { $MapTsv = "$root\reports\mt-to-kjv.tsv" }
$map = @{}; $known = @{}
foreach ($ln in [IO.File]::ReadAllLines($MapTsv, [Text.Encoding]::UTF8)) {
  $q = $ln.Split("`t"); $map["$($q[0]):$($q[1]):$($q[2])"] = $q[3].Split(','); $ck = "$($q[0]):$($q[1])"
  if (-not $known.ContainsKey($ck)) { $known[$ck] = New-Object 'System.Collections.Generic.HashSet[string]' }; [void]$known[$ck].Add($q[2])
}
$kcount = @{}; foreach ($ln in [IO.File]::ReadAllLines("$root\reports\kjv-keys.txt")) { $q = $ln.Split(':'); $kk = "$($q[0]):$($q[1])"; $kcount[$kk] = [Math]::Max([int]$kcount[$kk], [int]$q[2]) }
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\$Id.json", [Text.Encoding]::UTF8)); $meta = $j['meta']; $src = $j['books']
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$out = [ordered]@{}; $report = New-Object System.Collections.ArrayList; $used = 0; $left = 0
foreach ($b in ($src.Keys | Sort-Object { $order[$_] })) {
  if ($Books.Count -and $Books -notcontains $b) { continue }
  $acc = @{}; $ptr = @{}
  foreach ($c in ($src[$b].Keys | Sort-Object { [int]$_ })) {
    $ck = "${b}:$c"; $n = $src[$b][$c].Count
    $okc = $known.ContainsKey($ck); if ($okc) { foreach ($v in $src[$b][$c].Keys) { if (-not $known[$ck].Contains([string]$v)) { $okc = $false; break } } }
    if (-not $okc -and $b -eq 'ps' -and $kcount.ContainsKey($ck) -and @($src[$b][$c].Keys | ? { [int]$_ -gt $kcount[$ck] }).Count -gt 0) {   # a psalm the table does not cover and with more verse numbers than the English Bible: its title is numbered as the first verse(s)
      $mx = (@($src[$b][$c].Keys | % { [int]$_ }) | Measure-Object -Maximum).Maximum; $d = $mx - $kcount[$ck]; $title = New-Object System.Collections.ArrayList
      foreach ($v in ($src[$b][$c].Keys | Sort-Object { [int]$_ })) { if ([int]$v -le $d) { [void]$title.Add([string]$src[$b][$c][$v]) } else { $acc["${c}:$([int]$v - $d)"] = [string]$src[$b][$c][$v] } }
      if ($title.Count) { $t1 = $title -join ' '; $acc["${c}:1"] = if ($acc.ContainsKey("${c}:1")) { $t1 + ' ' + $acc["${c}:1"] } else { $t1 } }
      $used += $n; [void]$report.Add("$b $c : placed by the title rule (numbers 1 to $d are the title)"); continue
    }
    if (-not $okc -and $b -eq 'ps' -and $kcount.ContainsKey($ck) -and $n -le $kcount[$ck] -and @($src[$b][$c].Keys | ? { [int]$_ -gt $kcount[$ck] }).Count -eq 0) {   # a psalm with no separate title verse: the numbers are the English ones
      foreach ($v in $src[$b][$c].Keys) { $acc["${c}:$v"] = [string]$src[$b][$c][$v] }; $used += $n; [void]$report.Add("$b $c : placed by its own numbers (no title verse)"); continue
    }
    if (-not $okc) { $left += $n; [void]$report.Add("$b $c : $n verses left out (the chapter's verse numbers are not those of the Hebrew numbering)"); continue }
    foreach ($v in ($src[$b][$c].Keys | Sort-Object { [int]$_ })) {
      $keys = $map["${b}:${c}:$v"]; $t = [string]$src[$b][$c][$v]
      if ($acc.ContainsKey($keys[0])) { $acc[$keys[0]] = $acc[$keys[0]] + ' ' + $t } else { $acc[$keys[0]] = $t }
      for ($i = 1; $i -lt $keys.Count; $i++) { if (-not $ptr.ContainsKey($keys[$i])) { $ptr[$keys[$i]] = $keys[0] } }
      $used++
    }
  }
  $book = [ordered]@{}
  foreach ($k in (@($acc.Keys) + @($ptr.Keys | ? { -not $acc.ContainsKey($_) }) | Sort-Object { $x = $_.Split(':'); [int]$x[0] * 1000 + [int]$x[1] })) {
    $cc, $vv = $k.Split(':'); if (-not $book.Contains($cc)) { $book[$cc] = [ordered]@{} }
    $book[$cc][$vv] = if ($acc.ContainsKey($k)) { $acc[$k] } else { $f = $ptr[$k].Split(':'); if ($f[0] -eq $cc) { '^' + $f[1] } else { '^' + $ptr[$k] } }
  }
  if ($book.Count) { $out[$b] = $book }
}
$m2 = [ordered]@{}; foreach ($k in $meta.Keys) { $m2[$k] = $meta[$k] }; $m2['numbering'] = 'kjv'; $m2['alignedFrom'] = 'Hebrew numbering, through the verse table in reports/mt-to-kjv.tsv'
Write-NeutralJson "$root\aligned\$Id.json" $m2 $out
@("Verses placed by the Hebrew-numbering table: $used; verses in chapters left out: $left") + @($report) | Set-Content "$root\reports\$Id-alignment.txt" -Encoding UTF8
"$Id : $used verses placed, $left verses in $($report.Count) chapters left out"
