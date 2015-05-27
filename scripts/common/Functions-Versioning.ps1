function Get-AssemblyVersionRegexString()
{
    return "^(\[assembly: AssemblyVersion\()(`")(.*)(`"\))"
}

function Update-AutomaticallyIncrementAssemblyVersion()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [System.IO.FileInfo]$assemblyInfoFile,
        [Parameter(Position=1)]
        [scriptblock]$getSystemUtcDateTime={ return [System.DateTime]::UtcNow }
    )

    $fullyQualifiedAssemblyInfoPath = $assemblyInfoFile.FullName
    $assemblyVersionRegex = Get-AssemblyVersionRegexString

    $existingVersion = (select-string -Path "$fullyQualifiedAssemblyInfoPath" -Pattern $assemblyVersionRegex).Matches[0].Groups[3].Value
    $existingVersion = new-object System.Version($existingVersion)
 
    write-verbose ("Current version is [" + $existingVersion + "].")
 
    $currentUtcDateTime = & $getSystemUtcDateTime

    $major = $existingVersion.Major
    $minor = $existingVersion.Minor
    $build = $currentUtcDateTime.ToString("yy") + $currentUtcDateTime.DayOfYear.ToString("000")
    $revision = ([int](([int]$currentUtcDateTime.Subtract($currentUtcDateTime.Date).TotalSeconds) / 2) + 10000).ToString("00000")
 
    $newVersion = [System.String]::Format("{0}.{1}.{2}.{3}", $major, $minor, $build, $revision)
 
    $newVersion = Set-AssemblyVersion $assemblyInfoFile $newVersion

    $result = new-object psobject @{ "Old"=$existingVersion.ToString(); "New"=$newVersion }
    return $result
}

function Set-AssemblyVersion()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [System.IO.FileInfo]$assemblyInfoFile,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$newVersion
    )

    $fullyQualifiedAssemblyInfoPath = $assemblyInfoFile.FullName
    $assemblyVersionRegex = Get-AssemblyVersionRegexString
 
    write-verbose ("New version is [" + $newVersion + "].")
 
    write-verbose ("Replacing AssemblyVersion in [" + $fullyQualifiedAssemblyInfoPath + "] with new version.")
    $replacement = '$1"' + $newVersion + "`$4"

    (get-content $fullyQualifiedAssemblyInfoPath) | 
        foreach-object {$_ -replace $assemblyVersionRegex, $replacement} |
        set-content $fullyQualifiedAssemblyInfoPath

    return $newVersion
}
