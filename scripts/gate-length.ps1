param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$RefTsv, [double]$Threshold = 0.45, [int]$MinVerses = 5, [switch]$Apply)
# A check for a text whose verses were placed by their numbers: in a chapter that is really aligned, each verse is about as long as the
# verse it sits beside in the reference text (Hebrew or Greek). The chapter's score is the median of |ln(length ratio / the book's usual ratio)|;
# a chapter whose verses are shifted scores high. Lengths count letters only (no vowel points, accents or punctuation).
# Without -Apply it only prints the chapters that would be dropped; with -Apply they are removed from aligned/<id>.json.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."
function Len([string]$s) { ([regex]::Replace($s.Normalize('FormD'), '[^\p{L}]', '')).Length }
$ref = @{}; foreach ($ln in [IO.File]::ReadAllLines($RefTsv, [Text.Encoding]::UTF8)) { $q = $ln.Split("`t", 4); if ($q.Count -ge 4) { $ref["$($q[0]):$($q[1]):$($q[2])"] = Len $q[3] } }
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\aligned\$Id.json", [Text.Encoding]::UTF8)); $books = $j['books']
$drop = New-Object System.Collections.ArrayList; $dropped = 0; $kept = 0
function Median($a) { $s = @($a | Sort-Object); if (-not $s.Count) { return 0 }; $m = [int][Math]::Floor($s.Count / 2); if ($s.Count % 2) { $s[$m] } else { ($s[$m - 1] + $s[$m]) / 2 } }
foreach ($b in @($books.Keys)) {
  $all = @(); $perCh = @{}
  foreach ($c in $books[$b].Keys) { $rs = @(); foreach ($v in $books[$b][$c].Keys) { $t = [string]$books[$b][$c][$v]; if ($t.StartsWith('^')) { continue }; $rl = $ref["${b}:${c}:$v"]; $sl = Len $t; if ($rl -gt 0 -and $sl -gt 0) { $rs += [Math]::Log($sl / $rl) } }; $perCh[$c] = $rs; $all += $rs }
  $R = Median $all
  foreach ($c in @($books[$b].Keys)) {
    $rs = $perCh[$c]; $score = if ($rs.Count) { Median ($rs | % { [Math]::Abs($_ - $R) }) } else { 0 }
    if ($rs.Count -ge $MinVerses -and $score -gt $Threshold) { [void]$drop.Add(("{0} {1} (score {2:N2}, {3} verses)" -f $b, $c, $score, $rs.Count)); $dropped += $books[$b][$c].Count; if ($Apply) { [void]$books[$b].Remove($c) } } else { $kept += $books[$b][$c].Count }
  }
  if ($Apply -and $books[$b].Count -eq 0) { [void]$books.Remove($b) }
}
"{0}: {1} verses kept, {2} verses in {3} chapters over the threshold" -f $Id, $kept, $dropped, $drop.Count
$drop | select -first 60
if ($Apply) { $out = [ordered]@{}; foreach ($b in $books.Keys) { $out[$b] = $books[$b] }; Write-NeutralJson "$root\aligned\$Id.json" $j['meta'] $out; Add-Content "$root\reports\$Id-alignment.txt" (@('', "Length check against $RefTsv (threshold $Threshold): left out") + @($drop)) -Encoding UTF8 }
