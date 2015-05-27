function Wait-Ec2InstanceReachesDesiredState
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
        [string]$instanceid,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$desiredstate
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    write-verbose "Waiting for the EC2 Instance with Id [$($instanceid)] to reach [$desiredstate] state."
    $increment = 5
    $totalWaitTime = 0
    $timeout = 360
    while ($true)
    {
        $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret
        $state = $a.Instances[0].State.Name

        if ($state -eq $desiredstate)
        {
            write-verbose "The EC2 Instance with Id [$($instanceid)] took [$totalWaitTime] seconds to reach the [$desiredstate] state."
            break
        }

        write-verbose "$(Get-Date) Current State is [$state], Waiting for [$desiredstate]."

        Sleep -Seconds $increment
        $totalWaitTime = $totalWaitTime + $increment
        if ($totalWaitTime -gt $timeout)
        {
            throw "The EC2 Instance with Id [$($instanceid)] did not reach the [$desiredstate] state in [$timeout] seconds."
        }
    }
}

function Wait-Ec2InstanceReady
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
        [string]$instanceid
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"
    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    write-verbose "Waiting for the EC2 Instance with Id [$($instanceid)] to be ready."
    $increment = 5
    $totalWaitTime = 0
    $timeout = 600

    $ec2Config = new-object Amazon.EC2.AmazonEC2Config
    $ec2Config.RegionEndpoint = [Amazon.RegionEndpoint]::GetBySystemName($awsRegion)
    $client = [Amazon.AWSClientFactory]::CreateAmazonEC2Client($awsKey, $awsSecret,$ec2Config)

    while ($true)
    {
        $describeRequest = New-Object Amazon.EC2.Model.DescribeInstanceStatusRequest
        $describeRequest.InstanceIds.Add($instanceid)
        $describeResponse = $client.DescribeInstanceStatus($describeRequest)

        # Ready means that all of the instance status checks come back as "passed". Thats pretty much
        # the instance reachability check, but I check all just in case.
        $instanceStatus = $describeResponse.DescribeInstanceStatusResult.InstanceStatuses[0]
        if ($instanceStatus.Status.Details | All { $_.Status -eq "passed" })
        {
            write-verbose "The EC2 Instance with Id [$($instanceid)] took [$totalWaitTime] seconds to be ready."
            break
        }

        write-verbose "$(Get-Date) Waiting for the EC2 Instance with Id [$($instanceid)] to be ready."

        Sleep -Seconds $increment
        $totalWaitTime = $totalWaitTime + $increment
        if ($totalWaitTime -gt $timeout)
        {
            throw "The EC2 Instance with Id [$($instanceid)] was not ready in [$timeout] seconds."
        }
    }
}

function Tag-NameEc2Instance
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
        [string]$instanceid,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name
    )

    $tags = @()
    $nameTag = new-object Amazon.EC2.Model.Tag
    $nameTag.Key = "Name"
    $nameTag.Value = $name
    $tags += $nameTag

    write-verbose "Naming Instance [$instanceid] [$name]."
    New-EC2Tag -Resource $instanceid -Tag $tags -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion
}

function Tag-MakeEc2InstanceExpirable
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
        [string]$instanceid
    )

    $tags = @()

    $expireTag = new-object Amazon.EC2.Model.Tag
    $expireTag.Key = "expire"
    $expireTag.Value = "true"
    $tags += $expireTag

    write-verbose "Marking Instance [$instanceid] as expirable. It will be automatically terminated after some period (hours)."
    New-EC2Tag -Resource $instanceid -Tag $tags -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion
}

function Get-AwsEc2Instance
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
        [string]$instanceid
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

    $instance = ((Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceId} -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret).Instances) | Single

    return $instance
}

function Kill-Ec2Instance
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
        [string]$instanceid
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable
    
    write-verbose "Attempting to Terminate EC2 Instance [$instanceId]."
    $terminateResult = Stop-EC2Instance -Instance $instanceId -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret -Terminate -Force
    write-verbose "Terminated [$instanceId]."
}

function New-AwsEc2Instance
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
        [hashtable]$instanceParameters,
        [switch]$IsNotTemporary,
        [ValidateSet('DEV','AMI')]
        [string]$instancePurpose='UNKNOWN',
        [switch]$wait
    )

    try
    {
        if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

        $repositoryRootDirectoryPath = $repositoryRoot.FullName
        $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

        . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

        Ensure-AwsPowershellFunctionsAvailable

        $instanceRequest = New-EC2Instance @instanceParameters
        $instance = $instanceRequest.Instances[0]
        $instanceId = $instance.InstanceId

        . "$commonScriptsDirectoryPath\Functions-Aws-Ec2.ps1"
        . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

        $image = (Get-Ec2Image -ImageId $instanceParameters["ImageId"] -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret) | Single
        $imageName = $image.Name

        $user = whoami
        Tag-NameEc2Instance -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId -Name "[$instancePurpose] [$user] $imageName"
        if (!$IsNotTemporary)
        {
            Tag-MakeEc2InstanceExpirable -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId
        }

        if ($wait)
        {
            Wait-Ec2InstanceReachesDesiredState -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId -DesiredState "running"
            Wait-Ec2InstanceReady -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId
        }

        return Get-AwsEc2Instance -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId
    }
    catch
    {
        if (![string]::IsNullOrEmpty($instanceId))
        {
            Kill-Ec2Instance -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId
        }

        throw $_
    }
}

