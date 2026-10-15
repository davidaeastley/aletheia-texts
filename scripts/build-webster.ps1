param([Parameter(Mandatory)][string]$Csv)
# Builds packs/dict/webster1828.json from webster1828.csv (github.com/akaitsurugi/webster1828, a typed copy of Noah Webster's
# 1828 American Dictionary of the English Language; the CSV has two columns, a word and its entry as HTML).
# Pack layout: { "meta": {...}, "entries": [ ["word", "<p><b>WORD</b>, ... </p>"], ... ] }
. "$PSScriptRoot\lib.ps1"
$rows = Import-Csv -Path $Csv -Header word, html -Encoding UTF8
$out = "$PSScriptRoot\..\packs\dict"; New-Item -ItemType Directory -Force $out | Out-Null
$sb = New-Object Text.StringBuilder
$meta = [ordered]@{ id = 'webster1828'; kind = 'dict'; name = "Webster's 1828 American Dictionary of the English Language"; year = '1828'
  source = 'webster1828.csv from github.com/akaitsurugi/webster1828 (typed from the 1828 edition, checked against the archive.org scans)'
  license = 'CC BY-SA 4.0 (the 1828 text itself is public domain); credit: akaitsurugi/webster1828'; count = @($rows).Count }
[void]$sb.Append("{`n""meta"": {")
$first = $true; foreach ($k in $meta.Keys) { if (-not $first) { [void]$sb.Append(', ') }; $first = $false; $v = $meta[$k]; [void]$sb.Append((JsonStr $k) + ': ' + $(if ($v -is [int]) { "$v" } else { JsonStr ([string]$v) })) }
[void]$sb.Append("},`n""entries"": [`n")
$n = 0; $skipped = 0
foreach ($r in $rows) {
  $w = ([string]$r.word).Trim(); $h = ([string]$r.html).Trim()
  if ($w -eq '' -or $h -eq '') { $skipped++; continue }
  if ($n -gt 0) { [void]$sb.Append(",`n") }
  [void]$sb.Append('[' + (JsonStr $w) + ',' + (JsonStr $h) + ']'); $n++
}
[void]$sb.Append("`n]`n}`n")
[IO.File]::WriteAllText("$out\webster1828.json", $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
"webster1828 : $n entries ($skipped skipped), $([math]::Round((Get-Item "$out\webster1828.json").Length / 1MB, 1)) MB"
