$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$txtFile = Join-Path $root '..\resume.txt' | Resolve-Path -Relative
$lines = Get-Content $txtFile -ErrorAction Stop
$txt = ($lines -join "`n")

$headers = @('summary','profile','about','experience','work experience','education','skills','projects','contact','certifications')

function Find-Regex ($pattern, $lines) {
    foreach ($line in $lines) {
        if ($line -match $pattern) { return $matches[0] }
    }
    return ''
}

# Sanitize text: remove control chars, normalize quotes, dashes, and whitespace
function Sanitize($t) {
    if (-not $t) { return $t }
    $s = [string]$t
    # remove C0 control chars except newline/tab/carriage return
    $s = $s -replace "[\x00-\x08\x0B\x0C\x0E-\x1F]", ''
    # normalize smart quotes (use unicode escapes to avoid encoding issues)
    $s = $s -replace '\u2019', "'"
    $s = $s -replace '\u2018', "'"
    $s = $s -replace '\u201C', '"'
    $s = $s -replace '\u201D', '"'
    # normalize dashes (em/en)
    $s = $s -replace '\u2014', '-'
    $s = $s -replace '\u2013', '-'
    # normalize non-breaking space and multiple spaces/newlines
    $s = $s -replace "\u00A0", ' '
    $s = $s -replace '\s{2,}', ' '
    return $s.Trim()
}
$email = Find-Regex '\b[\w\.-]+@[\w\.-]+\.[A-Za-z]{2,}\b' $lines
$phone = Find-Regex '\+?\d[\d\-\s\(\)]{6,}\d' $lines

# locate headers
$idx = @{}
for ($i=0; $i -lt $lines.Count; $i++) {
    $s = $lines[$i].Trim().ToLower().TrimEnd(':')
    if ($headers -contains $s) { $idx[$s] = $i }
    elseif ($lines[$i].Trim().Length -gt 0 -and $lines[$i].Trim() -eq $lines[$i].Trim().ToUpper() -and $lines[$i].Trim().Length -lt 60) {
        $k = $lines[$i].Trim().ToLower().TrimEnd(':')
        if (-not $idx.ContainsKey($k)) { $idx[$k] = $i }
    }
}

function Section-Text($key, $lines, $idx) {
    if (-not $idx.ContainsKey($key)) { return '' }
    $start = $idx[$key] + 1
    $next = ($idx.Values | Where-Object { $_ -gt $idx[$key] } | Measure-Object -Minimum).Minimum
    if (-not $next) { $next = $lines.Count }
    $seg = $lines[$start..($next-1)] | Where-Object { $_.Trim().Length -gt 0 }
    return ($seg -join "\n").Trim()
}

$summary = ''
foreach ($k in @('summary','profile','about')) {
    if ($idx.ContainsKey($k)) { $summary = Section-Text $k $lines $idx; break }
}
if (-not $summary) { $summary = ($lines | Where-Object { $_.Trim().Length -gt 0 })[0..7] -join ' ' }
$summary = Sanitize($summary)

$skillsText = ''
if ($idx.ContainsKey('skills')) { $skillsText = Section-Text 'skills' $lines $idx }
$skills = @()
if ($skillsText) { $skills = ($skillsText -split '[,\n]') | ForEach-Object { Sanitize($_.Trim('-• ').Trim()) } | Where-Object { $_ -ne '' } }

# If no explicit "Skills" section, try capturing the block after 'Key Areas of Expertise:'
if ($skills.Count -eq 0) {
    $m = [regex]::Match($txt, '(?s)Key Areas of Expertise:(.*?)(?:PROJECTS SUMMARY|$)')
    if ($m.Success) {
        $block = $m.Groups[1].Value -replace '\r',' ' -replace '\n',' '
        $block = Sanitize($block)
        # Prefer sentence-level groups (split by period) to keep grouped expertise areas
        $sentences = ($block -split '\.\s+') | ForEach-Object { $_.Trim(' .') } | Where-Object { $_ -ne '' }
        if ($sentences.Count -gt 0) { $skills = $sentences }
    }
}

Write-Host "Extracted: email=$email phone=$phone skills=$($skills.Count)"

function Replace-Main($filePath, $innerHtml) {
    $text = Get-Content $filePath -Raw
    $pattern = '(?s)(<main[^>]*>).*?(</main>)'
    $repl = [Regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + "`n      " + $innerHtml + "`n    " + $m.Groups[2].Value }, 'Singleline')
    Set-Content -Path $filePath -Value $repl -Encoding UTF8
}

