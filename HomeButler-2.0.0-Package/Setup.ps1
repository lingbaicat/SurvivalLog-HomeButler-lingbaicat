param([ValidateSet('Check','Install','Uninstall')][string]$Action='Check')
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
$packageRoot=$PSScriptRoot
$stateDir='.state'
$gameRoot=[IO.Path]::GetFullPath((Split-Path $packageRoot -Parent))
$utf8=[Text.UTF8Encoding]::new($false)

function SafePath([string]$root,[string]$relative) {
    if ([IO.Path]::IsPathRooted($relative)) { throw 'Absolute paths are forbidden in package manifests.' }
    $prefix=[IO.Path]::GetFullPath($root).TrimEnd('\')+'\'
    $full=[IO.Path]::GetFullPath((Join-Path $root $relative))
    if (!$full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes package/game directory.' }
    $cursor=$full
    while($cursor -and $cursor.Length -ge $prefix.TrimEnd('\').Length) {
        if(Test-Path -LiteralPath $cursor) {
            if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked paths are not supported: $cursor" }
        }
        $cursor=Split-Path $cursor -Parent
    }
    return $full
}
function Hash([string]$path) {
    if(![IO.File]::Exists($path)){return ''}
    $sha=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($path)
    try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
}
function BytesHash([byte[]]$bytes) { $sha=[Security.Cryptography.SHA256]::Create(); try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}finally{$sha.Dispose()} }
function WriteBytes([string]$path,[byte[]]$bytes) {
    [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
    $temp=$path+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllBytes($temp,$bytes)
        if([IO.File]::Exists($path)){[IO.File]::Replace($temp,$path,[NullString]::Value)}else{[IO.File]::Move($temp,$path)}
    } finally { if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)} }
}
function SaveState($state) {
    $path=SafePath $packageRoot ($stateDir+'\current.json')
    WriteBytes $path $utf8.GetBytes(($state | ConvertTo-Json -Depth 8))
}
function LoadState {
    $path=SafePath $packageRoot ($stateDir+'\current.json')
    if(Test-Path -LiteralPath $path){return ([IO.File]::ReadAllText($path) | ConvertFrom-Json)}
    return $null
}
function AssertStopped {
    foreach($proc in Get-Process -Name SurvivalLog -ErrorAction SilentlyContinue) {
        if(!$proc.Path -or [IO.Path]::GetFullPath($proc.Path) -eq (Join-Path $gameRoot 'SurvivalLog.exe')) { throw 'Close this Survival Log installation before installing or uninstalling.' }
    }
}
function RestoreState($state) {
    $configRestores=@{}
    $preserveConfigs=@{}
    # Validate every destination and backup before touching any of them.
    foreach($r in $state.Files) {
        $target=SafePath $gameRoot $r.Path
        $now=Hash $target
        if($now -ne $r.After -and $now -ne $r.Before) {
            if($r.Path -eq 'BepInEx\config\BepInEx.cfg' -and (Test-Path -LiteralPath $target)) {
                $previous=if($r.Before){[IO.File]::ReadAllText((SafePath $packageRoot $r.Backup))}else{''}
                $restored=RestoreOfflineKeys ([IO.File]::ReadAllText($target)) $previous
                $configRestores[$r.Path]=$utf8.GetBytes($restored)
            } elseif($r.Path -like 'BepInEx\config\*.cfg') {
                $preserveConfigs[$r.Path]=$true
            } else {throw "File changed after installation; refusing to overwrite: $($r.Path)"}
        }
        if($r.Before) {
            $backup=SafePath $packageRoot $r.Backup
            if((Hash $backup) -ne $r.Before){throw "Backup missing or damaged: $($r.Path)"}
        }
    }
    for($ri=@($state.Files).Count-1; $ri -ge 0; $ri--) {
        $r=$state.Files[$ri]
        $target=SafePath $gameRoot $r.Path
        if($preserveConfigs.ContainsKey($r.Path)){continue}
        if($configRestores.ContainsKey($r.Path)) {
            $bytes=$configRestores[$r.Path]
            WriteBytes $target $bytes
            if((Hash $target) -ne (BytesHash $bytes)){throw 'Config restore verification failed.'}
            continue
        }
        if((Hash $target) -eq $r.Before){continue}
        if($r.Before){WriteBytes $target ([IO.File]::ReadAllBytes((SafePath $packageRoot $r.Backup)))}
        elseif(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Force}
        if((Hash $target) -ne $r.Before){throw "Restore verification failed: $($r.Path)"}
    }
    $state.Status='uninstalled'; SaveState $state
}
try {
    if(![Environment]::Is64BitOperatingSystem){throw 'Windows x64 is required.'}
    if(!(Test-Path -LiteralPath (SafePath $gameRoot 'SurvivalLog.exe') -PathType Leaf)){throw 'Extract beside SurvivalLog.exe, then run Install.cmd. Do not run inside the ZIP.'}
    $manifest=[IO.File]::ReadAllText((SafePath $packageRoot 'manifest.json')) | ConvertFrom-Json
    foreach($f in $manifest.PackageFiles) { if((Hash (SafePath $packageRoot $f.Path)) -ne $f.SHA256){throw ('Package damaged: '+$f.Path)} }
    . (Join-Path $packageRoot 'OfflineConfig.ps1')
    Add-Type -Path @((SafePath $packageRoot 'source/AdaptiveLayout.cs'),(SafePath $packageRoot 'source/PanelLayout.cs'))
    if(Test-Path -LiteralPath (SafePath $packageRoot '.safe-state.json')) {throw 'Safe mode is active. Run RestoreMods.cmd before install/check/uninstall; this restores settings but does not launch the game.'}
    $state=LoadState
    if($Action -eq 'Uninstall') {
        AssertStopped
        if(!$state -or $state.Status -eq 'uninstalled'){Write-Host 'Nothing installed by this package.'; exit 0}
        RestoreState $state
        Write-Host 'Uninstalled. Pre-existing files restored; unrelated files and saves untouched.'
        exit 0
    }
    if($state -and $state.Status -eq 'installing'){throw 'An earlier installation was interrupted. Run Uninstall.cmd to recover before retrying.'}
    $versionPath=SafePath $gameRoot $manifest.VersionFile
    if(!(Test-Path -LiteralPath $versionPath)){throw 'Game version file missing.'}
    $gameVersion=[IO.File]::ReadAllText($versionPath).Trim()
    if($gameVersion -ne $manifest.GameVersion){Write-Warning "Untested game version $gameVersion; checking layout structure. Native API compatibility is not guaranteed."}
    $unity=[Diagnostics.FileVersionInfo]::GetVersionInfo((SafePath $gameRoot 'UnityPlayer.dll')).FileVersion
    if(!$unity.StartsWith('6000.2.7.')){throw 'Unity engine changed. This offline runtime supports 6000.2.7 only.'}
    [AdaptiveLayout]::Apply($gameRoot,$true) | Write-Host
    $plan=New-Object 'System.Collections.Generic.List[object]'
    function PlanFile([string]$relative,[byte[]]$bytes,[bool]$allowReplace=$false) {
        $target=SafePath $gameRoot $relative
        $before=Hash $target; $after=BytesHash $bytes
        if($before -eq $after){return}
        if($before -and !$allowReplace){throw "Existing file conflicts with this bundle: $relative. No files changed."}
        if((Test-Path -LiteralPath $target) -and !(Test-Path -LiteralPath $target -PathType Leaf)){throw "Expected a file: $relative"}
        $plan.Add([pscustomobject]@{Path=$relative;Before=$before;After=$after;Bytes=$bytes})
    }
    $catalogScript=[IO.File]::ReadAllText((SafePath $packageRoot 'source/ContainerUI.js'))
    $inlineScript=[IO.File]::ReadAllText((SafePath $packageRoot 'source/InlineEditor/InlineEditor.js'))
    $navigationScript=[IO.File]::ReadAllText((SafePath $packageRoot 'source/Navigation/Navigation.js'))
    foreach($page in [PanelLayout]::Pages) {
        $relative='SurvivalLog_Data/StreamingAssets/WebUI/UI/'+$page+'/'+$page+'.html'
        $text=[IO.File]::ReadAllText((SafePath $gameRoot $relative))
        if($page -eq 'BackpackUI'){$text=[AdaptiveLayout]::Transform($text)}
        $text=[PanelLayout]::Transform($text,$page,$catalogScript)
        if($page -in @('BackpackUI','Cooking','ToolTable','BrewPanel','RatCage','TradeUI') -and !$text.Contains('id="homebutler-navigation-v100"')) {
            $text=$text.Replace('</body>',"<script id=`"homebutler-navigation-v100`">`n"+$navigationScript+"`n</script>`n</body>")
        }
        if($page -eq 'BackpackUI') {
            if(([regex]::Matches($text,'</body>')).Count -ne 1){throw 'Ambiguous BackpackUI body.'}
            $text=[regex]::Replace($text,'<script id="homebutler-inline-editor-v(?:100|110|111)">[\s\S]*?</script>\r?\n?','')
            $bridge='window.__hbRightBag = bagB; /* hb-right-state-v111 */'
            if(!$text.Contains($bridge)) {
                $anchor='const bagB = makeBagState();'
                if(([regex]::Matches($text,[regex]::Escape($anchor))).Count -ne 1){throw 'Unsupported right-container state structure.'}
                $text=$text.Replace($anchor,$anchor+"`n                "+$bridge)
            }
            $text=$text.Replace('</body>',"<script id=`"homebutler-inline-editor-v111`">`n"+$inlineScript+"`n</script>`n</body>")
        }
        PlanFile $relative $utf8.GetBytes($text) $true
    }
    foreach($f in $manifest.Payload) {
        $allowed=$false
        $entry=$manifest.UpgradeHashes.PSObject.Properties[$f.Target]
        if($null -ne $entry){$allowed=(Hash (SafePath $gameRoot $f.Target)) -in $entry.Value}
        PlanFile $f.Target ([IO.File]::ReadAllBytes((SafePath $packageRoot $f.Source))) $allowed
    }
    PlanFile $manifest.Offline.Target ([IO.File]::ReadAllBytes((SafePath $packageRoot $manifest.Offline.Source))) $true
    $coreConfig=SafePath $gameRoot 'BepInEx\config\BepInEx.cfg'
    $configText=if(Test-Path -LiteralPath $coreConfig){[IO.File]::ReadAllText($coreConfig)}else{''}
    if(!(Test-Path -LiteralPath $coreConfig)){$configText="[Logging.Console]`r`nEnabled = false`r`n[Logging.Disk]`r`nEnabled = true`r`n"}
    $configText=$configText.Replace("`r`r`n","`r`n")
    $alreadyOffline=TestOfflineConfig $configText
    # Preserve other sections and values. Reject ambiguity rather than editing a duplicate section.
    $sections=[regex]::Matches($configText,'(?m)^\[IL2CPP\][ \t]*\r?$')
    if($sections.Count -gt 1){throw 'Duplicate [IL2CPP] sections in BepInEx.cfg.'}
    if(!$sections.Count){$configText += "`r`n[IL2CPP]`r`n"}
    foreach($setting in @(@('UnityBaseLibrariesSource',$manifest.Offline.FileName),@('UpdateInteropAssemblies','true'),@('IL2CPPInteropAssembliesPath','{BepInEx}'))) {
        $section=[regex]::Match($configText,'(?ms)^\[IL2CPP\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)')
        if(!$section.Success){throw 'Cannot parse [IL2CPP] section in BepInEx.cfg.'}
        $body=$section.Groups['body'].Value
        $pattern='(?m)^'+[regex]::Escape($setting[0])+'[ \t]*=[^\r\n]*'
        $entries=[regex]::Matches($body,$pattern)
        if($entries.Count -gt 1){throw ('Duplicate config key: '+$setting[0])}
        $line=$setting[0]+' = '+$setting[1]
        if($entries.Count){$body=[regex]::Replace($body,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $line})}
        else{$body += "`r`n"+$line+"`r`n"}
        $configText=$configText.Substring(0,$section.Groups['body'].Index)+$body+$configText.Substring($section.Groups['body'].Index+$section.Groups['body'].Length)
    }
    if(!$alreadyOffline){PlanFile 'BepInEx\config\BepInEx.cfg' $utf8.GetBytes($configText) $true}
    # Fail before installation if the generated-cache path is a linked path.
    $interopHash=SafePath $gameRoot 'BepInEx\interop\assembly-hash.txt'
    $interopCore=SafePath $gameRoot 'BepInEx\interop\UnityEngine.CoreModule.dll'
    $interopGame=SafePath $gameRoot 'BepInEx\interop\HotUpdate.dll'
    # Check renamed/duplicate copies before the BepInEx loader can load them twice.
    $plugins=SafePath $gameRoot 'BepInEx\plugins'
    if(Test-Path -LiteralPath $plugins) {
        foreach($file in Get-ChildItem -LiteralPath $plugins -File -Recurse -Filter '*.dll') {
            $simple=''
            try{$simple=[Reflection.AssemblyName]::GetAssemblyName($file.FullName).Name}catch{}
            if($simple -in @('BaseButler','BaseButler.HomeAccess','BaseButler.NativeCompatibility','BaseButler.ContainerNavigation','BaseButler.ContainerInlineEditor')) {
                $expected=SafePath $gameRoot ('BepInEx\plugins\'+$simple+'.dll')
                if($file.FullName -ne $expected){throw "Duplicate/relocated plugin detected: $($file.FullName)"}
            }
            if($simple -eq 'CookingSourceExpand'){throw 'Legacy CookingSourceExpand plugin detected. Remove it before installing.'}
        }
    }
    foreach($c in $manifest.Configs) {
        $target=SafePath $gameRoot $c.Target
        if(!(Test-Path -LiteralPath $target)) {
            PlanFile $c.Target ([IO.File]::ReadAllBytes((SafePath $packageRoot $c.Source)))
        } elseif($c.Target -eq 'BepInEx\config\com.basebutler.mod.cfg') {
            $text=[IO.File]::ReadAllText($target)
            $section=[regex]::Match($text,'(?ms)^\[Split\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
            if(!$section.Success){throw 'Existing BaseButler config has no [Split] section; cannot safely migrate it.'}
            $body=$section.Groups['body'].Value
            $keys=[regex]::Matches($body,'(?m)^OneModifier\s*=\s*([^\r\n]+)')
            if($keys.Count -ne 1){throw 'Existing OneModifier setting is missing or duplicated.'}
            if($keys[0].Groups[1].Value.Trim() -eq 'LeftAlt') {
                $fixed=[regex]::Replace($body,'(?m)^(OneModifier[ \t]*=[ \t]*)LeftAlt[ \t]*(?=\r?$)', '${1}Tab')
                $text=$text.Substring(0,$section.Groups['body'].Index)+$fixed+$text.Substring($section.Groups['body'].Index+$body.Length)
                PlanFile $c.Target $utf8.GetBytes($text) $true
            }
        }
    }
    if($state -and $state.Status -eq 'installed') {
        foreach($r in $state.Files){
            $path=SafePath $gameRoot $r.Path
            if((Hash $path) -ne $r.After){
                if($r.Path -eq 'BepInEx\config\BepInEx.cfg' -and (Test-Path -LiteralPath $path) -and (TestOfflineConfig ([IO.File]::ReadAllText($path)))){continue}
                if($r.Path -like 'BepInEx\config\*.cfg' -and $r.Path -ne 'BepInEx\config\BepInEx.cfg' -and (Test-Path -LiteralPath $path)){continue}
                throw "Installation changed: $($r.Path). Run Check.cmd and inspect before reinstalling."
            }
        }
        if($plan.Count){throw 'New changes detected after installation. Uninstall this package before reinstalling.'}
        if($Action -eq 'Install'){AssertStopped}
        Write-Host 'Already installed and verified. Original backups preserved.'; exit 0
    }
    Write-Host "Checked game $($manifest.GameVersion); $($plan.Count) file changes planned."
    if($Action -eq 'Check'){Write-Host 'Check passed. No game files changed.'; exit 0}
    AssertStopped
    $id=[Guid]::NewGuid().ToString('N')
    $records=New-Object 'System.Collections.Generic.List[object]'
    foreach($p in $plan) {
        $backup=$stateDir+'\backups\'+$id+'\'+$p.Path
        if($p.Before){WriteBytes (SafePath $packageRoot $backup) ([IO.File]::ReadAllBytes((SafePath $gameRoot $p.Path)))}
        $records.Add([pscustomobject]@{Path=$p.Path;Before=$p.Before;After=$p.After;Backup=$backup})
    }
    $state=[pscustomobject]@{Version=$manifest.Release;Status='installing';Files=@($records.ToArray())}
    SaveState $state
    try {
        foreach($p in $plan) {
            $target=SafePath $gameRoot $p.Path
            if((Hash $target) -ne $p.Before){throw "File changed during installation: $($p.Path)"}
            WriteBytes $target $p.Bytes
            if((Hash $target) -ne $p.After){throw "Write verification failed: $($p.Path)"}
        }
        # Derived cache only: invalidating this marker makes BepInEx regenerate an incomplete interop set.
        # Preserve its previous content for diagnostics, but never restore stale cache on uninstall.
        if((Test-Path -LiteralPath $interopHash) -and (!(Test-Path -LiteralPath $interopCore) -or !(Test-Path -LiteralPath $interopGame))) {
            WriteBytes (SafePath $packageRoot ($stateDir+'\previous-assembly-hash.txt')) ([IO.File]::ReadAllBytes($interopHash))
            WriteBytes $interopHash $utf8.GetBytes('HomeButler offline: regenerate incomplete cache')
        }
        $state.Status='installed'; SaveState $state
    } catch {
        $failure=$_.Exception.Message
        try{RestoreState $state}catch{Write-Warning "Automatic restore could not finish: $($_.Exception.Message). Keep this folder and run Uninstall.cmd after resolving the conflict."}
        throw $failure
    }
    Write-Host 'Installed successfully. Start the game through Launch.cmd. First launch generates interop locally using the bundled Unity archive; no component download needed.'
    Write-Host 'Keep the HomeButler-2.0.0-Package folder: it contains your uninstall backups.'
    exit 0
} catch {
    Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red
    exit 1
}
