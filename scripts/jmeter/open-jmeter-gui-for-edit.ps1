$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"

$repositoryRoot = Find-RepositoryRoot $currentDirectoryPath
$repositoryRootDirectoryPath = $repositoryRoot.FullName

. "$repositoryRootDirectoryPath\scripts\jmeter\Functions-Jmeter.ps1"

Execute-JMeter