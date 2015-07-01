function Get-OctopusToolsExecutable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Nuget.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $octoPackageId = "OctopusTools"
    $octoVersion = "2.6.1.46"
    $expectedOctoDirectory = "$nugetPackagesDirectoryPath\$octoPackageId.$octoVersion"
    if (-not (Test-Path $expectedOctoDirectory))
    {
        Nuget-Install -PackageId $octoPackageId -Version $octoVersion -OutputDirectory $nugetPackagesDirectoryPath
    }

    $octoExecutable = (Get-ChildItem -Path $expectedOctoDirectory -Filter octo.exe -Recurse) | Single

    return $octoExecutable
}

function Ensure-OctopusClientClassesAvailable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
        . "$commonScriptsDirectoryPath\Functions-Nuget.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $octoPackageId = "Octopus.Client"
    $octoVersion = "2.6.1.796"
    $expectedOctoDirectoryPath = "$nugetPackagesDirectoryPath\$octoPackageId.$octoVersion"
    if (-not (Test-Path $expectedOctoDirectoryPath))
    {
        Nuget-Install -PackageId $octoPackageId -Version $octoVersion -OutputDirectory $nugetPackagesDirectoryPath
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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

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
		[string]$version,
        [switch]$onlyCurrentMachine,
        [switch]$wait,
        [hashtable]$variables
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $octoExecutable = Get-OctopusToolsExecutable
    $octoExecutablePath = $octoExecutable.FullName

	if ([String]::IsNullOrEmpty($version)) {
        Write-Verbose "No Version specified. Getting last version of project [$projectName] deployed to [$environment]."
		$version = Get-LastReleaseToEnvironment -projectName $projectName -environmentName $environment -octopusServerUrl $octopusServerUrl -octopusApiKey $octopusApiKey
	}

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
    $arguments += $version
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

    if ($variables -ne $null)
    {
        $variables.Keys | % { $arguments += "--variable"; $arguments += "$($_):$($variables.Item($_))" }
    }

    (& "$octoExecutablePath" $arguments) | Write-Verbose
    $octoReturn = $LASTEXITCODE
    if ($octoReturn -ne 0)
    {
        throw "$command failed. Exit code [$octoReturn]."
    }
}

function Get-OctopusProjectByName
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
        [string]$projectName
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Retrieving Octopus Projects."
    $result = $repository.Projects.FindByName($projectName)

    return $result
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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Retrieving Octopus Projects."
    $result = $repository.Projects.FindAll()

    return $result
}

function Get-LastReleaseToEnvironment
{
	[CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$projectName,
		[Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$environmentName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey
    )

      if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

    Ensure-OctopusClientClassesAvailable $octopusServerUrl $octopusApiKey
    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl, $octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    $env = $repository.Environments.FindByName($environmentName)
    $project = $repository.Projects.FindByName($projectName)
    $latestDeployment = $repository.Deployments.FindMany({ param($x) $x.EnvironmentId -eq $env.Id -and $x.ProjectId -eq $project.Id })  | 
                            Sort -Descending -Property ReleaseId  | 
                            Select -First 1

    $release = $repository.Releases.Get($latestDeployment.ReleaseId)
    $version = if ($release -eq $null) { "latest" } else { $release.Version }

    return $version
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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

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

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    Ensure-OctopusClientClassesAvailable

    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl,$octopusApiKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    write-verbose "Deleting Octopus Machine with Id [$machineId]."
    $result = $repository.Machines.Delete($repository.Machines.Get($machineId))

    return $result
}