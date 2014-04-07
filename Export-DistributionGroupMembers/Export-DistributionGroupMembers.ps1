#vars
$outputDirectory = "C:\groups"



# Get the Exchange stuff

if ( (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction silentlycontinue) -eq $null )
{
    Write-Host "Importing Exchange modules" -BackgroundColor Black -ForegroundColor Yellow
	Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue
}

if ( (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction silentlycontinue) -eq $null )
{
    throw "Unable to import exchange modules! Aborting..."
}

# Create the output directory if it doesn't exist
if ((Test-Path $outputDirectory) -eq $false) {
	$null = New-Item $outputDirectory -ItemType Directory
}

# Get the groups
$groups = Get-DistributionGroup -ResultSize unlimited 
$numberOfGroups = $groups.Count

Write-Host "Got $numberOfGroups groups. Processing ..."

$groupProgressCounter = 1

foreach ($group in $groups) {
	Write-Progress -activity "Distribution Group Analysis" -status "Processing $group" -PercentComplete $($groupProgressCounter / $numberOfGroups * 100)
	
	$group | Get-DistributionGroupMember -ResultSize unlimited | Select-Object DisplayName,Alias | Export-Csv -NoTypeInformation -NoClobber -Path $outputDirectory"\"$group".csv" -Force 
	
	$groupProgressCounter++
}