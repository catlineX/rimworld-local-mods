param([Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$yokai=@{}
foreach($dir in @('Common','1.6','')){
    $folder=Join-Path ('F:/SteamLibrary/steamapps/workshop/content/294100/1532938687/'+$dir) 'Languages/ChineseSimplified'
    if(!(Test-Path $folder)){continue}
    foreach($file in Get-ChildItem $folder -Recurse -File -Filter '*.xml'){
        try{$doc=[xml](Get-Content $file.FullName -Raw -Encoding UTF8);foreach($n in $doc.DocumentElement.ChildNodes){if($n.NodeType -eq 'Element'){$yokai[$file.Name+'|'+$n.Name.Replace(']','').Replace('[','.')]= $true}}}catch{}
    }
}
$excluded=0
$xml=New-Object Xml.XmlDocument
[void]$xml.AppendChild($xml.CreateXmlDeclaration('1.0','utf-8',$null))
$top=$xml.CreateElement('repairs');[void]$xml.AppendChild($top)
foreach($line in Get-Content -LiteralPath $Report -Encoding UTF8){
    $type=$null;$key=$null;$file=$null;$reason=$null
    if($line -match '^Found no (\S+) named \S+ to match (\S+) \(([^()]+)\)$'){$type=$Matches[1];$key=$Matches[2];$file=$Matches[3];$reason='missing-target'}
    elseif($line -match "^Couldn't inject (\S+) into (\S+) \(([^()]+)\):"){$key=$Matches[1];$type=$Matches[2];$file=$Matches[3];$reason='invalid-path'}
    elseif($line -match '^Duplicate def-injected.*Both \S+ and (\S+) refer.*\(([^()]+\.xml)\)$'){$key=$Matches[1];$type='Verse.ThingDef';$file=$Matches[2];$reason='duplicate-alias'}
    if(!$type){continue}
    if($yokai.ContainsKey($file+'|'+$key) -or $key -match '^(Yokai|UniHAR_Yokai)' -or $file -match 'Yokai|Yokaibandage'){$excluded++;continue}
    $entry=$xml.CreateElement('entry');$entry.SetAttribute('type',$type);$entry.SetAttribute('file',$file);$entry.SetAttribute('key',$key);$entry.SetAttribute('reason',$reason);[void]$top.AppendChild($entry)
}
if($top.ChildNodes.Count+$excluded -ne 819){throw 'Reviewed error count mismatch'}
[void](New-Item (Join-Path $root 'Repairs') -ItemType Directory -Force)
$xml.Save((Join-Path $root 'Repairs/KnownErrors.xml'))
Write-Host "Recorded $($top.ChildNodes.Count) field rules; $excluded Yokai entries explicitly excluded; only MarkThatPawn directory repair remains."
