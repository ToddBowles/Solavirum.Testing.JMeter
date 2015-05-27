function Get-NuGetExecutable
{
    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }
    $repositoryRootDirectoryPath = $repositoryRoot.FullName

    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-FileSystem.ps1"

    $nugetExecutablePath = "$repositoryRootDirectoryPath\tools\nuget.exe"

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
    $arguments += "-NoCache"

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