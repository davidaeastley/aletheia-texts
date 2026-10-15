param([Parameter(Mandatory)][string]$PagesDir, [string]$Id = 'great')
# Parses the downloaded Great Bible chapter pages (<tr><td class="ref">c:v</td><td>text</td></tr>) into neutral/<id>.json.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web
$canon = @($script:BookRows | ? { $_.group -ne 'apoc' } | % { $_.id })
$data = [ordered]@{}; $warn = New-Object System.Collections.ArrayList; $pages = 0
for ($bn = 1; $bn -le 66; $bn++) {
  $bid = $canon[$bn - 1]; $data[$bid] = [ordered]@{}
  for ($c = 1; ; $c++) {
    $f = Join-Path $PagesDir "${bn}_${c}.html"; if (-not (Test-Path $f)) { break }
    $pages++
    $h = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($h, '<tr><td class="ref">(\d+):(\d+)</td><td>(.*?)</td></tr>', 'Singleline')) {
      $cc = $m.Groups[1].Value; $vv = $m.Groups[2].Value
      if ($cc -ne [string]$c) { [void]$warn.Add("page $bn/$c holds chapter $cc") }
      $t = [Web.HttpUtility]::HtmlDecode(([regex]::Replace($m.Groups[3].Value, '<[^>]+>', ''))); $t = ($t -replace '\s+', ' ').Trim()
      if (-not $data[$bid].Contains($cc)) { $data[$bid][$cc] = [ordered]@{} }
      $data[$bid][$cc][$vv] = $t
      if ($t -eq '') { [void]$warn.Add("empty $bid ${cc}:${vv}") }
    }
  }
}
$meta = [ordered]@{ id = $Id; name = 'The Great Bible (1539)'; year = '1539'; source = 'textusreceptus.thekingsbible.com (Great Bible 1539)'; license = 'Text public domain; transcription from textusreceptusbibles.com, terms not stated'; numbering = 'kjv'; note = 'Original 1539 spelling; the 66 canonical books' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $data
$nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : 66 books, $pages pages, $nv verses, $($warn.Count) warnings"; $warn | Select-Object -First 10
$warn | Set-Content "$PSScriptRoot\..\reports\$Id-warnings.txt" -Encoding UTF8
