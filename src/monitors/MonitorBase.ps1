#Requires -Version 5.1

class MonitorBase {
    [string]$Id
    [string]$Provider
    [bool]$Enabled
    [string]$Url
    [string]$BaseUrl
    [int]$TimeoutSeconds
    [int]$RetryAttempts

    MonitorBase([object]$Config) {
        $this.Id = $Config.id
        $this.Provider = $Config.provider
        $this.Enabled = $Config.enabled
        $this.Url = $Config.url
        $this.BaseUrl = $Config.base_url
        $this.TimeoutSeconds = if ($Config.timeout_seconds) { $Config.timeout_seconds } else { 30 }
        $this.RetryAttempts = if ($Config.retry_attempts) { $Config.retry_attempts } else { 3 }
    }

    [object[]] Invoke() { throw [System.NotImplementedException]::new("Subclass must implement Invoke()") }
    
    [void] Validate() {
        if (-not $this.Url) { throw "Monitor URL is required" }
        if (-not $this.BaseUrl) { throw "Monitor base URL is required" }
    }
}
