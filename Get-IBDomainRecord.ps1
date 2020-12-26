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
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Uri,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $BaseURL,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $CallbackURL,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainType,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainDate,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainDisabled,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainRequester,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainRequest,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $DomainComment,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("A","AAAA","CNAME","DNAME","DNSKEY","DS","HOST","LBDN","MX","NAPTR","NS","NSEC","NSEC3","NSEC3PARAM","PTR","RRSIG","SRV","TXT","SOA")]
        [string[]] $Filter=$null
    )

    begin { }
    process {
        try
        {
            # POST to Callback URL to specify to the internal API that we want to query the resource records for the specified domain. POST will return the URL to query the internal API through GET requests, and we will call that URL as $APICallURL:
            $FirstRequestParameters = @{
                Uri = $Uri + $CallbackURL + "?random=" + ((Get-Random -Minimum 0.0 -Maximum 0.99) -replace ',','.')
                WebSession = $WebSession
                Method = 'Post'
                ContentType = 'application/x-www-form-urlencoded'
                Body = $APICallURLPostParameters = @{
                    wicketAction='renderWicketComponent'
                    context='IBExt.context.DataManagement.DNS.Zones'
                    type='record'
                    hierInfo="[{`"objectId`":`"dns.network_view`$0`",`"objectType`":`"NetworkView`",`"objectName`":`"`"},{`"objectId`":`"dns.view$._default`",`"objectType`":`"View`",`"objectName`":`"default`",`"scheduled`":false,`"isEditable`":false},{`"isEditable`":true,`"cloudUsage`":`"`",`"scheduled`":false,`"objectName`":`"$DomainName`",`"dnsViewName`":`"default`",`"objectTitleType`":`"`",`"objectId`":`"$DomainId`",`"objectType`":`"$DomainType`"}]"
                }
                Headers = @{
                    "Wicket-Ajax"="true"
                    "Wicket-Ajax-BaseURL"=$BaseURL
                    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                }
            }
            
            $WebRequest = Invoke-WebRequest @FirstRequestParameters -SkipCertificateCheck
            
            $APICallURL = [string](([regex]::Match($WebRequest.Content,"\), proxy: new Ext.data.HttpProxy\(new Ext.data.Connection\({ url: \'\.\.\\/\.\.\\/(?<dns_networkview_url>[a-zA-Z0-9\-_\/\.\\]+)'\,")).groups["dns_networkview_url"].value) -Replace "\\",""
            Write-Verbose "[Get-IBDomainRecord] API Call URL: $APICallURL"
            if ($APICallURL -eq $null) { throw }

            # Query internal API through GET requests. It will return a JSON object:
            $Page = 'first'
            do {
                $SecondRequestParameters = @{
                    Uri = $Uri + $APICallURL + "?page=$Page&sort=view_type&dir=ASC&jsonCommand=grid-data-load"
                    WebSession = $WebSession
                    Method = 'Get'
                    Headers = @{
                        "Wicket-Ajax"="true"
                        "Wicket-Ajax-BaseURL"=$BaseURL
                        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
                    }
                }
                
                Write-Verbose "[Get-IBDomainRecord] Visiting page: $PageURL"
                $JsonResponse = Invoke-RestMethod @SecondRequestParameters -SkipCertificateCheck
                if ($Page -eq 'first') { $Page = 'next' }

                # Iterate through root object and return results to the pipeline:
                foreach ($object in $JsonResponse.root) {

                    # Grab data from json response:
                    $RecordType = [string](([regex]::Match($object.customProperties.objInfo.objectName,"(?<record_type>[A-Za-z0-9]+) [A-Za-z0-9]+ ")).groups["record_type"].value).ToUpper() -replace '&nbsp;',' ' -replace '&amp;','&'

                    # Check if there is a filter for a record type:
                    #if ((-not($null -ne $Filter)) -and (-not($RecordType -in $Filter))) { continue }
                    
                    $RecordName = [string](([regex]::Match($object.dns_name,"<span[^>]*>(?<dns_name>.*?)</span>")).groups["dns_name"].value) -replace '&nbsp;',' ' -replace '&amp;','&'
                    $RecordValue = [string](([regex]::Match($object.value,"<span[^>]*>(?<value>.*?)</span>")).groups["value"].value) -replace '&nbsp;',' ' -replace '&amp;','&'
                    # Ext1one: record Implementer
                    $RecordImplementer = [string](([regex]::Match($object.Ext1one,"<span[^>]*>(?<implementer>.*?)</span>")).groups["implementer"].value) -replace '&nbsp;',' ' -replace '&amp;','&'
                    # Ext3one: record Requester
                    $RecordRequester = [string](([regex]::Match($object.Ext3one,"<span[^>]*>(?<requester>.*?)</span>")).groups["requester"].value) -replace '&nbsp;',' ' -replace '&amp;','&'
                    # creation_timestamp: record Creation
                    $RecordCreationTimestamp = [string](([regex]::Match($object.creation_timestamp,"<span[^>]*>(?<creation_timestamp>.*?)</span>")).groups["creation_timestamp"].value) -replace '&nbsp;',' ' -replace '&amp;','&'
                    # Ext0one: record Request
                    $RecordRequest = [string](([regex]::Match($object.Ext0one,"<span[^>]*>(?<request>.*?)</span>")).groups["request"].value) -replace '&nbsp;',' ' -replace '&amp;','&'
                    # Ext2one: record Data
                    $RecordDate = [string](([regex]::Match($object.Ext2one,"<span[^>]*>(?<date>.*?)</span>")).groups["date"].value) -replace '&nbsp;',' ' -replace '&amp;','&'

                    $ReturnObject = $null
                    $ReturnObject = New-Object System.Object
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainId -Value $DomainId
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainName -Value $DomainName
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainType -Value $DomainType
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainDisabled -Value $DomainDisabled
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainRequester -Value $DomainRequester
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainRequest -Value $DomainRequest
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainComment -Value $DomainComment
                    $ReturnObject | Add-Member -Type NoteProperty -Name DomainDate -Value $DomainDate

                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordName -Value $RecordName
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordType -Value $RecordType
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordValue -Value $RecordValue
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordImplementer -Value $RecordImplementer
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordRequester -Value $RecordRequester
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordRequest -Value $RecordRequest
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordDate -Value $RecordDate
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordCreationTimestamp -Value $RecordCreationTimestamp

                    $ReturnObject
                     
                }
            }
            until (-not $JsonResponse.has_next) # Query the internal API while there is a next page of results available.
        
        }
        catch
        {
            throw "Can't obtain data."
        }
    }
    end { }
}