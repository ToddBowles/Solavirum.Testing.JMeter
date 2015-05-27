function Get-7ZipExecutable
{
    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }
    $repositoryRootDirectoryPath = $repositoryRoot.FullName

    $commondScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"
    . "$commondScriptsDirectoryPath\Functions-Enumerables.ps1"

    $toolsDirectoryPath = "$repositoryRootDirectoryPath\tools"

    $nuget = "$toolsDirectoryPath\nuget.exe"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $7zipPackageId = "7-Zip.CommandLine"
    $7zipVersion = "9.20.0"
    $expected7zipDirectory = "$nugetPackagesDirectoryPath\$7zipPackageId.$7zipVersion"
    if (-not (Test-Path $expected7zipDirectory))
    {
        & $nuget install $7zipPackageId -Version $7zipVersion -OutputDirectory $nugetPackagesDirectoryPath | Write-Verbose
    }

    $7zipExecutable = (Get-ChildItem -Path $expected7zipDirectory -Filter 7za.exe -Recurse) | Single

    return $7zipExecutable
}

function 7Zip-ZipDirectories
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [System.IO.DirectoryInfo[]]$include,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$destination,
        [switch]$additive,
        [string[]]$subdirectoriesToExclude
    )

    $7zipExecutable = Get-7ZipExecutable

    $7zipExecutablePath = $7zipExecutable.FullName

    if ((-not $additive) -and ($destination.Exists))
    {
        Write-Verbose "Destination archive [$($destination.FullName)] exists and Additive switch not set. Deleting."
        $destination.Delete()
    }

    foreach ($directory in $include)
    {
        $arguments = "a","$($destination.FullName)","$($directory.FullName)"

        foreach ($subdirectory in $subdirectoriesToExclude)
        {
            $arguments += "-xr!$subdirectory"
        }

        (& $7zipExecutablePath $arguments) | Write-Verbose

        $7ZipExitCode = $LASTEXITCODE
        if ($7ZipExitCode -ne 0)
        {
            $destination.Delete()
            throw "An error occurred while zipping [$directory]. 7Zip Exit Code was [$7ZipExitCode]."
        }
    }

    return $destination
}

function 7Zip-ZipFiles
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo[]]$include,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$destination,
        [switch]$additive
    )

    $7zipExecutable = Get-7ZipExecutable

    $7zipExecutablePath = $7zipExecutable.FullName

    if ((-not $additive) -and ($destination.Exists))
    {
        Write-Verbose "Destination archive [$($destination.FullName)] exists. Deleting."
        $destination.Delete()
    }

    foreach ($file in $include)
    {
        (& "$7zipExecutablePath" a "$($destination.FullName)" "$($file.FullName)") | Write-Verbose

        $7ZipExitCode = $LASTEXITCODE
        if ($7ZipExitCode -ne 0)
        {
            $destination.Delete()
            throw "An error occurred while zipping [$file]. 7Zip Exit Code was [$7ZipExitCode]."
        }
    }

    return $destination
}

function 7Zip-Unzip
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$archive,
        [Parameter(Mandatory=$true)]
        [System.IO.DirectoryInfo]$destinationDirectory
    )

    $7zipExecutable = Get-7ZipExecutable

    $7zipExecutablePath = $7zipExecutable.FullName
    $archivePath = $archive.FullName
    $destinationDirectoryPath = $destinationDirectory.FullName

    Write-Verbose "Unzipping [$archivePath] to [$destinationDirectoryPath] using 7Zip at [$7zipExecutablePath]."
    (& $7zipExecutablePath x "$archivePath" -o"$destinationDirectoryPath" -aoa) | Write-Verbose

    $7zipExitCode = $LASTEXITCODE
    if ($7zipExitCode -ne 0)
    {
        throw "An error occurred while unzipping [$archivePath] to [$destinationDirectoryPath]. 7Zip Exit Code was [$7zipExitCode]."
    }

    return $destinationDirectory
}