function Single
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
        $hasMatch = $false
        $accepted = $null
    }
    process
    {
        if ($predicate -eq $null -or (& $predicate $input))
        {
            if ($hasMatch) { throw "Multiple elements matching predicate found. First element was [$accepted]. This element is [$_]." }

            $hasMatch = $true
            $accepted = $_
        }
    }
    end
    {
        if ($accepted -eq $null) { throw "No elements matching predicate found." }
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
        $predicate
    )

    begin
    {
        $hasMatch = $false
    }
    process
    {
        if ((-not $hasMatch) -and ($predicate -eq $null) -or (& $predicate $input))
        {
            $hasMatch = $true
        }
    }
    end
    {
        return $hasMatch
    }
}