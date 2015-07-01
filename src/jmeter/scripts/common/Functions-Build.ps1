function Build-LibraryComponent
{
    [CmdletBinding()]
    param
    (
        [switch]$publish,
        [string]$nugetServerUrl,
        [string]$nugetServerApiKey,
        [switch]$teamCityPublish,
        [string]$subDirectory
    )

    try
    {
        $error.Clear()

        $ErrorActionPreference = "Stop"

        $here = Split-Path $script:MyInvocation.MyCommand.Path

        . "$here\_Find-RootDirectory.ps1"

        $rootDirectory = Find-RootDirectory $here
        $rootDirectoryPath = $rootDirectory.FullName

        . "$rootDirectoryPath\scripts\common\Functions-Strings.ps1"

        #if ($publish)
        #{
        #    $nugetServerUrl | ShouldNotBeNullOrEmpty -Identifier "NugetServerUrl"
        #    $octopusServerApiKey | ShouldNotBeNullOrEmpty -Identifier "NugetServerApiKey"
        #}

        . "$rootDirectoryPath\scripts\common\Functions-Versioning.ps1"
        . "$rootDirectoryPath\scripts\common\Functions-Enumerables.ps1"

        $srcDirectoryPath = "$rootDirectoryPath\src"
        if (![string]::IsNullOrEmpty($subDirectory))
        {
            $srcDirectoryPath = "$srcDirectoryPath\$subDirectory"
        }

        $sharedAssemblyInfo = (Get-ChildItem -Path "$srcDirectoryPath\Common" -Filter SharedAssemblyInfo.cs -Recurse) | Single
        $versionChangeResult = Update-AutomaticallyIncrementAssemblyVersion -AssemblyInfoFile $sharedAssemblyInfo

        write-host "##teamcity[buildNumber '$($versionChangeResult.New)']"

        . "$rootDirectoryPath\scripts\common\Functions-FileSystem.ps1"
        $buildOutputRoot = "build-output"
        if (![string]::IsNullOrEmpty($subDirectory))
        {
            $buildOutputRoot = "$buildOutputRoot\$subDirectory"
        }
        $buildDirectory = Ensure-DirectoryExists ([System.IO.Path]::Combine($rootDirectory.FullName, "$buildOutputRoot\$($versionChangeResult.New)"))

        $solutionFile = (Get-ChildItem -Path "$srcDirectoryPath" -Filter *.sln -Recurse) |
            Single -Predicate { -not ($_.FullName -match "packages") }

        . "$rootDirectoryPath\scripts\common\Functions-NuGet.ps1"
        NuGet-Restore $solutionFile

        $msbuild = (Get-ChildItem -Path "C:\Windows\Microsoft.NET" -Filter MSBuild.exe -Recurse) |
            Where-Object { $_.FullName -match "(.*)Framework(.*)v4.0(.*)" } | 
            Select-Object -First 1

        $msbuildArgs = '"' + $solutionFile.FullName + '" ' + '/t:clean,rebuild /v:minimal /p:Configuration="Release"'

        & "$($msbuild.FullName)" $msbuildArgs
        if($LASTEXITCODE -ne 0)
        {
            throw "MSBuild Failed."
        }

        # Run Tests
        Write-Warning "Not running tests. Code not implemented."

        $projectFile = (Get-ChildItem -Path "$srcDirectoryPath" -Filter *.csproj -Recurse) |
            Single -Predicate { -not ($_.FullName -match "packages" -or $_.FullName -like "*test*") }

        Nuget-Pack -ProjectOrNuspecFile $projectFile -OutputDirectory $buildDirectory -Version $versionChangeResult.New

        # Publish
        if ($publish)
        {
            Write-Warning "Arbitrary publish not implemented."
        }

        if ($teamCityPublish)
        {
            write-host "##teamcity[publishArtifacts '$($buildDirectory.FullName)']"
        }
    }
    finally
    {
        if ($versionChangeResult -ne $null)
        {
            Write-Verbose "Restoring version to old version to avoid making permanent changes to the SharedAssemblyInfo file."
            $version = Set-AssemblyVersion $sharedAssemblyInfo $versionChangeResult.Old
        }
    }
}

