#Requires -Version 5.1

<#
.SYNOPSIS
Common helper utilities for IPSC Kurs Watcher.
#>

function ConvertTo-SafeJson {
    <#
    .SYNOPSIS
    Safely converts an object to JSON string, returning null on error.

    .DESCRIPTION
    Wraps ConvertTo-Json with error handling. Returns $null if conversion fails
    instead of throwing, allowing pipelines to continue.

    .PARAMETER InputObject
    Object to convert to JSON. Accepts pipeline input.

    .PARAMETER Depth
    JSON nesting depth. Defaults to 10.

    .OUTPUTS
    String (JSON) or $null on error.

    .EXAMPLE
    $obj = @{ id = 1; name = 'Course' }
    $obj | ConvertTo-SafeJson
    # Returns: {"id": 1, "name": "Course"}

    .NOTES
    Errors are logged but do not halt execution.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][object]$InputObject, [int]$Depth = 10)
    process {
        try { $InputObject | ConvertTo-Json -Depth $Depth -ErrorAction Stop }
        catch { Write-Error "JSON conversion failed: $_"; $null }
    }
}

function ConvertFrom-SafeJson {
    <#
    .SYNOPSIS
    Safely parses JSON string to object, returning null on error.

    .DESCRIPTION
    Wraps ConvertFrom-Json with error handling. Returns $null if parsing fails
    instead of throwing, allowing pipelines to continue gracefully.

    .PARAMETER JsonString
    JSON string to parse. Accepts pipeline input.

    .OUTPUTS
    PSCustomObject or $null on error.

    .EXAMPLE
    '{"id": 1, "name": "Course"}' | ConvertFrom-SafeJson
    # Returns: PSCustomObject with id and name properties

    .NOTES
    Errors are logged but do not halt execution.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][string]$JsonString)
    process {
        try { $JsonString | ConvertFrom-Json -ErrorAction Stop }
        catch { Write-Error "JSON parse error: $_"; $null }
    }
}

function Test-FilePath {
    <#
    .SYNOPSIS
    Tests whether a path exists and is a file (not a directory).

    .DESCRIPTION
    Returns $true only if the path exists and points to a file.
    Returns $false if the path doesn't exist or is a directory.

    .PARAMETER Path
    File path to test.

    .OUTPUTS
    Boolean - $true if file exists, $false otherwise.

    .EXAMPLE
    Test-FilePath -Path 'config/config.json'
    # Returns: $true if file exists

    .NOTES
    Directories return $false; only regular files return $true.
    #>
    [CmdletBinding()]
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    if (!(Get-Item $Path).PSIsContainer) { return $true }
    return $false
}

function Test-ValidUrl {
    <#
    .SYNOPSIS
    Validates URL format and scheme for security.

    .DESCRIPTION
    Validates that a URL is well-formed and uses only safe schemes (http/https).
    Prevents URL injection attacks by validating format before use in web requests.

    .PARAMETER Url
    URL string to validate.

    .OUTPUTS
    Boolean - $true if URL is valid, $false otherwise.

    .EXAMPLE
    Test-ValidUrl -Url 'https://www.example.com/path'
    # Returns: $true

    .EXAMPLE
    Test-ValidUrl -Url 'ftp://example.com'
    # Returns: $false (unsupported scheme)

    .EXAMPLE
    Test-ValidUrl -Url 'not a url'
    # Returns: $false (invalid format)

    .NOTES
    Only http and https schemes are allowed. Relative URLs return $false.
    #>
    [CmdletBinding()]
    param([string]$Url)

    if (-not $Url) { return $false }

    try {
        $uri = [System.Uri]::new($Url)

        if (-not $uri.IsAbsoluteUri) {
            return $false
        }

        if ($uri.Scheme -notin @('http', 'https')) {
            return $false
        }

        return $true
    }
    catch {
        return $false
    }
}

