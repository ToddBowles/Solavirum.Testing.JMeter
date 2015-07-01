$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path

. "$currentDirectoryPath\_Find-RootDirectory.ps1"

$rootDirectory = Find-RootDirectory $currentDirectoryPath
$rootDirectoryPath = $rootDirectory.FullName

. "$rootDirectoryPath\scripts\common\Functions-LogManagement.ps1"
InitialiseCommonLogsDirectory
CreateLogsClearingTask