#Requires -Version 5.1

<#
.SYNOPSIS
    Monitor implementation for shooting-store.ch
.DESCRIPTION
    Scrapes shooting-store.ch course listing using CSS selectors
.NOTES
    Provider: shooting-store
#>

. "$PSScriptRoot/MonitorBase.ps1"

class MonitorShootingStore : MonitorBase {
    MonitorShootingStore([hashtable]$Config) : base($Config) {
        if ($this.Provider -ne "shooting-store") {
            throw "Provider must be 'shooting-store'"
        }
    }

    [array]GetCourses() {
        $this.ValidateConfig()

        Write-Verbose "Fetching courses from $($this.Url)"

        try {
            $htmlContent = $this.FetchWebContent()
            $courses = $this.ParseHtml($htmlContent)

            Write-Verbose "Found $($courses.Count) courses"
            return $courses
        } catch {
            throw "Failed to get courses: $_"
        }
    }

    hidden [array]ParseHtml([string]$HtmlContent) {
        $courses = @()

        if ([string]::IsNullOrWhiteSpace($HtmlContent)) {
            return $courses
        }

        try {
            # Load HTML for parsing
            $doc = New-Object System.Xml.XmlDocument
            $doc.PreserveWhitespace = $true

            # Clean HTML for XML parsing
            $htmlClean = $this.CleanHtml($HtmlContent)

            $doc.LoadXml($htmlClean)

            # Use XPath to find course elements
            $courseSelector = $this.ParserConfig.selector_course
            if ([string]::IsNullOrWhiteSpace($courseSelector)) {
                $courseSelector = "//div[@class='course-item']"
            }

            $courseElements = $doc.SelectNodes($courseSelector)

            foreach ($element in $courseElements) {
                try {
                    $course = $this.ExtractCourseData($element)
                    if ($course) {
                        $courses += $course
                    }
                } catch {
                    Write-Verbose "Failed to extract course data: $_"
                    continue
                }
            }

            return $courses
        } catch {
            throw "HTML parsing failed: $_"
        }
    }

    hidden [hashtable]ExtractCourseData([System.Xml.XmlElement]$Element) {
        $course = @{
            id = ""
            title = ""
            type = ""
            availability = 0
            url = ""
            date = ""
        }

        # Extract title
        $titleSelector = $this.ParserConfig.selector_title
        if ($titleSelector) {
            $titleElement = $Element.SelectSingleNode($titleSelector)
            if ($titleElement) {
                $course.title = $titleElement.InnerText.Trim()
            }
        }

        # Extract type
        $typeSelector = $this.ParserConfig.selector_type
        if ($typeSelector) {
            $typeElement = $Element.SelectSingleNode($typeSelector)
            if ($typeElement) {
                $course.type = $typeElement.InnerText.Trim()
            }
        }

        # Extract availability
        $availabilitySelector = $this.ParserConfig.selector_availability
        if ($availabilitySelector) {
            $availElement = $Element.SelectSingleNode($availabilitySelector)
            if ($availElement) {
                $availText = $availElement.InnerText.Trim()
                # Try to extract number (e.g., "5 PlÃ¤tze" -> 5)
                if ($availText -match '(\d+)') {
                    $course.availability = [int]$matches[1]
                }
            }
        }

        # Generate ID from title + type
        if ($course.title) {
            $hashInput = "$($this.Id)|$($course.title)|$($course.type)"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput)
            $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
            $hashBytes = $hashAlgorithm.ComputeHash($bytes)
            $course.id = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').Substring(0, 16)
        }

        if ([string]::IsNullOrWhiteSpace($course.title)) {
            return $null
        }

        return $course
    }

    hidden [string]CleanHtml([string]$Html) {
        # Basic HTML cleanup for XML parsing
        $cleaned = $Html

        # Remove script and style tags
        $cleaned = $cleaned -replace '<script[^>]*>.*?</script>', ''
        $cleaned = $cleaned -replace '<style[^>]*>.*?</style>', ''

        # Decode HTML entities
        $cleaned = [System.Net.WebUtility]::HtmlDecode($cleaned)

        return $cleaned
    }
}

# Export-ModuleMember -Variable MonitorShootingStore
