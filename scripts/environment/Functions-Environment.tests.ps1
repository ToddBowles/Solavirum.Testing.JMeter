$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -ireplace "tests.", ""
. "$here\$sut"

. "$currentDirectoryPath\_Find-RepositoryRoot.ps1"
$repositoryRoot = Find-RepositoryRoot $here


function Create-UniqueEnvironmentName
{
    $currentUtcDateTime = [DateTime]::UtcNow
    $a = $currentUtcDateTime.ToString("yy") + $currentUtcDateTime.DayOfYear.ToString("000")
    $b = ([int](([int]$currentUtcDateTime.Subtract($currentUtcDateTime.Date).TotalSeconds) / 2)).ToString("00000")
    $uniqueId = "$($env:username)-$a-$b"
    return "Test-$uniqueId"
}

function Get-AwsCredentials
{
    $logAggregatorEnvironmentCreationKeyLookupKey = "LOGAGGREGATOR_AWS_ENVIRONMENT_KEY"
    $logAggregatorAwsEnvironmentCreationSecretLookupKey = "LOGAGGREGATOR_AWS_ENVIRONMENT_SECRET"

    $awsCreds = @{
        AwsKey = (Get-CredentialByKey $logAggregatorEnvironmentCreationKeyLookupKey);
        AwsSecret = (Get-CredentialByKey $logAggregatorAwsEnvironmentCreationSecretLookupKey);
        AwsRegion = "ap-southeast-2";
    }
    return New-Object PSObject -Property $awsCreds
}

Describe "New-Environment" {
    Context "When executed with appropriate parameters" {
        It "Returns appropriate outputs, including stack identifiers and name of JMeter Worker auto scaling group for exposed services" {
            try
            {
                $creds = Get-AWSCredentials
                $environmentName = Create-UniqueEnvironmentName
                $environmentCreationResult = New-Environment -AwsKey $creds.AwsKey -AwsSecret $creds.AwsSecret -AwsRegion $creds.AwsRegion -EnvironmentName $environmentName -Wait -DisableCleanupOnFailure

                Write-Verbose (ConvertTo-Json $environmentCreationResult)

                $environmentCreationResult.AutoScalingGroupName | Should Not BeNullOrEmpty
            }
            finally
            {
                if ($environmentCreationResult -ne $null)
                {
                    Delete-Environment -AwsKey $creds.AwsKey -AwsSecret $creds.AwsSecret -AwsRegion $creds.AwsRegion -EnvironmentName $environmentName -Wait
                }
            }
        }
    }
}