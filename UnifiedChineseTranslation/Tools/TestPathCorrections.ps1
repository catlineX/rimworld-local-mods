param([string]$BaselineCommit='8972975')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repo=Split-Path $root -Parent
$corrections=Get-Content (Join-Path $root 'PathCorrections.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$count=0
foreach($p in $corrections){
    $oldGroup='DefInjected/'+$p.oldDefType
    $directory='UnifiedChineseTranslation/Modules/'+$p.module+'/Languages/ChineseSimplified/'+$oldGroup
    $found=$null
    foreach($path in @(& git -C $repo ls-tree -r --name-only $BaselineCommit -- $directory)){
        $raw=(& git -C $repo show ($BaselineCommit+':'+$path)) -join "`n"
        if($LASTEXITCODE -ne 0){throw 'Cannot read committed baseline'}
        $old=[xml]$raw;$node=$old.SelectSingleNode('/LanguageData/'+$p.oldKey)
        if($node){$found=$node.InnerText;break}
    }
    if($null -eq $found){throw "Missing baseline translation: $($p.oldKey)"}
    $group='Keyed';if($p.kind -eq 'DefInjected'){$group='DefInjected/'+$p.defType}
    $newText=$null
    foreach($file in Get-ChildItem (Join-Path $root ('Modules/'+$p.module+'/Languages/ChineseSimplified/'+$group)) -File -Filter '*.xml'){
        $new=[xml](Get-Content $file.FullName -Raw -Encoding UTF8);$node=$new.SelectSingleNode('/LanguageData/'+$p.key)
        if($node){$newText=$node.InnerText;break}
    }
    if($found -cne $newText){throw "Translation changed while repairing path: $($p.oldKey)"}
    $count++
}
Write-Host "PASS: $count corrected entries preserve exact committed translation text and placeholders."
