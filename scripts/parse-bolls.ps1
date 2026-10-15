param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Name, [string]$Year = '', [string]$Source = '', [string]$License = 'Public domain', [string]$Numbering = 'kjv', [string]$Note = '')
# Parses a Bible JSON of the form {"metadata":{...},"verses":[{"book":1,"chapter":1,"verse":1,"text":"..."}]} (books numbered 1-66 in the usual order)
# into neutral/<id>.json. Strong's markers such as {H776} and any HTML tags are removed.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = [int]::MaxValue
$j = $ser.DeserializeObject([IO.File]::ReadAllText($Src, [Text.Encoding]::UTF8))
$bible = @($script:BookRows | ? { $_.group -ne 'apoc' })
$data = @{}; $empty = 0
foreach ($x in $j['verses']) {
  $b = $bible[[int]$x['book'] - 1].id
  $t = [string]$x['text']
  $t = [regex]::Replace($t, '\{[HG]\d+[a-z]?\}', ''); $t = [regex]::Replace($t, '<[^>]+>', ' ')
  $t = $t.Replace('&nbsp;', ' ').Replace('&amp;', '&')
  $t = ($t -replace '\s+', ' ').Trim()
  if ($t -eq '') { $empty++; continue }
  $c = [string][int]$x['chapter']; $v = [string][int]$x['verse']
  if (-not $data.ContainsKey($b)) { $data[$b] = [ordered]@{} }
  if (-not $data[$b].Contains($c)) { $data[$b][$c] = [ordered]@{} }
  $data[$b][$c][$v] = $t
}
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$out = [ordered]@{}; foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) {
  $bk = [ordered]@{}; foreach ($c in ($data[$b].Keys | Sort-Object { [int]$_ })) { $ch = [ordered]@{}; foreach ($v in ($data[$b][$c].Keys | Sort-Object { [int]$_ })) { $ch[$v] = $data[$b][$c][$v] }; $bk[$c] = $ch }
  $out[$b] = $bk }
$meta = [ordered]@{ id = $Id; name = $Name; year = $Year; source = $Source; license = $License; numbering = $Numbering; note = $Note }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses (empty skipped: $empty)"
