param([Parameter(Mandatory)][string]$Dir, [string]$Id = 'peshitta-ot')
# Reads the Syriac Old Testament (ETCBC "plain" text files, one per book: "Chapter N", then "N text" lines, long verses wrap) into neutral/<id>.json.
. "$PSScriptRoot\lib.ps1"
$files = [ordered]@{ gen='Genesis'; exod='Exodus'; lev='Leviticus'; num='Numbers'; deut='Deuteronomy'; josh='Joshua'; judg='Judges'; ruth='Ruth'; '1sam'='Samuel_1'; '2sam'='Samuel_2'; '1kgs'='Kings_1'; '2kgs'='Kings_2'; '1chr'='Chronicles_1'; '2chr'='Chronicles_2'; ezra='Ezra'; neh='Nehemia'; esth='Esther'; job='Job'; ps='Psalms'; prov='Proverbs'; eccl='Ecclesiastes'; song='Song_of_Songs'; isa='Isaiah'; jer='Jeremiah'; lam='Lamentations'; ezek='Ezekiel'; dan='Daniel'; hos='Hosea'; joel='Joel'; amos='Amos'; obad='Obadiah'; jonah='Jonah'; mic='Micah'; nah='Nahum'; hab='Habakkuk'; zeph='Zephaniah'; hag='Haggai'; zech='Zechariah'; mal='Malachi' }
$out = [ordered]@{}
foreach ($b in $files.Keys) {
  $path = Join-Path $Dir ($files[$b] + '.txt'); if (-not (Test-Path $path)) { continue }
  $book = [ordered]@{}; $ch = $null; $vn = $null; $buf = $null
  $flush = { if ($null -ne $vn) { $t = (($buf -join ' ') -replace '\s+', ' ').Trim(); if ($t -ne '') { $book[$ch][$vn] = $t } }; $script:vn = $null; $script:buf = $null }
  foreach ($line in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
    if ($line -match '^\s*Chapter\s+(\d+)\s*$') { & $flush; $ch = [string][int]$Matches[1]; if (-not $book.Contains($ch)) { $book[$ch] = [ordered]@{} }; continue }
    if ($null -eq $ch -or $line.Trim() -eq '') { continue }
    if ($line -match '^(\d+)\s+(.*)$') { & $flush; $vn = [string][int]$Matches[1]; $buf = New-Object System.Collections.ArrayList; [void]$buf.Add($Matches[2]); continue }
    if ($null -ne $vn) { [void]$buf.Add($line.Trim()) }
  }
  & $flush
  $out[$b] = $book
}
$meta = [ordered]@{ id = $Id; name = 'Syriac Old Testament (Peshitta, 2nd century)'; year = 'from the 2nd century'; source = 'ETCBC peshitta, plain text 0.2 (github.com/ETCBC/peshitta; text of the Leiden Peshitta Institute edition)'; license = 'MIT (ETCBC / Dirk Roorda)'; numbering = 'hebrew'; note = 'Syriac; Old Testament only' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses"
