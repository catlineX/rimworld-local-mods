$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output='D:/learn/openCode/content/game-data/rimworld/reports/unified-translation-tests'
[void](New-Item -ItemType Directory -Path $output -Force)
$exe=Join-Path $output ('translation-loading-'+[guid]::NewGuid().ToString('N')+'.exe')
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /reference:System.Xml.dll ('/out:'+$exe) (Join-Path $root 'Source/TranslationLoading.cs') (Join-Path $root 'Tests/TranslationLoadingTests.cs')
if($LASTEXITCODE -ne 0){throw 'Stand-in tests did not compile'}
& $exe
if($LASTEXITCODE -ne 0){throw 'Stand-in tests failed'}
