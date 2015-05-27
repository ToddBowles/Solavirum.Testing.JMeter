function Ensure-AwsPowershellFunctionsAvailable()
{
    if ($repositoryRoot -eq $null) { throw "repositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }
    $repositoryRootDirectoryPath = $repositoryRoot.FullName

    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $toolsDirectoryPath = "$repositoryRootDirectoryPath\tools"
	
    if ((Get-Module | Where-Object { $_.Name -eq "AWSPowershell" }) -eq $null)
    {
        Write-Verbose "AWSPowershell Module not found. Importing"
		if (-not(Test-Path "$toolsDirectoryPath\packages\AWSPowershell"))
        {
            7Zip-Unzip "$toolsDirectoryPath\AWSPowershell.7z" "$toolsDirectoryPath\packages"
        }
        
	    $importResult = Import-Module "$toolsDirectoryPath\packages\AWSPowershell\AWSPowerShell.psd1"
    }
}