param([string]$Id = 'wessex-gospels', [string]$Cache = "$env:TEMP\hist\wessex")
# The West Saxon (Wessex) Gospels from Wikisource: Matthew (J. W. Bright, 1910; one page per chapter), Mark (Bright, 1905) and Luke.
# (John is not on Wikisource.) The pages are fetched through the Wikisource API (a pause between requests) and kept in $Cache.
# Verse numbers are read in order: a number counts as the start of the next verse only if it is the verse number that is expected.
. "$PSScriptRoot\lib.ps1"
New-Item -ItemType Directory -Force $Cache | Out-Null
$h = @{ 'User-Agent' = 'AletheiaApp/1.0 (personal Bible study app; contact davidaeastley@gmail.com)' }
function Api([string]$q) { Start-Sleep -Milliseconds 400; Invoke-RestMethod "https://en.wikisource.org/w/api.php?$q&format=json&redirects=1" -Headers $h }
function Rendered([string]$title, [string]$file) {
  $f = Join-Path $Cache $file; if (Test-Path $f) { return [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) }
  $r = Api "action=parse&disablelimitreport=1&prop=text&page=$([uri]::EscapeDataString($title))"; $x = $r.parse.text.'*'
  [IO.File]::WriteAllText($f, $x, (New-Object Text.UTF8Encoding($false))); $x
}
function Wikitext([string]$title, [string]$file) {
  $f = Join-Path $Cache $file; if (Test-Path $f) { return [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) }
  $r = Api "action=parse&prop=wikitext&page=$([uri]::EscapeDataString($title))"; $x = $r.parse.wikitext.'*'
  [IO.File]::WriteAllText($f, $x, (New-Object Text.UTF8Encoding($false))); $x
}
function PlainHtml([string]$x) {
  $x = [regex]::Replace($x, '<style[^>]*>.*?</style>', '', 'Singleline'); $x = [regex]::Replace($x, '<table.*?</table>', '', 'Singleline'); $x = [regex]::Replace($x, '<sup[^>]*class="reference".*?</sup>', '', 'Singleline')
  $x = [regex]::Replace($x, '<[^>]+>', ' '); [Net.WebUtility]::HtmlDecode(([regex]::Replace($x, '\s+', ' ')))
}
# split a chapter's text into verses: "1 text 2 text ..." (or "1. text"), taking each number only when it is the next expected verse
function SplitVerses([string]$t) {
  $v = [ordered]@{}; $next = 1; $pos = 0; $starts = @()
  while ($true) {
    $m = [regex]::Match($t.Substring($pos), "(?<![\p{L}\p{N}])$next\.?\s+(?=\S)")
    if (-not $m.Success -and $next -gt 1) { $m = [regex]::Match($t.Substring($pos), "(?<![\p{L}\p{N}])$($next - 1)\.?\s+(?=\S)") }   # a misprinted number (the edition has 32 twice in Matthew 23): the repeat counts as the next verse
    if (-not $m.Success) { break }
    $starts += @{ n = $next; at = $pos + $m.Index; len = $m.Length }; $pos = $pos + $m.Index + $m.Length; $next++
  }
  for ($i = 0; $i -lt $starts.Count; $i++) {
    $a = $starts[$i].at + $starts[$i].len; $b = if ($i + 1 -lt $starts.Count) { $starts[$i + 1].at } else { $t.Length }
    $s = $t.Substring($a, $b - $a); $s = [regex]::Replace($s, '(?s)\s*(Category:|\|\s*translation).*$', ''); $s = $s.Replace([string][char]0x2191, '')   # page footers that come with the last verse
    $s = ($s -replace '\s+', ' ').Trim(); if ($s -ne '') { $v[[string]$starts[$i].n] = $s }
  }
  $v
}
$data = @{}
# Matthew: Chapter 1 ... 28
$mt = [ordered]@{}
for ($c = 1; $c -le 28; $c++) {
  $x = Rendered "Evangelium Secundum Mattheum: the Gospel of Saint Matthew in West-Saxon/Chapter $c" "mt$c.html"; $t = PlainHtml $x
  $i = $t.IndexOf('CAPUT'); if ($i -ge 0) { $t = $t.Substring($i); $t = [regex]::Replace($t, '^CAPUT\s+[IVXL]+\s*', '') }
  $t = [regex]::Replace($t, '\[\s*\d+\s*\]', ' ')   # page numbers of the printed edition
  $t = [regex]::Replace($t, '(?s)\bTransclusion.*$', ''); $t = [regex]::Replace($t, '(?s)\bNewPP.*$', '')
  $t = [regex]::Replace($t, '(?s)\s(A|B|Corp\.)\s,\s.*$', '')   # the list of variant readings under the chapter
  $vs = SplitVerses $t; if ($vs.Count) { $mt[[string]$c] = $vs }
}
$data['matt'] = $mt
# Mark and Luke: one page, a heading for every chapter ("==1 Heafodweard==" in Mark)
foreach ($g in @(@('mark', 'The Gospel of Saint Mark in West-Saxon'), @('luke', 'The Gospel of Saint Luke in West-Saxon'))) {
  $w = Wikitext $g[1] "$($g[0]).wiki"; $bk = [ordered]@{}
  $parts = [regex]::Split($w, '(?m)^==([^=\r\n]+)==\s*$')   # text, heading, text, heading ...
  $ch = 0
  for ($i = 1; $i -lt $parts.Count; $i += 2) {
    $ch++; $body = $parts[$i + 1]
    $body = [regex]::Replace($body, '\{\{[^}]*\}\}', ' '); $body = [regex]::Replace($body, '<[^>]+>', ' '); $body = [regex]::Replace($body, '\[\[(?:[^\]|]*\|)?([^\]]*)\]\]', '$1'); $body = $body.Replace("'''", '').Replace("''", '')
    $body = [regex]::Replace($body, '(?m)^:', ''); $body = ($body -replace '\s+', ' ').Trim()
    $vs = SplitVerses $body; if ($vs.Count) { $bk[[string]$ch] = $vs }
  }
  $data[$g[0]] = $bk
}
$out = [ordered]@{}; foreach ($b in 'matt', 'mark', 'luke') { if ($data[$b].Count) { $out[$b] = $data[$b] } }
$meta = [ordered]@{ id = $Id; name = 'West Saxon Gospels (Wessex Gospels, c. 990)'; year = 'c. 990'; source = 'Wikisource: Matthew (ed. J. W. Bright, 1910), Mark (Bright, 1905) and Luke in West Saxon'; license = 'Text public domain; Wikisource transcription CC BY-SA 4.0'; numbering = 'kjv'; note = 'Old English; Matthew, Mark and Luke (John is not on Wikisource)' }
Write-NeutralJson "$PSScriptRoot\..\neutral\$Id.json" $meta $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses"
foreach ($b in $out.Keys) { "$b : $($out[$b].Count) chapters, $((($out[$b].Values | % { $_.Count }) | measure -Sum).Sum) verses" }
