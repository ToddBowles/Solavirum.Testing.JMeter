function Wait-CloudFormationStack
{
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$stackName,
        [Amazon.CloudFormation.StackStatus]$testStatus=[Amazon.CloudFormation.StackStatus]::CREATE_IN_PROGRESS,
        [int]$timeoutSeconds=3000
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    write-verbose "Waiting for the CloudFormation Stack with Id [$($stackName)] to not be [$testStatus]."
    $incrementSeconds = 30
    $totalWaitTime = 0
    while ($true)
    {
        $a = Get-CFNStack -StackName $stackName -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret
        $status = $a.StackStatus

        if ($status -ne $testStatus)
        {
            write-verbose "The CloudFormation Stack with Id [$stackName] has exited [$testStatus] into [$status] taking [$totalWaitTime] seconds."
            return $a
        }

        write-verbose "Current status of CloudFormation Stack with Id [$stackName] is [$status]. Waiting [$incrementSeconds] seconds and checking again for change."

        Sleep -Seconds $incrementSeconds
        $totalWaitTime = $totalWaitTime + $incrementSeconds
        if ($totalWaitTime -gt $timeoutSeconds)
        {
            throw "The CloudFormation Stack with Id [$stackName] did not exit [$testStatus] status within [$timeoutSeconds] seconds."
        }
    }
}

function Convert-HashTableToAWSCloudFormationParametersArray
{
    param
    (
        [CmdletBinding()]
        [hashtable]$paramsHashtable
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    $parameters = @()
    foreach ($p in $paramsHashtable.Keys)
    {
        $param = new-object Amazon.CloudFormation.Model.Parameter
        $param.ParameterKey = $p
        $param.ParameterValue = $paramsHashtable.Item($p)
            
        $parameters += $param
    }

    return $parameters
}