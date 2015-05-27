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
    [string]$awsRegion="ap-southeast-2"
)

$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"

$repositoryRoot = Find-RepositoryRoot $currentDirectoryPath

$repositoryRootDirectoryPath = $repositoryRoot.FullName
$commonScriptsDirectoryPath = "$repositoryRootDirectoryPath\scripts\common"

. "$repositoryRootDirectoryPath\scripts\environment\Functions-Environment.ps1"

. "$commonScriptsDirectoryPath\Functions-Aws.ps1"

Ensure-AwsPowershellFunctionsAvailable

$stack = $null
try
{
    $stack = Get-Environment -EnvironmentName $environmentName -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion
}
catch 
{
    Write-Warning $_
}

if ($stack -eq $null)
{
    $update = ($stack -ne $null)

    $stack = New-Environment -EnvironmentName $environmentName -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -UpdateExisting:$update -Wait -disableCleanupOnFailure
}

$autoScalingGroupName = $stack.AutoScalingGroupName

$asg = Get-ASAutoScalingGroup -AutoScalingGroupNames $autoScalingGroupName -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion
$instances = $asg.Instances

. "$commonScriptsDirectoryPath\Functions-Aws-Ec2.ps1"

$remoteUser = "Administrator"
$remotePassword = "ObviouslyInsecurePasswordsAreTricksyMonkeys"
$securePassword = ConvertTo-SecureString $remotePassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($remoteUser, $securePassword)

$usersPerMachine = 100
$nextAvailableCustomerNumber = 1
$jobs = @()
foreach ($instance in $instances)
{
    # Get the instance
    $instance = Get-AwsEc2Instance -InstanceId $instance.InstanceId -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion

    $ipAddress = $instance.PrivateIpAddress
    
    $session = New-PSSession -ComputerName $ipAddress -Credential $cred

    $remoteScript = {
        param
        (
            [int]$totalNumberOfUsers,
            [int]$startingCustomerNumber
        )
        Set-ExecutionPolicy -ExecutionPolicy Bypass
        & "C:\cfn\dependencies\scripts\jmeter\execute-load-test-no-gui.ps1" -totalNumberOfUsers $totalNumberOfUsers -startingCustomerNumber $startingCustomerNumber -AllocatedMemory 512
    }
    $job = Invoke-Command -Session $session -ScriptBlock $remoteScript -ArgumentList $usersPerMachine,$nextAvailableCustomerNumber -AsJob
    $jobs += $job
    $nextAvailableCustomerNumber += $usersPerMachine

    #Sleep -Seconds ([TimeSpan]::FromHours(2).TotalSeconds)
    Sleep -Seconds 300

    # Can use Get-Job or record list of jobs and then terminate them. I suppose we could also wait on all of them to be complete. Might be good to get some feedback from
    # the remote process somehow, to indicate whether or not it is still running/what it is doing.
}