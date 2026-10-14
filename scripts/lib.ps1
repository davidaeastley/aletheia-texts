# Shared helpers for building translation packs.
$script:BookRows = Get-Content "$PSScriptRoot\books.csv" | ? { $_ -and $_ -notmatch '^#' } | % { $p = $_.Split(',',4); [pscustomobject]@{ usfm=$p[0]; id=$p[1]; group=$p[2]; label=$p[3] } }
$script:ByUsfm = @{}; foreach ($b in $script:BookRows) { $script:ByUsfm[$b.usfm] = $b }

function JsonStr([string]$s) {
  $sb = New-Object Text.StringBuilder; [void]$sb.Append('"')
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) { '"' { [void]$sb.Append('\"') } '\' { [void]$sb.Append('\\') } "`n" { [void]$sb.Append('\n') } "`r" { } "`t" { [void]$sb.Append(' ') }
      default { if ([int]$ch -lt 32) { } else { [void]$sb.Append($ch) } } }
  }
  [void]$sb.Append('"'); $sb.ToString()
}

# $data: ordered book-id -> ordered chapter -> ordered verse-label -> text
function Write-NeutralJson($path, $meta, $data) {
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("{`n""meta"": {")
  $mk = @($meta.Keys); for ($i = 0; $i -lt $mk.Count; $i++) { [void]$sb.Append((JsonStr $mk[$i]) + ': ' + (JsonStr ([string]$meta[$mk[$i]]))); if ($i -lt $mk.Count - 1) { [void]$sb.Append(', ') } }
  [void]$sb.Append("},`n""books"": {`n")
  $bi = 0; $bcount = $data.Count
  foreach ($bid in $data.Keys) {
    [void]$sb.Append('"' + $bid + '": {')
    $ci = 0; $ccount = $data[$bid].Count
    foreach ($ch in $data[$bid].Keys) {
      [void]$sb.Append('"' + $ch + '": {')
      $vi = 0; $vcount = $data[$bid][$ch].Count
      foreach ($v in $data[$bid][$ch].Keys) { [void]$sb.Append('"' + $v + '": ' + (JsonStr $data[$bid][$ch][$v])); $vi++; if ($vi -lt $vcount) { [void]$sb.Append(', ') } }
      [void]$sb.Append('}'); $ci++; if ($ci -lt $ccount) { [void]$sb.Append(', ') }
    }
    [void]$sb.Append('}'); $bi++; if ($bi -lt $bcount) { [void]$sb.Append(",`n") }
  }
  [void]$sb.Append("`n}`n}`n")
  [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
}

function Clean-Verse([string]$t) {
  $t = [regex]::Replace($t, '\\f\s.*?\\f\*', '')
  $t = [regex]::Replace($t, '\\x\s.*?\\x\*', '')
  $t = [regex]::Replace($t, '\\\+?[a-z]+\d?\*?', '')
  ($t -replace '\s+', ' ').Trim()
}

function ConvertFrom-UsfmFile($path, $warn) {
  $lines = Get-Content $path -Encoding UTF8
  $st = @{ code = $null; book = $null; ch = $null; vl = $null }
  $buf = New-Object Text.StringBuilder
  function Flush-Verse {
    if ($null -ne $st.vl) {
      $t = Clean-Verse $buf.ToString(); $b = $st.book; $c = $st.ch; $v = $st.vl
      if (-not $b.Contains($c)) { $b[$c] = [ordered]@{} }
      if ($b[$c].Contains($v)) { [void]$warn.Add("duplicate $($st.code) ${c}:${v}") }
      $b[$c][$v] = $t
      if ($t -eq '') { [void]$warn.Add("empty verse $($st.code) ${c}:${v}") }
    }
    [void]$buf.Clear(); $st.vl = $null
  }
  foreach ($ln in $lines) {
    if ($ln -match '^\\id\s+([A-Z0-9]{3})') { $st.code = $Matches[1]; $st.book = [ordered]@{}; continue }
    if ($ln -match '^\\c\s+(\d+)') { Flush-Verse; $st.ch = $Matches[1]; continue }
    if ($ln -match '^\\v\s+(\d+(?:[-,]\d+)?)\s*(.*)$') { Flush-Verse; $st.vl = $Matches[1]; [void]$buf.Append($Matches[2]); continue }
    if ($null -ne $st.vl -and $ln -notmatch '^\\(s|r|d|ms|mr|sp|b|mt|h|toc)\d?\b') { [void]$buf.Append(' ' + ($ln -replace '^\\[a-z]+\d?\s*', '')) }
  }
  Flush-Verse
  [pscustomobject]@{ code = $st.code; chapters = $st.book }
}