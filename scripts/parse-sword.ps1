param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Name, [string]$Year = '', [string]$Source = '', [string]$License = 'Public domain', [string]$Numbering = 'kjv', [string]$Note = '', [switch]$DropSectionHeadings)   # -DropSectionHeadings: also remove untyped <title> section headings found inside verse entries (the BSB has them), keeping Psalm superscriptions
# Reads an unpacked CrossWire SWORD zText module (OSIS markup, zlib) and writes neutral/<id>.json.
# $Dir = the module's data folder (.../modules/texts/ztext/<name>). Book and chapter boundaries come from the OSIS markers inside the entries.
. "$PSScriptRoot\lib.ps1"
Add-Type -TypeDefinition ([IO.File]::ReadAllText("$PSScriptRoot\SwordZText.cs")) -Language CSharp -ReferencedAssemblies System.IO.Compression -ErrorAction SilentlyContinue
$osis = @{
 Gen='gen';Exod='exod';Lev='lev';Num='num';Deut='deut';Josh='josh';Judg='judg';Ruth='ruth';'1Sam'='1sam';'2Sam'='2sam';'1Kgs'='1kgs';'2Kgs'='2kgs';'1Chr'='1chr';'2Chr'='2chr';Ezra='ezra';Neh='neh';Esth='esth';Job='job';Ps='ps';Prov='prov';Eccl='eccl';Song='song';Isa='isa';Jer='jer';Lam='lam';Ezek='ezek';Dan='dan';Hos='hos';Joel='joel';Amos='amos';Obad='obad';Jonah='jonah';Mic='mic';Nah='nah';Hab='hab';Zeph='zeph';Hag='hag';Zech='zech';Mal='mal'
 Matt='matt';Mark='mark';Luke='luke';John='john';Acts='acts';Rom='rom';'1Cor'='1cor';'2Cor'='2cor';Gal='gal';Eph='eph';Phil='phil';Col='col';'1Thess'='1thess';'2Thess'='2thess';'1Tim'='1tim';'2Tim'='2tim';Titus='titus';Phlm='phlm';Heb='heb';Jas='jas';'1Pet'='1pet';'2Pet'='2pet';'1John'='1john';'2John'='2john';'3John'='3john';Jude='jude';Rev='rev'
 Tob='tob';Jdt='jdt';AddEsth='addesth';Wis='wis';Sir='sir';Bar='bar';EpJer='epjer';PrAzar='sg3';Sus='sus';Bel='bel';'1Macc'='1macc';'2Macc'='2macc';'3Macc'='3macc';'4Macc'='4macc';'1Esd'='1esd';'2Esd'='2esd';PrMan='prman';Ps151='ps151';Laod='laod';EpLao='laod'
}
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
function Clean-Osis([string]$t) {
  $t = [regex]::Replace($t, '<title\b[^>]*type="parallel"[^>]*>.*?</title>', '', 'Singleline')   # cross-reference headings such as (John 1:1-5)
  if ($DropSectionHeadings) { $t = [regex]::Replace($t, '<title\b(?![^>]*type="psalm")[^>]*>.*?</title>', '', 'Singleline') }
  $t = [regex]::Replace($t, '<note\b[^>]*?/>', ''); $t = [regex]::Replace($t, '<note\b[^>]*>.*?</note>', '', 'Singleline')
  $t = [regex]::Replace($t, '<[^>]+>', '')
  $t = $t.Replace('&amp;', '&').Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"').Replace('&apos;', "'").Replace('&#39;', "'")
  ($t -replace '\s+', ' ').Trim()
}
$data = @{}; $warn = New-Object System.Collections.ArrayList; $unknown = @{}
foreach ($t in 'ot', 'nt') {
  if (-not (Test-Path (Join-Path $Dir "$t.bzv"))) { continue }
  $entries = [SwordZText]::ReadTestament($Dir, $t)
  $bk = $null; $ch = $null; $v = 0
  foreach ($e in $entries) {
    if ($null -ne $e -and $e -match 'type="book"' -and $e -match 'osisID="([^"]+)"') {
      $o = $Matches[1]; if ($osis.ContainsKey($o)) { $bk = $osis[$o] } else { $bk = $null; $unknown[$o] = 1 }; $ch = $null; $v = 0; continue }
    if ($null -ne $e -and $e -match '<chapter\b[^>]*osisID="([^"]+)\.(\d+)"') { $o = $Matches[1]; $ch = $Matches[2]; $v = 0; if ($osis.ContainsKey($o)) { $bk = $osis[$o] } else { $bk = $null; $unknown[$o] = 1 }; continue }
    if ($null -eq $bk -or $null -eq $ch) { continue }
    $v++
    if ($null -eq $e) { continue }
    $txt = Clean-Osis $e
    if ($txt -eq '') { continue }
    if (-not $data.ContainsKey($bk)) { $data[$bk] = [ordered]@{} }
    if (-not $data[$bk].Contains($ch)) { $data[$bk][$ch] = [ordered]@{} }
    $data[$bk][$ch][[string]$v] = $txt
  }
}
$out = [ordered]@{}; foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) { $out[$b] = $data[$b] }
$meta = [ordered]@{ id = $Id; name = $Name; year = $Year; source = $Source; license = $License; numbering = $Numbering; note = $Note }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses; unknown OSIS ids: $(($unknown.Keys | sort) -join ',')"
"books: " + (($out.Keys | % { "$_($(($out[$_].Keys).Count)ch)" }) -join ' ')
