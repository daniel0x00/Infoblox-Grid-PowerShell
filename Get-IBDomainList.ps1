Function Get-IBDomainList {
    <#
    .SYNOPSIS
        Get a list of all domains in DNS records of Infoblox. 
    
    .DESCRIPTION
        Query the DNS zone to get a full domain list. Requires a valid WebSession as an input, obtained with New-IBSession function. 

    .EXAMPLE
        New-IBSession -Uri https://grid.infobloxserver.com/ui/ -Credential (get-credential) | Get-IBDomainList

    .PARAMETER Uri
        The base Uri for the Infoblox.
        
        String. Mandatory. Pipeline enabled.

    .PARAMETER BaseURL
        The base URL obtained in the Infoblox login process (New-IBSession takes care of it).

        String. Mandatory. Pipeline enabled.

    .PARAMETER WebSession
        The web session created in the Infoblox login process (New-IBSession takes care of it).

        WebRequestSession. Mandatory. Pipeline enabled.
    
    .PARAMETER Passthru
        If specified, pass to the pipeline the WebSession & BaseURL, required to query each domain separately.

        Switch. Not mandatory.

    .PARAMETER FindOne
        If specified, domain list will only return the first page of results instead recurring query all possible pages.

        Switch. Not mandatory.

    #>   
    [CmdletBinding()]
    [OutputType([psobject])]
    param(    
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Uri,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $BaseURL,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,

        [Parameter(Mandatory=$false)]
        [switch] $Passthru,

        [Parameter(Mandatory=$false)]
        [switch] $FindOne
    )

    begin { $ReturnArray = @() }
    process {
        try
        {
            # Get the Callback URL. This URL will be used to POST request to IB-Grid in order to be able to GET results from the internal API:
            $FirstRequestParameters = @{
                Uri = $Uri + $BaseURL
                WebSession = $WebSession
                Method = 'Get'
                Headers = @{
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                }
            }

            $WebRequest = Invoke-WebRequest @FirstRequestParameters -SkipCertificateCheck
            $CallbackURL = [string](([regex]::Match($WebRequest.Content,"callbackUrl \: \'\.\.\/\.\.\/(?<callback_url>[a-zA-Z0-9\-_\/]+)\'\,")).groups["callback_url"].value)
            Write-Verbose "[Get-IBDomainList] CallbackURL: $CallbackURL"
            if ($CallbackURL -eq $null) { throw }

            # After we have the Callback URL, we POST to that a request than indicate we want to query the DNS zones in the next call to the internal API. POST will return the URL to query the internal API through GET requests, and we will call that URL as $APICallURL:
            $SecondRequestParameters = @{
                Uri = $Uri + $CallbackURL + "?random=" + ((Get-Random -Minimum 0.0 -Maximum 0.99) -replace ',','.')
                WebSession = $WebSession
                Method = 'Post'
                ContentType = 'application/x-www-form-urlencoded'
                Body = @{
                    wicketAction='renderWicketComponent'
                    context='IBExt.context.DataManagement.DNS.Zones'
                    networkViewId='dns.network_view$0'
                    hierInfo='[{"objectId":"dns.network_view$0","objectType":"NetworkView","objectName":""},{"objectId":"dns.view$._default","objectType":"View","objectName":"default","scheduled":false,"isEditable":false}]'
                }
                Headers = @{
                    "Wicket-Ajax"="true"
                    "Wicket-Ajax-BaseURL"=$BaseURL
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                }
            }
            
            $WebRequest = Invoke-WebRequest @SecondRequestParameters -SkipCertificateCheck

            $APICallURL = [string](([regex]::Match($WebRequest.Content,"\), proxy: new Ext.data.HttpProxy\(new Ext.data.Connection\({ url: \'\.\.\\/\.\.\\/(?<dns_networkview_url>[a-zA-Z0-9\-_\/\.\\]+)'\,")).groups["dns_networkview_url"].value) -Replace "\\",""
            Write-Verbose "[Get-IBDomainList] APICallURL: $APICallURL"
            if ($null -eq $APICallURL) { throw }

            # Query internal API through GET requests. It will return a JSON object:
            $Page = 'first'
            do {
                $ThirdRequestParameters = @{
                    Uri = $Uri + $APICallURL + "?page=$Page&sort=Ext2one&dir=DESC&jsonCommand=grid-data-load"
                    WebSession = $WebSession
                    Method = 'Get'
                    Headers = @{
                        "Wicket-Ajax"="true"
                        "Wicket-Ajax-BaseURL"=$BaseURL
                        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                    }
                }
                $JsonResponse = Invoke-RestMethod @ThirdRequestParameters -SkipCertificateCheck
                
                if ($Page -eq 'first') { $Page = 'next' }

                # Iterate through root object and return results to the pipeline:
                foreach ($object in $JsonResponse.root) {

                    $DomainFQDN = ($object.fqdn -replace '&nbsp;',' ' -replace '&amp;','&' -replace '<[^>]*>','').Trim()
                    $DomainType = ($object.ibapObject -replace '&nbsp;',' ' -replace '&amp;','&' -replace '<[^>]*>','').Trim()
                    $DomainZoneType = ($object.zone_type -replace '&nbsp;',' ' -replace '&amp;','&' -replace '<[^>]*>','').Trim()
                    $DomainComment = ($object.comment -replace '&nbsp;',' ' -replace '&amp;','&' -replace '<[^>]*>','').Trim()
                    $DomainPrimaryServer = ($object.grid_primary_server_names -replace '&nbsp;',' ' -replace '&amp;','&' -replace '<[^>]*>','').Trim()
                    $DomainCustomPropertyObjectName = ($object.customProperties.objInfo.objectName -replace '&nbsp;',' ' -replace '&amp;','&' -replace '<[^>]*>','').Trim()

                    $ReturnObject = $null
                    $ReturnObject = New-Object System.Object
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainType -Value $DomainType
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainCustomPropertyObjectName -Value $DomainCustomPropertyObjectName
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainFQDN -Value $DomainFQDN
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainZoneType -Value $DomainZoneType
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainComment -Value $DomainComment
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainPrimaryServer -Value $DomainPrimaryServer
                    
                    # Check for Passthru, if specified, send WebSession & related required session values to the pipeline
                    if ($Passthru) {
                        $ReturnObject | Add-Member -Type NoteProperty -Name Uri -Value $Uri
                        $ReturnObject | Add-Member -Type NoteProperty -Name BaseURL -Value $BaseURL
                        $ReturnObject | Add-Member -Type NoteProperty -Name CallbackURL -Value $CallbackURL
                        $ReturnObject | Add-Member -Type NoteProperty -Name WebSession -Value $WebSession
                    }

                    $ReturnArray += $ReturnObject
                }
            }
            until ((-not $JsonResponse.has_next) -or ($FindOne)) # Query the internal API while there is a next page of results available or user specified -FindOne switch parameter.
        
        }
        catch
        {
            throw "Can't obtain data."
        }
    }
    end { $ReturnArray }
}
