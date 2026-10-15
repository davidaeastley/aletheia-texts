param([Parameter(Mandatory)][string]$Src, [string]$Id = 'nrsvue-apoc')
# Parses the "Apocrypha" section of the NRSVue JSON into neutral/<id>.json (KJV-Apocrypha book ids).
# Letter of Jeremiah becomes Baruch 6 (as in the KJV Apocrypha); the Greek Esther is not imported (its additions are woven into the whole book).
# Editorial notes at the start of some books (e.g. "(a) The books ... are recognized as Deuterocanonical Scripture ...") are removed.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 200MB
$a = ($ser.DeserializeObject([IO.File]::ReadAllText($Src, [Text.Encoding]::UTF8)))['Apocrypha']
$map = [ordered]@{ 'Tobit' = 'tob'; 'Judith' = 'jdt'; 'Wisdom Of Solomon' = 'wis'; 'Sirach' = 'sir'; 'Baruch' = 'bar'; 'Letter Of Jeremiah' = 'bar'; 'Prayer Of Azariah' = 'sg3'; 'Susanna' = 'sus'; 'Bel And The Dragon' = 'bel'; '1 Maccabees' = '1macc'; '2 Maccabees' = '2macc'; '1 Esdras' = '1esd'; 'Prayer Of Manasseh' = 'prman'; 'Psalm 151' = 'ps151'; '3 Maccabees' = '3macc'; '2 Esdras' = '2esd'; '4 Maccabees' = '4macc' }
$sup = '[' + [char]0x2070 + [char]0xB9 + [char]0xB2 + [char]0xB3 + [char]0x2074 + '-' + [char]0x2079 + ']'
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$data = @{}; $skipped = @(); $dropped = New-Object System.Collections.ArrayList
foreach ($name in $a.Keys) {
  if (-not $map.Contains($name)) { $skipped += $name; continue }
  $bid = $map[$name]; if (-not $data.ContainsKey($bid)) { $data[$bid] = [ordered]@{} }
  foreach ($c0 in $a[$name].Keys) {
    $c = if ($name -eq 'Letter Of Jeremiah') { '6' } else { [string]$c0 }
    foreach ($v in $a[$name][$c0].Keys) {
      $x = [string]$a[$name][$c0][$v]
      $x = [regex]::Replace($x, "^\s*$sup+\s*", ''); $x = [regex]::Replace($x, $sup + '+', '')
      if ($c0 -eq '1' -and $v -eq '1') {   # editorial note in front of the first verse of a book
        $paras = [regex]::Split($x.Trim(), "\n\s*\n")
        if ($paras.Count -gt 1 -and $paras[0] -match '^\((a|b|c|d)\)|^Note:|^\(Additions to') { [void]$dropped.Add("${bid}: " + $paras[0].Substring(0, [Math]::Min(60, $paras[0].Length))); $x = ($paras[1..($paras.Count - 1)] -join "`n") }
        elseif ($paras.Count -eq 1 -and $paras[0] -match '^\(Additions to') { [void]$dropped.Add("${bid}: " + $paras[0]); $x = '' }
      }
      $x = [regex]::Replace($x, '^[,;:\s]+', '')
      $lines = @(($x -split "`n") | % { ($_ -replace '[ \t ]+', ' ').Trim() } | ? { $_ -ne '' }); $t = $lines -join "`n"
      if ($t -eq '') { continue }
      if (-not $data[$bid].Contains($c)) { $data[$bid][$c] = [ordered]@{} }
      $data[$bid][$c][[string]$v] = $t
    }
  }
}
$out = [ordered]@{}; foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) { $out[$b] = $data[$b] }
$meta = [ordered]@{ id = $Id; name = 'New Revised Standard Version Updated Edition (Apocrypha)'; year = '2021'; source = 'supplied bible.json (gist sebastiancarlos/2fdb072e46ee80038d6da196cc0bb8bc)'; license = 'Copyright 2021 National Council of the Churches of Christ in the USA; private use only, not for redistribution'; numbering = 'kjv'; note = 'Apocrypha; Greek Esther not imported' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses; skipped: $($skipped -join ', '); editorial notes removed: $($dropped.Count)"; $dropped
"books: " + (($out.Keys | % { "$_($(($out[$_].Keys).Count)ch)" }) -join ' ')
