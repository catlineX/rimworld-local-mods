$ErrorActionPreference = 'Stop'
$upstream = 'F:/SteamLibrary/steamapps/workshop/content/294100/1725544583'
$modRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$folders = @('', 'v1.1', 'v1.2', 'v1.3', 'v1.4', 'v1.5', 'v1.6')
function Effective-Files([string]$relative) {
    $files = @{}
    foreach ($folder in $folders) {
        $base = Join-Path $upstream $folder
        $path = Join-Path $base $relative
        if (Test-Path -LiteralPath $path) {
            foreach ($f in (Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.xml')) {
                $files[$f.FullName.Substring($path.TrimEnd('\').Length).TrimStart('\')] = $f.FullName
            }
        }
    }
    return $files.Values
}
function Read-Language($paths) {
    $result = @{}
    foreach ($path in $paths) {
        $x = New-Object System.Xml.XmlDocument; $x.Load($path)
        foreach ($n in $x.DocumentElement.ChildNodes) { if ($n.NodeType -eq 'Element') { $result[$n.Name] = $n.InnerText } }
    }
    return $result
}
$en = Read-Language (Effective-Files 'Languages/English/Keyed')
$upstreamKeys = @($en.Keys)
$debugEnglish = Read-Language (Get-ChildItem -LiteralPath (Join-Path $modRoot 'Languages/English/Keyed') -Recurse -File -Filter '*.xml' | Select-Object -ExpandProperty FullName)
foreach ($key in $debugEnglish.Keys) { $en[$key] = $debugEnglish[$key] }
$oldKeyed = Read-Language (Effective-Files 'Languages/ChineseSimplified/Keyed')
$newKeyed = Read-Language (Get-ChildItem -LiteralPath (Join-Path $modRoot 'Languages/ChineseSimplified/Keyed') -Recurse -File -Filter '*.xml' | Select-Object -ExpandProperty FullName)
$oldInjected = Read-Language (Effective-Files 'Languages/ChineseSimplified/DefInjected')
$newInjected = Read-Language (Get-ChildItem -LiteralPath (Join-Path $modRoot 'Languages/ChineseSimplified/DefInjected') -Recurse -File -Filter '*.xml' | Select-Object -ExpandProperty FullName)
$defs = @{}
foreach ($path in (Effective-Files 'Defs')) {
    $x = New-Object System.Xml.XmlDocument; $x.Load($path)
    foreach ($d in $x.DocumentElement.ChildNodes) {
        if ($d.defName) {
            $id = [string]$d.defName
            if ($defs.ContainsKey($id)) { $defs[$id] = @($defs[$id]) + @($d) } else { $defs[$id] = @($d) }
        }
    }
}
function Resolve-Node([string]$key) {
    $parts = $key.Split('.')
    foreach ($definition in $defs[$parts[0]]) {
    $node = $definition
    for ($i=1; $i -lt $parts.Length -and $node; $i++) {
        if ($parts[$i] -match '^\d+$') {
            $children = @($node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
            $index = [int]$parts[$i]
            if ($index -ge $children.Count) { $node = $null; break }
            $node = $children[$index]
        } else { $node = $node.SelectSingleNode($parts[$i]) }
    }
    if ($node) { return $node }
    }
    return $null
}
function Tokens([string]$text) {
    return (([regex]::Matches($text, '\{[^{}]+\}|\[[^\[\]]+\]') | ForEach-Object { $_.Value } | Sort-Object) -join '|')
}
foreach ($key in $newKeyed.Keys) {
    if (!$en.ContainsKey($key)) { throw "Unknown keyed entry: $key" }
    if ((Tokens $en[$key]) -cne (Tokens $newKeyed[$key])) { throw "Keyed placeholder mismatch: $key" }
}
foreach ($key in $en.Keys) { if (!$newKeyed.ContainsKey($key)) { throw "Keyed entry not covered: $key" } }
foreach ($key in $newInjected.Keys) {
    $node = Resolve-Node $key
    if (!$node) { throw "Invalid injected path: $key" }
    if ((Tokens $node.InnerText) -cne (Tokens $newInjected[$key])) { throw "Def placeholder mismatch: $key" }
    if ($key -match '\.rulesStrings\.\d+$') {
        if ($node.InnerText.Split(@('->'), [StringSplitOptions]::None)[0] -cne $newInjected[$key].Split(@('->'), [StringSplitOptions]::None)[0]) { throw "Rule identifier changed: $key" }
    }
}
$missingBefore = 0; $remaining = New-Object 'System.Collections.Generic.List[string]'
function Check-Fields($node, [string]$path) {
    $index = 0
    foreach ($n in $node.ChildNodes) {
        if ($n.NodeType -ne 'Element') { continue }
        $part = $n.Name
        if ($n.Name -eq 'li') { $part = [string]$index }
        $key = $path + '.' + $part
        $isText = $n.Name -in @('label','description','letterLabel','letterText','labelShort','pawnLabel','gerundLabel','verb','gerund','reportString','text','addedPart') -or ($n.Name -eq 'li' -and $node.Name -eq 'rulesStrings')
        if ($isText) {
            if (!$oldInjected.ContainsKey($key)) { $script:missingBefore++ }
            $translation = $oldInjected[$key]
            if ($newInjected.ContainsKey($key)) { $translation = $newInjected[$key] }
            if (!$translation -or $translation -ceq $n.InnerText) { $remaining.Add($key) }
        } else { Check-Fields $n $key }
        $index++
    }
}
foreach ($group in $defs.Values) { foreach ($d in $group) { Check-Fields $d ([string]$d.defName) } }
if ($remaining.Count) { throw ('Untranslated effective text: ' + ($remaining -join ', ')) }
$missingKeys = @($upstreamKeys | Where-Object { !$oldKeyed.ContainsKey($_) }).Count
Write-Host "PASS: $($newKeyed.Count) keyed entries covered; $missingKeys missing in upstream Chinese"
Write-Host "PASS: $($newInjected.Count) injected entries resolve to effective definitions"
Write-Host "PASS: placeholders and quest rule identifiers unchanged"
Write-Host "PASS: $missingBefore originally missing Def fields; 0 untranslated audited effective text fields remain"
Write-Host 'Static audit only: does not prove in-game UI layout or runtime language injection.'
