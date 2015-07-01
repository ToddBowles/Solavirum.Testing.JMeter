$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$here\_Find-RootDirectory.ps1"
$rootDirectory = Find-RootDirectory $here
$commonScriptsDirectoryPath = "$($rootDirectory.FullName)\scripts\common"

. "$commonScriptsDirectoryPath\Functions-Compression.ps1"

$modules = Get-ChildItem -Path "$here\modules" -Filter *.zip |
    ForEach-Object { 7Zip-Unzip $_ "C:\Program Files\WindowsPowerShell\Modules" }