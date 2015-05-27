function Get-CommonStackNamePrefix
{
    return "JMeter-Workers"
}

function Get-ComponentIdentifier
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$environmentName
    )

    return "$(Get-CommonStackNamePrefix)-$environmentName"
}

function Get-S3Bucket
{
    return "some-sort-of-scratch-bucket"
}

function New-Environment
{
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
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [switch]$wait,
        [switch]$disableCleanupOnFailure,
        [switch]$updateExisting
    )

    try
    {
        write-verbose "Creating New Environment $environmentName"

        if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. That's bad, its used to find dependencies." }

        $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
        write-verbose "Script is located at [$scriptFileLocation]."

        $repositoryRootDirectoryPath = $repositoryRoot.FullName
        $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

        . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

        Ensure-AwsPowershellFunctionsAvailable

        $componentIdentifier = Get-ComponentIdentifier $environmentName

        $dependenciesArchiveUrl = CollectAndUploadDependencies -componentIdentifier $componentIdentifier -commonScriptsDirectory $commonScriptsDirectoryPath

        $filter_name = New-Object Amazon.EC2.Model.Filter -Property @{Name = "name"; Value = "Windows_Server-2012-R2_RTM-English-64Bit-Core*"}
        $ec2ImageDetails = Get-EC2Image -Owner amazon -Filter $filter_name  -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion | Sort-Object Name -Descending | Select-Object -first 1

        $amiId = $ec2ImageDetails.ImageId

        $parametersHash = @{
            "AdminPassword"="ObviouslyInsecurePasswordsAreTricksyMonkeys";
            "DependenciesArchiveS3Url"=$dependenciesArchiveUrl;
            "EnvironmentName"="$environmentName";
            "S3AccessKey"="$awsKey";
            "S3SecretKey"="$awsSecret";
            "S3BucketName"="$(Get-S3Bucket)";
            "ProxyUrlAndPort"="http://[YOU MAY OR MAY NOT HAVE A PROXY HERE]:3128";
            "AmiId"=$amiId;
        }

        . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

        $resultHash = @{}
        $resultHash.Add("StackId", $null)
        $resultHash.Add("Stack", $null)
        $resultHash.Add("AutoScalingGroupName", $null)

        $result = new-object PSObject $resultHash

        $templateFilePath = "$($repositoryRoot.FullName)\scripts\environment\JMeter.Workers.cloudformation.template"
        $apiTemplateContent = Get-Content $templateFilePath -Raw
        if (-not ($updateExisting))
        {
            $tags = @()
            $octopusEnvironmentTag = new-object Amazon.CloudFormation.Model.Tag
            $octopusEnvironmentTag.Key = "Environment"
            $octopusEnvironmentTag.Value = $environmentName
            $tags += $octopusEnvironmentTag

            write-verbose "Creating JMeter Worker stack using template at [$templateFilePath]."
            $stackId = New-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -StackName "$componentIdentifier" -TemplateBody $apiTemplateContent -Parameters (Convert-HashTableToAWSCloudFormationParametersArray $parametersHash) -DisableRollback:$disableCleanupOnFailure.IsPresent -Tags $tags
        }
        else
        {
            write-verbose "Updating JMeter Worker stack using template at [$templateFilePath]."
            $stackId = Update-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -StackName "$componentIdentifier" -TemplateBody $apiTemplateContent -Parameters (Convert-HashTableToAWSCloudFormationParametersArray $parametersHash)
        }
        $result.StackId = $stackId

        if ($wait)
        {
            if (-not ($updateExisting))
            {
                $testStatus = [Amazon.CloudFormation.StackStatus]::CREATE_IN_PROGRESS
            }
            else
            {
                $testStatus = [Amazon.CloudFormation.StackStatus]::UPDATE_IN_PROGRESS
            }

            $result = Wait-Environment -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -NewEnvironmentResult $result -testStatus $testStatus
            $stack = $result.Stack
            if (-not (($stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::CREATE_COMPLETE) -or ($stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::UPDATE_COMPLETE)))
            {
                throw "Stack creation for [$stackId] failed. If DisableCleanupOnFailure is set, you will be able to check the Stack in the AWS Dashboard and investigate. If not, rerun with that switch set to get more information."
            } 

            . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

            $result.AutoScalingGroupName = ($stack.Outputs | Where-Object { $_.OutputKey -eq "AutoScalingGroupName" } | Single).OutputValue
        }

        return $result
    }
    catch
    {
        if (!$disableCleanupOnFailure)
        {
            Write-Verbose "A failure occurred and DisableCleanupOnFailure flag was set to false. Cleaning up."
            Delete-Environment -environmentName $environmentName -awsKey $awsKey -awsSecret $awsSecret -awsRegion $awsRegion
        }

        throw $_
    }
}

