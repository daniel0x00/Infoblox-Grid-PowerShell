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

    begin { }
    process {
        try
        {
            # Create the first GET request of login page:
            if (-not($Uri -match '/$')) { $Uri = $Uri+'/' }

            $FirstRequestParameters = @{
                Uri = $Uri
                Method = 'Get'
                Headers = @{
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                }
            }

            $FirstRequest = Invoke-WebRequest @FirstRequestParameters -SessionVariable LoginSession -ErrorAction Stop -SkipCertificateCheck

            # Filling the login form and submitting it:
            #$FirstRequest.Forms['loginForm'].fields['username'] = $credential.UserName
            #$FirstRequest.Forms['loginForm'].fields['password'] = $credential.GetNetworkCredential().Password
            #$LoginToken = $FirstRequest | Select-Object -ExpandProperty InputFields | Where-Object { $_.outerHTML -match 'loginButton' } | Select-Object onclick -Unique | ForEach-Object { [string](([regex]::Match($_.onclick,"Form\'\, '\.\/(?<form_id>[a-zA-Z0-9\-_]+)'\,")).groups["form_id"].value) }

            $LoginToken = [string](([regex]::Match($FirstRequest.Content,"Form&#039;\, &#039;\.\/(?<form_id>[a-zA-Z0-9\-_]+)&#039;\,")).groups["form_id"].value)
            Write-Verbose "[New-IBSession] LoginToken: $LoginToken" 
            $Username = $credential.UserName
            $Password = $credential.GetNetworkCredential().Password
            $LoginURL = $Uri + $LoginToken + "?random=" + ((Get-Random -Minimum 0.0 -Maximum 0.99) -replace ',','.')

            $LoginParameters = @{
                Uri = $LoginURL
                Method = 'Post'
                #Body = $FirstRequest.Forms['loginForm'].Fields
                Body = "loginForm_hf_0=&username=$Username&password=$Password&loginButton=Login&timezone=&contextId="
                WebSession = $LoginSession
                ContentType = 'application/x-www-form-urlencoded;charset=UTF-8'
                Headers = @{
                    "Wicket-Ajax" = "true"
                    "Wicket-Ajax-BaseURL" = "."
                    "Referer" = $Uri
                    "Origin" = $Uri -replace '/ui/',''
                    "Accept" = "text/xml"
                    "Sec-Fetch-Site" = "same-origin"
                    "Sec-Fetch-Mode" = "cors"
                    "Sec-Fetch-Dest" = "empty"
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                }
            }

            $WebRequest = Invoke-WebRequest @LoginParameters -ErrorAction Stop -SkipCertificateCheck
        
            # Get Base URL id from Ajax-Location response header:
            $BaseURL = [string](([regex]::Match($WebRequest.Headers['Ajax-Location'],"\.\/(?<base_url>[a-zA-Z0-9\-_\/]+)")).groups["base_url"].value)
            if ($BaseURL -eq $null) { throw }
            
            $ReturnObject = New-Object System.Object
            $ReturnObject | Add-Member -Type NoteProperty -Name Uri -Value $Uri
            $ReturnObject | Add-Member -Type NoteProperty -Name BaseURL -Value $BaseURL
            $ReturnObject | Add-Member -Type NoteProperty -Name WebSession -Value $LoginSession

            $ReturnObject
        }
        catch
        {
            throw "Received invalid session. Bad credentials? Exception: " + $_.Exception.Message
        }
    }
    end { }
}