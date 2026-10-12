$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$index=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'Modules/index.json') | ConvertFrom-Json
$load=New-Object Xml.XmlDocument;$load.Load((Join-Path $root 'LoadFolders.xml'))
$routes=@($load.SelectNodes('/loadFolders/v1.6/li'))
if($routes.Count -ne $index.modules.Count+1){throw 'Module routing count mismatch'}
$paths=@{};$ids=@{}
foreach($module in $index.modules){
    if($paths.ContainsKey($module.directory) -or $ids.ContainsKey($module.packageId)){throw 'Duplicate module identity'}
    $paths[$module.directory]=$true;$ids[$module.packageId]=$true
    $route=$load.SelectSingleNode('/loadFolders/v1.6/li[text()="Modules/'+$module.directory+'"]')
    if(!$route -or $route.GetAttribute('IfModActive') -ne $module.packageId){throw 'Missing conditional route'}
    $folder=Join-Path $root ('Modules/'+$module.directory)
    if(!(Test-Path -LiteralPath $folder)){throw 'Missing module folder'}
}
$translations=@{};$count=0
foreach($file in (Get-ChildItem -LiteralPath (Join-Path $root 'Modules') -Recurse -File -Filter '*.xml')){
    if($file.FullName -match '\\Modules\\YokaiVillage\\'){continue}
    $x=New-Object Xml.XmlDocument;$x.Load($file.FullName)
    if($file.FullName -notmatch '[\\/]Languages[\\/]ChineseSimplified[\\/](.+)[\\/][^\\/]+\.xml$'){continue}
    $kind=$Matches[1].Replace('\','/')
    foreach($n in $x.DocumentElement.ChildNodes){
        if($n.NodeType -ne 'Element'){continue}
        $key=$kind+':'+$n.Name
        if($translations.ContainsKey($key) -and $translations[$key] -cne $n.InnerText){throw "Conflicting cross-module translation: $key"}
        $translations[$key]=$n.InnerText;$count++
    }
}
# Verify migrated local assets except the intentionally modified debug source.
$repo=Split-Path $root -Parent
$corrections=Get-Content (Join-Path $root 'PathCorrections.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach($file in (Get-ChildItem -LiteralPath (Join-Path $repo 'GlitterNet_ChineseFix/Languages') -Recurse -File)){
    $base=(Join-Path $repo 'GlitterNet_ChineseFix/Languages')
    $relative=$file.FullName.Substring($base.Length).TrimStart('\')
    $dest=Join-Path (Join-Path $root 'Modules/GlitterNet/Languages') $relative
    if($relative -match '^ChineseSimplified\\DefInjected\\QuestScriptDef\\'){
        $old=[xml](Get-Content $file.FullName -Raw -Encoding UTF8);$new=[xml](Get-Content $dest -Raw -Encoding UTF8)
        foreach($node in $old.LanguageData.ChildNodes){
            if($node.NodeType -ne 'Element'){continue}
            $p=@($corrections | Where-Object {$_.module -eq 'GlitterNet' -and $_.oldKey -eq $node.Name})
            $key=$node.Name;if($p.Count){$key=$p[0].key}
            $replacement=$new.SelectSingleNode('/LanguageData/'+$key)
            if(!$replacement -or $replacement.InnerText -cne $node.InnerText){throw "Migrated quest text changed or missing: $key"}
        }
    } elseif((Get-FileHash -LiteralPath $dest).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash){throw 'GlitterNet migration mismatch'}
}
foreach($p in $corrections){
    if($p.module -eq 'YokaiVillage'){continue}
    $group='Keyed';if($p.kind -eq 'DefInjected'){$group='DefInjected/'+$p.defType}
    if(!$translations.ContainsKey($group+':'+$p.key)){throw "Missing corrected path: $($p.key)"}
    if($translations.ContainsKey('DefInjected/'+$p.oldDefType+':'+$p.oldKey)){throw "Stale bad path: $($p.oldKey)"}
}
$source=Join-Path $repo 'CustomInfestationsContinued_ChineseSimplified/Patches/ChineseSimplified.xml'
$dest=Join-Path $root 'Modules/CustomInfestations/Patches/ChineseSimplified.xml'
if((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $dest).Hash){throw 'Infestation migration mismatch'}
Write-Host "PASS: $($index.modules.Count) conditional modules; $count language entries; no conflicting cross-module keys"
Write-Host "PASS: $(@($corrections | Where-Object {$_.module -ne 'YokaiVillage'}).Count) active path corrections present; old bad paths absent; migrated text preserved"
if($load.SelectSingleNode('/loadFolders/v1.6/li[text()="Modules/YokaiVillage"]')){throw 'Excluded Yokai module is still routed'}
$repair=[xml](Get-Content (Join-Path $root 'Repairs/KnownErrors.xml') -Raw -Encoding UTF8)
if($repair.repairs.entry.Count -ne 483){throw 'Reviewed non-Yokai repair count mismatch'}
foreach($entry in $repair.repairs.entry){if($entry.key -match '^(Yokai|UniHAR_Yokai)' -or $entry.file -match 'Yokai|Yokaibandage'){throw 'Excluded Yokai repair rule found'}}
Write-Host 'PASS: 483 reviewed upstream field rules; Yokai translation and repair excluded'
Write-Host 'Static only; runtime field injection and menu layout still require game verification.'
