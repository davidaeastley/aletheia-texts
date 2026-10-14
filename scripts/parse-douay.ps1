param([string]$Src, [string]$Id = 'douay-rheims-challoner')
. "$PSScriptRoot\lib.ps1"
$map = [ordered]@{
 'Genesis'='gen';'Exodus'='exod';'Leviticus'='lev';'Numbers'='num';'Deuteronomy'='deut';'Josue'='josh';'Judges'='judg';'Ruth'='ruth'
 '1 Kings'='1sam';'2 Kings'='2sam';'3 Kings'='1kgs';'4 Kings'='2kgs';'1 Paralipomenon'='1chr';'2 Paralipomenon'='2chr'
 '1 Esdras'='ezra';'2 Esdras'='neh';'Tobias'='tob';'Judith'='jdt';'Esther'='esth';'Job'='job';'Psalms'='ps';'Proverbs'='prov'
 'Ecclesiastes'='eccl';'Canticle of Canticles'='song';'Wisdom'='wis';'Ecclesiasticus'='sir';'Isaias'='isa';'Jeremias'='jer'
 'Lamentations'='lam';'Baruch'='bar';'Ezechiel'='ezek';'Daniel'='dan';'Osee'='hos';'Joel'='joel';'Amos'='amos';'Abdias'='obad'
 'Jonas'='jonah';'Micheas'='mic';'Nahum'='nah';'Habacuc'='hab';'Sophonias'='zeph';'Aggeus'='hag';'Zacharias'='zech';'Malachias'='mal'
 '1 Machabees'='1macc';'2 Machabees'='2macc';'Matthew'='matt';'Mark'='mark';'Luke'='luke';'John'='john';'Acts'='acts';'Romans'='rom'
 '1 Corinthians'='1cor';'2 Corinthians'='2cor';'Galatians'='gal';'Ephesians'='eph';'Philippians'='phil';'Colossians'='col'
 '1 Thessalonians'='1thess';'2 Thessalonians'='2thess';'1 Timothy'='1tim';'2 Timothy'='2tim';'Titus'='titus';'Philemon'='phlm'
 'Hebrews'='heb';'James'='jas';'1 Peter'='1pet';'2 Peter'='2pet';'1 John'='1john';'2 John'='2john';'3 John'='3john';'Jude'='jude';'Apocalypse'='rev'
}
$warn = New-Object System.Collections.ArrayList
$L = Get-Content $Src -Encoding UTF8
$start = ($L | Select-String -Pattern '^Genesis Chapter 1\s*$' | Select-Object -First 1).LineNumber - 1
$end = ($L | Select-String -SimpleMatch '*** END OF THE PROJECT GUTENBERG' | Select-Object -First 1).LineNumber - 1
$data = [ordered]@{}; $bid = $null; $ch = $null; $script:off = 0; $para = New-Object Collections.Generic.List[string]
function AddVerse([string]$txt) {
  if ($txt -match '^(\d+):(\d+)[.:]?\s+(.*)$') {
    if ($null -eq $bid) { return }
    $c = $Matches[1]; $v = [string]([int]$Matches[2] + $(if ($script:off -gt 0 -and $Matches[1] -eq $ch) { $script:off } else { 0 })); $t = ($Matches[3] -replace '\s+', ' ').Trim()
    if ($c -ne $ch) { [void]$warn.Add("verse chapter mismatch ${bid} heading $ch vs marker ${c}:${v}") }
    if (-not $data[$bid].Contains($c)) { $data[$bid][$c] = [ordered]@{} }
    if ($data[$bid][$c].Contains($v)) { [void]$warn.Add("duplicate ${bid} ${c}:${v}") }
    $data[$bid][$c][$v] = $t
  }
}
function EndPara {
  if ($para.Count -eq 0) { return }
  $txt = ($para -join ' ').Trim(); $para.Clear()
  if ($txt -match '^\(Psalm Chapter \d+ according to the Hebrews') { $script:off = $data[$bid][$ch].Count; return }
  if ($txt -match '^\d+:\d+[.:]?\s') { foreach ($piece in [regex]::Split($txt, '\s{2,}(?=\d+:\d+[.:]?\s+\S)')) { AddVerse $piece.Trim() } }
}
for ($i = $start; $i -lt $end; $i++) {
  $ln = $L[$i]
  if ($ln -match '^(.+?) Chapter (\d+)(\s.*)?$' -and $map.Contains($Matches[1])) {
    EndPara; $script:off = 0; $bid = $map[$Matches[1]]; $ch = $Matches[2]
    if (-not $data.Contains($bid)) { $data[$bid] = [ordered]@{} }
    continue
  }
  if ($ln.Trim() -eq '') { EndPara; continue }
  if ($ln -match '^\d+:\d+[.:]?\s') { EndPara }
  $para.Add($ln.Trim())
}
EndPara
$meta = [ordered]@{ id = $Id; name = 'Douay-Rheims Bible (Challoner revision)'; year = '1749-1752'; source = 'Project Gutenberg #8300'; license = 'Public domain'; numbering = 'vulgate'; note = 'Challoner modernised spelling; Psalms use Vulgate numbering' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $data
$nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($data.Count) books, $nv verses, $($warn.Count) warnings"; $warn | Set-Content "$PSScriptRoot\..\reports\$Id-warnings.txt" -Encoding UTF8; ($warn | % { ($_ -replace '\d+:\d+','') -replace '\s+\S+$','' } | Group-Object | % { "$($_.Count) x $($_.Name)" })