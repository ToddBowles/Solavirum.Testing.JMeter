function Get-CredentialByKey
{
    [CmdletBinding()]
    param
    (
        [string]$keyName
    )

    if ($globalCredentialsLookup -eq $null)
    {
        throw "Global hashtable variable called [globalCredentialsLookup] was not found. Credentials are specified at the entry point of your script. Specify hashtable content with @{KEY=VALUE}."
    }

    if (-not ($globalCredentialsLookup.ContainsKey($keyName)))
    {
        throw "The credential with key [$keyName] could not be found in the global hashtable variable called [globalCredentialsLookup]. Specify hashtable content with @{KEY=VALUE}."
    }

    return $globalCredentialsLookup.Get_Item($keyName)
}