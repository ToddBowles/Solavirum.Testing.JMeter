function Single
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $input,
        [Parameter(Mandatory=$false)]
        [scriptblock]$predicate
    )

    begin
    {
        $hasMatch = $false
        $accepted = $null
        
        if ($predicate -eq $null) { $loggedPredicate = "No Predicate Specified" }
        else { $loggedPredicate = $predicate }
    }
    process
    {
        if ($predicate -eq $null -or (& $predicate $input))
        {
            write-verbose "Single: [$_] matches when tested with [$loggedPredicate]"
            if ($hasMatch) { throw "Single: Multiple elements matching predicate [$loggedPredicate] found. First element was [$accepted]. This element is [$_]." }

            $hasMatch = $true
            $accepted = $_
        }
    }
    end
    {
        if ($accepted -eq $null) { throw "No elements matching predicate [$loggedPredicate] found." }
        return $accepted
    }
}

function First
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $input,
        [Parameter(Mandatory=$false)]
        $predicate
    )

    begin
    {
        $accepted = $null
    }
    process
    {
        $accepted = $_
    }
    end
    {
        if ($accepted -eq $null) { throw "No elements found." }
        return $accepted
    }
}

function Any
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $input,
        [Parameter(Mandatory=$false)]
        [scriptblock]$predicate
    )

    begin
    {
        $hasMatch = $false

        if ($predicate -eq $null) { $loggedPredicate = "No Predicate Specified" }
        else { $loggedPredicate = $predicate }
    }
    process
    {
        if ((-not $hasMatch) -and (($predicate -eq $null) -or (& $predicate $_)))
        {
            write-verbose "Any: [$_] matched [$loggedPredicate], returning true."
            $hasMatch = $true
        }
        else
        {
            write-verbose "Any: [$_] does not match when tested with [$loggedPredicate]"
        }
    }
    end
    {
        return $hasMatch
    }
}