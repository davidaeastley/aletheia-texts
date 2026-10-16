param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string[]]$Parts)
# Joins the aligned/<part>.json files (each a set of books in KJV numbering) into aligned/<id>.json; the meta comes from neutral/<id>.json.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."
$Parts = @($Parts | % { $_ -split ',' } | ? { $_ })   # (powershell -File passes a comma list as one string)
$order = @{}; $oi = 0; foreach ($b in $script:BookRows) { $order[$b.id] = $oi++ }
$all = @{}
foreach ($p in $Parts) { $j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\aligned\$p.json", [Text.Encoding]::UTF8)); foreach ($b in $j['books'].Keys) { $all[$b] = $j['books'][$b] } }
$meta = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\$Id.json", [Text.Encoding]::UTF8))['meta']; $m = [ordered]@{}; foreach ($k in $meta.Keys) { $m[$k] = $meta[$k] }; $m['numbering'] = 'kjv'
$out = [ordered]@{}; foreach ($b in ($all.Keys | Sort-Object { $order[$_] })) { $out[$b] = $all[$b] }
Write-NeutralJson "$root\aligned\$Id.json" $m $out
$nv = 0; foreach ($b in $out.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($out.Count) books, $nv verses"
