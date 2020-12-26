# Infoblox Grid PowerShell

This code allows to connect to Infoblox GRID and pull a list of domains and/or pull records associated with a domain. 

Note this code doesn't require an API account. It requires instead a regular 'portal'/GUI account.

## Usage

1. Use PowerShell 7. 
2. Install the module by invoking it or dot-sourcing it:
```
iex((iwr <placeholder> -UseBasicParsing).content)
iex((iwr <placeholder> -UseBasicParsing).content)
iex((iwr <placeholder> -UseBasicParsing).content)
```
3. Run the cmdlet as shown below.

### Pull a sample of domains & their records

Note: remove the `-FindOne` switch to pull all domains together with all records on each domain.

```
PS C:\> $c = Get-Credential
PS C:\> $domains = New-IBSession -Uri https://grid.infobloxserver.com/ui/ -Credential $c | Get-IBDomainList -FindOne -Passthru | Get-IBDomainRecord -Verbose
PS C:\> $domains | select -first 1 | format-list
```
