param([Parameter(Mandatory)][string]$Src, [string]$Id = 'nrsvue')
# Parses the NRSVue JSON ({"Old Testament": {"Genesis": {"1": {"1": "¹ text"}}}, "New Testament": ..., "Apocrypha": ...}) into neutral/<id>.json.
# Only the 66 canonical books are kept (the Apocrypha section is not imported). Verse numbers printed at the start of each text are removed;
# poetry line breaks are kept as "\n" (the reader shows them), indentation is dropped.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 200MB
$j = $ser.DeserializeObject([IO.File]::ReadAllText($Src, [Text.Encoding]::UTF8))
$canon = @($script:BookRows | ? { $_.group -ne 'apoc' } | % { $_.id })
$sup = '[' + [char]0x2070 + [char]0xB9 + [char]0xB2 + [char]0xB3 + [char]0x2074 + '-' + [char]0x2079 + ']'
$data = [ordered]@{}; $empty = New-Object System.Collections.ArrayList
$bi = 0
foreach ($testament in 'Old Testament', 'New Testament') {
  foreach ($bookName in $j[$testament].Keys) {
    $bid = $canon[$bi]; $bi++; $data[$bid] = [ordered]@{}
    foreach ($c in $j[$testament][$bookName].Keys) {
      foreach ($v in $j[$testament][$bookName][$c].Keys) {
        $x = [string]$j[$testament][$bookName][$c][$v]
        $x = [regex]::Replace($x, "^\s*$sup+\s*", ''); $x = [regex]::Replace($x, $sup + '+', ''); $x = [regex]::Replace($x, '^[,;:\s]+', '')
        $lines = @(($x -split "`n") | % { ($_ -replace '[ \t ]+', ' ').Trim() } | ? { $_ -ne '' })
        $t = $lines -join "`n"
        if ($t -eq '') { [void]$empty.Add("$bid ${c}:${v}"); continue }
        if (-not $data[$bid].Contains($c)) { $data[$bid][$c] = [ordered]@{} }
        $data[$bid][$c][[string]$v] = $t
      }
    }
  }
}
"books mapped: $bi (expected 66); verses without text (omitted in this translation): $($empty.Count): $($empty -join ', ')"
$meta = [ordered]@{ id = $Id; name = 'New Revised Standard Version Updated Edition'; year = '2021'; source = 'supplied bible.json (gist sebastiancarlos/2fdb072e46ee80038d6da196cc0bb8bc)'; license = 'Copyright 2021 National Council of the Churches of Christ in the USA; private use only, not for redistribution'; numbering = 'kjv'; note = '66 books; the Apocrypha section of the source is not imported' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $data
$nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($data.Count) books, $nv verses"
