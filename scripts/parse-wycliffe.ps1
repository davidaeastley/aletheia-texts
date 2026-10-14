param([string]$Src, [string]$Id = 'wycliffe')
# Parses the Wikisource transcription "Bible (Wycliffe)" (one wikitext file per book, saved by the fetch step).
. "$PSScriptRoot\lib.ps1"
$map = [ordered]@{
 'Genesis'='gen';'Exodus'='exod';'Leviticus'='lev';'Numbers'='num';'Deuteronomy'='deut';'Joshua'='josh';'Judges'='judg';'Ruth'='ruth'
 '1 Kings'='1sam';'2 Kings'='2sam';'3 Kings'='1kgs';'4 Kings'='2kgs';'1 Paralipomenon'='1chr';'2 Paralipomenon'='2chr'
 '1 Esdras'='ezra';'2 Esdras'='neh';'3 Esdras'='1esd';'Tobit'='tob';'Judith'='jdt';'Esther'='esth';'Job'='job';'Psalms'='ps';'Proverbs'='prov'
 'Ecclesiastes'='eccl';'Songes of Songes'='song';'Wisdom'='wis';'Syrach'='sir';'Isaiah'='isa';'Jeremiah'='jer';'Lamentations'='lam'
 'Baruk'='bar';'Preier of Jeremye'='epjer';'Ezechiel'='ezek';'Daniel'='dan';'Osee'='hos';'Joel'='joel';'Amos'='amos';'Abdias'='obad'
 'Jonas'='jonah';'Mychee'='mic';'Naum'='nah';'Abacuk'='hab';'Sofonye'='zeph';'Aggey'='hag';'Sacarie'='zech';'Malachie'='mal'
 '1 Machabeis'='1macc';'2 Machabeis'='2macc';'Matheu'='matt';'Mark'='mark';'Luke'='luke';'John'='john';'Dedis of Apostlis'='acts';'Romaynes'='rom'
 '1 Corinthis'='1cor';'2 Corinthis'='2cor';'Galathies'='gal';'Effesies'='eph';'Filipensis'='phil';'Colosencis'='col'
 '1 Thessalonycensis'='1thess';'2 Thessalonycensis'='2thess';'1 Tymothe'='1tim';'2 Tymothe'='2tim';'Tite'='titus';'Filemon'='phlm'
 'Ebrews'='heb';'James'='jas';'1 Petre'='1pet';'2 Petre'='2pet';'1 Joon'='1john';'2 Joon'='2john';'3 Joon'='3john';'Judas'='jude';'Apocalips'='rev';'Laodicensis'='laod'
}
$order = @{}; $i = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $i++ }
$warn = New-Object System.Collections.ArrayList
$tmp = @{}
foreach ($name in $map.Keys) {
  $f = Join-Path $Src (($name -replace '[^A-Za-z0-9 ]', '_') + '.txt')
  if (-not (Test-Path $f)) { [void]$warn.Add("missing file for $name"); continue }
  $t = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
  $t = [regex]::Replace($t, '<ref[^>]*?/>', ''); $t = [regex]::Replace($t, '<ref[^>]*>.*?</ref>', '', 'Singleline')
  $t = [regex]::Replace($t, '<section [^>]*/>', ''); $t = [regex]::Replace($t, '</?(onlyinclude|noinclude|includeonly)>', '')
  $t = [regex]::Replace($t, '<references\s*/>', '')
  $book = [ordered]@{}
  $ms = [regex]::Matches($t, '\{\{verse\|chapter=(\d+)\|verse=(\d+)\}\}')
  for ($k = 0; $k -lt $ms.Count; $k++) {
    $start = $ms[$k].Index + $ms[$k].Length
    $end = if ($k + 1 -lt $ms.Count) { $ms[$k + 1].Index } else { $t.Length }
    $seg = $t.Substring($start, $end - $start)
    $cut = [regex]::Match($seg, '(?m)^(==|\{\{biblecontents|\{\{chapter)'); if ($cut.Success) { $seg = $seg.Substring(0, $cut.Index) }
    $seg = [regex]::Replace($seg, "\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", '$1'); $seg = $seg -replace "'''?", ''
    $txt = ($seg -replace '\s+', ' ').Trim()
    $c = $ms[$k].Groups[1].Value; $v = $ms[$k].Groups[2].Value
    if (-not $book.Contains($c)) { $book[$c] = [ordered]@{} }
    if ($book[$c].Contains($v)) { [void]$warn.Add("duplicate $name ${c}:${v}") }
    if ($txt -eq '') { [void]$warn.Add("empty $name ${c}:${v}") }
    $book[$c][$v] = $txt
  }
  $tmp[$map[$name]] = $book
}
$data = [ordered]@{}; foreach ($bk in ($tmp.Keys | Sort-Object { $order[$_] })) { $data[$bk] = $tmp[$bk] }
$meta = [ordered]@{ id = $Id; name = 'Wycliffe Bible (c. 1395, Later Version)'; year = '1388-1395'; source = 'Wikisource, Bible (Wycliffe)'; license = 'Public domain'; numbering = 'vulgate'; note = 'Middle English; Vulgate book names and numbering' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $data
$nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($data.Count) books, $nv verses, $($warn.Count) warnings"
$warn | Set-Content "$PSScriptRoot\..\reports\$Id-warnings.txt" -Encoding UTF8; $warn | Select-Object -First 15
