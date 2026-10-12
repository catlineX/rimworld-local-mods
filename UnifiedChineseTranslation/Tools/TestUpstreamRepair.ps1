$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output='D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-tests'
[void](New-Item $output -ItemType Directory -Force)
$exe=Join-Path $output ('upstream-repair-'+[guid]::NewGuid().ToString('N')+'.exe')
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /reference:System.Xml.dll ('/out:'+$exe) (Join-Path $root 'Source/UpstreamTranslationRepair.cs') (Join-Path $root 'Tests/UpstreamRepairTests.cs')
if($LASTEXITCODE -ne 0){throw 'Repair tests compilation failed'}
& $exe
if($LASTEXITCODE -ne 0){throw 'Repair tests failed'}
