# The NRSVue source file (gist bible.json) stops at Psalm 119:100. This adds verses 101-176 from private/nrsvue-ps119-101-176.txt
# (text supplied by the owner; the NRSVue is copyrighted and private/ is not published) to neutral/nrsvue.json.
# Run it after parse-nrsvue.ps1 and before align.ps1.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."
$lines = [IO.File]::ReadAllLines("$root\private\nrsvue-ps119-101-176.txt", [Text.Encoding]::UTF8)
$verses = [ordered]@{}; $cur = $null
foreach ($l in $lines) {
  if ($l -match '^\s*(\d+)\s*$') { $cur = [string][int]$Matches[1]; $verses[$cur] = New-Object System.Collections.ArrayList; continue }
  if ($null -eq $cur) { continue }
  $t = ([regex]::Replace($l, '\[[a-z]\]', '')).Trim()   # footnote markers
  if ($t -ne '') { [void]$verses[$cur].Add($t) }
}
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\nrsvue.json", [Text.Encoding]::UTF8)); $meta = $j['meta']; $books = $j['books']
$ps = $books['ps']['119']; $added = 0
foreach ($v in $verses.Keys) { if ([int]$v -lt 101 -or [int]$v -gt 176) { continue }; $ps[$v] = ($verses[$v] -join "`n"); $added++ }
$out = [ordered]@{}; foreach ($b in $books.Keys) { $out[$b] = $books[$b] }
$sorted = [ordered]@{}; foreach ($v in ($ps.Keys | Sort-Object { [int]$_ })) { $sorted[$v] = $ps[$v] }; $out['ps']['119'] = $sorted
Write-NeutralJson "$root\neutral\nrsvue.json" $meta $out
"Psalm 119: $added verses added, now $($sorted.Count) verses"
