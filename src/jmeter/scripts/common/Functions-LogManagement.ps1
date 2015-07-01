function InitialiseCommonLogsDirectory
{
    $directoryPath = "C:\logs"
    if (-not (Test-Path $directoryPath))
    {
        Write-Verbose "Creating commong logs directory at [$directoryPath]"
        New-Item $directoryPath -Type Directory 
    }

    Write-Verbose "Making common logs directory [$directoryPath] writeable by everyone."
    $Acl = Get-Acl $directoryPath

    $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

    $Acl.SetAccessRule($Ar)
    Set-Acl $directoryPath $Acl
}

function CreateLogsClearingTask
{
    $directoryPath = "C:\logs"

    $taskName = "Clear Old Logs"

    $service = new-object -ComObject("Schedule.Service")
    $service.Connect()
    $rootFolder = $service.GetFolder("\")
    try
    {
        $rootFolder.DeleteTask($taskName, 0)
    }
    catch
    {
        if (-not ($_.Exception.Message -like "*The system cannot find the file specified*"))
        {
            throw $_.Exception
        }
    }

    $daysOld = 14
    $taskDescription = "Clears Logs that are older than [$daysOld] days"
    $taskCommand = "powershell"
    $taskArguments = "-Command `"&{ Get-ChildItem $directoryPath\logs\* -Include *.log -Recurse | Where LastWriteTime -lt (Get-Date).AddDays(-$daysOld) | Remove-Item }`" -ExecutionPolicy Bypass"
 
    write-verbose "Creating Scheduled Task to automatically execute [$taskCommand] with arguments [$taskArguments] on a regular basis."

    $TaskStartTime = [DateTime]::Now.Date.AddHours(1)
 
    $TaskDefinition = $service.NewTask(0) 
    $TaskDefinition.RegistrationInfo.Description = "$taskDescription"
    $TaskDefinition.Settings.Enabled = $true
    $TaskDefinition.Settings.AllowDemandStart = $true
 
    $triggers = $TaskDefinition.Triggers
    #http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
    $trigger = $triggers.Create(2)
    $trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
    $trigger.Enabled = $true
    $trigger.DaysInterval = 1
 
    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
    $Action = $TaskDefinition.Actions.Create(0)
    $action.Path = "$taskCommand"
    $action.Arguments = "$taskArguments"
 
    #http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
    $rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5)

    $task = $rootFolder.GetTask($taskName)

    Write-Verbose "Executing Scheduled Task."
    $task.Run($null)
}