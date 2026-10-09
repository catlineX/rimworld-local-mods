param(
    [ValidateSet('Inventory','Validate','Backup','Build','Deploy','Package','ConfigSnapshot','SkillDeploy','GitStatus','Connect')]
    [string]$Action = 'Inventory',
    [string]$Mod,
    [string]$RemoteUrl,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace = Get-Content -LiteralPath (Join-Path $repoRoot 'config/workspace.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$registry = Get-Content -LiteralPath (Join-Path $repoRoot 'config/mod-registry.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Scoped-Path([string]$Base, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) { throw "Expected relative path: $Relative" }
    $basePath = [IO.Path]::GetFullPath($Base).TrimEnd('\','/')
    $full = [IO.Path]::GetFullPath((Join-Path $basePath $Relative))
    if (-not $full.StartsWith($basePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes scope: $Relative"
    }
    return $full
}
function Selected-Mods {
    if ($Mod) {
        $found = @($registry.mods | Where-Object { $_.name -eq $Mod })
        if ($found.Count -ne 1) { throw "Unknown or ambiguous mod: $Mod" }
        return $found
    }
    return @($registry.mods)
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Backup-Targets([string]$Label, [string[]]$Paths) {
    $backup = Join-Path $workspace.backupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $Label + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6))
    if ($DryRun) { Write-Host "DRY RUN backup: $backup"; return $backup }
    [void](New-Item -ItemType Directory -Path $backup)
    $records = @(); $index = 0
    foreach ($path in $Paths) {
        $exists = Test-Path -LiteralPath $path
        $entry = [ordered]@{ source=$path; existed=$exists; copy=$null; files=@() }
        if ($exists) {
            $index++
            $copy = Join-Path $backup ($index.ToString('00') + '-' + (Split-Path $path -Leaf))
            Copy-Item -LiteralPath $path -Destination $copy -Recurse
            $entry.copy=$copy
            if ((Get-Item -LiteralPath $path).PSIsContainer) {
                foreach ($file in (Get-ChildItem -LiteralPath $path -Recurse -File)) {
                    $relative=$file.FullName.Substring($path.TrimEnd('\','/').Length+1)
                    $expected=Hash $file.FullName
                    if ($expected -ne (Hash (Join-Path $copy $relative))) { throw "Backup verification failed: $relative" }
                    $entry.files+=@{relative=$relative;sha256=$expected}
                }
            } else {
                $expected=Hash $path
                if ($expected -ne (Hash $copy)) { throw "Backup verification failed: $path" }
                $entry.files+=@{relative=(Split-Path $path -Leaf);sha256=$expected}
            }
        }
        $records+=$entry
    }
    $record=@{createdAt=(Get-Date).ToString('o');purpose=$Label;gamePath=$workspace.gamePath;targets=$records}
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $backup 'manifest.json') -Encoding UTF8
    Write-Host "Verified backup: $backup"
    return $backup
}
function Validate-Mod($Entry) {
    $source=Scoped-Path $repoRoot $Entry.sourceDir
    $about=New-Object System.Xml.XmlDocument
    $about.Load((Join-Path $source 'About/About.xml'))
    if ($about.ModMetaData.packageId -ne $Entry.packageId) { throw "Package ID mismatch: $($Entry.name)" }
    if ('1.6' -notin @($about.ModMetaData.supportedVersions.li)) { throw "Missing 1.6 declaration: $($Entry.name)" }
    foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -Filter '*.xml' -File)) {
        $xml=New-Object System.Xml.XmlDocument
        $xml.Load($file.FullName)
    }
    foreach ($path in @($Entry.sourceFiles)) {
        if (-not (Test-Path -LiteralPath (Scoped-Path $source $path))) { throw "Missing source: $path" }
    }
    if ($Entry.assembly) {
        $dll=Scoped-Path $source ('Assemblies/' + $Entry.assembly)
        if (-not (Test-Path -LiteralPath $dll)) { throw "Missing distributable DLL: $dll" }
        [void][Reflection.AssemblyName]::GetAssemblyName($dll)
    }
    Write-Host "XML and metadata valid: $($Entry.name) (runtime/XPath semantics not executed)"
}
function Check-GameStopped {
    if (Get-Process -Name RimWorldWin64 -ErrorAction SilentlyContinue) { throw 'Game is running; close it before deployment/config replacement.' }
}

switch ($Action) {
    'Inventory' {
        foreach ($entry in (Selected-Mods)) {
            $source=Scoped-Path $repoRoot $entry.sourceDir
            $install=Scoped-Path (Join-Path $workspace.gamePath 'Mods') $entry.installDir
            $different=0
            foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
                $relative=$file.FullName.Substring($source.Length+1)
                $dest=Join-Path $install $relative
                if (-not (Test-Path -LiteralPath $dest) -or (Hash $file.FullName) -ne (Hash $dest)) { $different++ }
            }
            [pscustomobject]@{Mod=$entry.name;PackageId=$entry.packageId;Installed=(Test-Path -LiteralPath $install);DifferentOrMissingFiles=$different}
        }
    }
    'Validate' { foreach ($entry in (Selected-Mods)) { Validate-Mod $entry } }
    'Backup' {
        foreach ($entry in (Selected-Mods)) {
            $source=Scoped-Path $repoRoot $entry.sourceDir
            $install=Scoped-Path (Join-Path $workspace.gamePath 'Mods') $entry.installDir
            [void](Backup-Targets ($entry.name+'-manual') @($source,$install))
        }
    }
    'Build' {
        foreach ($entry in (Selected-Mods)) {
            if (-not $entry.assembly) { Write-Host "XML-only, no compile: $($entry.name)"; continue }
            $source=Scoped-Path $repoRoot $entry.sourceDir
            [void](Backup-Targets ($entry.name+'-before-build') @($source))
            $managed=Join-Path $workspace.gamePath 'RimWorldWin64_Data/Managed'
            $output=Scoped-Path $source ('Assemblies/'+$entry.assembly)
            $compileArgs=@('/nologo','/noconfig','/target:library','/optimize+','/nostdlib',('/out:'+$output))
            foreach ($name in @('mscorlib','System','System.Core','netstandard','Assembly-CSharp','UnityEngine.CoreModule','UnityEngine.IMGUIModule')) {
                $compileArgs+=('/reference:'+(Join-Path $managed ($name+'.dll')))
            }
            foreach ($file in @($entry.sourceFiles)) { $compileArgs+=(Scoped-Path $source $file) }
            if ($DryRun) { Write-Host "DRY RUN compile: $($entry.name)"; continue }
            & $workspace.compiler @compileArgs
            if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($entry.name)" }
            Validate-Mod $entry
        }
    }
    'Deploy' {
        if (-not $Mod) { throw 'Deploy requires -Mod to identify the exact target.' }
        $entry=@(Selected-Mods)[0]; Validate-Mod $entry
        $source=Scoped-Path $repoRoot $entry.sourceDir
        $target=Scoped-Path (Join-Path $workspace.gamePath 'Mods') $entry.installDir
        if ($DryRun) { Write-Host "DRY RUN deploy $source -> $target (source files only; no deletion)"; break }
        Check-GameStopped
        [void](Backup-Targets ($entry.name+'-before-deploy') @($source,$target))
        if (-not (Test-Path -LiteralPath $target)) { [void](New-Item -ItemType Directory -Path $target) }
        foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
            $relative=$file.FullName.Substring($source.Length+1)
            $dest=Scoped-Path $target $relative
            $parent=Split-Path $dest -Parent
            if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
            Copy-Item -LiteralPath $file.FullName -Destination $dest
            if ((Hash $file.FullName) -ne (Hash $dest)) { throw "Deploy verification failed: $relative" }
        }
        Write-Host 'Deployment verified; extra destination files retained. Enable in-game separately.'
    }
    'Package' {
        if (-not $Mod) { throw 'Package requires -Mod.' }
        $entry=@(Selected-Mods)[0]; Validate-Mod $entry
        $source=Scoped-Path $repoRoot $entry.sourceDir
        $meta=New-Object System.Xml.XmlDocument;$meta.Load((Join-Path $source 'About/About.xml'))
        $version=[string]$meta.ModMetaData.modVersion
        if (-not $version) { throw 'Set About/modVersion before packaging.' }
        if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+([-.][A-Za-z0-9]+)*$') { throw 'Unsafe or invalid modVersion.' }
        $zip=Join-Path $workspace.releaseRoot ($entry.name+'-v'+$version+'.zip')
        if ($DryRun) { Write-Host "DRY RUN package: $zip"; break }
        [void](Backup-Targets ($entry.name+'-before-package') @($source,$zip))
        if (-not (Test-Path -LiteralPath $workspace.releaseRoot)) {[void](New-Item -ItemType Directory -Path $workspace.releaseRoot -Force)}
        $stage=Join-Path (Join-Path $repoRoot '..\work') ('package-'+$entry.name+'-'+[Guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $stage -Force)
        $package=Join-Path $stage $entry.name;[void](New-Item -ItemType Directory -Path $package)
        foreach ($item in @('About','Assemblies','Patches','Defs','Languages','LoadFolders.xml','README.md','LICENSE','LICENSE.md')) {
            $p=Join-Path $source $item
            if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $package $item) -Recurse }
        }
        $forbidden=@(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object { $_.Name -match '^(Assembly-CSharp|UnityEngine.*|mscorlib|System.*|netstandard|0Harmony)\.dll$' -or $_.Extension -in '.rws','.log','.dmp','.pdb' })
        if ($forbidden.Count) { throw 'Forbidden runtime/state file in release package.' }
        Compress-Archive -LiteralPath $package -DestinationPath $zip -Force
        Write-Host "Package: $zip (license=$($entry.publishLicense), no remote publication)"
    }
    'ConfigSnapshot' {
        $snapshot=Join-Path $repoRoot 'config/game-mods.snapshot.json'
        $settingsDir=Join-Path $repoRoot 'config/mod-settings'
        if ($DryRun) { Write-Host "DRY RUN snapshot: $snapshot"; break }
        [void](Backup-Targets 'mod-config-before-snapshot' @($snapshot,$settingsDir))
        $d=New-Object System.Xml.XmlDocument;$d.Load((Join-Path $workspace.gameConfigPath 'ModsConfig.xml'))
        $state=@{capturedAt=(Get-Date).ToString('o');enabledPackageIds=@($d.SelectNodes('/ModsConfigData/activeMods/li') | ForEach-Object {$_.InnerText});managedPackageIds=@($registry.mods | ForEach-Object {$_.packageId})}
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $snapshot -Encoding UTF8
        if (-not (Test-Path -LiteralPath $settingsDir)) { [void](New-Item -ItemType Directory -Path $settingsDir) }
        foreach ($entry in $registry.mods) {
            foreach ($file in @($entry.settingsFiles)) {
                if ($file -notmatch '^Mod_[A-Za-z0-9_]+\.xml$') { throw 'Settings filename is not allowlisted format.' }
                $source=Scoped-Path $workspace.gameConfigPath $file
                if (Test-Path -LiteralPath $source) {
                    $xml=New-Object System.Xml.XmlDocument;$xml.Load($source)
                    if ($xml.SelectNodes('//*[contains(translate(name(),"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz"),"token") or contains(translate(name(),"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz"),"password") or contains(translate(name(),"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz"),"secret")]').Count) { throw 'Potential credential in settings snapshot.' }
                    Copy-Item -LiteralPath $source -Destination (Join-Path $settingsDir $file)
                }
            }
        }
        Write-Host 'Managed config snapshot saved; live game configuration not changed.'
    }
    'SkillDeploy' {
        $source=Scoped-Path $repoRoot $workspace.skillSourceDir
        $target=[IO.Path]::GetFullPath($workspace.skillPath)
        $allowed='D:\learn\openCode\content\skills\rimworld-mod-workflow'
        if ($target -ne $allowed) { throw 'Skill deployment target does not match the explicitly configured skill directory.' }
        if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) { throw 'Versioned skill source is missing.' }
        if ($DryRun) { Write-Host "DRY RUN skill deploy $source -> $target"; break }
        [void](Backup-Targets 'rimworld-mod-workflow-before-skill-deploy' @($source,$target))
        if (-not (Test-Path -LiteralPath $target)) { [void](New-Item -ItemType Directory -Path $target) }
        foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
            $relative=$file.FullName.Substring($source.Length+1)
            $dest=Scoped-Path $target $relative
            $parent=Split-Path $dest -Parent
            if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
            Copy-Item -LiteralPath $file.FullName -Destination $dest
            if ((Hash $file.FullName) -ne (Hash $dest)) { throw "Skill deployment verification failed: $relative" }
        }
        Write-Host 'Versioned skill deployed and hash-verified.'
    }
    'GitStatus' { & git -C $repoRoot status --short; if ($LASTEXITCODE -ne 0) { throw 'Git status failed.' } }
    'Connect' {
        if (-not $RemoteUrl) { throw 'Supply the repository URL provided by the user.' }
        if ($RemoteUrl -match '^https://') {
            $uri=[Uri]$RemoteUrl
            if ($uri.UserInfo -or $uri.Query -or $uri.Fragment) { throw 'Credentials/query are not allowed in remote URLs.' }
        } elseif ($RemoteUrl -notmatch '^git@[A-Za-z0-9.-]+:[A-Za-z0-9._/-]+(\.git)?$') { throw 'Use a credential-free HTTPS or git@host SSH URL.' }
        $remoteNames=@(& git -C $repoRoot remote)
        if ($LASTEXITCODE -ne 0) { throw 'Not an initialized Git repository.' }
        $existing=$null
        if ('origin' -in $remoteNames) { $existing=& git -C $repoRoot remote get-url origin }
        if ($existing -and $existing -ne $RemoteUrl) { throw 'Existing origin differs; do not silently overwrite it.' }
        if ($DryRun) { Write-Host 'DRY RUN connect origin (no credential handling)'; break }
        & git ls-remote --heads $RemoteUrl
        if ($LASTEXITCODE -ne 0) { throw 'Remote access failed; origin unchanged.' }
        if (-not $existing) {
            [void](Backup-Targets 'git-before-origin' @((Join-Path $repoRoot '.git/config')))
            & git -C $repoRoot remote add origin $RemoteUrl
            if ($LASTEXITCODE -ne 0) { throw 'Remote add failed.' }
        }
        Write-Host 'Origin connected. No push, release, or Workshop upload performed.'
    }
}
