################################################################################
#
# Delete Old Files:
#	Deletes all of the files in a specified directory older than a specified
#   age recursively.  Then any empty folders in the specified directory are 
#   removed as well.
#
# Online Resources:
#   https://searchwindowsserver.techtarget.com/tutorial/Learn-how-to-create-a-scheduled-task-with-PowerShell
#   https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasktrigger?view=win10-ps
#
# Coded By:
#	Chris Brinkley
#
# Version:
#	1.0.0 	- 12/09/2020 -	Initial Build.
#
################################################################################
$WatchFolder = "C:\inetpub\logs\LogFiles"
$DaysToKeep = 10

################################################################################
# DO NOT EDIT BELOW
################################################################################
$instLoc = split-path -parent $MyInvocation.MyCommand.Definition

$logingDate = Get-Date -Format "MMddyyyy"
$Logpath = $instLoc + "\logs\deletedlog_" + $logingDate + ".log"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { 
# MUST BE RUNNING AS ADMINISTRATOR TO CHECK/ADD SCHEDUELED TASKS!
    try { 
        Get-ScheduledTask -TaskName 'IIS Log Clean Up' -ErrorAction Stop 
    } catch {
        Write-Host "Task does not exist."

        $argString = '-NonInteractive -NoLogo -NoProfile -File "' + $instLoc + '\DeleteFiles.ps1"'
        $taskAction = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument $argString
        $taskTrigger = New-ScheduledTaskTrigger -Daily -At 3am
        $taskSettings = New-ScheduledTaskSettingsSet
        $taskDescription = "Create by Chris Brinkley.  Ths script is located at " + $instLoc
        $taskDescription += "\DeleteFiles.ps1 and cleans up the IIS Log Folder"

        Register-ScheduledTask -TaskName 'IIS Log Clean Up' -Description $taskDescription -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User 'SYSTEM'
        Write-Host "Task created."
        Return;
    }
} else {
    Write-Host "You must be running this script as Administrator to check for and/or create the Schedueled Task." -BackgroundColor Red -ForegroundColor White
    Return;
}

# Delete files older than $DaysToKeep
Get-ChildItem $WatchFolder -Recurse -Force -ea 0 |
    Where-Object {!$_.PsIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-1 * $DaysToKeep)} |
    ForEach-Object {
        $_ | Remove-Item -Force
        $_.FullName | Out-File $Logpath -Append
    }

# Delete empty folders and subfolders
Get-ChildItem $WatchFolder -Recurse -Force -ea 0 |
    Where-Object {$_.PsIsContainer -eq $True} |
    Where-Object {$_.getfiles().count -eq 0} |
    ForEach-Object {
        $_ | Remove-Item  -Force
        $_.FullName | Out-File $Logpath -Append
    }