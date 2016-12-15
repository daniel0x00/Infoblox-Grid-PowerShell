Function New-IBSession {
    <#
    .SYNOPSIS
        Login to Infoblox platform by NOT using the API connection, but wrapper the http querys the site does to login the user when using a web browser. 
    
    .DESCRIPTION
        This function was inspired in this one (API based): https://github.com/RamblingCookieMonster/Infoblox
        Reason to not using the API it's because by the time of needing this project, API calls wasn't allowed. 

    .EXAMPLE
        New-IBSession -Uri https://grid.infobloxserver.com/ui/ -Credential (get-credential)

        Creates a Infoblox session with specific credential and passthru the credencial to the next pipeline cmdlet. 

    .PARAMETER Uri
        The base Uri for the Infoblox.

    .PARAMETER Credential
        A valid PSCredential object obtained with Get-Credential.
    #>   
    [CmdletBinding()]
    [OutputType([psobject])]
    param(    
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Uri,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Management.Automation.PSCredential] $Credential
    )

    try
    {
        # Create the first GET request of login page:
        if (-not($Uri -match '/$')) { $Uri = $Uri+'/' }
        $WebRequest = Invoke-WebRequest -Uri $Uri -Method Get -SessionVariable LoginSession -ErrorAction Stop 

        # Filling the login form and submitting it:
        $RandomNumber = Get-Random -Minimum 0.0 -Maximum 0.99; $RandomNumber = $RandomNumber -replace ',','.'
        $WebRequest.Forms['loginForm'].fields['username'] = $credential.UserName
        $WebRequest.Forms['loginForm'].fields['password'] = $credential.GetNetworkCredential().Password
        $LoginToken = $WebRequest | Select -ExpandProperty InputFields | Where-Object { $_.outerHTML -match 'loginButton' } | Select onclick -Unique | ForEach-Object { [string](([regex]::Match($_.onclick,"Form\'\, '\.\/(?<form_id>[a-zA-Z0-9\-_]+)'\,")).groups["form_id"].value) }

        $WebRequest = Invoke-WebRequest -Uri ($Uri + $LoginToken + "?random=$RandomNumber") -Method Post -Body $WebRequest.Forms['loginForm'].Fields -WebSession $LoginSession -ErrorAction Stop -Headers @{"Wicket-Ajax"="true";"Wicket-Ajax-BaseURL"="."} 
        
        # Get Base URL id from Ajax-Location response header:
        $BaseURL = [string](([regex]::Match($WebRequest.Headers['Ajax-Location'],"\.\/(?<base_url>[a-zA-Z0-9\-_\/]+)")).groups["base_url"].value)
        if ($BaseURL -eq $null) { throw }
    }
    catch
    {
        throw "Received invalid session. Bad credentials? $_"
    }

    $ReturnObject = New-Object System.Object
    $ReturnObject | Add-Member -Type NoteProperty -Name Uri -Value $Uri
    $ReturnObject | Add-Member -Type NoteProperty -Name BaseURL -Value $BaseURL
    $ReturnObject | Add-Member -Type NoteProperty -Name Credential -Value $Credential
    $ReturnObject | Add-Member -Type NoteProperty -Name WebSession -Value $LoginSession

    $ReturnObject
}