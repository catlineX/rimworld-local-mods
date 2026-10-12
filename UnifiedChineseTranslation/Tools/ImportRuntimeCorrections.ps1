param([Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$lines=Get-Content -LiteralPath $Report -Encoding UTF8
$own=@{}; $aliases=@{}; $slate=@{}
foreach($line in $lines){
    if($line -match '^OWN_UNINJECTED \S+ (\S+)$'){$own[$Matches[1]]=$true}
    if($line -match '^Duplicate def-injected translation key\. Both (\S+) and (\S+) refer to the same field'){$aliases[$Matches[2]]=$Matches[1]}
    if($line -match '^Translated non-System.String field \S+ of type .*SlateRef.* at path (\S+)\. Expected'){$slate[$Matches[1]]=$true}
}
$baseline=Get-Content 'D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-audit/baseline-candidates.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$sources=@{}; foreach($c in $baseline){$sources[$c.key]=$c.source}
$corrections=@(); $accounted=@{}
foreach($file in Get-ChildItem (Join-Path $root 'Modules') -Recurse -Filter '*.xml' -File){
    if($file.FullName -notmatch '\\Modules\\([^\\]+)\\Languages\\ChineseSimplified\\DefInjected\\([^\\]+)\\'){continue}
    $module=$Matches[1]; $type=$Matches[2]; $x=[xml](Get-Content $file.FullName -Raw -Encoding UTF8)
    foreach($node in $x.LanguageData.ChildNodes){
        if($node.NodeType -ne 'Element'){continue}
        $old=$node.Name; $key=$old; $kind='DefInjected'; $newType=$type; $reason=$null
        if($own.ContainsKey($old) -and $aliases.ContainsKey($old)){$key=$aliases[$old];$reason='runtime-confirmed-canonical-handle'}
        elseif($own.ContainsKey($old) -and $slate.ContainsKey($old)){$key=$old+'.slateRef';$reason='runtime-confirmed-SlateRef-string-field'}
        elseif($old -match '^Polaris[^.]+\.comps\.\d+\.useLabel$' -and $own.ContainsKey($old)){
            $doc=[xml](Get-Content $sources[$old] -Raw -Encoding UTF8); $parts=$old.Split('.')
            $items=@($doc.SelectSingleNode('/Defs/*[defName="'+$parts[0]+'"]/comps').ChildNodes | Where-Object {$_.NodeType -eq 'Element'})
            $item=$items[[int]$parts[2]]; $handle='CompUsable'
            if($item.compClass){$handle=([string]$item.compClass).Split('.')[-1]}
            elseif($item.GetAttribute('Class') -eq 'Polarisbloc.CompProperties_IdeoCode'){$handle='CompIdeoCode'}
            elseif($item.GetAttribute('Class') -ne 'CompProperties_Usable'){throw "Unverified component: $old"}
            $key=$parts[0]+'.comps.'+$handle+'.useLabel';$reason='source-and-assembly-confirmed-component-handle'
        }
        elseif($old -eq 'YokaiVillage_newPersonYadorigi.scenario.parts.0.text'){$key='YokaiVillage_newPersonYadorigi.scenario.parts.GameStartDialog.text';$reason='ScenPart-def-TranslationHandle'}
        # Convert ALL settings with author-supplied tKeys, not just the two out-of-range entries.
        if($module -eq 'ComplexJobs' -and $old -match '^FrozenSnowFoxComplexJobsSettings\.settings\.(\d+)\.(label|text)$'){
            $number=[int]$Matches[1]
            $doc=[xml](Get-Content $sources[$old] -Raw -Encoding UTF8)
            $items=@($doc.SelectSingleNode('/Defs/XmlExtensions.SettingsMenuDef/settings').ChildNodes | Where-Object {$_.NodeType -eq 'Element'})
            $item=$items[$number]; $tKey=[string]$item.tKey
            if(!$tKey){throw "Missing author tKey: $old"}
            $key=$tKey;$kind='Keyed';$newType='';$reason='XmlExtensions-TranslateIfTKeyAvailable-confirmed'
        }
        if($reason){
            $corrections += [pscustomobject]@{module=$module;oldKind='DefInjected';oldDefType=$type;oldKey=$old;kind=$kind;defType=$newType;key=$key;reason=$reason}
            if($own.ContainsKey($old)){$accounted[$old]=$true}
        }
    }
}
foreach($key in $own.Keys){if(!$accounted.ContainsKey($key)){throw "Unaccounted runtime failure: $key"}}
$corrections | Sort-Object module,oldKey | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'PathCorrections.json') -Encoding UTF8
Write-Host "Recorded $($corrections.Count) reproducible path corrections; all $($own.Count) reported failures accounted for."
