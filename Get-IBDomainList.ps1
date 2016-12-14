Function Get-IBDomain {
    <#
    .SYNOPSIS
        Get a list of all domains in DNS records of Infoblox.
    
    .DESCRIPTION
        This project was inspired in this one (API based): https://github.com/RamblingCookieMonster/Infoblox
        Reason to not using the API it's because by the time of needing this project, API calls wasn't allowed. 

    .EXAMPLE

        

    #>   
    [CmdletBinding()]
    [OutputType([psobject])]
    param(    
        
    )


    try
    {
        
    }
    catch
    {
        throw "$_"
    }
}