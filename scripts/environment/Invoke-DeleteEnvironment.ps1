[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$environmentName,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$awsKey,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$awsSecret,
    [string]$awsRegion="ap-southeast-2"
)

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"
. "$currentDirectoryPath\Functions-Environment.ps1"

$repositoryRoot = Find-RepositoryRoot $currentDirectoryPath

Delete-Environment $environmentName $awsKey $awsSecret $awsRegion -Wait