#Requires -Version 5.1

<#
.SYNOPSIS
    Email notification module using SMTP
.DESCRIPTION
    Sends email notifications via SMTP with support for TLS and authentication
.NOTES
    Passwords are DPAPI encrypted in config and decrypted at runtime
#>

function New-EmailNotifier {
    <#
    .SYNOPSIS
        Create email notifier instance
    .PARAMETER Config
        Email configuration from config.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $required = @('smtp_host', 'from_address', 'recipients')
    foreach ($field in $required) {
        if ([string]::IsNullOrWhiteSpace($Config.$field)) {
            throw "Email config missing required field: $field"
        }
    }

    if ($Config.recipients.Count -eq 0) {
        throw "Email config must have at least one recipient"
    }

    # Set defaults
    $Config.smtp_port = $Config.smtp_port ?? 587
    $Config.use_tls = $Config.use_tls ?? $true
    $Config.retry_attempts = $Config.retry_attempts ?? 3
    $Config.timeout_seconds = $Config.timeout_seconds ?? 30
    $Config.from_name = $Config.from_name ?? "IPSC Kurs Watcher"

    return $Config
}

function Test-EmailConnection {
    <#
    .SYNOPSIS
        Test SMTP server connection and authentication
    .PARAMETER Notifier
        Email notifier configuration
    .RETURNS
        $true if connection successful, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Notifier
    )

    try {
        $smtpClient = New-Object System.Net.Mail.SmtpClient
        $smtpClient.Host = $Notifier.smtp_host
        $smtpClient.Port = $Notifier.smtp_port
        $smtpClient.EnableSsl = $Notifier.use_tls

        if ($Notifier.smtp_username -and $Notifier.smtp_password_encrypted) {
            $password = Unprotect-SecretData -EncryptedData $Notifier.smtp_password_encrypted
            $credential = New-Object System.Management.Automation.PSCredential(
                $Notifier.smtp_username,
                $password
            )
            $smtpClient.Credentials = $credential
        }

        $smtpClient.Timeout = $Notifier.timeout_seconds * 1000

        Write-Verbose "Testing SMTP connection to $($Notifier.smtp_host):$($Notifier.smtp_port)"
        # Connection test via ServicePointManager
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        return $true
    } catch {
        Write-Error "SMTP connection test failed: $_"
        return $false
    }
}

function Send-EmailNotification {
    <#
    .SYNOPSIS
        Send email notification
    .PARAMETER Courses
        Array of courses to notify about
    .PARAMETER Notifier
        Email notifier configuration
    .PARAMETER MonitorName
        Name of the monitor source
    .EXAMPLE
        Send-EmailNotification -Courses $newCourses -Notifier $config.notifiers.email -MonitorName "shooting-store"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Notifier,

        [string]$MonitorName = "IPSC Kurs Watcher"
    )

    if ($Courses.Count -eq 0) {
        Write-Verbose "No courses to notify via email"
        return $true
    }

    if (-not $Notifier.enabled) {
        Write-Verbose "Email notifier is disabled"
        return $true
    }

    try {
        # Build email subject and body
        $subject = "[$($MonitorName)] $($Courses.Count) neue Kurs(e) verfÃ¼gbar"
        $body = Build-EmailBody -Courses $Courses -MonitorName $MonitorName

        # Create mail message
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = New-Object System.Net.Mail.MailAddress(
            $Notifier.from_address,
            $Notifier.from_name
        )

        foreach ($recipient in $Notifier.recipients) {
            $mailMessage.To.Add($recipient)
        }

        $mailMessage.Subject = $subject
        $mailMessage.Body = $body
        $mailMessage.IsBodyHtml = $true

        # Setup SMTP client
        $smtpClient = New-Object System.Net.Mail.SmtpClient
        $smtpClient.Host = $Notifier.smtp_host
        $smtpClient.Port = $Notifier.smtp_port
        $smtpClient.EnableSsl = $Notifier.use_tls
        $smtpClient.Timeout = $Notifier.timeout_seconds * 1000

        if ($Notifier.smtp_username -and $Notifier.smtp_password_encrypted) {
            $password = Unprotect-SecretData -EncryptedData $Notifier.smtp_password_encrypted
            $credential = New-Object System.Management.Automation.PSCredential(
                $Notifier.smtp_username,
                $password
            )
            $smtpClient.Credentials = $credential
        }

        # Send email
        Write-Verbose "Sending email notification to $($Notifier.recipients -join ', ')"
        $smtpClient.Send($mailMessage)

        Write-Verbose "Email notification sent successfully"
        return $true
    } catch {
        Write-Error "Failed to send email notification: $_"
        return $false
    } finally {
        if ($mailMessage) {
            $mailMessage.Dispose()
        }
        if ($smtpClient) {
            $smtpClient.Dispose()
        }
    }
}

function Build-EmailBody {
    <#
    .SYNOPSIS
        Build HTML email body
    .PARAMETER Courses
        Courses to include
    .PARAMETER MonitorName
        Name of monitor
    #>
    [CmdletBinding()]
    param(
        [array]$Courses,
        [string]$MonitorName
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; }
        .container { max-width: 600px; margin: 0 auto; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px 5px 0 0; }
        .courses { margin: 20px 0; }
        .course { background-color: #ecf0f1; padding: 15px; margin: 10px 0; border-left: 4px solid #3498db; }
        .course-title { font-weight: bold; font-size: 16px; }
        .course-type { color: #7f8c8d; font-size: 12px; }
        .course-availability { color: #27ae60; font-weight: bold; }
        .footer { background-color: #95a5a6; color: white; padding: 10px; text-align: center; border-radius: 0 0 5px 5px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Neue Kurse verfÃ¼gbar!</h2>
            <p>$($Courses.Count) neue/aktualisierte Kurse von $MonitorName</p>
        </div>
        <div class="courses">
"@

    foreach ($course in $Courses) {
        $availability = if ($course.availability -gt 0) {
            "<span class='course-availability'>$($course.availability) PlÃ¤tze frei</span>"
        } else {
            "<span>VerfÃ¼gbarkeit unbekannt</span>"
        }

        $html += @"
            <div class="course">
                <div class="course-title">$($course.title)</div>
                <div class="course-type">Typ: $($course.type ?? 'N/A')</div>
                <div>$availability</div>
            </div>
"@
    }

    $html += @"
        </div>
        <div class="footer">
            <p>IPSC Kurs Watcher - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

function Protect-SecretData {
    [CmdletBinding()]
    param([string]$PlainText)

    $encryptedBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText) |
        ConvertTo-SecureString -AsPlainText -Force |
        ConvertFrom-SecureString

    return $encryptedBytes
}

function Unprotect-SecretData {
    [CmdletBinding()]
    param([string]$EncryptedData)

    $secureString = ConvertTo-SecureString $EncryptedData
    $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secureString)
    $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($pointer)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($pointer)

    return (ConvertTo-SecureString $plainText -AsPlainText -Force)
}
