param([Parameter(Mandatory)][string]$Id)
$r = "$PSScriptRoot\.."
$kjv = [IO.File]::ReadAllLines("$r\reports\kjv-keys.txt"); $kset = New-Object 'System.Collections.Generic.HashSet[string]' (,$kjv)
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 200MB
$j = $ser.DeserializeObject([IO.File]::ReadAllText("$r\neutral\$Id.json"))
$have = New-Object 'System.Collections.Generic.HashSet[string]'; $odd = @()
foreach ($b in $j['books'].Keys) { foreach ($ch in $j['books'][$b].Keys) { foreach ($v in $j['books'][$b][$ch].Keys) { [void]$have.Add("${b}:${ch}:${v}"); if ($v -notmatch '^\d+$') { $odd += "${b}:${ch}:${v}" } } } }
$books = @($j['books'].Keys)
$kjvBooks = $kjv | % { $_.Split(':')[0] } | Select-Object -Unique
$scope = $kjv | ? { $books -contains $_.Split(':')[0] }
$missing = $scope | ? { -not $have.Contains($_) }; $extra = $have | ? { -not $kset.Contains($_) -and ($kjvBooks -contains $_.Split(':')[0]) }
$apoc = $books | ? { $kjvBooks -notcontains $_ }
"== $Id : books $($books.Count) (non-66: $($apoc -join ',')); verses $($have.Count)"
"KJV verses (in this translation's books) missing here: $(@($missing).Count)"; @($missing) | Select-Object -First 60 | % { "   - $_" }
"Verses here but not in KJV numbering: $(@($extra).Count)"; @($extra) | Select-Object -First 60 | % { "   + $_" }
"Odd verse labels (ranges etc.): $($odd.Count)"; $odd | Select-Object -First 30
$chars = @{}; foreach ($b in $j['books'].Values) { foreach ($c2 in $b.Values) { foreach ($t in $c2.Values) { foreach ($ch in $t.ToCharArray()) { if ([int]$ch -gt 126 -or [int]$ch -lt 32) { $chars[[string]$ch] = 1 + [int]$chars[[string]$ch] } } } } }
"Non-ASCII characters used: " + (($chars.GetEnumerator() | sort Value -Descending | % { "U+{0:X4}($($_.Value))" -f [int][char]$_.Name }) -join ' ')