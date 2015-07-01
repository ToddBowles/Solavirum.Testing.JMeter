function Get-KnownEnvironments
{
    return @("CI", "Staging", "Production")
}

function Get-StackName
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$environment
    )
    
    return "$(Get-UniqueEnvironmentComponentIdentifier)-$environment"
}

function Get-UniqueEnvironmentComponentIdentifier
{
    return "JMeter-Workers"
}

function Get-DependenciesS3BucketName
{
    return "some.bucket.you.have"
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
        [string]$awsRegion="ap-southeast-2",
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [switch]$wait,
        [switch]$disableCleanupOnFailure
    )

    try
    {
        write-verbose "Creating New Environment $environmentName"

        if ($rootDirectory -eq $null) { throw "RootDirectory script scoped variable not set. That's bad, its used to find dependencies." }

        $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
        write-verbose "Script is located at [$scriptFileLocation]."

        $rootDirectoryDirectoryPath = $rootDirectory.FullName
        $commonScriptsDirectoryPath = "$rootDirectoryDirectoryPath\scripts\common"

        . "$commonScriptsDirectoryPath\Functions-OctopusDeploy.ps1"
        $knownEnvironments = Get-KnownEnvironments
        if (!$knownEnvironments.Contains($environmentName))
        {
            write-warning "You have specified an environment [$environmentName] that is not in the list of known environments [$($knownEnvironments -join ", ")]. The script will temporarily create an environment in Octopus, and then delete it at the end."
            $shouldRemoveOctopusEnvironmentWhenDone = $true

            try
            {
                $octopusEnvironment = New-OctopusEnvironment -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey -EnvironmentName $environmentName -EnvironmentDescription "[SCRIPT] Environment automatically created because it did not already exist and the New-Environment Powershell function was being executed."
            }
            catch 
            {
                Write-Warning "Octopus Environment [$environmentName] could not be created."
                Write-Warning $_
            }
        }
        else
        {
            $octopusEnvironment = Get-OctopusEnvironmentByName -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey -EnvironmentName $environmentName
        }

        . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

        Ensure-AwsPowershellFunctionsAvailable
        $stackName = Get-StackName $environmentName
        $dependenciesS3Bucket = Get-DependenciesS3BucketName
        $user = (& whoami).Replace("\", "_")
        $date = [DateTime]::Now.ToString("yyyyMMddHHmmss")
        $buildIdentifier = "$user-$date" # Change this to a git commit or tag or something so we can track it later.

        $dependenciesArchiveUrl = _CollectAndUploadDependencies -dependenciesS3BucketName $dependenciesS3Bucket -stackName $stackName -buildIdentifier $buildIdentifier

        $filter_name = New-Object Amazon.EC2.Model.Filter -Property @{Name = "name"; Value = "Windows_Server-2012-R2_RTM-English-64Bit-Core*"}
        $ec2ImageDetails = Get-EC2Image -Owner amazon -Filter $filter_name  -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion | Sort-Object Name -Descending | Select-Object -first 1

        $amiId = $ec2ImageDetails.ImageId

        $parametersHash = @{
            "AdminPassword"="123Qwerty";
            "DependenciesArchiveS3Url"=$dependenciesArchiveUrl;
            "EnvironmentName"="$environmentName";
            "S3AccessKey"="$awsKey";
            "S3SecretKey"="$awsSecret";
            "S3BucketName"="$(Get-DependenciesS3BucketName)";
            "ProxyUrlAndPort"="http://someproxy.com:3128";
            "OctopusEnvironment"="$environmentName";
            "OctopusServerURL"=$octopusServerUrl;
            "OctopusAPIKey"=$octopusApiKey;
            "DesiredNumberOfWorkers"=5;
            "AmiId"=$amiId;
        }

        . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

        $resultHash = @{}
        $resultHash.Add("StackId", $null)
        $resultHash.Add("Stack", $null)
        $resultHash.Add("AutoScalingGroupName", $null)

        $result = new-object PSObject $resultHash

        $tags = @()
        $octopusEnvironmentTag = new-object Amazon.CloudFormation.Model.Tag
        $octopusEnvironmentTag.Key = "OctopusEnvironment"
        $octopusEnvironmentTag.Value = $environmentName
        $tags += $octopusEnvironmentTag

        . "$commonScriptsDirectoryPath\Functions-Aws-S3.ps1"

        $templateFilePath = "$($rootDirectory.FullName)\scripts\environment\JMeter.Workers.cloudformation.template"
        $templateS3Url = _UploadTemplate -dependenciesS3BucketName $dependenciesS3Bucket -stackName $stackName -buildIdentifier $buildIdentifier -templateFilePath $templateFilePath

        write-verbose "Creating stack [$stackName] using template at [$templateFilePath]."
        $stackId = New-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -StackName "$stackName" -TemplateURL $templateS3Url -Parameters (Convert-HashTableToAWSCloudFormationParametersArray $parametersHash) -DisableRollback:$true -Tags $tags
        $result.StackId = $stackId

        if ($wait)
        {
            $testStatus = [Amazon.CloudFormation.StackStatus]::CREATE_IN_PROGRESS

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
            Write-Warning "A failure occurred and DisableCleanupOnFailure flag was set to false. Cleaning up."
            Delete-Environment -environmentName $environmentName -awsKey $awsKey -awsSecret $awsSecret -awsRegion $awsRegion -octopusServerUrl $octopusServerUrl -octopusApiKey $octopusApiKey -Wait
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
        [string]$awsRegion="ap-southeast-2",
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $newEnvironmentResult,
        [Amazon.CloudFormation.StackStatus]$testStatus=[Amazon.CloudFormation.StackStatus]::CREATE_IN_PROGRESS
    )

    if ($rootDirectory -eq $null) { throw "RootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $rootDirectoryDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryDirectoryPath\scripts\common"

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
        [string]$awsRegion="ap-southeast-2",
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$octopusApiKey,
        [switch]$wait
    )
    
    Write-Verbose "Deleting Environment $environmentName"

    if ($rootDirectory -eq $null) { throw "RootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $rootDirectoryDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryDirectoryPath\scripts\common"

    $stackName = Get-StackName $environmentName

    . "$commonScriptsDirectoryPath\Functions-OctopusDeploy.ps1"

    Write-Verbose "Cleaning up Octopus environment [$environmentName]"
    $machines = Get-OctopusMachinesByRole -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey -Role $stackName
    $machines | ForEach-Object { $deletedMachine = Delete-OctopusMachine -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey -MachineId $_.Id }

    if (-not ((Get-KnownEnvironments) -contains $environmentName))
    {
        try
        {
            $environment = Get-OctopusEnvironmentByName -EnvironmentName $environmentName -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey
            if ($environment -ne $null)
            {
                $deletedEnvironment = Delete-OctopusEnvironment -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey -EnvironmentId $environment.Id
            }
        }
        catch 
        {
            Write-Warning "Octopus Environment [$environmentName] could not be deleted."
            Write-Warning $_
        }
    }

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable


    try
    {
        . "$commonScriptsDirectoryPath\Functions-Aws-CloudFormation.ps1"

        Remove-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion -Force -StackName "$stackName"
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
            $stack = Wait-CloudFormationStack -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -StackName "$stackName" -TestStatus ([Amazon.CloudFormation.StackStatus]::DELETE_IN_PROGRESS)
        }
        catch
        {
            if (-not($_.Exception.Message -like "Stack*does not exist"))
            {
                throw
            }
        }
    }
    
    try
    {

        . "$commonScriptsDirectoryPath\Functions-Aws-S3.ps1"

        $awsBucket = Get-DependenciesS3BucketName
        RemoveFilesFromS3ByPrefix -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -AwsBucket $awsBucket -Prefix $stackName -Force
    }
    catch
    {
        Write-Warning "Error occurred while trying to remove files for environment [$environmentName] from S3."
        Write-Warning $_
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

    if ($rootDirectory -eq $null) { throw "RootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }

    $scriptFileLocation = Split-Path $script:MyInvocation.MyCommand.Path
    write-verbose "Script is located at [$scriptFileLocation]."

    $rootDirectoryDirectoryPath = $rootDirectory.FullName
    $commonScriptsDirectoryPath = "$rootDirectoryDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    $stackName = Get-StackName $environmentName

    $stack = Get-CFNStack -AccessKey $awsKey -SecretKey $awsSecret -StackName $stackName -Region $awsRegion

    $resultHash = @{}
    $resultHash.Add("StackId", $stack.StackId)
    $resultHash.Add("Stack", $stack)
    $resultHash.Add("AutoScalingGroupName", ($stack.Outputs | Where-Object { $_.OutputKey -eq "AutoScalingGroupName" } | Single).OutputValue)

    $result = new-object PSObject $resultHash

    return $result
}

# Assumes that there is are variables in scope containing AWS credentials.
function _CollectAndUploadDependencies
{
    param
    (
        [string]$dependenciesS3BucketName,
        [string]$stackName,
        [string]$buildIdentifier
    )

    Write-Verbose "Gathering environment setup dependencies into single zip archive for distribution to S3 for usage by CloudFormation."
    $directories = Get-ChildItem -Directory -Path $($rootDirectory.FullName) |
        Where-Object { $_.Name -like "scripts" -or $_.Name -like "tools" }

    $here = Split-Path $script:MyInvocation.MyCommand.Path
    $archive = "$here\script-working\$environmentName\$user\$date\dependencies.zip"

    . "$($rootDirectory.FullName)\scripts\common\Functions-Compression.ps1"

    $archive = 7Zip-ZipDirectories $directories $archive -SubdirectoriesToExclude @("script-working","test-working", "packages")
    $archive = 7Zip-ZipFiles "$($rootDirectory.FullName)\script-root-indicator" $archive -Additive

    Write-Verbose "Uploading dependencies archive to S3 for usage by CloudFormation."
    $awsBucket = Get-DependenciesS3BucketName

    $dependenciesArchiveS3Key = "$stackName/$buildIdentifier/dependencies.zip"

    . "$($rootDirectory.FullName)\scripts\common\Functions-Aws-S3.ps1"

    $dependenciesArchiveS3Key = UploadFileToS3 -AwsBucket $dependenciesS3BucketName  -File $archive -S3FileKey $dependenciesArchiveS3Key -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion 

    return "https://s3-ap-southeast-2.amazonaws.com/$awsBucket/$dependenciesArchiveS3Key"
}

# Assumes that there is are variables in scope containing AWS credentials.
function _UploadTemplate
{
    param
    (
        [string]$dependenciesS3BucketName,
        [string]$stackName,
        [string]$templateFilePath,
        [string]$buildIdentifier
    )

    $directories = Get-ChildItem -Directory -Path $($rootDirectory.FullName) |
        Where-Object { $_.Name -like "scripts" -or $_.Name -like "tools" }

    Write-Verbose "Uploading CloudFormation template to S3 for usage by CloudFormation." 

    $templateS3Key = "$stackName/$buildIdentifier/CloudFormation.template"

    . "$($rootDirectory.FullName)\scripts\common\Functions-Aws-S3.ps1"

    $templateS3Key = UploadFileToS3 -AwsBucket $dependenciesS3BucketName -File $templateFilePath -S3FileKey $templateS3Key -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion 

    return "https://s3-ap-southeast-2.amazonaws.com/$dependenciesS3BucketName/$templateS3Key"
}