function New-Ec2InstanceForEdit
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
        [hashtable]$instanceParameters,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$remoteUsername,
        [Parameter(Mandatory=$true)]
        [string]$remotePassword
    )

    try
    {
        if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

        $repositoryRootDirectoryPath = $repositoryRoot.FullName
        $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

        . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

        Ensure-AwsPowershellFunctionsAvailable

        $instance = New-AwsEc2Instance -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceParameters $instanceParameters -Wait -IsTemporary -InstancePurpose "AMI"

        $privateIpAddress = $instance.PrivateIpAddress

        . "$commonScriptsDirectoryPath\Functions-Remoting.ps1"

        $remoteProcessId = New-RemoteDesktopSession -ComputerNameOrIp $privateIpAddress -User $remoteUsername -Password $remotePassword

        New-AwsEc2Image -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -Instance $instance

        $killAnswer = Read-Host -Prompt "Press any key to kill your instance. Enter 'save' to keep your instance. Make sure you clean it up through another mechanism when you are done"
    }
    finally
    {
        if (![string]::IsNullOrEmpty($instanceId) -and ($killAnswer -ne "save"))
        {
            Kill-Ec2Instance -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -InstanceId $instanceId
        }
    }
}

function New-AwsEc2Image
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
        [Amazon.EC2.Model.Instance]$instance
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    $snapshotAnswer = Read-Host -Prompt "Enter 'snapshot' to create an AMI from [$($instance.InstanceId)]"

    if ($snapshotAnswer -eq "snapshot")
    {
        . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

        $image = (Get-Ec2Image -ImageId $instance.ImageId -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret) | Single
        $imageName = $image.Name

        $newName = Get-IncrementedVersionedImageName $imageName 

        . "$commonScriptsDirectoryPath\Functions-Strings.ps1"

        $userDescription = Read-Host -Prompt "Enter some information about what you changed"
        $user = whoami
        $userDescription = StringNullOrEmptyCoalesce $userDescription "No information entered by user [$user] when creating image."

        $result = New-Ec2Image -InstanceId $instance.InstanceId -Name "$newName" -Description "$userDescription" -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion
        # Sometimes if you try to query the fresh image immediately after it has just been created you get nothing. Lets add a sleep to avoid that.
        Sleep -Seconds 2
        Wait-AmiAvailable -AmiId $result -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion

        return $result
    }
}

function Get-IncrementedVersionedImageName
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$oldImageName
    )

    $nameRegex = '(?''name''.*)V(?''version''[0-9]+)'
    $match = [regex]::Match($oldImageName, $nameRegex)
    if (!($match.Success))
    {
        return $oldImageName + " V2"
    }
    $oldVersion = [Int32]::Parse($match.Groups["version"])
    $newVersion = $oldVersion + 1

    $newName = "$($match.Groups["name"])V$newVersion"

    return $newName
}

function Wait-AmiAvailable
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
        [string]$amiId,
        [int]$timeoutSeconds=360
    )

    if ($repositoryRoot -eq $null) { throw "RepositoryRoot script scoped variable not set. Thats bad, its used to find dependencies." }

    $repositoryRootDirectoryPath = $repositoryRoot.FullName
    $commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Aws.ps1"
    . "$commonScriptsDirectoryPath\Functions-Enumerables.ps1"

    Ensure-AwsPowershellFunctionsAvailable

    write-verbose "Waiting for the AMI with Id [$($amiId)] to be available."
    $increment = 5
    $totalWaitTime = 0
    while ($true)
    {
        $a = Get-EC2Image -ImageId $amiId -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret
        $state = ($a | Single).State.Value

        if ($state -eq "available")
        {
            write-verbose "The AMI with Id [$($amiId)] took [$totalWaitTime] seconds to be available"
            break
        }

        write-verbose "$(Get-Date) Current State is [$state], Waiting for [available]."

        Sleep -Seconds $increment
        $totalWaitTime = $totalWaitTime + $increment
        if ($totalWaitTime -gt $timeoutSeconds)
        {
            throw "The EC2 Instance with Id [$($amiId)] was not [available] in [$timeoutSeconds] seconds."
        }
    }
}