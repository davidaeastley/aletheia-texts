param([Parameter(Mandatory)][string]$Dir, [string]$Id = 'coptic-sahidic', [string]$Name = 'Coptic Bible (Sahidic)', [string]$Year = '3rd century', [string]$Source = '', [string]$License = 'CC BY-SA 4.0', [string]$Numbering = 'lxx', [string]$Note = '')
# Reads a CrossWire zText module whose entries carry their own reference, as <ab n="B01K1V1" xml:id="Gen.1.1...."><w>word</w> ...</ab>
# (the Sahidic Bible 2 module): the Old Testament by the OSIS id in xml:id, the New Testament by the book number in n="B##K#V#".
# Verses with no <w> words (lost in the manuscripts) are left out. Writes neutral/<id>.json.
. "$PSScriptRoot\lib.ps1"
Add-Type -TypeDefinition ([IO.File]::ReadAllText("$PSScriptRoot\SwordZText.cs")) -Language CSharp -ReferencedAssemblies System.IO.Compression -ErrorAction SilentlyContinue
$osis = @{ Gen='gen';Exod='exod';Lev='lev';Num='num';Deut='deut';Josh='josh';Judg='judg';Ruth='ruth';'1Sam'='1sam';'2Sam'='2sam';'1Kgs'='1kgs';'2Kgs'='2kgs';'1Chr'='1chr';'2Chr'='2chr';Ezra='ezra';Neh='neh';Esth='esth';Job='job';Ps='ps';Prov='prov';Eccl='eccl';Song='song';Isa='isa';Jer='jer';Lam='lam';Ezek='ezek';Dan='dan';Hos='hos';Joel='joel';Amos='amos';Obad='obad';Jonah='jonah';Mic='mic';Nah='nah';Hab='hab';Zeph='zeph';Hag='hag';Zech='zech';Mal='mal' }
$nt = @('matt','mark','luke','john','acts','rom','1cor','2cor','gal','eph','phil','col','1thess','2thess','1tim','2tim','titus','phlm','heb','jas','1pet','2pet','1john','2john','3john','jude','rev')
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$data = @{}; $skipped = @{}
function Words([string]$e) {
  $t = [regex]::Replace($e, '<note\b[^>]*>.*?</note>', '', 'Singleline')
  $ws = [regex]::Matches($t, '<w\b[^>]*>(.*?)</w>', 'Singleline') | % { [regex]::Replace($_.Groups[1].Value, '<[^>]+>', '').Trim() } | ? { $_ -ne '' }
  (($ws -join ' ') -replace '\s+', ' ').Trim()
}
foreach ($t in 'ot', 'nt') {
  if (-not (Test-Path (Join-Path $Dir "$t.bzv"))) { continue }
  foreach ($e in [SwordZText]::ReadTestament($Dir, $t)) {
    if ($null -eq $e) { continue }
    $bk = $null; $c = $null; $v = $null
    if ($t -eq 'ot' -and $e -match 'xml:id="([A-Za-z0-9]+)\.(\d+)\.(\d+)\.') { $o = $Matches[1]; $c = $Matches[2]; $v = $Matches[3]; if ($osis.ContainsKey($o)) { $bk = $osis[$o] } else { $skipped[$o] = 1; continue } }
    elseif ($t -eq 'nt' -and $e -match '<ab n="B(\d+)K(\d+)V(\d+)"') { $n = [int]$Matches[1]; $c = $Matches[2]; $v = $Matches[3]; if ($n -ge 1 -and $n -le 27) { $bk = $nt[$n - 1] } else { continue } }
    if ($null -eq $bk) { continue }
    $txt = Words $e; if ($txt -eq '') { continue }
    $c = [string][int]$c; $v = [string][int]$v
    if (-not $data.ContainsKey($bk)) { $data[$bk] = [ordered]@{} }; if (-not $data[$bk].Contains($c)) { $data[$bk][$c] = [ordered]@{} }
    $data[$bk][$c][$v] = $txt
  }
}
$out = [ordered]@{}
foreach ($b in ($data.Keys | Sort-Object { $order[$_] })) { $bk = [ordered]@{}; foreach ($c in ($data[$b].Keys | Sort-Object { [int]$_ })) { $ch = [ordered]@{}; foreach ($v in ($data[$b][$c].Keys | Sort-Object { [int]$_ })) { $ch[$v] = $data[$b][$c][$v] }; $bk[$c] = $ch }; $out[$b] = $bk }
$meta = [ordered]@{ id = $Id; name = $Name; year = $Year; source = $Source; license = $License; numbering = $Numbering; note = $Note }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses; skipped books (not in the 66): $(($skipped.Keys | sort) -join ',')"
"books: " + (($out.Keys | % { "$_($(($out[$_].Values | % { $_.Count } | measure -Sum).Sum))" }) -join ' ')
