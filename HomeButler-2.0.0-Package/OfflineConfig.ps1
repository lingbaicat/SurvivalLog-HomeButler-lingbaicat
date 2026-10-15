function ReadOfflineValue([string]$text,[string]$key) {
    $text=$text.Replace("`r`r`n","`r`n")
    $sections=[regex]::Matches($text,'(?ms)^\[IL2CPP\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)')
    if($sections.Count -gt 1){throw 'Duplicate IL2CPP configuration sections.'}
    if(!$sections.Count){return $null}
    $entries=[regex]::Matches($sections[0].Groups['body'].Value,'(?m)^'+[regex]::Escape($key)+'[ \t]*=[ \t]*([^\r\n]*)')
    if($entries.Count -gt 1){throw ('Duplicate configuration key: '+$key)}
    if($entries.Count){return $entries[0].Groups[1].Value.Trim()}
    return $null
}
function TestOfflineConfig([string]$text) {
    return (ReadOfflineValue $text 'UnityBaseLibrariesSource') -eq $manifest.Offline.FileName -and
           (ReadOfflineValue $text 'UpdateInteropAssemblies') -eq 'true' -and
           (ReadOfflineValue $text 'IL2CPPInteropAssembliesPath') -eq '{BepInEx}'
}
function RestoreOfflineKeys([string]$current,[string]$previous) {
    if(!(TestOfflineConfig $current)){throw 'Offline settings were modified after installation; refusing to overwrite them.'}
    foreach($key in @('UnityBaseLibrariesSource','UpdateInteropAssemblies','IL2CPPInteropAssembliesPath')) {
        $old=ReadOfflineValue $previous $key
        $section=[regex]::Match($current,'(?ms)^\[IL2CPP\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)')
        $body=$section.Groups['body'].Value
        $pattern='(?m)^'+[regex]::Escape($key)+'[ \t]*=[^\r\n]*(?:\r?\n|$)'
        $replacement=if($null -eq $old){''}else{$key+' = '+$old+"`r`n"}
        $body=[regex]::Replace($body,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $replacement})
        $current=$current.Substring(0,$section.Groups['body'].Index)+$body+$current.Substring($section.Groups['body'].Index+$section.Groups['body'].Length)
    }
    return $current
}
