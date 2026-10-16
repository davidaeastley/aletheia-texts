param([Parameter(Mandatory)][string]$TextId, [Parameter(Mandatory)][string]$Out, [string]$DbPath = "$env:USERPROFILE\AndroidStudioProjects\Aletheia\app\src\main\assets\aletheia.db")
# Exports one text of the app's database (verses in KJV numbering) as a reference for align.ps1 -RefTsv:
#   <Out>.tsv           book, chapter, verse, text   (verses that carry text)
#   <Out>-pointers.tsv  book, chapter, verse, ^N     (verses the text runs into the verse before)
# For the Hebrew and Greek columns the text is the plain verse (word lists are not needed: only the length and the numbering matter).
Add-Type -TypeDefinition ([IO.File]::ReadAllText("$env:USERPROFILE\AndroidStudioProjects\Aletheia\tools\db\SqliteLite.cs")) -Language CSharp -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Web.Extensions
$d = New-Object SqliteDb ((Resolve-Path $DbPath).Path)
$j = $d.QueryJson("SELECT book, chapter, verse, body FROM verse WHERE text_id = '$TextId' ORDER BY id", [string[]]@(), 200000); $d.Dispose()
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = 400MB
$r = $ser.DeserializeObject($j)
$tsv = New-Object System.Collections.ArrayList; $ptr = New-Object System.Collections.ArrayList
foreach ($row in $r['rows']) {
  $t = ([string]$row[3]) -replace '[\t\r\n]+', ' '
  if ($t.StartsWith('^')) { [void]$ptr.Add("$($row[0])`t$($row[1])`t$($row[2])`t$t") } else { [void]$tsv.Add("$($row[0])`t$($row[1])`t$($row[2])`t$t") }
}
[IO.File]::WriteAllLines("$Out.tsv", $tsv, (New-Object Text.UTF8Encoding($false))); [IO.File]::WriteAllLines("$Out-pointers.tsv", $ptr, (New-Object Text.UTF8Encoding($false)))
"$TextId : $($tsv.Count) verses with text, $($ptr.Count) pointers"
