Function Get-IBDomainRecord {
    <#
    .SYNOPSIS
        Get a list of all DNS records of the specified domain. 

    .DESCRIPTION
        Query the DNS records of a specific domain. Requires a valid input obtained with Get-IBDomainList function. 

    .EXAMPLE
        New-IBSession -Uri https://grid.infobloxserver.com/ui/ (get-credential) | Get-IBDomainList -FindOne -Passthru | Get-IBDomainRecord

    .EXAMPLE
        New-IBSession -Uri https://grid.infobloxserver.com/ui/ (get-credential) | Get-IBDomainList -FindOne -Passthru | select -First 10 | Get-IBDomainRecord -Filter "A" | ft

    .PARAMETER Uri
        The base Uri for the Infoblox.
        
        String. Mandatory. Pipeline enabled.

    .PARAMETER BaseURL
        The base URL obtained in the Infoblox login process (New-IBSession takes care of it).

        String. Mandatory. Pipeline enabled.

    .PARAMETER CallbackURL
        If specified, pass to the pipeline the WebSession & BaseURL, required to query each domain separately.

        String. Mandatory.

    .PARAMETER WebSession
        The web session created in the Infoblox login process (New-IBSession takes care of it).

        WebRequestSession. Mandatory. Pipeline enabled.
    
    .PARAMETER ObjectName
        Object to query. Obtained by Get-IBDomainList function. 

        String. Mandatory.

    .PARAMETER ObjectType
        Object to query. Obtained by Get-IBDomainList function. 

        String. Mandatory.

    .PARAMETER ObjectId
        Object to query. Obtained by Get-IBDomainList function. 

        String. Mandatory.

    .PARAMETER Filter
        Filter to only request specific record type. If not specified, will return all possible record types.
        Possible values to filter are: A, AAAA, CNAME, DNAME, DNSKEY, DS, HOST, LBDN, MX, NAPTR, NS, NSEC, NSEC3, NSEC3PARAM, PTR, RRSIG, SRV, TXT, SOA

        String. Not mandatory.

    #>   
    [CmdletBinding()]
    [OutputType([psobject])]
    param(    
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $BaseURL,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $CallbackURL,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainType,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainCustomPropertyObjectName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainFQDN,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainZoneType,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainComment,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string] $DomainPrimaryServer,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("A", "AAAA", "CNAME", "DNAME", "DNSKEY", "DS", "HOST", "LBDN", "MX", "NAPTR", "NS", "NSEC", "NSEC3", "NSEC3PARAM", "PTR", "RRSIG", "SRV", "TXT", "SOA")]
        [string[]] $Filter = $null
    )

    begin { }
    process {
        # POST to Callback URL to specify to the internal API that we want to query the resource records for the specified domain. POST will return the URL to query the internal API through GET requests, and we will call that URL as $APICallURL:
        $FirstRequestParameters = @{
            Uri         = $Uri + $CallbackURL + "?random=" + ((Get-Random -Minimum 0.0 -Maximum 0.99) -replace ',', '.')
            WebSession  = $WebSession
            Method      = 'Post'
            ContentType = 'application/x-www-form-urlencoded'
            Body        = @{
                wicketAction = 'renderWicketComponent'
                context      = 'IBExt.context.DataManagement.DNS.Zones'
                type         = 'record'
                hierInfo     = "[{`"objectId`":`"dns.network_view`$0`",`"objectType`":`"NetworkView`",`"objectName`":`"`"},{`"objectId`":`"dns.view$._default`",`"objectType`":`"View`",`"objectName`":`"default`",`"scheduled`":false,`"isEditable`":false},{`"isEditable`":true,`"cloudUsage`":`"`",`"scheduled`":false,`"objectName`":`"$DomainFQDN`",`"dnsViewName`":`"default`",`"objectTitleType`":`"`",`"objectId`":`"$DomainId`",`"objectType`":`"$DomainType`"}]"
            }
            Headers     = @{
                "Wicket-Ajax"         = "true"
                "Wicket-Ajax-BaseURL" = $BaseURL
                "User-Agent"          = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
            }
        }
        
        $WebRequest = Invoke-WebRequest @FirstRequestParameters -SkipCertificateCheck
        
        $APICallURL = [string](([regex]::Match($WebRequest.Content, "\), proxy: new Ext.data.HttpProxy\(new Ext.data.Connection\({ url: \'\.\.\\/\.\.\\/(?<dns_networkview_url>[a-zA-Z0-9\-_\/\.\\]+)'\,")).groups["dns_networkview_url"].value) -Replace "\\", ""
        Write-Verbose "[Get-IBDomainRecord] API Call URL: $APICallURL"
        if ($APICallURL -eq $null) { throw }

        # Query internal API through GET requests. It will return a JSON object:
        $Page = 'first'
        do {
            $SecondRequestParameters = @{
                Uri        = $Uri + $APICallURL + "?page=$Page&sort=view_type&dir=ASC&jsonCommand=grid-data-load"
                WebSession = $WebSession
                Method     = 'Get'
                Headers    = @{
                    "Wicket-Ajax"         = "true"
                    "Wicket-Ajax-BaseURL" = $BaseURL
                    "User-Agent"          = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                }
            }
            
            Write-Verbose "[Get-IBDomainRecord] Visiting page: $PageURL"
            $JsonResponse = Invoke-RestMethod @SecondRequestParameters -SkipCertificateCheck
            if ($Page -eq 'first') { $Page = 'next' }

            # Return empty object if there is nothing:
            if ($JsonResponse.root.count -eq 0) {
                $ReturnObject = $null
                $ReturnObject = New-Object System.Object

                $ReturnObject | Add-Member -Type NoteProperty -Name DomainId -Value $DomainId
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainType -Value $DomainType
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainCustomPropertyObjectName -Value $DomainCustomPropertyObjectName
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainFQDN -Value $DomainFQDN
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainZoneType -Value $DomainZoneType
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainComment -Value $DomainComment
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainPrimaryServer -Value $DomainPrimaryServer

                $ReturnObject | Add-Member -Type NoteProperty -Name RecordViewType -Value ([string]::Empty)
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordCustomPropertyObjectName -Value ([string]::Empty)
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordName -Value ([string]::Empty)
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordValue -Value ([string]::Empty)
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordComment -Value 'NoRecordValuesReceived'
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordCreator -Value ([string]::Empty)
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordCreationTimestamp -Value ([string]::Empty)

                $ReturnObject
            }

            # Iterate through root object and return results to the pipeline:
            foreach ($object in $JsonResponse.root) {

                $RecordName = ($object.name -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()
                $RecordValue = ($object.value -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()
                $RecordCreator = ($object.creator -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()
                $RecordCreationTimestamp = ($object.creation_timestamp -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()
                $RecordViewType = ($object.view_type -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()
                $RecordComment = ($object.comment -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()
                $RecordCustomPropertyObjectName = ($object.customProperties.objInfo.objectName -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '<[^>]*>', '').Trim()

                $ReturnObject = $null
                $ReturnObject = New-Object System.Object

                $ReturnObject | Add-Member -Type NoteProperty -Name DomainId -Value $DomainId
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainType -Value $DomainType
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainCustomPropertyObjectName -Value $DomainCustomPropertyObjectName
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainFQDN -Value $DomainFQDN
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainZoneType -Value $DomainZoneType
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainComment -Value $DomainComment
                $ReturnObject | Add-Member -Type NoteProperty -Name DomainPrimaryServer -Value $DomainPrimaryServer

                $ReturnObject | Add-Member -Type NoteProperty -Name RecordViewType -Value $RecordViewType
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordCustomPropertyObjectName -Value $RecordCustomPropertyObjectName
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordName -Value $RecordName
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordValue -Value $RecordValue
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordComment -Value $RecordComment
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordCreator -Value $RecordCreator
                $ReturnObject | Add-Member -Type NoteProperty -Name RecordCreationTimestamp -Value $RecordCreationTimestamp

                $ReturnObject
                 
            }
        }
        until (-not $JsonResponse.has_next) # Query the internal API while there is a next page of results available.
    }
    end { }
}
