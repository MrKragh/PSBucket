#requires -Modules AADInternals
[CmdletBinding()]
Param(
    [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
    $domain,
    [switch]$Text
)
process {
    Write-Verbose "Processing $domain"
    $result = [PSCustomObject]@{
        domain         = $domain
        MX             = Resolve-DnsName -Name $domain -Type MX -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq "MX" }
        GatewayIsMS    = $null
        SPF            = Resolve-DnsName -Name $domain -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -match "v=spf1" }
        DMARC          = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -match "v=DMARC1" }
        DKIM           = Resolve-DnsName -Name "_domainkey.$domain" -Type TXT -ErrorAction SilentlyContinue
        SecurityTXT    = $null
        SecurityTXTUrl = $null
        TenantID       = Get-AADIntTenantID -domain $domain
        TenantName     = $null
        domains        = Get-AADIntTenantDomains -Domain $domain
    }
    $result.GatewayIsMS = if ($result.MX.NameExchange -match ".*\.mail\.protection\.outlook\.com$") { $true }else { $false }

    foreach ($azdomain in $result.domains) {
        if ([string]::IsNullOrEmpty($result.TenantName) -and $azdomain.ToLower() -match "^[^.]*\.onmicrosoft.com$") {
            $result.TenantName = $azdomain
            Write-Verbose "Found praimary $azdomain"
        }
    }
    Write-Verbose "Looking for security.txt"
    ForEach ($Uri in @(
            "https://$Domain/.well-known/security.txt",
            "https://$Domain/security.txt",
            "http://$Domain/.well-known/security.txt",
            "http://$Domain/security.txt")
    ) {
        try {
            $WebRequest = Invoke-WebRequest -Method "Get" -UseBasicParsing -MaximumRedirection 1 -Uri $Uri -ErrorAction SilentlyContinue
        }
        catch {
            $WebRequest = $null
        }
        If ($null -ne $WebRequest -and $WebRequest.StatusCode -eq 200) {
            $result.SecurityTXTUrl = $Uri
            $result.SecurityTXT = $WebRequest.Content.Trim()
            break
        }
    }

    $result | Select-object `
    @{N = "Domain"; E = { $_.Domain } }, `
    @{N = "MX"; E = { $mx = ($_.MX | ForEach-Object { "{0} {1}" -f $_.Preference, $_.NameExchange }); if ($text) { $mx -join "`r`n" } else { $mx } } }, `
    @{N = "GatewayIsMs"; E = { $_.GatewayIsMs } }, `
    @{N = "SPF"; E = { $_.SPF.Strings } }, `
    @{N = "DMARC"; E = { $_.DMARC.Strings } }, `
    @{N = "DKIM"; E = { [bool]$_.DKIM } }, `
    @{N = "SecurityTXTUrl"; E = { $_.SecurityTXTUrl } }, `
    @{N = "SecurityTXTData"; E = { $_.SecurityTXT } }, `
    @{N = "TenantID"; E = { $_.TenantID } }, `
    @{N = "TenantName"; E = { $_.TenantName } }, `
    @{N = "Domains"; E = { $domains = $_.domains; if ($text) { $domains -join "`r`n" } else { $domains } } `

    }
}