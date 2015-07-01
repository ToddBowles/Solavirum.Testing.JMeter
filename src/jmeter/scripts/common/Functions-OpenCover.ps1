function Get-OpenCoverExecutable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Nuget.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $packageId = "OpenCover"
    $version = "4.5.3522"
    $expectedDirectory = "$nugetPackagesDirectoryPath\$packageId.$version"
    if (-not (Test-Path $expectedDirectory))
    {
        Nuget-Install -PackageId $packageId -Version $version -OutputDirectory $nugetPackagesDirectoryPath
    }

    $executable = (Get-ChildItem -Path $expectedDirectory -Filter OpenCover.Console.exe -Recurse) | Single

    return $executable
}

function Get-ReportGeneratorExecutable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Nuget.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"

    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $packageId = "ReportGenerator"
    $version = "2.1.0.0"
    $expectedDirectory = "$nugetPackagesDirectoryPath\$packageId.$version"
    if (-not (Test-Path $expectedDirectory))
    {
        Nuget-Install -PackageId $packageId -Version $version -OutputDirectory $nugetPackagesDirectoryPath
    }

    $executable = (Get-ChildItem -Path $expectedDirectory -Filter ReportGenerator.exe -Recurse) | Single

    return $executable
}

function OpenCover-ExecuteTests
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$testLibrary
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $rootDirectoryPath = $rootDirectory.FullName
    . "$rootDirectoryPath\scripts\common\Functions-NUnit.ps1"

    $nunitRunnerPath = (Get-NUnitConsoleExecutable).FullName

    $executable = Get-OpenCoverExecutable
    $executablePath = $executable.FullName

    $libraryDirectoryPath = $testLibrary.Directory.FullName

    $testResultsFilePath = "$libraryDirectoryPath\$($testLibrary.Name).TestResults.xml"
    $coverageResultsFilePath = "$libraryDirectoryPath\_CodeCoverageResult.xml"

    $arguments = @()
    $arguments += "-target:`"$nunitRunnerPath`""
    $arguments += "-targetargs:`"$($testLibrary.FullName)`" /noshadow /framework:net-4.5 /xml:`"$testResultsFilePath`""
    $arguments += "-register:user"
    $arguments += "-returntargetcode"
    $arguments += "-output:`"$coverageResultsFilePath`""

    Write-Verbose "OpenCover-ExecuteTests $executablePath $arguments"
    (& "$executablePath" $arguments) | Write-Verbose
    $numberOfFailedTests = $LASTEXITCODE

    $reportGeneratorPath = (Get-ReportGeneratorExecutable).FullName
    $coverageReportDirectoryPath = "$libraryDirectoryPath\CodeCoverageReport"

    $reportGeneratorArgs = @()
    $reportGeneratorArgs += "-reports:`"$coverageResultsFilePath`""
    $reportGeneratorArgs += "-targetdir:`"$coverageReportDirectoryPath`""

    Write-Verbose "OpenCover-ExecuteTests $reportGeneratorPath $reportGeneratorArgs"
    & "$reportGeneratorPath" $reportGeneratorArgs

    $results = @{}
    $results.Add("LibraryName", $($testLibrary.Name))
    $results.Add("TestResultsFile", "$testResultsFilePath")
    $results.Add("CoverageResultsDirectory", "$coverageReportDirectoryPath")
    $results.Add("NumberOfFailingTests", $numberOfFailedTests)

    return new-object PSObject $results
}