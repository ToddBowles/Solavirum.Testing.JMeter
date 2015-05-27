function Find-RepositoryRoot
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.IO.DirectoryInfo]$searchStart
    )

    if ((Get-ChildItem -Path $searchStart.FullName -Filter script-root-indicator) -eq $null) { return Find-RepositoryRoot $searchStart.Parent }
    
    return $searchStart 
}