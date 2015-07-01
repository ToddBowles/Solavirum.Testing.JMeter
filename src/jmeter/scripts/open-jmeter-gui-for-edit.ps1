$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RootDirectory.ps1"

$rootDirectory = Find-RootDirectory $currentDirectoryPath
$rootDirectoryDirectoryPath = $rootDirectory.FullName

. "$rootDirectoryDirectoryPath\scripts\Functions-Jmeter.ps1"

Execute-JMeter