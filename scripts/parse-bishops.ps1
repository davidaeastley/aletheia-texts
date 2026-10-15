param([Parameter(Mandatory)][string]$Src, [string]$Id = 'bishops')
# Parses bishops.json: {"metadata":{...},"verses":[{"book_name","book","chapter","verse","text"}, ...]} into neutral/<id>.json.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 200MB
$j = $ser.DeserializeObject([IO.File]::ReadAllText($Src, [Text.Encoding]::UTF8))
$names = @{}; $nums = @{}
foreach ($v in $j['verses']) { $nums[[int]$v['book']] = [string]$v['book_name'] }
"book numbers: $($nums.Count): " + (($nums.Keys | sort | % { "$_=$($nums[$_])" }) -join ', ')
$canon = @($script:BookRows | ? { $_.group -ne 'apoc' } | % { $_.id })
$data = @{}; $skipped = @{}
foreach ($v in $j['verses']) {
  $n = [int]$v['book']; $bn = [string]$v['book_name']
  $bid = if ($n -le 66) { $canon[$n - 1] } else { $null }
  if (-not $bid) { $skipped[$bn] = 1 + [int]$skipped[$bn]; continue }
  $c = [string]$v['chapter']; $vv = [string]$v['verse']
  if (-not $data.ContainsKey($bid)) { $data[$bid] = [ordered]@{} }
  if (-not $data[$bid].Contains($c)) { $data[$bid][$c] = [ordered]@{} }
  $data[$bid][$c][$vv] = ([string]$v['text'] -replace '\s+', ' ').Trim()
}
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$out = [ordered]@{}; foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) { $out[$b] = $data[$b] }
$md = $j['metadata']
$meta = [ordered]@{ id = $Id; name = "Bishops' Bible (1568)"; year = '1568'; source = 'supplied file bishops.json (' + $md['module_version'] + ')'; license = 'Public domain'; numbering = 'kjv'; note = 'Original 1568 spelling' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses; skipped (not in the 66 canonical books): " + (($skipped.Keys | % { "$_ $($skipped[$_])" }) -join ', ')
