param([string]$CandidateFile='D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-audit/baseline-candidates.json')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$candidates = Get-Content -Raw -Encoding UTF8 -LiteralPath $CandidateFile | ConvertFrom-Json
$known = @{}
foreach ($e in $candidates) { $known[$e.packageId+'|'+$e.kind+'|'+$e.defType+'|'+$e.key] = $e }
$index = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'Modules/index.json') | ConvertFrom-Json
$modules = @($index.modules | Where-Object { $_.source -eq 'migrated-local-translation' })
function Tokens([string]$text) { (([regex]::Matches($text,'\{[^{}]+\}|\[[^\[\]]+\]') | ForEach-Object { $_.Value } | Sort-Object) -join '|') }
function Find-OriginalField($map, $entry) {
    $parts=$entry.key.Split('.')
    $paths=@($candidates | Where-Object { $_.packageId -eq $map.packageId -and $_.defType -eq $entry.defType } | Select-Object -ExpandProperty source -Unique)
    foreach($path in $paths) {
        $doc=New-Object System.Xml.XmlDocument; $doc.Load($path)
        $node=$doc.SelectSingleNode('/Defs/*[defName="'+$parts[0]+'"]')
        for($i=1;$i -lt $parts.Length -and $node;$i++) {
            if($parts[$i] -match '^\d+$') {
                $children=@($node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
                if([int]$parts[$i] -ge $children.Count){$node=$null;break}
                $node=$children[[int]$parts[$i]]
            } else { $node=$node.SelectSingleNode($parts[$i]) }
        }
        if($node -and $node.InnerText -ceq $entry.original){return [pscustomobject]@{original=$node.InnerText;source=$path}}
    }
    return $null
}
foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $root 'Reviewed') -Filter '*.json' -File)) {
    if ($file.Name -eq 'RetainedEnglish.json') { continue }
    $map = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName | ConvertFrom-Json
    if ($map.directory -notmatch '^[A-Za-z0-9_-]+$') { throw 'Unsafe module directory.' }
    $groups = @{}
    foreach ($entry in $map.entries) {
        $source = $known[$map.packageId+'|'+$entry.kind+'|'+$entry.defType+'|'+$entry.key]
        if (!$source -and $entry.original -and $entry.kind -eq 'DefInjected') { $source=Find-OriginalField $map $entry }
        if (!$source -and $entry.original -and $entry.source -and $entry.kind -eq 'Keyed') {
            $doc=New-Object System.Xml.XmlDocument; $doc.Load([string]$entry.source)
            $node=$doc.SelectSingleNode('/LanguageData/'+$entry.key)
            if($node -and $node.InnerText -ceq $entry.original){$source=[pscustomobject]@{original=$node.InnerText;source=$entry.source}}
        }
        if (!$source) { throw "Reviewed entry not in baseline candidate file: $($entry.key)" }
        if ($entry.kind -eq 'Keyed') {
            $sourceTokens=(([regex]::Matches($source.original,'\{[^{}]+\}') | ForEach-Object {$_.Value} | Sort-Object) -join '|')
            $targetTokens=(([regex]::Matches($entry.text,'\{[^{}]+\}') | ForEach-Object {$_.Value} | Sort-Object) -join '|')
            if($sourceTokens -cne $targetTokens){throw "Keyed placeholder mismatch: $($entry.key)"}
        } elseif ((Tokens $source.original) -cne (Tokens $entry.text)) { throw "Placeholder mismatch: $($entry.key)" }
        if ($entry.key -match '\.rulesStrings\.\d+$' -and $source.original.Contains('->')) {
            if ($source.original.Split(@('->'),[StringSplitOptions]::None)[0] -cne $entry.text.Split(@('->'),[StringSplitOptions]::None)[0]) { throw "Rule grammar changed: $($entry.key)" }
        }
        $group = 'Keyed'
        if ($entry.kind -eq 'DefInjected') { $group = 'DefInjected/' + $entry.defType }
        if (!$groups.ContainsKey($group)) { $groups[$group] = @() }
        $groups[$group] += $entry
    }
    foreach ($group in $groups.Keys) {
        $xml = New-Object System.Xml.XmlDocument
        [void]$xml.AppendChild($xml.CreateXmlDeclaration('1.0','utf-8',$null))
        $language = $xml.CreateElement('LanguageData'); [void]$xml.AppendChild($language)
        $keys = @{}
        foreach ($entry in $groups[$group]) {
            if ($keys.ContainsKey($entry.key)) { throw "Duplicate translation: $($entry.key)" }
            $keys[$entry.key] = $true
            $node = $xml.CreateElement($entry.key); $node.InnerText = $entry.text; [void]$language.AppendChild($node)
        }
        $dir = Join-Path $root ('Modules/'+$map.directory+'/Languages/ChineseSimplified/'+$group)
        [void](New-Item -ItemType Directory -Path $dir -Force)
        $settings = New-Object System.Xml.XmlWriterSettings; $settings.Indent=$true; $settings.Encoding=New-Object System.Text.UTF8Encoding($false)
        $writer = [Xml.XmlWriter]::Create((Join-Path $dir ('Unified_'+$map.directory+'.xml')),$settings)
        try { $xml.Save($writer) } finally { $writer.Dispose() }
    }
    $modules += [pscustomobject]@{ directory=$map.directory; packageId=$map.packageId; name=$map.name; status='reviewed-candidate-texts-static-not-runtime'; entries=$map.entries.Count; source='reviewed-map' }
}
$index.modules = $modules
$index | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'Modules/index.json')
$load = New-Object System.Xml.XmlDocument; $load.Load((Join-Path $root 'LoadFolders.xml'))
$version = $load.SelectSingleNode('/loadFolders/v1.6')
$version.RemoveAll()
$base = $load.CreateElement('li'); $base.InnerText='/'; [void]$version.AppendChild($base)
foreach ($module in $modules) {
    $node=$load.CreateElement('li'); $node.InnerText='Modules/'+$module.directory
    $condition=$module.packageId
    $node.SetAttribute('IfModActive',$condition); [void]$version.AppendChild($node)
}
$load.Save((Join-Path $root 'LoadFolders.xml'))
$about = New-Object System.Xml.XmlDocument; $about.Load((Join-Path $root 'About/About.xml'))
$after=$about.ModMetaData.loadAfter; $after.RemoveAll()
foreach ($id in @(@('brrainz.harmony','imranfish.xmlextensions')+@($modules | ForEach-Object { $_.packageId }) | Select-Object -Unique)) {
    $n=$about.CreateElement('li');$n.InnerText=$id;[void]$after.AppendChild($n)
}
$about.Save((Join-Path $root 'About/About.xml'))
Write-Host "Generated conditional translations for $($modules.Count) modules; placeholders/rule names checked."
