param([Parameter(Mandatory)][string]$Src, [string]$Id = 'textus-receptus')
# Scrivener's 1894 Textus Receptus, accented and punctuated, from github.com/honza/textus-receptus (data/gnt.flat.json): one record per verse with the text in "greek_text".
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = [int]::MaxValue
$rows = $ser.DeserializeObject([IO.File]::ReadAllText($Src, [Text.Encoding]::UTF8))
$ids = @{}; foreach ($b in $script:BookRows) { $ids[$b.id.ToLower()] = $b.id }
$data = @{}; $unk = @{}; $n = 0
foreach ($x in $rows) {
  $k = ([string]$x['book_name_osis']).ToLower(); $bid = if ($ids.ContainsKey($k)) { $ids[$k] } else { $null }
  if (-not $bid) { $unk[$k] = 1; continue }
  $t = (([string]$x['greek_text']) -replace '\s+', ' ').Trim(); if ($t -eq '') { continue }
  $c = [string][int]$x['chapter']; $v = [string][int]$x['verse']
  if (-not $data.ContainsKey($bid)) { $data[$bid] = [ordered]@{} }; if (-not $data[$bid].Contains($c)) { $data[$bid][$c] = [ordered]@{} }
  $data[$bid][$c][$v] = $t; $n++
}
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$out = [ordered]@{}; foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) { $bk = [ordered]@{}; foreach ($c in ($data[$b].Keys | Sort-Object { [int]$_ })) { $ch = [ordered]@{}; foreach ($v in ($data[$b][$c].Keys | Sort-Object { [int]$_ })) { $ch[$v] = $data[$b][$c][$v] }; $bk[$c] = $ch }; $out[$b] = $bk }
$meta = [ordered]@{ id = $Id; name = 'Textus Receptus (Scrivener 1894)'; year = '1894'; source = 'Scrivener 1894 edition of the Textus Receptus, accented and punctuated, from github.com/honza/textus-receptus'; license = 'Free to use without limitation (credit requested): honza/textus-receptus'; numbering = 'kjv'; note = 'Greek; the New Testament' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
"$Id : $($out.Count) books, $n verses; unknown books: $($unk.Keys -join ' ')"