function UploadFileToS3
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [string]$awsBucket,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$file,
        [Parameter(Mandatory=$true)]
        [string]$S3FileKey
    )

    Write-Verbose "Uploading [$($file.FullName)] to [$($awsRegion):$($awsBucket):$S3FileKey]."
    (Write-S3Object -BucketName $awsBucket -Key $S3FileKey -File "$($file.FullName)" -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret) | Write-Verbose

    return $S3FileKey
}

function DownloadFileFromS3ByKey
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [string]$awsBucket,
        [Parameter(Mandatory=$true)]
        [string]$S3FileKey,
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$destination
    )

    if ($destination.Exists)
    {
        Write-Verbose "Destination for S3 download of [$S3FileKey] ([$($destination.FullName)]) already exists. Deleting."
        $destination.Delete()
    }

    Write-Verbose "Downloading [$($awsRegion):$($awsBucket):$S3FileKey] to [$($destinationFile.FullName)]."
    (Read-S3Object -BucketName $awsBucket -Key $S3FileKey -File "$($destination.FullName)" -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret) | Write-Verbose

    $destination.Refresh()

    return $destination
}

function RemoveFilesFromS3ByPrefix
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [string]$awsBucket,
        [string]$prefix,
        [switch]$Force
    )

    write-verbose "Removing all objects in S3 that match [Region: $awsRegion, Location: $awsBucket\$prefix]."
    Get-S3Object -BucketName $awsBucket -KeyPrefix $prefix -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret | ForEach-Object {
        Write-Verbose "Removing $($_.Key)."
        $result = Remove-S3Object -BucketName $awsBucket -Key $_.Key -Region $awsRegion -AccessKey $awsKey -SecretKey $awsSecret -Force:$Force
    }
}