function Get-NssmExecutable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-FileSystem.ps1"

    $executablePath = "$rootDirectoryPath\tools\nssm-x64-2.24.exe"

    return Test-FileExists $executablePath
}

function Nssm-Stop
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$service
    )

    $executable = Get-NssmExecutable

    $command = "stop"
    $arguments = @()
    $arguments += $command
    $arguments += """$service"""

    write-verbose "[$command] Service [$service] via Nssm."
    (& "$($executable.FullName)" $arguments) | Write-Verbose
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "Nssm '$command' failed. Exit code [$return]."
    }
}

function Nssm-Remove
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$service
    )

    $executable = Get-NssmExecutable

    $command = "remove"
    $arguments = @()
    $arguments += $command
    $arguments += """$service"""
    $arguments += "confirm"

    write-verbose "[$command] Service [$service] via Nssm."
    (& "$($executable.FullName)" $arguments) | Write-Verbose
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "Nssm '$command' failed. Exit code [$return]."
    }
}

function Nssm-Install
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$service,
        [System.IO.FileInfo]$program,
        [int]$maxLogFileSizeBytesBeforeRotation=10000000,
        [System.IO.DirectoryInfo]$DI_LogFilesDirectory="C:\logs"
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $executable = Get-NssmExecutable

    $command = "install"
    $arguments = @()
    $arguments += $command
    $arguments += """$service"""
    $arguments += """$($program.FullName)"""

    write-verbose "[$command] Service [$service] via Nssm."
    (& "$($executable.FullName)" $arguments) | Write-Verbose
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "Nssm '$command' failed. Exit code [$return]."
    }

    . "$rootDirectoryPath\scripts\common\Functions-FileSystem.ps1"

    $logDirectoryPath = "$($DI_LogFilesDirectory.FullName)\nssm\$service\"
    Ensure-DirectoryExists $logDirectoryPath

    $logFile = "$logDirectoryPath\output.log"

    (& $executable set "$service" AppStdout "$logFile") | Write-Verbose
    (& $executable set "$service" AppStderr "$logFile") | Write-Verbose
    (& $executable set "$service" AppStdoutCreationDisposition  4) | Write-Verbose
    (& $executable set "$service" AppStderrCreationDisposition  4) | Write-Verbose
    (& $executable set "$service" AppRotateFiles  1) | Write-Verbose
    (& $executable set "$service" AppRotateOnline  1) | Write-Verbose
    (& $executable set "$service" AppRotateBytes  $maxLogFileSizeBytesBeforeRotation) | Write-Verbose
}