# Update about.html
$aboutPath = Join-Path $root '..\about.html' | Resolve-Path -Relative
$aboutHtml = "<h1>About Me</h1>`n      <p>$summary</p>`n"
Replace-Main $aboutPath $aboutHtml

# Update skills.html
$skillsPath = Join-Path $root '..\skills.html' | Resolve-Path -Relative
if ($skills.Count -gt 0) {
    $list = ($skills | ForEach-Object { "<li>$_</li>" }) -join "`n      "
} else { $list = '<li>—</li>' }
$skillsHtml = "<h1>Skills</h1>`n      <ul>`n      $list`n      </ul>`n"
Replace-Main $skillsPath $skillsHtml

# Extract projects starting at lines with 'Project:'
# Extract projects by scanning lines and splitting on lines that start with 'Project:'
$projects = @()
$i = 0
while ($i -lt $lines.Count) {
    $ln = $lines[$i]
    if ($ln -match '^\s*Project:\s*(.*)') {
        $title = $Matches[1].Trim()
        $descLines = @()
        $j = $i + 1
        while ($j -lt $lines.Count) {
            $next = $lines[$j]
            if ($next -match '^\s*Project:\s*') { break }
            $descLines += $next.Trim()
            $j++
        }
        $desc = ($descLines -join ' ') -replace '\s{2,}',' '
        $projects += @{ title = $title; desc = $desc }
        $i = $j
        continue
    }
    $i++
}

# Update projects.html with concise cards, role/dates, tags and read-more
$projectsPath = Join-Path $root '..\projects.html' | Resolve-Path -Relative
function Shorten($text, $n) {
    $s = -join $text
    $s = [string]$s
    if ($s.Length -le $n) { return $s } else { return $s.Substring(0,$n).TrimEnd() + '…' }
}

# simple tech keywords to detect
$techKeywords = @('EDMS','IVR','BOTS','Automation','BI','Self-Service','Portal','Java','C#','.NET','SQL','Oracle','AWS','Azure','Python','JavaScript','React')

if ($projects.Count -gt 0) {
    $cards = @()
    foreach ($p in $projects) {
        $full = Sanitize($p.desc)
        # extract role
        $role = ''
        if ($full -match 'Role:\s*([^\n\r]+)') { $role = $Matches[1].Trim() }
        # extract date range
        $dates = ''
        if ($full -match '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s*\d{4}(\s*[–-]\s*(Current|\w+\.?\s*\d{4}))?') { $dates = $Matches[0].Trim() }

        $short = Shorten($full, 280)

        # detect tech tags
        $tags = @()
        foreach ($k in $techKeywords) { if ($full -match [regex]::Escape($k)) { $tags += $k } }
        if ($tags.Count -eq 0) { $tags = @('Public Sector','Government') }

        $tagHtml = ($tags | ForEach-Object { "<span class='tag'>$_</span>" }) -join ' '

        $card = "<article class='proj-card'><h3>" + ($p.title -replace '[\r\n]+',' ') + "</h3>"
        $meta = ''
        if ($role -and $dates) { $meta = $role + ' · ' + $dates }
        elseif ($role) { $meta = $role }
        elseif ($dates) { $meta = $dates }
        if ($meta) { $card += "<p class='meta'>" + $meta + "</p>" }
        function HtmlEncode($t) {
            $t = $t -replace '&','&amp;'
            $t = $t -replace '<','&lt;'
            $t = $t -replace '>','&gt;'
            $t = $t -replace '"','&quot;'
            $t = $t -replace "'","&#39;"
            return $t
        }
        $escapedFull = HtmlEncode($full)
        $card += "<p class='desc'>" + (HtmlEncode(Sanitize($short))) + " <a href='#' class='proj-more'>Read more</a></p>"
        $card += "<div class='proj-full' style='display:none;white-space:pre-wrap;margin-top:.5rem;'>" + $escapedFull + "</div>"
        $card += "<p class='tags'>" + $tagHtml + "</p></article>"
        $cards += $card
    }
    $projHtml = "<h1>Projects</h1>`n      " + ($cards -join "`n      ") + "`n"
} else {
    $projHtml = "<h1>Projects</h1>`n      <p>No projects extracted from resume.</p>`n"
}
Replace-Main $projectsPath $projHtml

# Update contact.html
$contactPath = Join-Path $root '..\contact.html' | Resolve-Path -Relative
$contactHtml = "<h1>Contact</h1>`n      <p>Reach out via email: <a href='mailto:$email'>$email</a>"
if ($phone) { $contactHtml += "<br>Phone: $phone" }
$contactHtml += "</p>`n"
Replace-Main $contactPath $contactHtml

Write-Host "Site pages updated (about, skills, contact, projects=$($projects.Count))"
