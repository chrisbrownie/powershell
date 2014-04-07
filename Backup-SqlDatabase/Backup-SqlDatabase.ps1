#############################################################################
# Backup-SqlDatabase.ps1
# Backup a specified database using SMO
# 
# Pre-Requisites: SQL SMO
#
# Usage syntax:
# Backup-Database.ps1 server database
#
# Usage Examples:
#
# Backup-Database.ps1 sqlsvr01 myData
#
# Last Modified: 06/01/2011
#
# Version: 
# 1.00 (Current)
#
# Version History:
# 1.00 (Current)
# - original script
#
# DISCLAIMER
# ==========
# THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
# RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#############################################################################

Param(
	[string]$database
  , [string]$server)


#load assemblies
#note need to load SqlServer.SmoExtended to use SMO backup in SQL Server 2008
#otherwise may get this error
#Cannot find type [Microsoft.SqlServer.Management.Smo.Backup]: make sure
#the assembly containing this type is loaded.

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
#Need SmoExtended for smo.backup
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null

#create a new server object
$server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $server
$backupDirectory = $server.Settings.BackupDirectory

#display default backup directory
"Default Backup Directory: " + $backupDirectory

$db = $server.Databases[$database]
$dbName = $db.Name

$timestamp = Get-Date -format yyyyMMddHHmmss
$smoBackup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup")

#BackupActionType specifies the type of backup.
#Options are Database, Files, Log
#This belongs in Microsoft.SqlServer.SmoExtended assembly

$smoBackup.Action = "Database"
$smoBackup.BackupSetDescription = "Full Backup of " + $dbName
$smoBackup.BackupSetName = $dbName + " Backup"
$smoBackup.Database = $dbName
$smoBackup.MediaDescription = "Disk"
$smoBackup.Devices.AddDevice($backupDirectory + "\" + $dbName + "_" + $timestamp + ".bak", "File")
$smoBackup.SqlBackup($server)

#let's confirm, let's list list all backup files
$directory = Get-ChildItem $backupDirectory

#list only files that end in .bak, assuming this is your convention for all backup files
$backupFilesList = $directory | where {$_.extension -eq ".bak"}
$backupFilesList | Format-Table Name, LastWriteTime

