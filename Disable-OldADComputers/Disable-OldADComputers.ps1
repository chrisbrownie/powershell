#############################################################################
# Disable-OldAdComputers.ps1
# Disables computer accounts in the domain that have not logged on in x days
# 
# Pre-Requisites: Microsoft's AD Powershell Extensions
#
# Usage syntax:
# Disable-OldAdComputers.ps1 numberofdays
#
# Usage Examples:
#
# Disable-OldAdComputers.ps1 60
# 	- Disables computers that have not logged on in 60 days
#
# Last Modified: 13/10/2010
#
# Version: 
# 1.00 (Current)
#
# Version History:
# 1.00 (Current)
# - original script
#
# Created by 
# Chris Brown
# http://www.flamingkeys.com/
# chris@chrisbrown.id.au
# 
# DISCLAIMER
# ==========
# THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
# RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#############################################################################

# ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?
# How many days before the account is considered "old"?
Param([int]$oldAccountAge = 90)
#
# ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?

# First check if the ActiveDirectory module is imported. If not, import it.

if ((Get-Module ActiveDirectory).Name -eq "ActiveDirectory") {
    # The module is imported.
    Write-Host "ActiveDirectory module is already imported. Proceeding"
} else { 
    # The module is not imported. Try to import it.
        Import-Module ActiveDirectory | Out-Null
        if ((Get-Module ActiveDirectory).Name -eq "ActiveDirectory") { 
            Write-Host "Successfully imported ActiveDirectory module. Proceeding"
        } else {
            Write-Host "Unable to import ActiveDirectory module."
            break
        }
}

# What date is the "oldest" a computer can have gone since logging on?
$timeLimit = (Get-Date).AddDays(0 - $oldAccountAge).ToFileTimeUTC().ToString()

# Get a list of old computers that are currently enabled
$Computers = Get-ADComputer -LDAPFilter "(&(objectCategory=Computer)(lastlogontimestamp<=$timeLimit) (!(userAccountControl:1.2.840.113556.1.4.803:=2)))"

$list = @()

#for each of these computers
$computersDisabled = 0
foreach ($Computer in $Computers) {
    # build a description to indicate that they were disabled by script
	$newDescription = "Disabled by Script " + (Get-Date).ToString() + $Computer.Description
	$computersDisabled += 1
    # disable them and apply description
    Set-ADComputer -Identity $Computer.DistinguishedName -Enabled $False -Description $newDescription 
	$list += $Computer.DistinguishedName
    Write-Host $Computer.Name " was disabled"
}

Write-Host "Disabled $($computersDisabled) Computers"