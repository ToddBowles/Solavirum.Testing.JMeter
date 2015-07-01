[CmdletBinding()]
param
(
    [string]$specificTestNames="*",
    [hashtable]$globalCredentialsLookup=@{}
)

$error.Clear()

$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path

. "$currentDirectoryPath\_Find-RootDirectory.ps1"

$rootDirectoryPath = (Find-RootDirectory $currentDirectoryPath).FullName
$scriptsDirectoryPath = "$rootDirectoryPath\scripts"
$commonScriptsDirectoryPath = "$scriptsDirectoryPath\common"

. "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

$toolsDirectoryPath = "$rootDirectoryPath\tools"
$nuget = "$toolsDirectoryPath\nuget.exe"

$nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"
$pesterVersion = "3.3.6"
& $nuget install Pester -Version $pesterVersion -OutputDirectory $nugetPackagesDirectoryPath | Write-Verbose

$pesterDirectoryPath = ((Get-ChildItem -Path $nugetPackagesDirectoryPath -Directory -Filter Pester.$pesterVersion) | Single).FullName

Import-Module "$pesterDirectoryPath\tools\Pester.psm1"
$scriptDirectories = Get-ChildItem -Path $rootDirectoryPath -Recurse -Directory |
    Where { ($_.GetFiles() | Any -Predicate { $_.FullName -like "*.tests.ps1" }) -and $_.FullName -notlike "*packages*" }

$results = $scriptDirectories |
    ForEach-Object { Invoke-Pester -Strict -Path $_.FullName -TestName $specificTestNames -PassThru }

$totalTime = [TimeSpan]::Zero
$results | ForEach-Object { $totalTime = $totalTime + $_.Time }
$results = @{
    Passed=($results | Measure-Object PassedCount -Sum).Sum;
    Failed=($results | Measure-Object FailedCount -Sum).Sum;
    Time=$totalTime;
}

return $results