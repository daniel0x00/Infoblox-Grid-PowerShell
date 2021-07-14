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
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.106 Safari/537.36"
                }
            }

            $FirstRequest = Invoke-WebRequest @FirstRequestParameters -SessionVariable LoginSession -ErrorAction Stop -SkipCertificateCheck 

            #$LoginToken = [string](([regex]::Match($FirstRequest.Content,"Form&#039;\, &#039;\.\/(?<form_id>[a-zA-Z0-9\-_]+)&#039;\,")).groups["form_id"].value)
            $LoginToken = [string](([regex]::Match($FirstRequest.Content,"wicketSubmitFormById\(&#039;loginForm&#039;,.?&#039;\.\/(?<form_id>[a-zA-Z0-9\-_]+)&#039;, &#039;loginButton")).groups["form_id"].value)
            Write-Verbose "[New-IBSession] LoginToken: $LoginToken" 

            $Username = $Credential.UserName
            $Password = [uri]::EscapeDataString($Credential.GetNetworkCredential().Password)
            $LoginURL = $Uri + $LoginToken + "?random=" + ((Get-Random -Minimum 0.0 -Maximum 0.99) -replace ',','.')

            $LoginParameters = @{
                Uri = $LoginURL
                Method = 'Post'
                Body = "loginForm_hf_0=&username=$Username&password=$Password&contextId=&loginButton=1"
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
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.106 Safari/537.36"
                    "sec-ch-ua" = '" Not;A Brand";v="99", "Google Chrome";v="91", "Chromium";v="91"'
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
