$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repoRoot 'config/workspace.json') | ConvertFrom-Json
$defs = New-Object System.Xml.XmlDocument
$defs.Load((Join-Path $workspace.gamePath 'Data/Core/Defs/Storyteller/Storytellers.xml'))
$patch = New-Object System.Xml.XmlDocument
$patch.Load((Join-Path $PSScriptRoot '../Patches/Interval.xml'))
$original = $defs.OuterXml
$operation = $patch.Patch.Operation
$nodes = @($defs.SelectNodes([string]$operation.xpath))
if ($nodes.Count -ne 1) { throw "Expected one current BaseStoryteller field, got $($nodes.Count)" }
$node = $nodes[0]
$before = $node.InnerText
$component = $node.ParentNode
if ($before -ne '4' -or $component.mtbDays -ne '60' -or $component.minSpacingDays -ne '60') { throw 'Upstream defaults changed; review scope before deploying.' }
$replacement = $operation.value.FirstChild
[void]$component.ReplaceChild($defs.ImportNode($replacement, $true), $node)
$days = [double]$component.mtbDays * [double]$component.existingMechanitorOrMechlinkMTBFactor
if ([Math]::Abs($days - 10) -gt 0.00001) { throw "Wrong effective interval: $days" }
if ($component.minSpacingDays -ne '60') { throw 'Minimum spacing changed.' }
Write-Host "PASS: existing mechanitor/mechlink average interval ~= $days days"
Write-Host 'PASS: base interval and minimum spacing remain 60 days'
$component.existingMechanitorOrMechlinkMTBFactor = $before
if ($defs.OuterXml -cne $original) { throw 'Unrelated upstream fields changed.' }
Write-Host 'PASS: restoring the single target field exactly reproduces original XML (all other conditions unchanged)'
