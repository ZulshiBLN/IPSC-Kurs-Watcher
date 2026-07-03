#Requires -Version 5.1

<#
.SYNOPSIS
Monitors shooting-store.ch course catalog, fetching and parsing course data.

.DESCRIPTION
Inherits from MonitorBase. Implements web scraping for shooting-store.ch,
extracting course details (name, date, time, price, availability) from HTML.
Handles individual course detail page requests for availability information.

.NOTES
Provider: shooting-store (hardcoded)
Parses HTML structure: artikel_box_content_wrapper, content artikel_box_name, artikel_preis
Fetches availability from detail pages: data-update lagerinfo_anzeige
Retries on failure up to RetryAttempts with TimeoutSeconds per request.
#>
class CourseMonitor : MonitorBase {
    CourseMonitor([object]$Config) : base($Config) { $this.Validate() }

    [object[]] Invoke() {
        $startTime = Get-Date
        Write-Log -Level INFO -Message "Monitor starting" -Context @{ id = $this.Id; provider = $this.Provider }
        
        try {
            $courses = $this._FetchAndParseCourses()
            if ($courses.Count -eq 0) {
                Write-Log -Level WARN -Message "No courses found" -Context @{ url = $this.Url }
            } else {
                Write-Log -Level INFO -Message "Courses fetched" -Context @{ count = $courses.Count; duration_ms = ((Get-Date) - $startTime).TotalMilliseconds }
            }
            return $courses
        }
        catch {
            Write-Log -Level ERROR -Message "Monitor execution failed" -Context @{ id = $this.Id } -Exception $_
            throw
        }
    }

    hidden [object[]] _FetchAndParseCourses() {
        $response = Invoke-WebRequest -Uri $this.Url -TimeoutSec $this.TimeoutSeconds -UseBasicParsing
        $blocks = $response.Content -split '<div class="artikel_box_content_wrapper">'
        $courses = @()
        
        for ($i = 1; $i -lt $blocks.Count; $i++) {
            $block = $blocks[$i]
            if ($block -match '<a href="([^"]+)"[^>]*class="content artikel_box_name"[^>]*>([^<]+)</a>') {
                $detailHref = $Matches[1]
                $fullText = $Matches[2].Trim()
                
                $price = ""
                if ($block -match '<span class="artikel_preis\s*"[^>]*>\s*([^<]+)</span>') { $price = $Matches[1].Trim() }
                
                if ($fullText -match '^(.*?)\s+(\d{2}\.\d{2}\.\d{4})\s+(\d{2}:\d{2}-\d{2}:\d{2})$') {
                    $courseName = $Matches[1].Trim()
                    $courseDate = $Matches[2]
                    $courseTime = $Matches[3]
                    
                    $availability = 0
                    if ($detailHref) {
                        $detailUrl = "$($this.BaseUrl)$detailHref"
                        if (-not (Test-ValidUrl -Url $detailUrl)) {
                            Write-Log -Level WARN -Message "Invalid detail URL detected, skipping" -Context @{ url = $detailUrl }
                            continue
                        }
                        try {
                            $detailResponse = Invoke-WebRequest -Uri $detailUrl -TimeoutSec $this.TimeoutSeconds -UseBasicParsing
                            if ($detailResponse.Content -match 'data-update="lagerinfo_anzeige\.lagerinfo">(\d+)\s+Artikel') {
                                $availability = [int]$Matches[1]
                            }
                        }
                        catch {
                            Write-Log -Level WARN -Message "Failed to fetch availability details" -Context @{ url = $detailUrl } -Exception $_
                        }
                    }
                    
                    $courses += @{
                        id = "$courseName|$courseDate|$courseTime"
                        name = $courseName; date = $courseDate; time = $courseTime
                        price = $price; availability = $availability
                        url = "$($this.BaseUrl)$detailHref"
                        monitor_id = $this.Id
                        fetched_at = [datetime]::UtcNow.ToString('o')
                    }
                }
            }
        }
        return $courses
    }
}
