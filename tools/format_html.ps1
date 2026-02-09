$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Write-Host "Formatting HTML files under: $root"

$rawTags = @('pre','code','textarea','script','style')
$voidTags = @('area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr')

function Format-File($path) {
    $content = Get-Content $path -Raw -Encoding UTF8

    # split into tags and text
    $matches = [regex]::Matches($content, '(<[^>]+>)')
    $tokens = @()
    $last = 0
    foreach ($m in $matches) {
        $idx = $m.Index
        if ($idx -gt $last) {
            $tokens += $content.Substring($last, $idx - $last)
        }
        $tokens += $m.Value
        $last = $idx + $m.Length
    }
    if ($last -lt $content.Length) { $tokens += $content.Substring($last) }

    $out = New-Object System.Text.StringBuilder
    $indent = 0
    $inRaw = $false
    $rawTag = ''

    foreach ($t in $tokens) {
        if ($t -match '^<\s*!--') {
            # comment
            $line = $t.Trim()
            [void]$out.AppendLine((' ' * ($indent*2)) + $line)
            continue
        }

        if ($inRaw) {
            # include until closing raw tag
            if ($t -match "^<\s*/\s*($rawTag)\b") {
                $inRaw = $false
                $indent--
                [void]$out.AppendLine((' ' * ($indent*2)) + $t.Trim())
            } else {
                # write inner raw content as-is
                [void]$out.AppendLine((' ' * ($indent*2)) + $t)
            }
            continue
        }

        if ($t -match '^<\s*/\s*([a-zA-Z0-9:-]+)') {
            # closing tag
            $indent = [Math]::Max(0, $indent - 1)
            [void]$out.AppendLine((' ' * ($indent*2)) + $t.Trim())
            continue
        }

        if ($t -match '^<\s*([a-zA-Z0-9:-]+)') {
            $tag = $matches= $null; $tag = $matches = $t -replace '^<\s*([a-zA-Z0-9:-]+).*','$1'
            $isVoid = ($t.TrimEnd().EndsWith('/>') -or ($voidTags -contains $tag.ToLower()))
            [void]$out.AppendLine((' ' * ($indent*2)) + $t.Trim())
            if (-not $isVoid) {
                if ($rawTags -contains $tag.ToLower()) {
                    $inRaw = $true
                    $rawTag = $tag.ToLower()
                }
                $indent++
            }
            continue
        }

        # text node
        $text = $t -replace '\s+', ' '
        $text = $text.Trim()
        if ($text -ne '') { [void]$out.AppendLine((' ' * ($indent*2)) + $text) }
    }

    $new = $out.ToString().TrimEnd() + "`n"
    if ($new -ne $content) {
        Copy-Item -Path $path -Destination ($path + '.fmt.bak') -Force
        Set-Content -Path $path -Value $new -Encoding UTF8
        Write-Host "Formatted: $([IO.Path]::GetFileName($path))"
        return $true
    } else {
        Write-Host "Already formatted: $([IO.Path]::GetFileName($path))"
        return $false
    }
}

$files = Get-ChildItem $root -Include *.html -File -Recurse
$count = 0
foreach ($f in $files) { if (Format-File $f.FullName) { $count++ } }
Write-Host "Formatting complete. Files changed: $count"
