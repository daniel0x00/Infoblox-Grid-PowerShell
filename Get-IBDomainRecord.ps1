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
        [string] $ObjectName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $ObjectType,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $ObjectId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("A","AAAA","CNAME","DNAME","DNSKEY","DS","HOST","LBDN","MX","NAPTR","NS","NSEC","NSEC3","NSEC3PARAM","PTR","RRSIG","SRV","TXT","SOA")]
        [string] $Filter=$false
    )

    begin { }
    process {
        try
        {
            # POST to Callback URL to specify to the internal API that we want to query the resource records for the specified domain. POST will return the URL to query the internal API through GET requests, and we will call that URL as $APICallURL:
            $RandomNumber = Get-Random -Minimum 0.0 -Maximum 0.99; $RandomNumber = $RandomNumber -replace ',','.'
            $APICallURLPostParameters = @{wicketAction='renderWicketComponent'; context='IBExt.context.DataManagement.DNS.Zones'; type='record'; hierInfo="[{`"objectId`":`"dns.network_view`$0`",`"objectType`":`"NetworkView`",`"objectName`":`"`"},{`"objectId`":`"dns.view$._default`",`"objectType`":`"View`",`"objectName`":`"default`",`"scheduled`":false,`"isEditable`":false},{`"isEditable`":true,`"cloudUsage`":`"`",`"scheduled`":false,`"objectName`":`"$ObjectName`",`"dnsViewName`":`"default`",`"objectTitleType`":`"`",`"objectId`":`"$ObjectId`",`"objectType`":`"$ObjectType`"}]"}
            $WebRequest = Invoke-WebRequest -Uri ($Uri + $CallbackURL + "?random=$RandomNumber") -WebSession $WebSession -Method Post -Body $APICallURLPostParameters -Headers @{"Wicket-Ajax"="true"; "Wicket-Ajax-BaseURL"=$BaseURL} -ContentType application/x-www-form-urlencoded
            $APICallURL = [string](([regex]::Match($WebRequest.Content,"\(\{ url\: \'\.\.\\/\.\.\\/(?<dns_networkview_url>[a-zA-Z0-9\-_\/\.\\]+PlD97)'\,")).groups["dns_networkview_url"].value) -Replace "\\",""
            if ($APICallURL -eq $null) { throw }

            # Query internal API through GET requests. It will return a JSON object:
            $Page = 'first'
            do {
                $JsonResponse = Invoke-RestMethod -Uri ($Uri + $APICallURL + "?page=$Page&sort=view_type&dir=ASC&jsonCommand=grid-data-load") -WebSession $WebSession -Method Get -Headers @{"Wicket-Ajax"="true"; "Wicket-Ajax-BaseURL"=$BaseURL} 
                if ($Page -eq 'first') { $Page = 'next' }

                # Iterate through root object and return results to the pipeline:
                foreach ($object in $JsonResponse.root) {

                    # Grab data from json response:
                    $RecordType = [string](([regex]::Match($object.customProperties.objInfo.objectName,"(?<record_type>[A-Za-z0-9]+) [A-Za-z0-9]+ ")).groups["record_type"].value).ToUpper()

                    # Check if there is a filter for a record type:
                    if ((-not($Filter -eq $false)) -and (-not($RecordType -like $Filter.ToUpper()))) { continue }
                    
                    $RecordName = [string](([regex]::Match($object.dns_name,"<span[^>]*>(?<dns_name>.*?)</span>")).groups["dns_name"].value)
                    $RecordValue = [string](([regex]::Match($object.value,"<span[^>]*>(?<value>.*?)</span>")).groups["value"].value)

                    $ReturnObject = $null
                    $ReturnObject = New-Object System.Object
                    $ReturnObject | Add-Member -Type NoteProperty -Name ObjectName -Value $ObjectName
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordType -Value $RecordType
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordName -Value $RecordName
                    $ReturnObject | Add-Member -Type NoteProperty -Name RecordValue -Value $RecordValue

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