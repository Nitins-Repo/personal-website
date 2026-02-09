$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Write-Host "Sanitizing HTML files under: $root"

function SanitizeText($s) {
    if (-not $s) { return $s }
    $t = [string]$s
    # remove C0 control chars except tab/newline/carriage
    $t = $t -replace "[\x00-\x08\x0B\x0C\x0E-\x1F]", ''
    # normalize smart quotes and dashes using unicode escapes
    $t = $t -replace '\u2019', "'"
    $t = $t -replace '\u2018', "'"
    $t = $t -replace '\u201C', '"'
    $t = $t -replace '\u201D', '"'
    $t = $t -replace '\u2014', '-'
    $t = $t -replace '\u2013', '-'
    # normalize non-breaking space
    $t = $t -replace '\u00A0', ' '
    # collapse repeated whitespace
    $t = $t -replace '\s{2,}', ' '
    return $t.Trim()
}

$files = Get-ChildItem $root -Include *.html -File -Recurse
$count = 0
foreach ($f in $files) {
    try {
        $orig = Get-Content $f.FullName -Raw -Encoding UTF8
        $clean = SanitizeText($orig)
        if ($clean -ne $orig) {
            # backup
            $bak = "$($f.FullName).bak"
            Copy-Item -Path $f.FullName -Destination $bak -Force
            Set-Content -Path $f.FullName -Value $clean -Encoding UTF8
            Write-Host "Sanitized: $($f.Name) (backup created: $([IO.Path]::GetFileName($bak)))"
            $count++
        } else {
            Write-Host "OK: $($f.Name)"
        }
    } catch {
        Write-Warning "Failed to process $($f.FullName): $_"
    }
}
Write-Host "Sanitization complete. Files modified: $count"
