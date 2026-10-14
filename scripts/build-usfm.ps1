param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Name, [string]$Year='', [string]$Source='', [string]$License='Public domain', [string]$Note='')
. "$PSScriptRoot\lib.ps1"
$warn = New-Object System.Collections.ArrayList
$data = [ordered]@{}
foreach ($f in (Get-ChildItem "$Dir\*.usfm" | Sort-Object Name)) {
  $o = ConvertFrom-UsfmFile $f.FullName $warn
  if (-not $script:ByUsfm.ContainsKey($o.code)) { [void]$warn.Add("unknown book code $($o.code) in $($f.Name)"); continue }
  $data[$script:ByUsfm[$o.code].id] = $o.chapters
}
$meta = [ordered]@{ id = $Id; name = $Name; year = $Year; source = $Source; license = $License; note = $Note }
$out = "$PSScriptRoot\..\neutral\$Id.json"
Write-NeutralJson $out $meta $data
$nv = 0; foreach ($b in $data.Values) { foreach ($c in $b.Values) { $nv += $c.Count } }
"$Id : $($data.Count) books, $nv verses, $((Get-Item $out).Length) bytes, $($warn.Count) warnings"
$warn | Select-Object -First 40