function Build-DeployableComponent
{
    [CmdletBinding()]
    param
    (
        [switch]$deploy,
        [string]$environment,
        [string]$octopusProjectPrefix,
        [string]$octopusServerUrl,
        [string]$octopusServerApiKey,
        [string]$subDirectory,
        [string[]]$projects,
        [switch]$isMsbuild=$true,
        [scriptblock]$DI_sourceDirectory={ return "$rootDirectoryPath\src" },
        [scriptblock]$DI_buildOutputDirectory={ return "$rootDirectoryPath\build-output" }
    )

    try
    {
        Write-Host "##teamcity[blockOpened name='Setup']"

        $error.Clear()
        $ErrorActionPreference = "Stop"

        $here = Split-Path $script:MyInvocation.MyCommand.Path

        . "$here\_Find-RootDirectory.ps1"

        $rootDirectory = Find-RootDirectory $here
        $rootDirectoryPath = $rootDirectory.FullName

        . "$rootDirectoryPath\scripts\common\Functions-Strings.ps1"
        . "$rootDirectoryPath\scripts\common\Functions-Versioning.ps1"
        . "$rootDirectoryPath\scripts\common\Functions-Enumerables.ps1"

        if ($deploy)
        {
            $octopusServerUrl | ShouldNotBeNullOrEmpty -Identifier "OctopusServerUrl"
            $octopusServerApiKey | ShouldNotBeNullOrEmpty -Identifier "OctopusServerApiKey"
            $environment | ShouldNotBeNullOrEmpty -Identifier "ConfigId"

            if ($projects -eq $null -or (-not ($projects | Any)))
            {
                if ([string]::IsNullOrEmpty($octopusProjectPrefix))
                {
                    throw "One of OctopusProjectPrefix or Projects must be set to determine which Octopus Projects to deploy to."
                }
            }

            if ((($projects -ne $null) -and ($projects | Any)) -and -not [string]::IsNullOrEmpty($octopusProjectPrefix))
            {
                Write-Warning "Both a specific list of projects and a project prefix were specified. The list will take priority for deployment purposes."
            }
        }

        $srcDirectoryPath = & $DI_sourceDirectory
        if (![string]::IsNullOrEmpty($subDirectory))
        {
            $srcDirectoryPath = "$srcDirectoryPath\$subDirectory"
        }

        Write-Host "##teamcity[blockOpened name='Versioning']"

        $sharedAssemblyInfo = (Get-ChildItem -Path "$srcDirectoryPath\Common" -Filter SharedAssemblyInfo.cs -Recurse) | Single
        $versionChangeResult = Update-AutomaticallyIncrementAssemblyVersion -AssemblyInfoFile $sharedAssemblyInfo

        Write-Host "##teamcity[blockClosed name='Versioning']"

        write-host "##teamcity[buildNumber '$($versionChangeResult.New)']"

        . "$rootDirectoryPath\scripts\common\Functions-FileSystem.ps1"
        $buildOutputRoot = & $DI_buildOutputDirectory
        if (![string]::IsNullOrEmpty($subDirectory))
        {
            $buildOutputRoot = "$buildOutputRoot\$subDirectory"
        }
        $buildDirectory = Ensure-DirectoryExists ([System.IO.Path]::Combine($rootDirectory.FullName, "$buildOutputRoot\$($versionChangeResult.New)"))

        Write-Host "##teamcity[blockClosed name='Setup']"

        if ($isMsbuild)
        {
            Write-Host "##teamcity[blockOpened name='Compiling and Packaging']"
            $solutionFile = (Get-ChildItem -Path "$srcDirectoryPath" -Filter *.sln -Recurse) |
                Single -Predicate { -not ($_.FullName -match "packages") }

            . "$rootDirectoryPath\scripts\common\Functions-NuGet.ps1"
            NuGet-Restore $solutionFile

            $msbuildArgs = @()
            $msbuildArgs += "`"$($solutionFile.FullName)`""
            $msbuildArgs += "/t:clean,rebuild"
            $msbuildArgs += "/v:minimal"
            $msbuildArgs += "/p:Configuration=`"Release`";RunOctoPack=true;OctoPackPublishPackagesToTeamCity=false;OctoPackPublishPackageToFileShare=`"$($buildDirectory.FullName)`""

            Execute-MSBuild -msBuildArgs $msbuildArgs

            Write-Host "##teamcity[blockClosed name='Compiling and Packaging']"
        }
        else
        {
            Write-Host "##teamcity[blockOpened name='Packaging']"
            $nuspecFile = Get-ChildItem -Path $srcDirectoryPath -Filter *.nuspec | Single

            . "$rootDirectoryPath\scripts\common\Functions-NuGet.ps1"

            NuGet-Pack $nuspecFile $buildDirectory -Version $versionChangeResult.New

            Write-Host "##teamcity[blockClosed name='Packaging']"
        }

        write-host "##teamcity[publishArtifacts '$($buildDirectory.FullName)']"

        FindAndExecuteNUnitTests $srcDirectoryPath $buildDirectory

        if ($deploy)
        {
            Write-Host "##teamcity[blockOpened name='Deployment ($environment)']"

            Get-ChildItem -Path ($buildDirectory.FullName) | 
                Where { $_.FullName -like "*.nupkg" } |
                NuGet-Publish -ApiKey $octopusServerApiKey -FeedUrl "$octopusServerUrl/nuget/packages"

            . "$rootDirectoryPath\scripts\common\Functions-OctopusDeploy.ps1"
            
            if ($projects -eq $null)
            {
                Write-Verbose "No projects to deploy to have been specified. Deploying to all projects starting with [$octopusProjectPrefix]."
                $octopusProjects = Get-AllOctopusProjects -octopusServerUrl $octopusServerUrl -octopusApiKey $octopusServerApiKey | Where { $_.Name -like "$octopusProjectPrefix*" }

                if (-not ($octopusProjects | Any -Predicate { $true }))
                {
                    throw "You have elected to do a deployment, but no Octopus Projects could be found to deploy to (using prefix [$octopusProjectPrefix]."
                }

                $projects = ($octopusProjects | Select -ExpandProperty Name)
            }

            foreach ($project in $projects)
            {
                New-OctopusRelease -ProjectName $project -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusServerApiKey -Version $versionChangeResult.New -ReleaseNotes "[SCRIPT] Automatic Release created as part of Build."
                New-OctopusDeployment -ProjectName $project -Environment "$environment" -Version $versionChangeResult.New -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusServerApiKey -Wait
            }

            Write-Host "##teamcity[blockClosed name='Deployment ($environment)']"
        }

        $result = @{}
        $result.Add("VersionInformation", $versionChangeResult)
        $result.Add("BuildOutput", $buildDirectory.FullName)

        return $result
    }
    finally
    {
        Write-Host "##teamcity[blockOpened name='Cleanup']"

        if ($versionChangeResult -ne $null)
        {
            Write-Verbose "Restoring version to old version to avoid making permanent changes to the SharedAssemblyInfo file."
            $version = Set-AssemblyVersion $sharedAssemblyInfo $versionChangeResult.Old
        }

        Write-Host "##teamcity[blockClosed name='Cleanup']"
    }
}

