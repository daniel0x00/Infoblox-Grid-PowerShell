# Infoblox Grid PowerShell

This code allows to connect to Infoblox GRID and pull a list of domains and/or pull records associated with a domain. 

Note this code doesn't require an API account. It requires instead a regular 'portal'/GUI account.

## Usage

1. Use PowerShell 7. 
2. Install the module by invoking it or dot-sourcing it:
```
iex((iwr https://raw.githubusercontent.com/daniel0x00/Infoblox-Grid-PowerShell/master/New-IBSession.ps1 -UseBasicParsing).content)
iex((iwr https://raw.githubusercontent.com/daniel0x00/Infoblox-Grid-PowerShell/master/Get-IBDomainList.ps1 -UseBasicParsing).content)
iex((iwr https://raw.githubusercontent.com/daniel0x00/Infoblox-Grid-PowerShell/master/Get-IBDomainRecord.ps1 -UseBasicParsing).content)
```
3. Run the cmdlet as shown below.

### Pull a sample of domains & their records

Note: remove the `-FindOne` switch to pull all domains together with all records on each domain.

```
PS C:\> $c = Get-Credential
PS C:\> $domains = New-IBSession -Uri https://grid.infobloxserver.com/ui/ -Credential $c | Get-IBDomainList -FindOne -Passthru | Get-IBDomainRecord -Verbose
PS C:\> $domains | select -first 1 | fl

DomainId                : dns.zone$._default.domain.com
DomainName              : domain.com
DomainType              : AuthZone
DomainDisabled          : No
DomainRequester         : requester@domain.com
DomainRequest           : <free-text>
DomainComment           : <free-text>
DomainDate              : 2020-03-30
RecordName              : www
RecordType              : CNAME
RecordValue             : subdomain.domain.com.edgekey.net
RecordImplementer       : <username>
RecordRequester         : <username>
RecordRequest           : <free-text>
RecordDate              : 2019-03-27
RecordCreationTimestamp : 2019-03-27 09:57:53 UTC
```
