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
            $WebRequest = Invoke-WebRequest -Uri ($Uri + $BaseURL) -WebSession $WebSession -Method Get 
            $CallbackURL = [string](([regex]::Match($WebRequest.Content,"callbackUrl \: \'\.\.\/\.\.\/(?<callback_url>[a-zA-Z0-9\-_\/]+)\'\,")).groups["callback_url"].value)
            if ($CallbackURL -eq $null) { throw }

            # After we have the Callback URL, we POST to that a request than indicate we want to query the DNS zones in the next call to the internal API. POST will return the URL to query the internal API through GET requests, and we will call that URL as $APICallURL:
            $RandomNumber = Get-Random -Minimum 0.0 -Maximum 0.99; $RandomNumber = $RandomNumber -replace ',','.'
            $APICallURLPostParameters = @{wicketAction='renderWicketComponent'; context='IBExt.context.DataManagement.DNS.Zones'; networkViewId='dns.network_view$0'; hierInfo='[{"objectId":"dns.network_view$0","objectType":"NetworkView","objectName":""},{"objectId":"dns.view$._default","objectType":"View","objectName":"default","scheduled":false,"isEditable":false}]'}
            $WebRequest = Invoke-WebRequest -Uri ($Uri + $CallbackURL + "?random=$RandomNumber") -WebSession $WebSession -Method Post -Body $APICallURLPostParameters -Headers @{"Wicket-Ajax"="true"; "Wicket-Ajax-BaseURL"=$BaseURL} -ContentType application/x-www-form-urlencoded
            $APICallURL = [string](([regex]::Match($WebRequest.Content,"\(\{ url\: \'\.\.\\/\.\.\\/(?<dns_networkview_url>[a-zA-Z0-9\-_\/\.\\]+PlD97)'\,")).groups["dns_networkview_url"].value) -Replace "\\",""
            if ($APICallURL -eq $null) { throw }

            # Query internal API through GET requests. It will return a JSON object:
            $Page = 'first'
            do {
                $JsonResponse = Invoke-RestMethod -Uri ($Uri + $APICallURL + "?page=$Page&sort=Ext2one&dir=DESC&jsonCommand=grid-data-load") -WebSession $WebSession -Method Get -Headers @{"Wicket-Ajax"="true"; "Wicket-Ajax-BaseURL"=$BaseURL} 
                if ($Page -eq 'first') { $Page = 'next' }

                # Iterate through root object and return results to the pipeline:
                foreach ($object in $JsonResponse.root) {

                    # Ext2one json-key represents the date the domain was addded:
                    $ObjectDate = [string](([regex]::Match($object.Ext2one,"<span[^>]*>(?<date>.*?)</span>")).groups["date"].value)

                    $ReturnObject = $null
                    $ReturnObject = New-Object System.Object
                    $ReturnObject | Add-Member -Type NoteProperty -Name ObjectName -Value $object.customProperties.objInfo.objectName
                    $ReturnObject | Add-Member -Type NoteProperty -Name ObjectType -Value $object.ibapObject
                    $ReturnObject | Add-Member -Type NoteProperty -Name ObjectId -Value $object.customProperties.objInfo.objectId
                    $ReturnObject | Add-Member -Type NoteProperty -Name ObjectDate -Value $ObjectDate

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