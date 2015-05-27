function StringNullOrEmptyCoalesce
{
    [CmdletBinding()]
    param
    (
        [string]$a,
        [string]$b
    )

    if ($a -eq $null) { return $b }
    if ([String]::IsNullOrEmpty($a)) { return $b }
    return $a
}