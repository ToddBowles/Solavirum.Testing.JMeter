function Ensure-AwsPowershellFunctionsAvailable()
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"
	
    if ((Get-Module | Where-Object { $_.Name -eq "AWSPowershell" }) -eq $null)
    {
        Write-Verbose "AWSPowershell Module not found. Importing"
		if (-not(Test-Path "$toolsDirectoryPath\packages\AWSPowershell"))
        {
            7Zip-Unzip "$toolsDirectoryPath\AWSPowershell.7z" "$toolsDirectoryPath\packages"
        }
        
	    Import-Module "$toolsDirectoryPath\packages\AWSPowershell\AWSPowerShell.psd1"
    }
}