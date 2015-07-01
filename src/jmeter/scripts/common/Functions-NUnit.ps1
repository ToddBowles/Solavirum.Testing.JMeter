function Get-NUnitConsoleExecutable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Nuget.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $packageId = "NUnit.Runners"
    $version = "2.6.4"
    $expectedDirectory = "$nugetPackagesDirectoryPath\$packageId.$version"
    if (-not (Test-Path $expectedDirectory))
    {
        Nuget-Install -PackageId $packageId -Version $version -OutputDirectory $nugetPackagesDirectoryPath
    }

    $executable = (Get-ChildItem -Path $expectedDirectory -Filter nunit-console.exe -Recurse) | Single

    return $executable
}