function Get-NuGetExecutable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-FileSystem.ps1"

    $nugetExecutablePath = "$rootDirectoryPath\tools\nuget.exe"

    return Test-FileExists $nugetExecutablePath
}

function NuGet-Restore
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$solutionOrProjectFile
    )

    $nugetExecutable = Get-NuGetExecutable

    $command = "restore"
    $arguments = @()
    $arguments += $command
    $arguments += "`"$($solutionOrProjectFile.FullName)`""

    write-verbose "Restoring NuGet Packages for [$($solutionOrProjectFile.FullName)]."
    (& "$($nugetExecutable.FullName)" $arguments) | Write-Verbose
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "NuGet '$command' failed. Exit code [$return]."
    }
}

function NuGet-Publish
{
    [CmdletBinding()]
    param
    (
        
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [System.IO.FileInfo]$package,
        [Parameter(Mandatory=$true)]
        [string]$apiKey,
        [Parameter(Mandatory=$true)]
        [string]$feedUrl,
        [scriptblock]$DI_ExecutePublishUsingNuGetExeAndArguments={ 
            param
            (
                [System.IO.FileInfo]$nugetExecutable, 
                [array]$arguments
            ) 
            
            (& "$($nugetExecutable.FullName)" $arguments) | Write-Verbose 
        }
    )

    begin
    {
        $nugetExecutable = Get-NuGetExecutable
    }
    process
    {
        $command = "push"
        $arguments = @()
        $arguments += $command
        $arguments += "`"$($_.FullName)`""
        $arguments += "-ApiKey"
        $arguments += "`"$apiKey`""
        $arguments += "-Source"
        $arguments += "`"$feedUrl`""

        write-verbose "Publishing package[$($_.FullName)] to [$feedUrl]."
        & $DI_ExecutePublishUsingNuGetExeAndArguments $nugetExecutable $arguments
        $return = $LASTEXITCODE
        if ($return -ne 0)
        {
            throw "NuGet '$command' failed. Exit code [$return]."
        }
    }
}

function NuGet-Pack
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$projectOrNuspecFile,
        [Parameter(Mandatory=$true)]
        [System.IO.DirectoryInfo]$outputDirectory,
        [Version]$version,
        [string]$configuration="Release",
        [string[]]$additionalArguments,
        [scriptblock]$DI_ExecutePackUsingNuGetExeAndArguments={ 
            param
            (
                [System.IO.FileInfo]$nugetExecutable, 
                [array]$arguments
            ) 
            
            (& "$($nugetExecutable.FullName)" $arguments) | Write-Verbose 
        }
    )

    $nugetExecutable = Get-NuGetExecutable

    $command = "pack"
    $arguments = @()
    $arguments += $command
    $arguments += "`"$($projectOrNuspecFile.FullName)`""
    $arguments += "-OutputDirectory"
    $arguments += "`"$($outputDirectory.FullName)`""
    if ($version -ne $null)
    {
        $arguments += "-Version"
        $arguments += "$($version.ToString())"
    }
    
    $arguments += "-Properties"
    $arguments += "Configuration=$configuration"

    $arguments = $arguments + $additionalArguments

    write-verbose "Packing [$($projectOrNuspecFile.FullName)] to [$($outputDirectory.FullName)]."
    & $DI_ExecutePackUsingNuGetExeAndArguments $nugetExecutable $arguments
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "NuGet '$command' failed. Exit code [$return]."
    }
}

function NuGet-Install
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$packageId,
        [string]$version,
        [Parameter(Mandatory=$true)]
        [string]$outputDirectory
    )

    $nugetExecutable = Get-NuGetExecutable

    $command = "install"
    $arguments = @()
    $arguments += $command
    $arguments += "`"$packageId`""
    $arguments += "-Version"
    $arguments += $version
    $arguments += "-OutputDirectory"
    $arguments += "`"$outputDirectory`""
    $arguments += "-NoCache"

    write-verbose "Installing NuGet Package [$packageId - $version] into [$outputDirectory]."
    (& "$($nugetExecutable.FullName)" $arguments) | Write-Verbose
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "NuGet '$command' failed. Exit code [$return]."
    }
}
