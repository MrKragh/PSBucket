#requires -Modules AADInternals
[CmdletBinding()]
Param(
    [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
    $Mail,
    $Name
)
process {
    Write-Verbose "Testing $Mail"
    $domain = $Mail -split "@" | Select-Object -Last 1
    $recon = & $PSScriptRoot\Invoke-MailDomainRecon.ps1 -domain $domain
    $SMTPServer = "{0}.mail.protection.outlook.com" -f ($recon.TenantName -split "\." | Select-Object -first 1)

    $timestamp = Get-Date

    $EmailTo = $Mail
    if($Name){
        Write-Verbose "Using $Name as sender name"
        $EmailFrom = New-Object System.Net.Mail.MailAddress($Mail, $Name)
    } else {
        Write-Verbose "Using $Mail as sender name"
        $EmailFrom = $Mail
    }
    
    $Subject = "Exchange Online Protection Spoofing Test - $($timestamp.ToUniversalTime().ToString("o"))"
    $Body = "This is an email sent thrugh Exchange Online Protection as spoofed. Did it work? If so, you should see this email in your inbox." 

    $SMTPMessage = New-Object System.Net.Mail.MailMessage($EmailFrom,$EmailTo,$Subject,$Body)
    $SMTPMessage.Headers.Add("X-Spoof-Test", "https://blog.cyberunfiltered.com/posts/a-tale-about-email-spoofing/")
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 25) 
    $SMTPClient.EnableSsl = $true 
    
    try {
        $SMTPClient.Send($SMTPMessage)
        $result = "Mail was queued successfully"
    }
    catch {
        $result = $_.Exception.Message
    }

    [PSCustomObject]@{
        result = $result
        param  = @{
            From       = $EmailFrom
            To         = $EmailTo
            Subject    = $Subject
            Body       = $Body
            SmtpServer = $SMTPServer
        }
        recon  = $recon
    }
}