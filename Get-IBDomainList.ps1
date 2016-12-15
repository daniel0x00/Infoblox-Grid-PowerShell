Function Get-IBDomainList {
    <#
    .SYNOPSIS
        Get a list of all domains in DNS records of Infoblox.
    
    .DESCRIPTION
        

    .EXAMPLE

        

    #>   
    [CmdletBinding()]
    [OutputType([psobject])]
    param(    
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Uri,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $BaseURL,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession
    )


    try
    {
        $WebRequest = Invoke-WebRequest -Uri ($Uri + $BaseURL) -WebSession $WebSession -Method Get 
        $CallbackURL = [string](([regex]::Match($WebRequest.Content,"callbackUrl \: \'\.\.\/\.\.\/(?<callback_url>[a-zA-Z0-9\-_\/]+)\'\,")).groups["callback_url"].value)
        if ($CallbackURL -eq $null) { throw }

        $RandomNumber = Get-Random -Minimum 0.0 -Maximum 0.99; $RandomNumber = $RandomNumber -replace ',','.'
        $DNSNetworkViewPostParameters = @{wicketAction='renderWicketComponent'; context='IBExt.context.DataManagement.DNS.Zones'; networkViewId='dns.network_view$0'; hierInfo='[{"objectId":"dns.network_view$0","objectType":"NetworkView","objectName":""},{"objectId":"dns.view$._default","objectType":"View","objectName":"default","scheduled":false,"isEditable":false}]'}
        $WebRequest = Invoke-WebRequest -Uri ($Uri + $CallbackURL + "?random=$RandomNumber") -WebSession $WebSession -Method Post -Body $DNSNetworkViewPostParameters -Headers @{"Wicket-Ajax"="true"; "Wicket-Ajax-BaseURL"=$BaseURL; "Client-Date"="2016-12-14 15:55:38"; "Accept"="*/*"; "Accept-Encoding"="gzip, deflate, br"; "Origin"="https://144.199.214.139"; "Referer"="https://144.199.214.139/ui/JAJ_IQcrFuGI6y0cPUW-BA/JAJf2/IQc5a"} -ContentType application/x-www-form-urlencoded
        $DNSNetworkViewURL = [string](([regex]::Match($WebRequest.Content,"\(\{ url\: \'\.\.\\/\.\.\\/(?<dns_networkview_url>[a-zA-Z0-9\-_\/\.\\]+PlD97)'\,")).groups["dns_networkview_url"].value) -Replace "\\",""
        if ($DNSNetworkViewURL -eq $null) { throw }

        
        $JsonResponse = Invoke-RestMethod -Uri ($Uri + $DNSNetworkViewURL + "?_dc=1481726133272&page=first&sort=Ext2one&dir=DESC&jsonCommand=grid-data-load") -WebSession $WebSession -Method Get -Headers @{"Wicket-Ajax"="true"; "Wicket-Ajax-BaseURL"=$BaseURL} 
        
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
            $ReturnObject
        }
    }
    catch
    {
        throw "Can't obtain data. $_"
    }
}