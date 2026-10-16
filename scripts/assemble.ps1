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
$baseBuildOnly = @('nrsvue', 'nrsvue-apoc', 'bsb')   # shipped inside the app only; NRSVue is copyrighted and must never be published here
foreach ($f in (Get-ChildItem "$PSScriptRoot\..\aligned\*.json")) {
  if ($baseBuildOnly -contains $f.BaseName -or $withheld -contains $f.BaseName) { continue }
  $j = $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)); $meta = $j['meta']; $id = $meta['id']
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
$sb = New-Object Text.StringBuilder; [void]$sb.Append("{`n""version"": 1,`n""packs"": [`n")
for ($k = 0; $k -lt $entries.Count; $k++) { $e = $entries[$k]
  [void]$sb.Append('  {"id": ' + (JsonStr $e.id) + ', "kind": ' + (JsonStr $e.kind) + ', "name": ' + (JsonStr $e.name) + ', "year": ' + (JsonStr $e.year) + ', "license": ' + (JsonStr $e.license) + ', "file": ' + (JsonStr $e.file) + ', "bytes": ' + $e.bytes + ', "sha256": ' + (JsonStr $e.sha256) + ', "verses": ' + $e.verses + ', "books": [' + (($e.books | % { '"' + $_ + '"' }) -join ',') + ']}')
  if ($k -lt $entries.Count - 1) { [void]$sb.Append(",`n") } }
[void]$sb.Append("`n]`n}`n"); [IO.File]::WriteAllText("$out\manifest.json", $sb.ToString(), (New-Object Text.UTF8Encoding($false)))