#Requires -Version 5.1

<#
.SYNOPSIS
    Service for managing WPF dialog boxes
.DESCRIPTION
    Provides methods for showing message boxes and file dialogs
#>

class DialogService {
    DialogService() {
        Add-Type -AssemblyName PresentationFramework
    }

    [System.Windows.MessageBoxResult] ShowMessage(
        [string]$title,
        [string]$message,
        [System.Windows.MessageBoxButton]$button = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$icon = [System.Windows.MessageBoxImage]::Information
    ) {
        return [System.Windows.MessageBox]::Show($message, $title, $button, $icon)
    }

    [System.Windows.MessageBoxResult] ShowConfirmation([string]$message, [string]$title = "Confirm") {
        return $this.ShowMessage($title, $message, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    }

    [System.Windows.MessageBoxResult] ShowError([string]$message, [string]$title = "Error") {
        return $this.ShowMessage($title, $message, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }

    [System.Windows.MessageBoxResult] ShowWarning([string]$message, [string]$title = "Warning") {
        return $this.ShowMessage($title, $message, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }

    [System.Windows.MessageBoxResult] ShowInfo([string]$message, [string]$title = "Information") {
        return $this.ShowMessage($title, $message, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }

    [string] ShowOpenFileDialog([string]$filter = "All files (*.*)|*.*", [string]$initialDirectory = "") {
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Filter = $filter
        if ($initialDirectory) {
            $dialog.InitialDirectory = $initialDirectory
        }

        $result = $dialog.ShowDialog()
        if ($result -eq $true) {
            return $dialog.FileName
        }
        return $null
    }

    [string] ShowSaveFileDialog([string]$filter = "All files (*.*)|*.*", [string]$initialDirectory = "") {
        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = $filter
        if ($initialDirectory) {
            $dialog.InitialDirectory = $initialDirectory
        }

        $result = $dialog.ShowDialog()
        if ($result -eq $true) {
            return $dialog.FileName
        }
        return $null
    }

    [string] ShowFolderBrowserDialog([string]$description = "Select a folder") {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $description

        $result = $dialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }
        return $null
    }
}

function New-DialogService {
    return [DialogService]::new()
}
