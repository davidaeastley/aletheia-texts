param([string]$DataDir = "$env:USERPROFILE\AndroidStudioProjects\Aletheia\tools\db\source\data")
# Builds the Clementine Vulgate pack from the per-book files the app used to carry (vul_<book>.js).
# Those verses are already in KJV numbering (merged/split verses are marked with ^N pointers), so no alignment is needed:
# the result goes straight to aligned/vulgate-clementine.json. It also writes reports/clementine-bible.tsv (the verses
# that carry text), which align.ps1 -RefTsv uses to place the Jerome Vulgate.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 200MB
$root = "$PSScriptRoot\.."; New-Item -ItemType Directory -Force "$root\aligned" | Out-Null
$out = [ordered]@{}; $tsv = New-Object System.Collections.ArrayList; $ptr = New-Object System.Collections.ArrayList
foreach ($b in $script:BookRows) {
  if ($b.group -eq 'apoc') { continue }
  $f = "$DataDir\vul_$($b.id).js"; if (-not (Test-Path $f)) { continue }
  $t = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8); $i = $t.IndexOf(']={')
  $d = $ser.DeserializeObject($t.Substring($i + 2).TrimEnd().TrimEnd(';'))
  $chs = @{}
  foreach ($k in $d.Keys) { $p = $k.Split(':'); $x = [string]$d[$k]; if (-not $x.Trim()) { continue }; if (-not $chs.ContainsKey($p[0])) { $chs[$p[0]] = @{} }; $chs[$p[0]][$p[1]] = $x }
  $book = [ordered]@{}
  foreach ($c in ($chs.Keys | Sort-Object { [int]$_ })) {
    $book[$c] = [ordered]@{}
    foreach ($v in ($chs[$c].Keys | Sort-Object { [int]$_ })) { $x = $chs[$c][$v]; $book[$c][$v] = $x; if ($x.StartsWith('^')) { [void]$ptr.Add("$($b.id)`t$c`t$v`t$x") } else { [void]$tsv.Add("$($b.id)`t$c`t$v`t$($x -replace '[\t\r\n]+', ' ')") } }
  }
  $out[$b.id] = $book
}
$meta = [ordered]@{ id = 'vulgate-clementine'; name = 'Latin Vulgate (Clementine)'; year = '1592'; source = 'Clementine Vulgate Project / VulSearch (Michael Tweedale)'; license = 'Public domain'; numbering = 'kjv'; note = 'Latin; verses aligned to the KJV numbering (merged verses marked)' }
Write-NeutralJson "$root\aligned\vulgate-clementine.json" $meta $out
[IO.File]::WriteAllLines("$root\reports\clementine-bible.tsv", $tsv, (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines("$root\reports\clementine-bible-pointers.tsv", $ptr, (New-Object Text.UTF8Encoding($false)))
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"vulgate-clementine : $($out.Count) books, $nv verses ($($tsv.Count) with text)"
