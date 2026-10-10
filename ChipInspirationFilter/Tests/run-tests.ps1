$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repoRoot 'config/workspace.json') | ConvertFrom-Json
$testRoot = Join-Path (Join-Path $repoRoot '../work') ('chip-filter-test-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot -Force)
$output = Join-Path $testRoot 'ChipFilterTests.exe'
& $workspace.compiler '/nologo' '/target:exe' ('/out:' + $output) (Join-Path $PSScriptRoot '../Source/ChipInspirationFilter.cs') (Join-Path $PSScriptRoot 'Stubs.cs') (Join-Path $PSScriptRoot 'Program.cs')
if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
& $output
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
Write-Host "Test-only artifacts (not runtime verification): $testRoot"
