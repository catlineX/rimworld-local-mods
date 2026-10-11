param([switch]$Apply)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repo 'config/workspace.json') | ConvertFrom-Json
$config=[IO.Path]::GetFullPath((Join-Path $workspace.gameConfigPath 'ModsConfig.xml'))
$newId='local.xuewen.unifiedchinesetranslation'
$oldIds=@('local.xuewen.glitternet.zhcnfix','local.xuewen.custominfestations.continued.zhcn')
if(Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue){throw 'Game running; configuration not changed'}
$doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.Load($config)
$active=$doc.SelectSingleNode('/ModsConfigData/activeMods');if(!$active){throw 'Missing activeMods'}
$before=@($active.SelectNodes('li') | ForEach-Object {$_.InnerText})
$untouched=@($before | Where-Object {$_ -notin $oldIds -and $_ -ne $newId})
Write-Host 'Only enable unified translation at the end and disable the two replaced local translation patches; keep all other mods.'
if(!$Apply){Write-Host 'Dry run: no configuration write';return}
if(!(Test-Path -LiteralPath (Join-Path $workspace.gamePath 'Mods/UnifiedChineseTranslation/About/About.xml'))){throw 'Unified mod not deployed'}
. (Join-Path $repo 'tools/mod-workflow.ps1') -Action Inventory -Mod UnifiedChineseTranslation
# This is live game configuration, not mod source: independent backup is still required.
$backup=Backup-Targets 'unified-translation-before-config-switch' @($config)
$baseline=(Get-FileHash -LiteralPath $config).Hash
foreach($n in @($active.SelectNodes('li'))){if($n.InnerText -in $oldIds -or $n.InnerText -eq $newId){[void]$active.RemoveChild($n)}}
$node=$doc.CreateElement('li');$node.InnerText=$newId;[void]$active.AppendChild($node)
$expected=@($untouched)+@($newId)
$actual=@($active.SelectNodes('li') | ForEach-Object {$_.InnerText})
if(($expected -join '|') -cne ($actual -join '|')){throw 'Unrelated enabled mods changed'}
if(Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue){throw 'Game started; configuration write stopped'}
if((Get-FileHash -LiteralPath $config).Hash -ne $baseline){throw 'Configuration changed concurrently; write stopped'}
$temp=Join-Path $workspace.gameConfigPath ('ModsConfig.unified-translation-'+[Guid]::NewGuid().ToString('N')+'.tmp')
$doc.Save($temp)
$check=New-Object Xml.XmlDocument;$check.Load($temp)
if((@($check.SelectNodes('/ModsConfigData/activeMods/li') | ForEach-Object {$_.InnerText}) -join '|') -cne ($expected -join '|')){throw 'Temporary config verification failed'}
if((Get-FileHash -LiteralPath $config).Hash -ne $baseline){throw 'Configuration changed concurrently; replacement stopped'}
[IO.File]::Replace($temp,$config,[NullString]::Value)
$check.Load($config)
if((@($check.SelectNodes('/ModsConfigData/activeMods/li') | ForEach-Object {$_.InnerText}) -join '|') -cne ($expected -join '|')){throw 'Final configuration verification failed; restore from reported backup'}
Write-Host "Enabled unified translation; other mod order unchanged. Config backup: $backup"
