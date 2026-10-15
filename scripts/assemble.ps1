# Splits each aligned/<id>.json into packs/bible/<id>.json (OT+NT) and packs/apoc/<id>.json (Apocrypha),
# then writes packs/manifest.json (sizes + SHA-256) for the app's download screen.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$order = @{}; $i = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $i++ }
$grp = @{}; foreach ($b in $script:BookRows) { $grp[$b.id] = $b.group }
$out = "$PSScriptRoot\..\packs"; New-Item -ItemType Directory -Force "$out\bible", "$out\apoc" | Out-Null
$entries = @()
$baseBuildOnly = @('nrsvue', 'nrsvue-apoc', 'bsb')   # shipped inside the app only; NRSVue is copyrighted and must never be published here
foreach ($f in (Get-ChildItem "$PSScriptRoot\..\aligned\*.json")) {
  if ($baseBuildOnly -contains $f.BaseName) { continue }
  $j = $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)); $meta = $j['meta']; $id = $meta['id']
  foreach ($kind in 'bible', 'apoc') {
    if ($id -eq 'kjv' -and $kind -eq 'bible') { continue }   # the app already contains the KJV; only its Apocrypha is published
    $ids = @($j['books'].Keys | ? { ($grp[$_] -eq 'apoc') -eq ($kind -eq 'apoc') } | Sort-Object { $order[$_] })
    $p = "$out\$kind\$id.json"
    if ($ids.Count -eq 0) { if (Test-Path $p) { Remove-Item $p }; continue }
    $data = [ordered]@{}; foreach ($b in $ids) { $data[$b] = $j['books'][$b] }
    $m = [ordered]@{}; foreach ($k in $meta.Keys) { $m[$k] = $meta[$k] }; $m['kind'] = $kind; $m['books'] = ($ids -join ',')
    Write-NeutralJson $p $m $data
    $nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
    $sha = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
    $entries += [pscustomobject]@{ id = $id; kind = $kind; name = $meta['name']; year = $meta['year']; license = $meta['license']; file = "$kind/$id.json"; bytes = (Get-Item $p).Length; sha256 = $sha; books = $ids; verses = $nv }
    "{0,-26} {1,-5} {2,3} books {3,6} verses {4,9} bytes" -f $id, $kind, $ids.Count, $nv, (Get-Item $p).Length
  }
}
$sb = New-Object Text.StringBuilder; [void]$sb.Append("{`n""version"": 1,`n""packs"": [`n")
for ($k = 0; $k -lt $entries.Count; $k++) { $e = $entries[$k]
  [void]$sb.Append('  {"id": ' + (JsonStr $e.id) + ', "kind": ' + (JsonStr $e.kind) + ', "name": ' + (JsonStr $e.name) + ', "year": ' + (JsonStr $e.year) + ', "license": ' + (JsonStr $e.license) + ', "file": ' + (JsonStr $e.file) + ', "bytes": ' + $e.bytes + ', "sha256": ' + (JsonStr $e.sha256) + ', "verses": ' + $e.verses + ', "books": [' + (($e.books | % { '"' + $_ + '"' }) -join ',') + ']}')
  if ($k -lt $entries.Count - 1) { [void]$sb.Append(",`n") } }
[void]$sb.Append("`n]`n}`n"); [IO.File]::WriteAllText("$out\manifest.json", $sb.ToString(), (New-Object Text.UTF8Encoding($false)))