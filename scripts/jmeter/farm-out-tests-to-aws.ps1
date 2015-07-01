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
    [string]$octopusApiKey
)

$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path
write-verbose "Script is located at [$currentDirectoryPath]."

. "$currentDirectoryPath\_Find-RootDirectory.ps1"

$rootDirectory = Find-RootDirectory $currentDirectoryPath

$rootDirectoryPath = $rootDirectory.FullName
$commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

. "$rootDirectoryPath\scripts\environment\Functions-Environment.ps1"

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
    $stack = New-Environment -EnvironmentName $environmentName -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion -OctopusServerUrl $octopusServerUrl -OctopusApiKey $octopusApiKey -Wait
}

$autoScalingGroupName = $stack.AutoScalingGroupName

$asg = Get-ASAutoScalingGroup -AutoScalingGroupNames $autoScalingGroupName -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion
$instances = $asg.Instances

. "$commonScriptsDirectoryPath\Functions-Aws-Ec2.ps1"

$remoteUser = "Administrator"
$remotePassword = "123Qwerty"
$securePassword = ConvertTo-SecureString $remotePassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($remoteUser, $securePassword)

$usersPerMachine = 50
$nextAvailableCustomerNumber = 1
$jobs = @()
try
{
    foreach ($instance in $instances)
    {
        # Get the instance
        $instance = Get-AwsEc2Instance -InstanceId $instance.InstanceId -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion
        $instanceId = $instance.InstanceId

        $ipAddress = $instance.PrivateIpAddress
    
        $session = New-PSSession -ComputerName $ipAddress -Credential $cred

        $remoteScript = {
            param
            (
                [int]$totalNumberOfUsers,
                [int]$startingCustomerNumber
            )
            Set-ExecutionPolicy -ExecutionPolicy Bypass
            & "C:\JMETER_LiveAgentServiceLoadTest\scripts\execute-load-test-no-gui.ps1" -totalNumberOfUsers $totalNumberOfUsers -startingCustomerNumber $startingCustomerNumber -AllocatedMemory 512
        }
        Write-Verbose "Executing command on [$instanceId][$ipAddress]. Customer Number starting at [$nextAvailableCustomerNumber]."
        $job = Invoke-Command -Session $session -ScriptBlock $remoteScript -ArgumentList $usersPerMachine,$nextAvailableCustomerNumber -AsJob
        $job.Name = "$instanceId [$nextAvailableCustomerNumber - $($nextAvailableCustomerNumber + $usersPerMachine)]"
        $jobs += $job
        $nextAvailableCustomerNumber += $usersPerMachine

        Write-Verbose "Sleeping."
        Sleep -Seconds 300
    }
    
    Read-Host -Prompt "Press any key to terminate the load tests"
}
finally
{
    Stop-Job $jobs
    Wait-Job $jobs

    foreach ($instance in $instances)
    {
        # Get the instance
        $instance = Get-AwsEc2Instance -InstanceId $instance.InstanceId -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion
        $instanceId = $instance.InstanceId

        $ipAddress = $instance.PrivateIpAddress
    
        $session = New-PSSession -ComputerName $ipAddress -Credential $cred

        $remoteScript = {
            Set-ExecutionPolicy -ExecutionPolicy Bypass
            (Get-Process -Name "java") | where { $_.Path -match "JMETER" } | kill
        }
        Write-Verbose "Terminating any rogue instances of the load tests on the remote machine [$instanceId][$ipAddress]"
        Invoke-Command -Session $session -ScriptBlock $remoteScript
    }
}