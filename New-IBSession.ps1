Function New-IBSession {
    <#
    .SYNOPSIS
        Login to Infoblox platform by not using the API connection, but wrapper the http querys the site does to login the user when using a web browser. 
    
    .DESCRIPTION
        This function was inspired in this one (API based): https://github.com/RamblingCookieMonster/Infoblox
        Reason to not using the API it's because by the time of needing this project, API calls wasn't allowed. 

    .EXAMPLE
        New-IBSession -Uri https://grid.infobloxserver.com/ui -Credential (get-credential) -Passthru

        Creates a Infoblox session with specific credential and passthru the credencial to the next pipeline cmdlet. 

    .PARAMETER Uri
        The base Uri for the Infoblox.

    .PARAMETER Credential
        A valid PSCredential.

    .PARAMETER PassThru
        If specified, returns the web session to the pipeline.
    #>   
    [CmdletBinding()]
    [OutputType([psobject])]
    param(    
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Uri,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Management.Automation.PSCredential] $Credential,

        [Parameter(Mandatory=$false)]
        [switch] $PassThru
    )

    try
    {
        # Create the first GET request of login page
        if (-not($Uri -match '/$')) { $Uri = $Uri+'/' }
        $WebRequest = Invoke-WebRequest -Uri $Uri -Method Get -SessionVariable LoginSession -ErrorAction Stop

        # Filling the login form:
        $WebRequest.Forms['loginForm'].fields['username'] = $credential.UserName
        $WebRequest.Forms['loginForm'].fields['password'] = $credential.GetNetworkCredential().Password
        $LoginToken = $WebRequest | Select -ExpandProperty InputFields | Where-Object { $_.outerHTML -match 'loginButton' } | Select onclick -Unique | ForEach-Object { [string](([regex]::Match($_.onclick,"Form\'\, '\.\/(?<form_id>[a-zA-Z0-9\-_]+)'\,")).groups["form_id"].value) }
        Write-Verbose "Login token: $LoginToken"

        $WebRequest = Invoke-WebRequest -Uri ($Uri + $LoginToken) -Method Post -Body $WebRequest.Forms['loginForm'].Fields -WebSession $LoginSession -ContentType application/x-www-form-urlencoded -ErrorAction Stop
    }
    catch
    {
        Throw "Error retrieving session: $_"
    }

    if ($PassThru)
    {
        $LoginSession
    }
}