function Get-OctopusToolsExecutable
{
    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }
    $repositoryRootDirectoryPath = $repositoryRoot.FullName

    $commondScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"
    . "$commondScriptsDirectoryPath\Functions-Enumerables.ps1"

    $toolsDirectoryPath = "$repositoryRootDirectoryPath\tools"

    $nuget = "$toolsDirectoryPath\nuget.exe"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $octoPackageId = "OctopusTools"
    $octoVersion = "2.6.1.46"
    $expectedOctoDirectory = "$nugetPackagesDirectoryPath\$octoPackageId.$octoVersion"
    if (-not (Test-Path $expectedOctoDirectory))
    {
        & $nuget install $octoPackageId -Version $octoVersion -OutputDirectory $nugetPackagesDirectoryPath | Write-Verbose
    }

    $octoExecutable = (Get-ChildItem -Path $expectedOctoDirectory -Filter octo.exe -Recurse) | Single

    return $octoExecutable
}

function Ensure-OctopusClientClassesAvailable
{
    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }
    $repositoryRootDirectoryPath = $repositoryRoot.FullName

    $commondScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"
    . "$commondScriptsDirectoryPath\Functions-Enumerables.ps1"

    $toolsDirectoryPath = "$repositoryRootDirectoryPath\tools"

    $nuget = "$toolsDirectoryPath\nuget.exe"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $octoPackageId = "Octopus.Client"
    $octoVersion = "2.6.1.796"
    $expectedOctoDirectoryPath = "$nugetPackagesDirectoryPath\$octoPackageId.$octoVersion"
    if (-not (Test-Path $expectedOctoDirectoryPath))
    {
        & $nuget install $octoPackageId -Version $octoVersion -OutputDirectory $nugetPackagesDirectoryPath | Write-Verbose
    }

    $newtonsoftJsonDirectory = Get-ChildItem -Path $nugetPackagesDirectoryPath -Directory | 
        Where-Object { $_.FullName -match "Newtonsoft\.Json\.(.*)" } | 
        Single

    Write-Verbose "Loading Octopus .NET Client Libraries."
    Add-Type -Path "$($newtonsoftJsonDirectory.FullName)\lib\net40\Newtonsoft.Json.dll"
    Add-Type -Path "$expectedOctoDirectoryPath\lib\net40\Octopus.Client.dll"
    Add-Type -Path "$expectedOctoDirectoryPath\lib\net40\Octopus.Platform.dll"
}

function New-OctopusRelease
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$projectName,
        [string]$releaseNotes,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$version,
        [Parameter(Mandatory=$false)]
        [hashtable]$stepPackageVersions
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $octoExecutable = Get-OctopusToolsExecutable
    $octoExecutablePath = $octoExecutable.FullName

    $command = "create-release"
    $arguments = @()
    $arguments += $command
    $arguments += "--project"
    $arguments += $projectName
    $arguments += "--server"
    $arguments += $octopusServerUrl
    $arguments += "--apiKey" 
    $arguments += $octopusApiKey
    if (![String]::IsNullOrEmpty($releaseNotes))
    {
        $arguments += "--releasenotes"
        $arguments += "`"$releaseNotes`""
    }
    if (![String]::IsNullOrEmpty($version))
    {
        $arguments += "--version"
        $arguments += $version
        $arguments += "--packageversion"
        $arguments += $version
    }

    if ($stepPackageVersions -ne $null) {
        foreach ($stepname in $stepPackageVersions.Keys) {
            $stepPackageVersion = $stepPackageVersions[$stepname]
            $arguments += "--package=${stepname}:$stepPackageVersion"
        }
    }

    (& "$octoExecutablePath" $arguments) | Write-Verbose
    $octoReturn = $LASTEXITCODE
    if ($octoReturn -ne 0)
    {
        throw "$command failed. Exit code [$octoReturn]."
    }
}

function New-OctopusDeployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$projectName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environment,
        [switch]$onlyCurrentMachine,
        [switch]$wait
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $octoExecutable = Get-OctopusToolsExecutable
    $octoExecutablePath = $octoExecutable.FullName

    $command = "deploy-release"
    $arguments = @()
    $arguments += $command
    $arguments += "--project"
    $arguments += $projectName
    $arguments += "--server"
    $arguments += $octopusServerUrl
    $arguments += "--apiKey"
    $arguments += $octopusApiKey
    $arguments += "--version"
    $arguments += "latest"
    $arguments += "--deployTo"
    $arguments += "`"$environment`""

    if ($onlyCurrentMachine)
    {
        $arguments += "--specificmachines"
        $arguments+= "$([system.environment]::MachineName),Octopus"
    }

    if ($wait)
    {
        $arguments += "--waitfordeployment"
    }

    (& "$octoExecutablePath" $arguments) | Write-Verbose
    $octoReturn = $LASTEXITCODE
    if ($octoReturn -ne 0)
    {
        throw "$command failed. Exit code [$octoReturn]."
    }
}

function Get-AllOctopusProjects
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Retrieving Octopus Projects."
    $result = $repository.Projects.FindAll()

    return $result
}

function New-OctopusEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environmentName,
        [string]$environmentDescription="[SCRIPT] Environment automatically created by Powershell script."
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    $properties = @{Name="$environmentName";Description=$environmentDescription}
 
    $environment = New-Object Octopus.Client.Model.EnvironmentResource -Property $properties

    write-verbose "Creating Octopus Environment with Name [$environmentName]."
    $result = $repository.Environments.Create($environment)

    return $result
}

function Get-OctopusEnvironmentByName
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environmentName
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Retrieving Octopus Environment with Name [$environmentName]."
    $result = $repository.Environments.FindByName($environmentName)

    return $result
}

function Delete-OctopusEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environmentId
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Deleting Octopus Environment with Id [$environmentId]."
    $result = $repository.Environments.Delete($repository.Environments.Get($environmentId))

    return $result
}

function Get-OctopusMachinesByRole
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$role
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    $machines = $repository.Machines.FindAll() | Where-Object { $_.Roles -contains $role }

    return $machines
}

function Get-OctopusMachinesByEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environmentId
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    $machines = $repository.Machines.FindAll() | Where-Object { $_.EnvironmentIds -contains $environmentId }

    return $machines
}

function Delete-OctopusMachine
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$machineId
    )

    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Deleting Octopus Machine with Id [$machineId]."
    $result = $repository.Machines.Delete($repository.Machines.Get($machineId))

    return $result
}