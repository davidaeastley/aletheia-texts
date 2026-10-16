param([Parameter(Mandatory)][string]$Xml, [string]$Id = 'sinaiticus')
# Reads the Codex Sinaiticus Project's XML transcription (github.com/itsee-birmingham/codex-sinaiticus, CC BY-NC-SA 3.0) into neutral/<id>.json.
# Each verse is an <ab xml:id="V-B33K5V3-33-MATT">: book number, chapter and verse are in the id. The text of a verse is its words in order:
#   - the first hand's reading where a corrector changed a word (the corrector's, only where the first hand left a gap),
#   - line breaks, hyphens, punctuation points, running titles and the Eusebian numbers in the margin are left out,
#   - the lunate sigma of the manuscript is written as an ordinary sigma so that the text can be searched,
#   - abbreviations (nomina sacra) are as the scribe wrote them, with the expansions the project marks inside them.
# Barnabas, Hermas, the Apocrypha and the leaf fragments are not taken (they have no place in the 66 books).
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Xml.Linq
$ids = @{ GEN='gen'; LEV='lev'; NUM='num'; DEUT='deut'; JOSH='josh'; JUDG='judg'; '1CHR'='1chr'; '2ESD'='ezra'; EST='esth'; ISA='isa'; JER='jer'; LAM='lam'; JOEL='joel'; OBAD='obad'; JONAH='jonah'; NAH='nah'; HAB='hab'; ZEPH='zeph'; HAG='hag'; ZECH='zech'; MAL='mal'; PS='ps'; PROV='prov'; ECCL='eccl'; CANT='song'; JOB='job'
  MATT='matt'; MARK='mark'; LUKE='luke'; JOHN='john'; ROM='rom'; '1COR'='1cor'; '2COR'='2cor'; GAL='gal'; EPH='eph'; PHIL='phil'; COL='col'; '1THESS'='1thess'; '2THESS'='2thess'; HEB='heb'; '1TIM'='1tim'; '2TIM'='2tim'; TITUS='titus'; PHLM='phlm'; ACTS='acts'; JAS='jas'; '1PET'='1pet'; '2PET'='2pet'; '1JOHN'='1john'; '2JOHN'='2john'; '3JOHN'='3john'; JUDE='jude'; REV='rev' }
$SKIP = @{ note = 1; fw = 1; ptr = 1; graphic = 1; pc = 1; lb = 1; cb = 1; pb = 1; handShift = 1 }
$lunate = [string][char]0x3F2; $LUNATE = [string][char]0x3F9; $sg = [string][char]0x3C3; $SG = [string][char]0x3A3   # (hashtable keys ignore case, so these are plain variables)
function Txt($n) {
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.Nodes()) {
    if ($c.NodeType -eq 'Text') { [void]$sb.Append($c.Value); continue }
    if ($c.NodeType -ne 'Element') { continue }
    $nm = $c.Name.LocalName
    if ($SKIP.ContainsKey($nm)) { continue }
    if ($nm -eq 'gap') { [void]$sb.Append('[.]'); continue }
    [void]$sb.Append((Txt $c))
  }
  $sb.ToString()
}
function Words($n, $list) {
  foreach ($c in $n.Elements()) {
    $nm = $c.Name.LocalName
    if ($SKIP.ContainsKey($nm)) { continue }
    if ($nm -eq 'seg' -and ($c.Attribute('type').Value -eq 'margin')) { continue }
    if ($nm -eq 'w') { $t = (Txt $c).Trim(); if ($t -ne '') { [void]$list.Add($t) }; continue }
    if ($nm -eq 'app') {
      $orig = @($c.Elements() | ? { $_.Attribute('type') -and $_.Attribute('type').Value -eq 'orig' }); $corr = @($c.Elements() | ? { $_.Attribute('type') -and $_.Attribute('type').Value -eq 'corr' })
      $try = New-Object System.Collections.ArrayList; foreach ($o in $orig) { Words $o $try }
      if ($try.Count -eq 0 -or (($try -join '') -match '^\[\.\]+$')) { $try = New-Object System.Collections.ArrayList; if ($corr.Count) { Words $corr[$corr.Count - 1] $try } }
      foreach ($x in $try) { [void]$list.Add($x) }; continue
    }
    Words $c $list
  }
}
$set = New-Object Xml.XmlReaderSettings; $set.DtdProcessing = 'Ignore'; $set.XmlResolver = $null
$rd = [Xml.XmlReader]::Create($Xml, $set)
$data = @{}; $n = 0
$xmlNs = [Xml.Linq.XNamespace]::Xml
$rd.Read() | Out-Null
while (-not $rd.EOF) {
  if ($rd.NodeType -ne 'Element' -or $rd.LocalName -ne 'ab') { $rd.Read() | Out-Null; continue }
  $ab = [Xml.Linq.XElement]::ReadFrom($rd)   # (ReadFrom leaves the reader on the node after the element, so no extra Read here)
  $xid = $ab.Attribute($xmlNs + 'id'); if ($null -eq $xid) { continue }
  if ($xid.Value -notmatch '^V-B(\d+)K(\d+)V(\d+)-\d+-([A-Z0-9]+)') { continue }
  $code = $Matches[4]; $c = [int]$Matches[2]; $v = [int]$Matches[3]
  if (-not $ids.ContainsKey($code) -or $v -lt 1 -or $c -lt 1) { continue }
  $bk = $ids[$code]
  if ($code -eq '2ESD' -and $c -gt 10) { $bk = 'neh'; $c -= 10 }   # 2 Esdras holds Ezra (1-10) and Nehemiah (11-23)
  $words = New-Object System.Collections.ArrayList; Words $ab $words
  $t = ($words -join ' '); $t = $t.Replace($lunate, $sg).Replace($LUNATE, $SG); $t = ($t -replace '\s+', ' ').Trim()
  if ($t -eq '') { continue }
  if (-not $data.ContainsKey($bk)) { $data[$bk] = @{} }; if (-not $data[$bk].ContainsKey($c)) { $data[$bk][$c] = @{} }
  if ($data[$bk][$c].ContainsKey($v)) { $data[$bk][$c][$v] = $data[$bk][$c][$v] + ' ' + $t } else { $data[$bk][$c][$v] = $t }
  $n++
}
$rd.Close()
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$out = [ordered]@{}
foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) { $bk = [ordered]@{}; foreach ($c in ($data[$b].Keys | Sort-Object)) { $ch = [ordered]@{}; foreach ($v in ($data[$b][$c].Keys | Sort-Object)) { $ch[[string]$v] = $data[$b][$c][$v] }; $bk[[string]$c] = $ch }; $out[$b] = $bk }
$meta = [ordered]@{ id = $Id; name = 'Codex Sinaiticus (4th century)'; year = 'c. 350'; source = 'The Codex Sinaiticus Project transcription v1.95 (github.com/itsee-birmingham/codex-sinaiticus), first-hand readings, lunate sigma written as sigma'; license = 'CC BY-NC-SA 3.0 (Codex Sinaiticus Project): non-commercial use only, with credit and the same licence'; numbering = 'lxx'; note = 'Greek; the parts of the Old Testament and the New Testament that the codex has' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses"
"books: " + (($out.Keys | % { "$_($(($out[$_].Values | % { $_.Count } | measure -Sum).Sum))" }) -join ' ')
