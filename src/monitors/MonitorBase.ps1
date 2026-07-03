#Requires -Version 5.1

<#
.SYNOPSIS
    Abstract base class for all monitor implementations
.DESCRIPTION
    Provides common functionality for course monitoring from different sources
.NOTES
    All monitor providers should extend this class and implement Get-Courses
#>

class MonitorBase {
    [string]$Id
    [string]$Name
    [string]$Provider
    [string]$Url
    [int]$TimeoutSeconds
    [int]$RetryAttempts
    [hashtable]$ParserConfig

    MonitorBase([hashtable]$Config) {
        $this.Id = $Config.id
        $this.Name = $Config.name
        $this.Provider = $Config.provider
        $this.Url = $Config.url
        $this.TimeoutSeconds = $Config.request_timeout_seconds ?? 30
        $this.RetryAttempts = $Config.retry_attempts ?? 3
        $this.ParserConfig = $Config.parser_config ?? @{}
    }

    [array]Get-Courses() {
        throw "Get-Courses() must be implemented by derived class"
    }

    [string]Test-Connection() {
        try {
            $params = @{
                Uri = $this.Url
                Method = 'Get'
                TimeoutSec = $this.TimeoutSeconds
                ErrorAction = 'Stop'
            }

            $response = Invoke-WebRequest @params
            return "OK"
        } catch {
            return "FAILED: $_"
        }
    }

    [object]Invoke-WithRetry([scriptblock]$ScriptBlock) {
        $attempt = 0
        $lastError = $null

        while ($attempt -lt $this.RetryAttempts) {
            try {
                return & $ScriptBlock
            } catch {
                $lastError = $_
                $attempt++

                if ($attempt -lt $this.RetryAttempts) {
                    $backoffSeconds = [Math]::Pow(2, $attempt - 1)
                    Write-Verbose "Retry attempt $attempt/$($this.RetryAttempts) in ${backoffSeconds}s"
                    Start-Sleep -Seconds $backoffSeconds
                }
            }
        }

        throw "Failed after $($this.RetryAttempts) retries: $lastError"
    }

    [object]Fetch-WebContent() {
        $scriptBlock = {
            $params = @{
                Uri = $this.Url
                Method = 'Get'
                TimeoutSec = $this.TimeoutSeconds
                UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                ErrorAction = 'Stop'
            }

            $response = Invoke-WebRequest @params
            return $response.Content
        }

        return $this.Invoke-WithRetry($scriptBlock)
    }

    [void]ValidateConfig() {
        if ([string]::IsNullOrWhiteSpace($this.Url)) {
            throw "Monitor URL is required"
        }

        if ($this.TimeoutSeconds -lt 5 -or $this.TimeoutSeconds -gt 120) {
            throw "Timeout must be between 5 and 120 seconds"
        }

        if ($this.RetryAttempts -lt 0 -or $this.RetryAttempts -gt 5) {
            throw "Retry attempts must be between 0 and 5"
        }
    }
}

Export-ModuleMember -Variable MonitorBase