function Execute-MSBuild
{
    [CmdletBinding()]
    param
    (
        [string[]]$msBuildArgs
    )

    $msbuild = (Get-ChildItem -Path "C:\Windows\Microsoft.NET" -Filter MSBuild.exe -Recurse) |
        Where-Object { $_.FullName -match "(.*)Framework(.*)v4.0(.*)" } | 
        Select-Object -First 1

    & "$($msbuild.FullName)" $msBuildArgs | Write-Verbose
    if($LASTEXITCODE -ne 0)
    {
        throw "MSBuild Failed."
    }
}

function FindAndExecuteNUnitTests
{
    [CmdletBinding()]
    param
    (
        [System.IO.DirectoryInfo]$searchRoot,
        [System.IO.DirectoryInfo]$buildOutput
    )

    Write-Host "##teamcity[blockOpened name='Unit and Integration Tests']"

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    . "$rootDirectoryPath\scripts\common\Functions-Enumerables.ps1"
    . "$rootDirectoryPath\scripts\common\Functions-OpenCover.ps1"

    $testAssemblySearchPredicate = { 
            $_.FullName -like "*release*" -and 
            $_.FullName -notlike "*obj*" -and
            (
                $_.Name -like "*integration*" -or 
                $_.Name -like "*unit*"
            )
        }
    Write-Verbose "Locating test assemblies using predicate [$testAssemblySearchPredicate]."
    $testLibraries = Get-ChildItem -File -Path $srcDirectoryPath -Recurse -Filter "*.Test*.dll" |
        Where $testAssemblySearchPredicate
            
    $failingTestCount = 0
    foreach ($testLibrary in $testLibraries)
    {
        $testSuiteName = $testLibrary.Name
        Write-Host "##teamcity[testSuiteStarted name='$testSuiteName']"
        $result = OpenCover-ExecuteTests $testLibrary
        $failingTestCount += $result.NumberOfFailingTests
        $newResultsPath = "$($buildDirectory.FullName)\$($result.LibraryName).TestResults.xml"
        Copy-Item $result.TestResultsFile "$newResultsPath"
        Write-Host "##teamcity[importData type='nunit' path='$newResultsPath']"

        Copy-Item $result.CoverageResultsDirectory "$($buildDirectory.FullName)\$($result.LibraryName).CodeCoverageReport" -Recurse

        Write-Host "##teamcity[testSuiteFinished name='$testSuiteName']"
    }

    write-host "##teamcity[publishArtifacts '$($buildDirectory.FullName)']"
    Write-Host "##teamcity[blockClosed name='Unit and Integration Tests']"

    if ($failingTestCount -gt 0)
    {
        throw "[$failingTestCount] Failing Tests. Aborting Build."
    }
}