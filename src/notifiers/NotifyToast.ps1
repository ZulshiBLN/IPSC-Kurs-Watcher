#Requires -Version 5.1

function Send-ToastNotification { param([object[]]$Courses, [object]$Config)
    if (-not $Config.enabled) { return }
    if (-not $Courses -or $Courses.Count -eq 0) { return }
    Write-Log -Level INFO -Message "Toast notification stub" -Context @{ courses = $Courses.Count; status = 'STUB_v0.1_not_shown' }
}

