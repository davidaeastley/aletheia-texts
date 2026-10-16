param([string]$Id = 'ja-kougo')
# The Japanese Kougo-yaku text (bolls.life JPKJV) marks every verse whose number differs from the English Bible with the English verse in square brackets:
#   [5] = English verse 5 of this chapter, [31:55] = English chapter 31, verse 55, [4-5] = English verses 4 and 5, [3a] / [3b] = the first / second part of verse 3,
#   [0] = a Psalm title. A verse can hold several markers, and a verse starting with * repeats the verse before it.
# This reads those markers and writes aligned/<id>.json in KJV numbering, with no guessing.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\$Id.json", [Text.Encoding]::UTF8)); $meta = $j['meta']; $src = $j['books']
$kset = New-Object 'System.Collections.Generic.HashSet[string]' (, [IO.File]::ReadAllLines("$root\reports\kjv-keys.txt"))
$out = [ordered]@{}; $report = New-Object System.Collections.ArrayList; $extra = @(); $stars = 0; $mt = New-Object System.Collections.ArrayList   # $mt: which English verses each source (Hebrew-numbered) verse supplies, for reports/mt-to-kjv.tsv
foreach ($b in $src.Keys) {
  $acc = @{}   # "c:v" -> text parts, in order
  $ptr = @{}
  $add = { param($key, $text) $text = $text.Trim(); if ($text -eq '') { return }; if (-not $acc.ContainsKey($key)) { $acc[$key] = New-Object System.Collections.ArrayList }; [void]$acc[$key].Add($text) }
  foreach ($c in ($src[$b].Keys | Sort-Object { [int]$_ })) {
    $titles = New-Object System.Collections.ArrayList; $lastV = $null
    foreach ($v in ($src[$b][$c].Keys | Sort-Object { [int]$_ })) {
      $t = [string]$src[$b][$c][$v]
      if ($t.StartsWith('*')) { $stars++; [void]$report.Add("$b ${c}:$v repeats the verse before it (skipped)"); continue }
      $parts = [regex]::Split($t, '(\[[^\]]*\])')   # text, marker, text, marker, text ...
      $vk = New-Object System.Collections.ArrayList
      $key = if ($null -ne $lastV) { "${c}:$($lastV + 1)" } else { "${c}:$v" }   # text before any marker follows the previous verse's English number
      $lastV = [int]$key.Split(':')[1]   # (it moves on when a marker names another verse)
      for ($i = 0; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        if ($i % 2 -eq 1) {
          $m = $p.Trim('[', ']')
          if ($m -match '^0+$') { $key = 'TITLE'; $lastV = 0 }
          elseif ($m -match '^(\d+):(\d+)b?$') { $key = "$($Matches[1]):$($Matches[2])"; $lastV = [int]$Matches[2] }
          elseif ($m -match '^(\d+)-(\d+)$') { $a = [int]$Matches[1]; $z = [int]$Matches[2]; $key = "${c}:$a"; for ($q = $a + 1; $q -le $z; $q++) { $ptr["${c}:$q"] = $a; if (-not $vk.Contains("${c}:$q")) { [void]$vk.Add("${c}:$q") } }; $lastV = $z }
          elseif ($m -match '^(\d+)[ab]?$') { $key = "${c}:$($Matches[1])"; $lastV = [int]$Matches[1] }
          else { [void]$report.Add("$b ${c}:$v unknown marker $p") }
        }
        else {
          if ($key -eq 'TITLE') { if ($p.Trim()) { [void]$titles.Add($p.Trim()); if (-not $vk.Contains("${c}:1")) { [void]$vk.Add("${c}:1") } } } else { & $add $key $p; if ($p.Trim() -and -not $vk.Contains($key)) { [void]$vk.Add($key) } }
        }
      }
      if ($vk.Count) { [void]$mt.Add("$b	$c	$v	$($vk -join ',')") }
    }
    if ($titles.Count) { $k1 = "${c}:1"; if (-not $acc.ContainsKey($k1)) { $acc[$k1] = New-Object System.Collections.ArrayList }; $acc[$k1].Insert(0, ($titles -join ' ').Trim()) }
  }
  $book = [ordered]@{}; $lastKept = $null
  $keys = @($acc.Keys + $ptr.Keys | Sort-Object -Unique { $x = $_.Split(':'); [int]$x[0] * 1000 + [int]$x[1] })
  foreach ($k in $keys) {
    $cc, $vv = $k.Split(':')
    if (-not $kset.Contains("${b}:$k")) { $extra += "${b}:$k"; if ($lastKept -and $acc.ContainsKey($k)) { $lc, $lv = $lastKept.Split(':'); $book[$lc][$lv] = $book[$lc][$lv] + ($acc[$k] -join '') }; continue }   # a verse the English Bible has not: it joins the verse before it
    if (-not $book.Contains($cc)) { $book[$cc] = [ordered]@{} }
    $lastKept = "${cc}:$vv"
    $book[$cc][$vv] = if ($acc.ContainsKey($k)) { ($acc[$k] -join '') } else { '^' + $ptr[$k] }
  }
  if ($b -eq '2cor' -and $book.Contains('13') -and $book['13'].Contains('13') -and -not $book['13'].Contains('14')) {   # this text has 13 verses in 2 Corinthians 13: its verse 12 holds English 12 and 13, its verse 13 is English 14 (not marked in the text)
    $book['13']['14'] = $book['13']['13']; $book['13']['13'] = '^12'; [void]$report.Add('2cor 13:13 is English verse 14; English 13 is part of verse 12') }
  $out[$b] = $book
}
[IO.File]::WriteAllLines("$root\reports\mt-to-kjv.tsv", $mt, (New-Object Text.UTF8Encoding($false)))
$m2 = [ordered]@{}; foreach ($k in $meta.Keys) { $m2[$k] = $meta[$k] }; $m2['numbering'] = 'kjv'; $m2['alignedFrom'] = 'English verse markers in the text'
Write-NeutralJson "$root\aligned\$Id.json" $m2 $out
$have = New-Object 'System.Collections.Generic.HashSet[string]'; foreach ($b in $out.Keys) { foreach ($c in $out[$b].Keys) { foreach ($v in $out[$b][$c].Keys) { [void]$have.Add("${b}:${c}:${v}") } } }
$missing = @($kset | ? { -not $have.Contains($_) })
@("Verse markers in the text give the English numbering.", "$stars repeated verses skipped", "KJV verses with no text: $($missing.Count)", "Mapped to verses the KJV lacks (dropped): $($extra.Count) $($extra -join ' ')") + @($report) | Set-Content "$root\reports\$Id-alignment.txt" -Encoding UTF8
"$Id : $($have.Count) KJV verses filled; KJV verses missing: $($missing.Count) ($(($missing | select -first 12) -join ' ')); outside the KJV numbering: $($extra.Count) ($(($extra | select -first 12) -join ' '))"
