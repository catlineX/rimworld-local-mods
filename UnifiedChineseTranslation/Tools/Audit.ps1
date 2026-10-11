param([string]$OutputDir = 'D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-audit', [switch]$IgnoreUnified)
$ErrorActionPreference = 'Stop'
$game = 'F:/SteamLibrary/steamapps/common/RimWorld'
$config = 'C:/Users/XueWen/AppData/LocalLow/Ludeon Studios/RimWorld by Ludeon Studios/Config/ModsConfig.xml'
$cfg = New-Object System.Xml.XmlDocument; $cfg.Load($config)
$active = @($cfg.SelectNodes('/ModsConfigData/activeMods/li') | ForEach-Object { $_.InnerText.ToLowerInvariant() })
$catalog = @{}
foreach ($base in @((Join-Path $game 'Data'), (Join-Path $game 'Mods'), 'F:/SteamLibrary/steamapps/workshop/content/294100')) {
    foreach ($directory in (Get-ChildItem -LiteralPath $base -Directory)) {
        $about = Join-Path $directory.FullName 'About/About.xml'
        if (!(Test-Path -LiteralPath $about)) { continue }
        try {
            $x = New-Object System.Xml.XmlDocument; $x.Load($about)
            $id = ([string]$x.ModMetaData.packageId).ToLowerInvariant()
            if ($id -and $active -contains $id) {
                $catalog[$id] = [ordered]@{ packageId=$id; name=[string]$x.ModMetaData.name; path=$directory.FullName; folders=@(); files=@{}; errors=@() }
            }
        } catch { Write-Warning "About XML unreadable: $about" }
    }
}
function Condition-Enabled($node) {
    foreach ($attr in @('IfModActive','MayRequire')) {
        if ($node.HasAttribute($attr)) {
            foreach ($id in ($node.GetAttribute($attr) -split ',')) { if ($active -notcontains $id.Trim().ToLowerInvariant()) { return $false } }
        }
    }
    foreach ($attr in @('IfModNotActive','MayRequireNot')) {
        if ($node.HasAttribute($attr)) {
            foreach ($id in ($node.GetAttribute($attr) -split ',')) { if ($active -contains $id.Trim().ToLowerInvariant()) { return $false } }
        }
    }
    return $true
}
foreach ($mod in $catalog.Values) {
    $load = Join-Path $mod.path 'LoadFolders.xml'
    $folders = @('')
    if (Test-Path -LiteralPath $load) {
        $x = New-Object System.Xml.XmlDocument; $x.Load($load)
        $node = $x.SelectSingleNode('/loadFolders/v1.6')
        if (!$node) { $node = $x.SelectSingleNode('/loadFolders/default') }
        if ($node) { $folders = @($node.SelectNodes('li') | Where-Object { Condition-Enabled $_ } | ForEach-Object { $_.InnerText.Trim('/\') }) }
        else { $mod.errors += 'No v1.6/default LoadFolders entry; fallback root/version needs review' }
    } else {
        if (Test-Path -LiteralPath (Join-Path $mod.path '1.6')) { $folders += '1.6' }
    }
    $mod.folders = $folders
    foreach ($folder in $folders) {
        $base = Join-Path $mod.path $folder
        foreach ($section in @('Defs','Languages/English','Languages/ChineseSimplified')) {
            $dir = Join-Path $base $section
            if (!(Test-Path -LiteralPath $dir)) { continue }
            foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.xml')) {
                $relative = $f.FullName.Substring($base.TrimEnd('\').Length).TrimStart('\').Replace('\','/')
                $mod.files[$relative] = $f.FullName
            }
        }
        $languages = Join-Path $base 'Languages'
        if (Test-Path -LiteralPath $languages) {
            foreach ($language in (Get-ChildItem -LiteralPath $languages -Directory | Where-Object { $_.Name -like 'ChineseSimplified *' })) {
                foreach ($f in (Get-ChildItem -LiteralPath $language.FullName -Recurse -File -Filter '*.xml')) {
                    $relative = 'Languages/ChineseSimplified/' + $f.FullName.Substring($language.FullName.Length).TrimStart('\').Replace('\','/')
                    $mod.files[$relative] = $f.FullName
                }
            }
        }
    }
}
$globalKeyed = @{}; $globalInjected = @{}
foreach ($id in $active) {
    if (!$catalog.ContainsKey($id)) { continue }
    foreach ($relative in $catalog[$id].files.Keys) {
        if ($relative -notmatch '^Languages/ChineseSimplified/') { continue }
        try {
            $x = New-Object System.Xml.XmlDocument; $x.Load($catalog[$id].files[$relative])
            foreach ($n in $x.DocumentElement.ChildNodes) {
                if ($n.NodeType -ne 'Element') { continue }
                if ($relative -match '/Keyed/') { $globalKeyed[$n.Name] = $n.InnerText }
                elseif ($relative -match '/DefInjected/([^/]+)/') { $globalInjected[$Matches[1] + ':' + $n.Name] = $n.InnerText }
            }
        } catch { $catalog[$id].errors += "Language parse failed: $relative" }
    }
}
$entries = New-Object 'System.Collections.Generic.List[object]'
$summaries = New-Object 'System.Collections.Generic.List[object]'
$accuracy = New-Object 'System.Collections.Generic.List[object]'
$retained = @{}
$retainedPath = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) 'Reviewed/RetainedEnglish.json'
if (Test-Path -LiteralPath $retainedPath) {
    $decisions = Get-Content -Raw -Encoding UTF8 -LiteralPath $retainedPath | ConvertFrom-Json
    foreach ($decision in $decisions.decisions) { $retained[$decision.packageId+'|'+$decision.key]=$decision.reason }
}
$stagedPatches = @{}
if (!$IgnoreUnified) {
    $unifiedRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $indexPath = Join-Path $unifiedRoot 'Modules/index.json'
    if (Test-Path -LiteralPath $indexPath) {
        $index = Get-Content -Raw -Encoding UTF8 -LiteralPath $indexPath | ConvertFrom-Json
        foreach ($module in $index.modules) {
            if ($active -notcontains $module.packageId.ToLowerInvariant()) { continue }
            $folder = Join-Path $unifiedRoot ('Modules/'+$module.directory)
            $lang = Join-Path $folder 'Languages/ChineseSimplified'
            if (Test-Path -LiteralPath $lang) {
                foreach ($file in (Get-ChildItem -LiteralPath $lang -Recurse -File -Filter '*.xml')) {
                    $x = New-Object System.Xml.XmlDocument; $x.Load($file.FullName)
                    foreach ($n in $x.DocumentElement.ChildNodes) {
                        if ($n.NodeType -ne 'Element') { continue }
                        if ($file.FullName -match '[\\/]Keyed[\\/]') { $globalKeyed[$n.Name] = $n.InnerText }
                        elseif ($file.FullName -match '[\\/]DefInjected[\\/]([^\\/]+)[\\/]') { $globalInjected[$Matches[1]+':'+$n.Name] = $n.InnerText }
                    }
                }
            }
            $patchDir = Join-Path $folder 'Patches'
            if (Test-Path -LiteralPath $patchDir) {
                $stagedPatches[$module.packageId] = @(Get-ChildItem -LiteralPath $patchDir -Recurse -File -Filter '*.xml' | Select-Object -ExpandProperty FullName)
            }
        }
    }
}
function Add-Candidate($mod, $kind, $type, $key, $text, $path) {
    if (!$text) { return }
    $visible = $text
    if ($key -match '\.rulesStrings\.\d+$' -and $visible.Contains('->')) { $visible = $visible.Substring($visible.IndexOf('->')+2) }
    $visible = [regex]::Replace($visible, '\[[^\[\]]+\]|\{[^{}]+\}|<[^>]+>', '')
    if ($visible -notmatch '[A-Za-z]{2}') { return }
    $translated = $null
    if ($kind -eq 'Keyed') { $translated = $globalKeyed[$key] }
    else { $translated = $globalInjected[$type + ':' + $key] }
    if ($translated -and $translated -match '[\p{IsCJKUnifiedIdeographs}]') {
        $pattern='\{[^{}]+\}|\[[^\[\]]+\]'
        if($kind -eq 'Keyed'){$pattern='\{[^{}]+\}'}
        $sourceTokens = (([regex]::Matches($text,$pattern) | ForEach-Object {$_.Value} | Sort-Object) -join '|')
        $targetTokens = (([regex]::Matches($translated,$pattern) | ForEach-Object {$_.Value} | Sort-Object) -join '|')
        $reasons=@()
        if ($sourceTokens -cne $targetTokens) { $reasons+='placeholder-difference-needs-review' }
        if ($key -match '\.rulesStrings\.\d+$' -and $text.Contains('->') -and $translated.Contains('->')) {
            if ($text.Split(@('->'),[StringSplitOptions]::None)[0] -cne $translated.Split(@('->'),[StringSplitOptions]::None)[0]) { $reasons+='rule-identifier-difference-needs-review' }
        }
        if ($reasons.Count -and !($mod.packageId -eq 'mlie.usethisinstead' -and $key -eq 'UTI.incompatibility')) { $accuracy.Add([ordered]@{packageId=$mod.packageId;mod=$mod.name;kind=$kind;defType=$type;key=$key;original=$text;existing=$translated;source=$path;reasons=$reasons;status='human-review-required'}) }
        return
    }
    if ($retained.ContainsKey($mod.packageId+'|'+$key)) { return }
    if ($text -match '[\p{IsCJKUnifiedIdeographs}]') { return }
    $entries.Add([ordered]@{ packageId=$mod.packageId; mod=$mod.name; kind=$kind; defType=$type; key=$key; original=$text; existing=$translated; source=$path; status='needs-human-review' })
}
function Walk-Def($mod, $node, $type, $path, $file) {
    $index = 0
    foreach ($n in $node.ChildNodes) {
        if ($n.NodeType -ne 'Element') { continue }
        $part = $n.Name; if ($n.Name -eq 'li') { $part = [string]$index }
        $key = $path + '.' + $part
        if (!(Condition-Enabled $n)) { $index++; continue }
        if ($n.Name -in @('label','description','letterLabel','letterText','labelShort','pawnLabel','gerundLabel','verb','gerund','reportString','text','addedPart','useLabel','tooltip','tooltipText','helpText','beginLetter','endMessage','baseInspectLine','inspectString','labelNoun','recoveryMessage','fixedName','title','buttonLabel') -or ($n.Name -eq 'li' -and $node.Name -eq 'rulesStrings')) {
            Add-Candidate $mod 'DefInjected' $type $key $n.InnerText $file
        } else { Walk-Def $mod $n $type $key $file }
        $index++
    }
}
foreach ($id in $active) {
    if (!$catalog.ContainsKey($id)) { continue }
    $mod = $catalog[$id]; $start = $entries.Count
    if ($id -notmatch '^ludeon\.') {
        foreach ($relative in $mod.files.Keys) {
            if ($relative -notmatch '^(Defs/|Languages/English/Keyed/)') { continue }
            try {
                $x = New-Object System.Xml.XmlDocument; $x.Load($mod.files[$relative])
                if ($relative -match '^Languages/English/Keyed/') {
                    foreach ($n in $x.DocumentElement.ChildNodes) { if ($n.NodeType -eq 'Element') { Add-Candidate $mod 'Keyed' '' $n.Name $n.InnerText $mod.files[$relative] } }
                } elseif ($relative -match '^Defs/') {
                    foreach ($patchPath in $stagedPatches[$id]) {
                        $p = New-Object System.Xml.XmlDocument; $p.Load($patchPath)
                        foreach ($op in $p.SelectNodes('/Patch/Operation[@Class="PatchOperationReplace"]')) {
                            foreach ($target in @($x.SelectNodes([string]$op.xpath))) { [void]$target.ParentNode.ReplaceChild($x.ImportNode($op.value.FirstChild,$true),$target) }
                        }
                    }
                    foreach ($d in $x.DocumentElement.ChildNodes) {
                        if (!$d.defName -or !(Condition-Enabled $d)) { continue }
                        $type = $d.LocalName
                        if ($type -eq 'Def' -and $d.HasAttribute('Class')) { $type = $d.GetAttribute('Class') }
                        Walk-Def $mod $d $type ([string]$d.defName) $mod.files[$relative]
                    }
                }
            } catch { $mod.errors += "Definition parse failed: $relative" }
        }
    }
    $summaries.Add([ordered]@{ packageId=$id; name=$mod.name; candidates=$entries.Count-$start; status= $(if($id -match '^ludeon\.'){ 'official-language-not-audited' }elseif($mod.errors.Count){'review-load-or-parse-errors'}else{'static-scan-only'}); errors=$mod.errors; folders=$mod.folders })
}
[void](New-Item -ItemType Directory -Path $OutputDir -Force)
if ($IgnoreUnified -and !(Test-Path -LiteralPath (Join-Path $OutputDir 'baseline-candidates.json'))) {
    $entries | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'baseline-candidates.json')
}
$entries | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'candidates.json')
$summaries | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'mods.json')
$accuracy | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'accuracy-review.json')
$unresolved = @($active | Where-Object { !$catalog.ContainsKey($_) })
[ordered]@{ date=(Get-Date).ToString('o'); active=$active.Count; resolved=$catalog.Count; candidates=$entries.Count; unresolved=$unresolved; limitations=@('Static XML/Keyed audit, not runtime translation injection or hardcoded strings','English technical names may intentionally remain; human review required','XML patch-added defs/text and XML Extensions settings require additional review','Official language archives excluded') } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'summary.json')
$summaries | ForEach-Object { [pscustomobject]$_ } | Sort-Object candidates -Descending | Select-Object -First 40 name,candidates,status | Format-Table -AutoSize
Write-Host "Active=$($active.Count) Resolved=$($catalog.Count) Candidates=$($entries.Count) AccuracyReview=$($accuracy.Count) Unresolved=$($unresolved -join ',')"
