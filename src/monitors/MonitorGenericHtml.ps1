#Requires -Version 5.1

<#
.SYNOPSIS
    Generic HTML monitor template for custom websites
.DESCRIPTION
    Template for monitoring any HTML-based course listing using CSS selectors
.NOTES
    Provider: generic-html
    Copy this file and customize selectors for new websites
#>

. "$PSScriptRoot/MonitorBase.ps1"

class MonitorGenericHtml : MonitorBase {
    MonitorGenericHtml([hashtable]$Config) : base($Config) {
        if ($this.Provider -ne "generic-html") {
            throw "Provider must be 'generic-html'"
        }
    }

    [array]Get-Courses() {
        $this.ValidateConfig()

        Write-Verbose "Fetching courses from $($this.Url) (generic-html)"

        try {
            $htmlContent = $this.Fetch-WebContent()
            $courses = $this.Parse-Html($htmlContent)

            Write-Verbose "Found $($courses.Count) courses"
            return $courses
        } catch {
            throw "Failed to get courses: $_"
        }
    }

    hidden [array]Parse-Html([string]$HtmlContent) {
        $courses = @()

        if ([string]::IsNullOrWhiteSpace($HtmlContent)) {
            return $courses
        }

        try {
            # Load HTML
            $doc = New-Object System.Xml.XmlDocument
            $doc.PreserveWhitespace = $true

            $htmlClean = $this.Clean-Html($HtmlContent)
            $doc.LoadXml($htmlClean)

            # Get course selector from config
            $courseSelector = $this.ParserConfig.selector_course
            if ([string]::IsNullOrWhiteSpace($courseSelector)) {
                throw "parser_config.selector_course is required"
            }

            $courseElements = $doc.SelectNodes($courseSelector)

            foreach ($element in $courseElements) {
                try {
                    $course = $this.Extract-CourseData($element)
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

    hidden [hashtable]Extract-CourseData([System.Xml.XmlElement]$Element) {
        $course = @{
            id = ""
            title = ""
            type = ""
            availability = 0
            url = ""
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
                # Try to extract number
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

    hidden [string]Clean-Html([string]$Html) {
        $cleaned = $Html

        # Remove script and style tags
        $cleaned = $cleaned -replace '<script[^>]*>.*?</script>', ''
        $cleaned = $cleaned -replace '<style[^>]*>.*?</style>', ''

        # Decode HTML entities
        $cleaned = [System.Net.WebUtility]::HtmlDecode($cleaned)

        return $cleaned
    }
}

Export-ModuleMember -Variable MonitorGenericHtml
