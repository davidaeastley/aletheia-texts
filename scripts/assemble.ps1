# Splits each aligned/<id>.json into packs/bible/<id>.json (OT+NT) and packs/apoc/<id>.json (Apocrypha),
# then writes packs/manifest.json (sizes + SHA-256) for the app's download screen.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$order = @{}; $i = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $i++ }
$grp = @{}; foreach ($b in $script:BookRows) { $grp[$b.id] = $b.group }
$out = "$PSScriptRoot\..\packs"; New-Item -ItemType Directory -Force "$out\bible", "$out\apoc" | Out-Null
$entries = @()
$noApoc = @('ru-synodal')   # packs whose Apocrypha is not published: the Russian one cannot be placed against the English KJV Apocrypha (different alphabet)
$withheld = @('great')   # not published: the Great Bible transcription came from a site whose terms do not allow it to be stored elsewhere (see README)
$baseBuildOnly = @('nrsvue', 'bsb')   # shipped inside the app only. (The NRSVue Apocrypha, aligned/nrsvue-apoc.json, is published at the owner's request as the pack "nrsvue"; the NRSVue Bible is not.)
foreach ($f in (Get-ChildItem "$PSScriptRoot\..\aligned\*.json")) {
  if ($baseBuildOnly -contains $f.BaseName -or $withheld -contains $f.BaseName) { continue }
  $j = $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)); $meta = $j['meta']; $id = $meta['id']
  if ($id -eq 'nrsvue-apoc') { $id = 'nrsvue'; $meta['id'] = 'nrsvue'; $meta['license'] = 'Copyright 2021 National Council of the Churches of Christ in the USA. The copyright holder keeps all rights.' }
  foreach ($kind in 'bible', 'apoc') {
    if ($noApoc -contains $id -and $kind -eq 'apoc') { continue }
    if ($id -eq 'kjv' -and $kind -eq 'bible') { continue }   # the app already contains the KJV; only its Apocrypha is published
    $ids = @($j['books'].Keys | ? { ($grp[$_] -eq 'apoc') -eq ($kind -eq 'apoc') } | Sort-Object { $order[$_] })
    $p = "$out\$kind\$id.json"
    if ($ids.Count -eq 0) { if (Test-Path $p) { Remove-Item $p }; continue }
    $data = [ordered]@{}; foreach ($b in $ids) { $data[$b] = $j['books'][$b] }
    $m = [ordered]@{}; foreach ($k in $meta.Keys) { $m[$k] = $meta[$k] }; $m['kind'] = $kind; $m['books'] = ($ids -join ',')
    Write-NeutralJson $p $m $data
    if ($kind -eq 'bible' -and (Test-Path "$PSScriptRoot\..\aligned\$id.strongs")) { $pt = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8).TrimEnd(); $pt = $pt.Substring(0, $pt.Length - 1).TrimEnd() + ",`n ""strongs"": " + [IO.File]::ReadAllText("$PSScriptRoot\..\aligned\$id.strongs", [Text.Encoding]::UTF8) + "`n}
"; [IO.File]::WriteAllText($p, $pt, (New-Object Text.UTF8Encoding($false))) }   # word-by-word Strong's numbers (Textus Receptus)
    $nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
    $sha = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
    $entries += [pscustomobject]@{ id = $id; kind = $kind; name = $meta['name']; year = $meta['year']; license = $meta['license']; file = "$kind/$id.json"; bytes = (Get-Item $p).Length; sha256 = $sha; books = $ids; verses = $nv }
    "{0,-26} {1,-5} {2,3} books {3,6} verses {4,9} bytes" -f $id, $kind, $ids.Count, $nv, (Get-Item $p).Length
  }
}
# dictionaries (packs/dict/*.json, made by build-webster.ps1) are listed too: they have entries, not books
foreach ($f in (Get-ChildItem "$out\dict\*.json" -ErrorAction SilentlyContinue)) {
  $j = $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)); $meta = $j['meta']
  $entries += [pscustomobject]@{ id = $meta['id']; kind = 'dict'; name = $meta['name']; year = $meta['year']; license = $meta['license']; file = "dict/$($f.Name)"; bytes = $f.Length; sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower(); books = @(); verses = @($j['entries']).Count }
  "{0,-26} dict  {1,6} entries {2,9} bytes" -f $meta['id'], @($j['entries']).Count, $f.Length
}
# the Pseudepigrapha (packs\pseud\ps-<text>.json, made by Aletheia\tools\pseud): one pack of kind "apoc" for each text, so the app can download it.
# A pack made from a copyrighted source goes in private\pseud instead and is not listed here.
foreach ($f in (Get-ChildItem "$out\pseud\ps-*.json" -ErrorAction SilentlyContinue)) {
  $j = $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)); $meta = $j['meta']; $nv = 0; foreach ($b in $j['books'].Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
  $entries += [pscustomobject]@{ id = $meta['id']; kind = 'apoc'; name = $meta['name']; year = $meta['year']; license = $meta['license']; file = "pseud/$($f.Name)"; bytes = $f.Length; sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower(); books = @($j['books'].Keys); verses = $nv }
  "{0,-26} pseud {1,6} verses {2,9} bytes" -f $meta['id'], $nv, $f.Length
}
# Other downloads: grammars, interlinear, the church-history map (with its terrain and boundaries) and the Bible Quiz. Their files are made elsewhere; they are only listed here.
$others = @(
  @('grammar', 'hebrew-alfred', 'grammar/hebrew-alfred.json', 'Simplified Hebrew Grammar by Justin Alfred', 'Freely available from Justin Alfred through Blue Letter Bible'),
  @('grammar', 'greek-alfred', 'grammar/greek-alfred.json', 'Simplified Greek Grammar by Justin Alfred', 'Freely available from Justin Alfred through Blue Letter Bible'),
  @('interlinear', 'bsb-interlinear', 'interlinear/bsb.json', 'Interlinear - BSB (Old Testament)', 'Berean Bible translation tables (berean.bible); the BSB is in the public domain'),
  @('interlinear', 'bsb-interlinear-nt', 'interlinear/bsb-nt.json', 'Interlinear - BSB (New Testament)', 'Berean Bible translation tables (berean.bible); the BSB is in the public domain'),
  @('map', 'church-map', 'map/church-map.json', 'Interactive Map of Church History', 'Places: OpenBible.info Bible Geocoding Data (CC BY 4.0) and the Doctrine and Covenants places compiled for Aletheia; base map: Natural Earth (public domain); Leaflet (BSD-2-Clause)'),
  @('map-terrain', 'church-map-terrain', 'map/terrain.json', 'Interactive Map of Church History - terrain', 'Natural Earth I with shaded relief (public domain)'),
  @('map-bounds', 'church-map-bounds', 'map/bounds.json', 'Interactive Map of Church History - boundaries', 'Old World kingdom boundaries compiled for Aletheia from general historical knowledge (approximate); US state and territory boundaries: Atlas of Historical County Boundaries, Newberry Library (CC BY-NC-SA 2.5), generalised; land: Natural Earth (public domain)'),
  @('quiz', 'bible-quiz', 'quiz/bible-quiz.json', 'Bible Quiz', 'Questions and explanations from Bible Hub (biblehub.com/trivia)'),
  @('jod', 'jod', 'jod/jod.json', 'The Journal of Discourses', 'The text is in the public domain; the details of each discourse are CC0 (jod.mrm.org)'),

  @('comm', 'comm-clarke', 'comm/clarke.json', 'Clarke, Commentary and Critical Notes on the Bible', 'Public-domain work; the text is from Wikisource (CC BY-SA 4.0) and this file is shared under CC BY-SA 4.0')
)
foreach ($o in $others) {
  $f = Get-Item "$out\$($o[2])" -ErrorAction SilentlyContinue; if (-not $f) { continue }
  $e = [ordered]@{ id = $o[1]; kind = $o[0]; name = $o[3]; year = ''; license = $o[4]; file = $o[2]; bytes = $f.Length; sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower() }
  if ($o[0] -eq 'grammar') { $e['modules'] = @($ser.DeserializeObject([IO.File]::ReadAllText($f.FullName))['modules'].Keys) }
  if ($o[0] -eq 'interlinear') { $e['books'] = @($ser.DeserializeObject([IO.File]::ReadAllText($f.FullName))['books'].Keys) }
  $entries += [pscustomobject]$e
  "{0,-26} {1,-11} {2,9} bytes" -f $o[1], $o[0], $f.Length
}
$sb = New-Object Text.StringBuilder; [void]$sb.Append("{`n""version"": 1,`n""packs"": [`n")
for ($k = 0; $k -lt $entries.Count; $k++) { $e = $entries[$k]
  [void]$sb.Append('  {"id": ' + (JsonStr $e.id) + ', "kind": ' + (JsonStr $e.kind) + ', "name": ' + (JsonStr $e.name) + ', "year": ' + (JsonStr $e.year) + ', "license": ' + (JsonStr $e.license) + ', "file": ' + (JsonStr $e.file) + ', "bytes": ' + $e.bytes + ', "sha256": ' + (JsonStr $e.sha256) + $(if ($null -ne $e.verses) { ', "verses": ' + $e.verses } else { '' }) + $(if ($null -ne $e.books) { ', "books": [' + (($e.books | % { '"' + $_ + '"' }) -join ',') + ']' } else { '' }) + $(if ($null -ne $e.modules) { ', "modules": [' + (($e.modules | % { '"' + $_ + '"' }) -join ',') + ']' } else { '' }) + '}')
  if ($k -lt $entries.Count - 1) { [void]$sb.Append(",`n") } }
[void]$sb.Append("`n]`n}`n"); [IO.File]::WriteAllText("$out\manifest.json", $sb.ToString(), (New-Object Text.UTF8Encoding($false)))