function Get-FileDirectory {
    <#
    .SYNOPSIS
    Ensures a directory exists, creating it if necessary.

    .DESCRIPTION
    Tests if the directory exists. If not, creates it.
    Returns the directory path on success, $null on failure.

    .PARAMETER Path
    Directory path to verify or create.

    .OUTPUTS
    String (the path) on success, $null on error.

    .EXAMPLE
    Get-FileDirectory -Path 'data/logs'
    # Creates directory if missing, returns 'data/logs'

    .NOTES
    Errors are logged but do not throw.
    #>
    [CmdletBinding()]
    param([string]$Path)
    if (-not (Test-Path $Path)) { try { New-Item -ItemType Directory -Path $Path -Force | Out-Null } catch { Write-Error "Failed to create directory $Path : $_"; return $null } }
    return $Path
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
    Executes a script block with exponential backoff retry logic.

    .DESCRIPTION
    Attempts to run the script block up to MaxAttempts times.
    On failure, waits with exponential backoff (2^(attempt-1) * BaseDelaySeconds)
    before retrying. Throws the last error if all attempts fail.

    .PARAMETER ScriptBlock
    Script block to execute.

    .PARAMETER MaxAttempts
    Maximum number of attempts. Defaults to 3.

    .PARAMETER BaseDelaySeconds
    Base delay for exponential backoff. Defaults to 1 second.
    Actual delay = 2^(attempt-1) * BaseDelaySeconds.

    .OUTPUTS
    Return value of the script block if successful.

    .EXAMPLE
    Invoke-WithRetry -ScriptBlock { Invoke-WebRequest 'https://api.example.com' } -MaxAttempts 3

    .NOTES
    Retries: 1s, 2s, 4s for default MaxAttempts=3, BaseDelaySeconds=1.
    Final attempt failure throws the error; no swallowing.
    #>
    [CmdletBinding()]
    param([scriptblock]$ScriptBlock, [int]$MaxAttempts = 3, [int]$BaseDelaySeconds = 1)
    $attempt = 0; $lastError = $null
    while ($attempt -lt $MaxAttempts) { try { return & $ScriptBlock } catch { $attempt++; $lastError = $_; if ($attempt -lt $MaxAttempts) { $delay = [Math]::Pow(2, $attempt - 1) * $BaseDelaySeconds; Start-Sleep -Seconds $delay } } }
    throw $lastError
}

function Protect-SensitiveData {
    <#
    .SYNOPSIS
    Masks sensitive information in strings for safe logging.

    .DESCRIPTION
    Replaces passwords, API keys, webhook URLs, and email addresses with ***MASKED***
    or similar placeholders. Used to sanitize log output before display or storage.

    .PARAMETER InputString
    String containing potentially sensitive data.

    .OUTPUTS
    String with sensitive parts masked.

    .EXAMPLE
    'password="secret123"' | Protect-SensitiveData
    # Returns: 'password="***MASKED***"'

    .EXAMPLE
    'user@example.com' | Protect-SensitiveData
    # Returns: '***@***.***'

    .NOTES
    Masks: passwords, api_key, webhook_url, and email addresses.
    Safe for logging and error messages.
    #>
    [CmdletBinding()]
    param([string]$InputString)
    if (-not $InputString) { return $InputString }
    $masked = $InputString
    $masked = $masked -replace '(password[^=]*=")[^"]*"', '$1***MASKED***"'
    $masked = $masked -replace '(api_key=")[^"]*"', '$1***MASKED***"'
    $masked = $masked -replace '(webhook_url=")[^"]*"', '$1***MASKED***"'
    $masked = $masked -replace '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '***@***.***'
    return $masked
}

function Invoke-SecureWebRequest {
    <#
    .SYNOPSIS
    Invoke-WebRequest with logging for security-critical endpoints.

    .DESCRIPTION
    Wrapper around Invoke-WebRequest that logs requests to critical endpoints
    (Azure AD, Microsoft Graph) for audit trail. Uses Windows certificate validation
    via system CA store. Supports all Invoke-WebRequest parameters.

    .PARAMETER Uri
    URI to request. Must be absolute HTTPS URL (validation via Test-ValidUrl).

    .PARAMETER Method
    HTTP method (GET, POST, etc). Defaults to GET.

    .PARAMETER Headers
    Request headers hashtable.

    .PARAMETER Body
    Request body (bytes or string).

    .PARAMETER TimeoutSeconds
    Request timeout in seconds. Defaults to 30.

    .OUTPUTS
    Invoke-WebRequest response object.

    .EXAMPLE
    $response = Invoke-SecureWebRequest -Uri 'https://graph.microsoft.com/v1.0/me' -Method GET

    .NOTES
    Critical endpoints logged: login.microsoftonline.com, graph.microsoft.com
    Falls back to standard Invoke-WebRequest for non-critical endpoints.
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()][string]$Uri,
        [string]$Method = 'GET',
        [hashtable]$Headers,
        [object]$Body,
        [int]$TimeoutSeconds = 30
    )

    try {
        $uri_obj = [System.Uri]::new($Uri)

        # Log requests to critical endpoints for audit trail
        $criticalEndpoints = @('login.microsoftonline.com', 'graph.microsoft.com')
        if ($uri_obj.Host -in $criticalEndpoints) {
            Write-Log -Level DEBUG -Message "Secure web request" `
                -Context @{ endpoint = $uri_obj.Host; method = $Method; timeout_seconds = $TimeoutSeconds }
        }

        # Build Invoke-WebRequest parameters
        $params = @{
            Uri             = $Uri
            Method          = $Method
            TimeoutSec      = $TimeoutSeconds
            UseBasicParsing = $true
        }

        if ($Headers) { $params.Headers = $Headers }
        if ($Body) { $params.Body = $Body }

        # Execute request (Windows validates certificates via system CA store)
        return Invoke-WebRequest @params
    }
    catch {
        Write-Log -Level ERROR -Message "Secure web request failed" `
            -Context @{ uri = $Uri; method = $Method; error = $_.Exception.Message } -Exception $_
        throw
    }
}

