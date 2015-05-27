[CmdletBinding()]
param
(
    [string]$specificTestNames="*"
)

$error.Clear()

$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"

$repositoryRootDirectoryPath = (Find-RepositoryRoot $currentDirectoryPath).FullName
$scriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts"
$commonScriptsDirectoryPath = "$scriptsDirectoryPath\common"

. "$commonScriptsDirectoryPath\functions-enumerables.ps1"

$toolsDirectoryPath = "$repositoryRootDirectoryPath\tools"
$nuget = "$toolsDirectoryPath\nuget.exe"

$nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"
& $nuget install Pester -Version 3.3.5 -OutputDirectory $nugetPackagesDirectoryPath | Write-Verbose

$pesterDirectoryPath = ((Get-ChildItem -Path $nugetPackagesDirectoryPath -Directory -Filter Pester*) | Single).FullName

Import-Module "$pesterDirectoryPath\tools\Pester.psm1"
Invoke-Pester -Strict -Path $scriptsDirectoryPath -TestName $specificTestNames
