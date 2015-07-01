function Ensure-JavaRuntimeEnvironmentIsAvailable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $jreId = "jre-1.8.0_40"

    $toolsDirectoryPath = "$rootDirectoryDirectoryPath\tools"
    $packagesDirectoryPath = "$toolsDirectoryPath\packages"
    $jreDirectoryPath = "$packagesDirectoryPath\$jreId"
    if (Test-Path $jreDirectoryPath)
    {
        Write-Verbose "JRE already available at [$jreDirectoryPath]."
    }
    else
    {
        $jreArchiveFile = Get-ChildItem -Path $toolsDirectoryPath -Filter "$jreId.7z" |
            Single

        Write-Verbose "Extracting JRE archive at [$($jreArchiveFile.FullName)]"
        $extractedDirectory = 7Zip-Unzip -Archive $jreArchiveFile -DestinationDirectory $packagesDirectoryPath
    }

    return "$jreDirectoryPath\bin"
}

function Ensure-JmeterIsAvailable
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $jmeterId = "apache-jmeter-2.13"

    $toolsDirectoryPath = "$rootDirectoryDirectoryPath\tools"
    $packagesDirectoryPath = "$toolsDirectoryPath\packages"
    $jmeterDirectoryPath = "$packagesDirectoryPath\$jmeterId"
    if (Test-Path $jmeterDirectoryPath)
    {
        Write-Verbose "JMeter already available at [$jmeterDirectoryPath]."
    }
    else
    {
        $jmeterArchiveFile = Get-ChildItem -Path $toolsDirectoryPath -Filter "$jmeterId.7z" | Single

        Write-Verbose "Extracting JMeter archive at [$($jmeterArchiveFile.FullName)]"
        $extractedDirectory = 7Zip-Unzip -Archive $jmeterArchiveFile -DestinationDirectory $packagesDirectoryPath
    }

    return "$jmeterDirectoryPath\bin\jmeter.bat"
}

function Execute-JMeter
{
    [CmdletBinding()]
    param
    (
        [array]$additionalArguments,
        [int]$allocatedMemory=2048,
        [string]$testRunId="GUI",
        [Nullable[int]]$totalNumberOfUsers,
        [Nullable[int]]$startingCustomerNumber
    )

    $jmeter = Ensure-JmeterIsAvailable
    $jreBinDirectoryPath = Ensure-JavaRuntimeEnvironmentIsAvailable

    $env:Path = "$jreBinDirectoryPath;$env:Path"

    $currentUtcDateTime = [DateTime]::UtcNow
    $a = $currentUtcDateTime.ToString("yyyyMMdd_HHmmss")

    $arguments = @()
    $arguments += "-t"
    $arguments += "$rootDirectoryDirectoryPath\Default.jmx"
    $arguments += "-J"
    $arguments += "search_paths=$rootDirectoryDirectoryPath\lib\"
    $arguments += "-q"
    $arguments += "$rootDirectoryDirectoryPath\user.properties"
    $arguments += "--jmeterlogfile"
    $arguments += "$rootDirectoryDirectoryPath\results\$a.log"
    $arguments += "-l"
    $arguments += "$rootDirectoryDirectoryPath\results\$a.csv"
    
    if ($totalNumberOfUsers -ne $null)
    {
        $arguments += "-JtotalNumberOfUsers=$($totalNumberOfUsers.ToString())"
    }

    if ($env:HTTP_PROXY -ne $null)
    {
        $proxy = $env:HTTP_PROXY
        $regexMatch = (select-string -InputObject $proxy -Pattern "http://(.*):(.*)").Matches[0]
        $address = $regexMatch.Groups[1].Value
        $port = $regexMatch.Groups[2].Value

        $arguments += "-H"
        $arguments += $address
        $arguments += "-P"
        $arguments += $port
    }

    $arguments += $additionalArguments

    $env:JVM_ARGS = "-Xms$($allocatedMemory.ToString())m -Xmx$($allocatedMemory.ToString())m"

    & $jmeter $arguments
}