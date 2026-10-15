param([ValidateSet('Launch','Safe','Restore')][string]$Action='Launch',[switch]$NoStart)
$ErrorActionPreference='Stop'
$package=$PSScriptRoot
$root=[IO.Path]::GetFullPath((Split-Path $package -Parent))
$statePath=Join-Path $package '.safe-state.json'
$utf8=[Text.UTF8Encoding]::new($false)
function SafePath($relative) {
    if([IO.Path]::IsPathRooted($relative)){throw 'Invalid relative path.'}
    $path=[IO.Path]::GetFullPath((Join-Path $root $relative))
    if(!$path.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes game folder.'}
    for($cursor=$path;$cursor -and $cursor.Length -ge $root.Length;$cursor=Split-Path $cursor -Parent){
        if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Linked paths are unsupported.'}
    }
    return $path
}
function Hash($path){if(Test-Path -LiteralPath $path -PathType Leaf){return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash};return ''}
function BytesHash($bytes){$s=[Security.Cryptography.SHA256]::Create();try{return [BitConverter]::ToString($s.ComputeHash($bytes)).Replace('-','')}finally{$s.Dispose()}}
function WriteBytes($path,$bytes){$temp=$path+'.safe.tmp';[IO.File]::WriteAllBytes($temp,$bytes);if(Test-Path -LiteralPath $path){[IO.File]::Replace($temp,$path,[NullString]::Value)}else{[IO.File]::Move($temp,$path)}}
function Restore {
    if(!(Test-Path -LiteralPath $statePath)){return}
    $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    foreach($r in $state.Files){
        $target=SafePath $r.Path
        $backup=SafePath $r.Backup
        if((Hash $backup) -ne $r.Before){throw 'Safe-mode backup damaged.'}
        if($r.Path -eq 'doorstop_config.ini' -and (Hash $target) -notin @($r.After,$r.Before)){throw 'Doorstop settings changed during safe mode; resolve this conflict before restoring.'}
    }
    foreach($r in $state.Files){
        $target=SafePath $r.Path
        if((Hash $target) -eq $r.After){WriteBytes $target ([IO.File]::ReadAllBytes((SafePath $r.Backup)))}
        elseif((Hash $target) -ne $r.Before){Write-Warning ('Newer game page preserved: '+$r.Path)}
    }
    Remove-Item -LiteralPath $statePath
}
try {
    if(!(Test-Path -LiteralPath (SafePath 'SurvivalLog.exe'))){throw 'Extract beside SurvivalLog.exe.'}
    foreach($proc in Get-Process -Name SurvivalLog -ErrorAction SilentlyContinue){
        if(!$proc.Path -or [IO.Path]::GetFullPath($proc.Path) -eq (Join-Path $root 'SurvivalLog.exe')){throw 'Close this game before changing launch mode.'}
    }
    if($Action -eq 'Restore'){Restore;Write-Host 'Mod settings restored. No game was launched.';exit 0}
    $manifest=Get-Content -LiteralPath (Join-Path $package 'manifest.json') -Raw | ConvertFrom-Json
    $supported=$true
    if($Action -eq 'Launch'){
        foreach($f in $manifest.LaunchFingerprints){if((Hash (SafePath $f.Path)) -ne $f.SHA256){$supported=$false}}
        if($supported -and (Test-Path -LiteralPath $statePath)){Restore}
        if($supported){
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package 'Setup.ps1') -Action Check
            if($LASTEXITCODE -ne 0){$supported=$false}
            $installed=Join-Path $package '.state\current.json'
            if(!(Test-Path -LiteralPath $installed) -or (Get-Content -LiteralPath $installed -Raw | ConvertFrom-Json).Status -ne 'installed'){$supported=$false}
        }
    }
    if($Action -eq 'Safe' -or !$supported){
        Write-Warning 'Safe mode: mods disabled. Unknown game update, failed validation, or manual safe-mode request.'
        if(!(Test-Path -LiteralPath $statePath)){
            $records=New-Object 'System.Collections.Generic.List[object]'
            $id=[Guid]::NewGuid().ToString('N')
            $backupRel=(Split-Path $package -Leaf)+'/.safe-backups/'+$id
            [IO.Directory]::CreateDirectory((SafePath $backupRel))|Out-Null
            function Plan($relative,$bytes){
                $target=SafePath $relative;$before=Hash $target;$after=BytesHash $bytes
                if($before -eq $after){return}
                $backup=$backupRel+'/'+$records.Count+'.bin'
                [IO.File]::WriteAllBytes((SafePath $backup),[IO.File]::ReadAllBytes($target))
                $safe=$backup+'.safe'
                [IO.File]::WriteAllBytes((SafePath $safe),$bytes)
                $records.Add([pscustomobject]@{Path=$relative;Before=$before;After=$after;Backup=$backup;Safe=$safe})
            }
            $door=SafePath 'doorstop_config.ini'
            if(Test-Path -LiteralPath $door){
                $text=[IO.File]::ReadAllText($door)
                $section=[regex]::Match($text,'(?ms)^\[General\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)')
                $matches=[regex]::Matches($section.Groups['body'].Value,'(?m)^enabled[ \t]*=[^\r\n]*')
                if(!$section.Success -or $matches.Count -ne 1){throw 'Cannot safely disable Doorstop; check doorstop_config.ini.'}
                $body=[regex]::Replace($section.Groups['body'].Value,'(?m)^enabled[ \t]*=[^\r\n]*','enabled = false')
                $text=$text.Substring(0,$section.Groups['body'].Index)+$body+$text.Substring($section.Groups['body'].Index+$section.Groups['body'].Length)
                Plan 'doorstop_config.ini' $utf8.GetBytes($text)
            }
            $installState=Join-Path $package '.state/current.json'
            $installedFiles=@()
            if(Test-Path -LiteralPath $installState){$installedFiles=(Get-Content -LiteralPath $installState -Raw|ConvertFrom-Json).Files}
            foreach($page in 'BackpackUI','Cooking','ToolTable','BrewPanel','Heater','FuelGenerator','RatCage','Compressor','Shredder','TradeUI'){
                $rel='SurvivalLog_Data/StreamingAssets/WebUI/UI/'+$page+'/'+$page+'.html'
                $target=SafePath $rel
                if(!(Test-Path -LiteralPath $target)){continue}
                $bytes=[IO.File]::ReadAllBytes($target)
                $r=$installedFiles|Where-Object {$_.Path -eq $rel}|Select-Object -First 1
                if($r -and (Hash $target) -eq $r.After -and $r.Before){
                    $prior=SafePath ((Split-Path $package -Leaf)+'/'+$r.Backup)
                    if((Hash $prior) -ne $r.Before){throw 'Original page backup damaged.'}
                    $bytes=[IO.File]::ReadAllBytes($prior)
                }
                $text=$utf8.GetString($bytes)
                $text=[regex]::Replace($text,'<script id="homebutler-(?:navigation-v100|container-ui-v120|inline-editor-v(?:100|110|111))">[\s\S]*?</script>\r?\n?','')
                $text=$text.Replace("`n                window.__hbRightBag = bagB; /* hb-right-state-v111 */",'')
                $bytes=$utf8.GetBytes($text)
                if($page -eq 'BackpackUI' -and $text.Contains('homeaccess-adaptive-layout-v1')){
                    $original=SafePath ('BepInEx/HomeButler-layout-backups/'+(BytesHash $bytes)+'.original')
                    if((Test-Path -LiteralPath $original) -and (Test-Path -LiteralPath ($original+'.sha256')) -and (Hash $original) -eq ([IO.File]::ReadAllText($original+'.sha256').Trim())){$bytes=[IO.File]::ReadAllBytes($original)}
                    else{Write-Warning 'Earlier layout adjustment remains; if UI is abnormal, verify game files in Steam. No old game page will be forced onto a changed page.'}
                }
                Plan $rel $bytes
            }
            $state=[pscustomobject]@{Files=@($records|Select-Object Path,Before,After,Backup,Safe)}
            WriteBytes $statePath $utf8.GetBytes(($state|ConvertTo-Json -Depth 6))
        }
        # Resume an interrupted transition before launching. Never overwrite a new game page.
        $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
        foreach($r in $state.Files){
            $target=SafePath $r.Path
            if((Hash (SafePath $r.Safe)) -ne $r.After){throw 'Safe-mode payload damaged.'}
            $now=Hash $target
            if($now -eq $r.Before){WriteBytes $target ([IO.File]::ReadAllBytes((SafePath $r.Safe)))}
            elseif($now -ne $r.After -and $r.Path -eq 'doorstop_config.ini'){throw 'Doorstop settings changed; safe mode cannot be guaranteed.'}
        }
    } else {Write-Host 'Validated game build: launching with mods.'}
    if(!$NoStart){Start-Process 'steam://rungameid/4164790' -WindowStyle Hidden}
    exit 0
} catch {Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red;exit 1}