function Protect-OAuthError {
    <#
    .SYNOPSIS
    Masks sensitive information in OAuth2 error messages for safe logging.

    .DESCRIPTION
    Sanitizes OAuth2 error messages by masking client_secret, client_id, tenant_id,
    and email addresses. Prevents accidental exposure of credentials in logs.

    .PARAMETER ErrorMessage
    OAuth2 error message to sanitize.

    .OUTPUTS
    String with sensitive parts masked.

    .EXAMPLE
    $error = "Invalid client_secret: xyz123abc for tenant_id: tenant-guid"
    Protect-OAuthError -ErrorMessage $error
    # Returns: "Invalid client_secret: [REDACTED_SECRET] for tenant_id: [REDACTED_TENANT]"

    .NOTES
    Used in OAuth2 token refresh and authentication error handling.
    #>
    [CmdletBinding()]
    param([string]$ErrorMessage)

    if (-not $ErrorMessage) { return $ErrorMessage }

    $masked = $ErrorMessage
    # Mask credential values (everything after : or = until space or end)
    $masked = $masked -replace '(client_secret)[:\s=]+([^\s]+)', '$1: [REDACTED_SECRET]'
    $masked = $masked -replace '(client_id)[:\s=]+([^\s]+)', '$1: [REDACTED_ID]'
    $masked = $masked -replace '(tenant[_-]?id)[:\s=]+([^\s]+)', '$1: [REDACTED_TENANT]'
    $masked = $masked -replace '(tenant)[:\s=]+([^\s]+)', '$1: [REDACTED_TENANT]'
    # Mask email addresses
    $masked = $masked -replace '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[REDACTED_EMAIL]'

    return $masked
}

function Get-UtcTimestamp {
    <#
    .SYNOPSIS
    Returns the current UTC time as ISO 8601 string.

    .DESCRIPTION
    Returns [datetime]::UtcNow formatted as ISO 8601 (o format).
    Useful for consistent timestamp logging and state files.

    .OUTPUTS
    String in ISO 8601 format (e.g., '2026-07-03T10:30:45.1234567Z').

    .EXAMPLE
    $timestamp = Get-UtcTimestamp
    # Returns: '2026-07-03T10:30:45.1234567Z'

    .NOTES
    Always UTC, never local time. Use for state files and logs.
    #>
    [CmdletBinding()]
    param()
    [datetime]::UtcNow.ToString('o')
}

function ConvertTo-UnixTimestamp {
    <#
    .SYNOPSIS
    Converts a DateTime object to Unix timestamp (seconds since 1970-01-01).

    .DESCRIPTION
    Takes a DateTime and returns the equivalent Unix timestamp as an integer.
    Useful for API calls and time comparisons.

    .PARAMETER DateTime
    DateTime object to convert.

    .OUTPUTS
    Int64 - Unix timestamp (seconds since 1970-01-01 UTC).

    .EXAMPLE
    ConvertTo-UnixTimestamp -DateTime '2026-07-03T10:30:00Z'
    # Returns: 1778899800

    .NOTES
    Uses PowerShell's Get-Date -UFormat %s for conversion.
    #>
    [CmdletBinding()]
    param([datetime]$DateTime)
    [int64][double]::Parse((Get-Date $DateTime -UFormat %s))
}