function Wait-Environment
{
    [CmdletBinding()]
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
        $newEnvironmentResult,
        [Amazon.CloudFormation.StackStatus]$testStatus=[Amazon.CloudFormation.StackStatus]::CREATE_IN_PROGRESS
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

    $stackId = $newEnvironmentResult.StackId
    $stack = Wait-CloudFormationStack -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -StackName "$stackId" -TestStatus $testStatus
    $newEnvironmentResult.Stack = $stack
    
    return $newEnvironmentResult
}

function Delete-Environment
{
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
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [switch]$wait
    )
    Write-Verbose "Deleting Environment $environmentName"

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    $componentIdentifier = Get-ComponentIdentifier $environmentName

    try
    {
        . "$commonScriptsDirectoryPath\Functions-Aws-S3.ps1"

        $awsBucket = Get-S3Bucket
        RemoveFilesFromS3ByPrefix -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -AwsBucket $awsBucket -Prefix $componentIdentifier -Force
    }
    catch
    {
        Write-Warning "Error occurred while trying to remove files for environment [$environmentName] from S3."
        Write-Warning $_
    }

    try
    {
        . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

        Remove-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -Force -StackName "$componentIdentifier"
    }
    catch
    {
        Write-Warning "Error occurred while trying to delete CFN stack for environment [$environmentName]."
        Write-Warning $_
    }

    if ($wait)
    {
        try
        {
            $stack = Wait-CloudFormationStack -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -StackName "$componentIdentifier" -TestStatus ([Amazon.CloudFormation.StackStatus]::DELETE_IN_PROGRESS)
        }
        catch
        {
            if (-not($_.Exception.Message -like "Stack*does not exist"))
            {
                throw
            }
        }
    }
}

function Get-Environment
{
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
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    $componentIdentifier = Get-ComponentIdentifier $environmentName

    $stack = Get-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -StackName $componentIdentifier -Region $awsRegion

    $resultHash = @{}
    $resultHash.Add("StackId", $stack.StackId)
    $resultHash.Add("Stack", $stack)
    $resultHash.Add("AutoScalingGroupName", ($stack.Outputs | Where-Object { $_.OutputKey -eq "AutoScalingGroupName" } | Single).OutputValue)

    $result = new-object PSObject $resultHash

    return $result
}

function CollectAndUploadDependencies
{
    param
    (
        [string]$componentIdentifier,
        [string]$commonScriptsDirectory
    )

    Write-Verbose "Gathering environment setup dependencies into single zip archive for distribution to S3 for usage by CloudFormation."
    $directories = Get-ChildItem -Directory -Path $($repositoryRoot.FullName) |
        Where-Object { $_.Name -like "scripts" -or $_.Name -like "tools" -or $_.Name -like "src" }

    $user = (& whoami).Replace("\", "_")
    $date = [DateTime]::Now.ToString("yyyyMMddHHmmss")

    $here = Split-Path $script:MyInvocation.MyCommand.Path
    $archive = "$here\script-working\$environmentName\$user\$date\dependencies.zip"

    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $archive = 7Zip-ZipDirectories $directories $archive -SubdirectoriesToExclude @("script-working","test-working", "packages")
    $archive = 7Zip-ZipFiles "$($repositoryRoot.FullName)\script-root-indicator" $archive -Additive

    Write-Verbose "Uploading dependencies archive to S3 for usage by CloudFormation."
    $awsBucket = Get-S3Bucket

    $dependenciesArchiveS3Key = "$componentIdentifier/$user/$date/dependencies.zip"

    . "$commonScriptsDirectoryPath\Functions-Aws-S3.ps1"

    $dependenciesArchiveS3Key = UploadFileToS3 -AwsKey $awsKey -AwsSecret $awsSecret -AwsBucket $awsBucket -AwsRegion $awsRegion -File $archive -S3FileKey $dependenciesArchiveS3Key

    return "https://s3-ap-southeast-2.amazonaws.com/$awsBucket/$dependenciesArchiveS3Key"
}