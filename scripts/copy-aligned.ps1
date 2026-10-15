param([Parameter(Mandatory)][string]$Id)
# For a translation that already uses the KJV chapter and verse numbers (it may leave some verses out, but has none the KJV lacks):
# neutral/<id>.json is copied as it is to aligned/<id>.json. Stops if the source has verses the KJV does not.
. "$PSScriptRoot\lib.ps1"
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 300MB
$root = "$PSScriptRoot\.."; New-Item -ItemType Directory -Force "$root\aligned" | Out-Null
$kset = New-Object 'System.Collections.Generic.HashSet[string]' (, [IO.File]::ReadAllLines("$root\reports\kjv-keys.txt"))
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$root\neutral\$Id.json", [Text.Encoding]::UTF8)); $meta = $j['meta']; $books = $j['books']
$extra = @(); $have = 0
foreach ($b in $books.Keys) { foreach ($c in $books[$b].Keys) { foreach ($v in $books[$b][$c].Keys) { $have++; if (-not $kset.Contains("${b}:${c}:${v}")) { $extra += "${b}:${c}:${v}" } } } }
if ($extra.Count) { throw "$Id has $($extra.Count) verses the KJV numbering lacks (e.g. $($extra[0..4] -join ', ')); use align.ps1" }
$m = [ordered]@{}; foreach ($k in $meta.Keys) { $m[$k] = $meta[$k] }; $m['numbering'] = 'kjv'
$out = [ordered]@{}; foreach ($b in $books.Keys) { $out[$b] = $books[$b] }
Write-NeutralJson "$root\aligned\$Id.json" $m $out
"$Id : $have verses copied; KJV verses it leaves out: $($kset.Count - $have)"
