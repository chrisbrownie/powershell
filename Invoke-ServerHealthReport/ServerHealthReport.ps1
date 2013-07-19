
####################################################################################################
#
# Script: Invoke-SystemHealthReport.ps1
# Author: Chris Brown (www.flamingkeys.com)
# Adapted from: https://www.simple-talk.com/sysadmin/powershell/building-a-daily-systems-report-email-with-powershell/ @shogan85
# Usage: .\Invoke-SystemHealthReport.ps1
#
# Version: 1.0
#
####################################################################################################


##############################
## BEGIN Settings
##############################

# Define settings objects (No need to touch these)
$smtp = New-Object -type PSObject -Property @{sender = $null;recipients = $null;server = $null;}
$settings = New-Object -TypeName PSObject -Property @{FreeDiskSpaceThreshold=$null;NumberEvents=$null;ProcessNumToFetch=$null}


# Script Options:
# Free Disk Space Threshold (in percent)
$settings.FreeDiskSpaceThreshold = 20
# How many recent event log events will we show?
$settings.NumberEvents = 3
# ProcessNumToFetch
$settings.ProcessNumToFetch = 10
# SMTP settings:
$smtp.sender = "Server Health Reporting <Alerts@contoso.com>"
$smtp.recipients = @("chris@contoso.com")
$smtp.server = "mail.contoso.com"


##############################
## END Settings
##############################

##############################
## BEGIN Initialization
##############################

$ListOfAttachments = @()
$Report = @()
$CurrentTime = Get-Date


# Assemble the HTML Header and CSS for our Report
$HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>My Systems Report</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

    #report { width: 835px; }

    table{
	border-collapse: collapse;
	border: none;
	font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
	color: black;
	margin-bottom: 10px;
}

    table td{
	font-size: 12px;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

    table th {
	font-size: 12px;
	font-weight: bold;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

h2{ clear: both; font-size: 130%; }

h3{
	clear: both;
	font-size: 115%;
	margin-left: 20px;
	margin-top: 30px;
}

p{ margin-left: 20px; font-size: 12px; }

table.list{ float: left; }

    table.list td:nth-child(1){
	font-weight: bold;
	border-right: 1px grey solid;
	text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
-->
</style>
</head>
<body>

"@

##############################
## END Initialization
##############################

##############################
## BEGIN Worker Functions
##############################

Function Create-PieChart() {
	param([string]$FileName)
		
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
	
	#Create our chart object 
	$Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
	$Chart.Width = 300
	$Chart.Height = 290 
	$Chart.Left = 10
	$Chart.Top = 10

	#Create a chartarea to draw on and add this to the chart 
	$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
	$Chart.ChartAreas.Add($ChartArea) 
	[void]$Chart.Series.Add("Data") 

	#Add a datapoint for each value specified in the arguments (args) 
    foreach ($value in $args[0]) {
		Write-Host "Now processing chart value: " + $value
		$datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $value)
	    $datapoint.AxisLabel = "Value" + "(" + $value + " GB)"
	    $Chart.Series["Data"].Points.Add($datapoint)
	}

	$Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
	$Chart.Series["Data"]["PieLabelStyle"] = "Outside" 
	$Chart.Series["Data"]["PieLineColor"] = "Black" 
	$Chart.Series["Data"]["PieDrawingStyle"] = "Concave" 
	($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true

	#Set the title of the Chart to the current date and time 
	$Title = new-object System.Windows.Forms.DataVisualization.Charting.Title 
	$Chart.Titles.Add($Title) 
	$Chart.Titles[0].Text = "RAM Usage Chart (Used/Free)"

	#Save the chart to a file
	$Chart.SaveImage($FileName + ".png","png")
}

Function Get-HostUptime {
	param ([string]$ComputerName)
	$Uptime = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
	$LastBootUpTime = $Uptime.ConvertToDateTime($Uptime.LastBootUpTime)
	$Time = (Get-Date) - $LastBootUpTime
	Return '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $Time.Days, $Time.Hours, $Time.Minutes, $Time.Seconds
}

##############################
## END Worker Functions
##############################

##############################
## BEGIN Smarts
##############################

$DiskInfo = Get-WmiObject -Class Win32_Volume | Where-Object {($_.DriveType -eq 3) -and (($_.freespace/$_.capacity)*100 -lt $Settings.FreeDiskSpaceThreshold)} `
            |  Select-Object SystemName,DriveType,Caption,Name, @{name='Size (GB)';expression={"{0:n0}" -f ($_.capacity/1gb)}}, `
            @{name='Percent Free';expression={"{0:n2}" -f ($_.freespace/$_.capacity*100)}} `
            | ConvertTo-Html -Fragment
            
$OS = (Get-WmiObject Win32_OperatingSystem | Select @{name="OSDescription";Expression={$_.Caption + " (" + $_.Version + ")"}}).OSDescription

$SystemInfo = Get-WmiObject -Class Win32_OperatingSystem | Select-Object Name, TotalVisibleMemorySize, FreePhysicalMemory
$TotalRAM = $SystemInfo.TotalVisibleMemorySize/1MB
$FreeRAM = $SystemInfo.FreePhysicalMemory/1MB
$UsedRAM = $TotalRAM - $FreeRAM
$RAMPercentFree = ($FreeRAM / $TotalRAM) * 100
$TotalRAM = [Math]::Round($TotalRAM, 2)
$FreeRAM = [Math]::Round($FreeRAM, 2)
$UsedRAM = [Math]::Round($UsedRAM, 2)
$RAMPercentFree = [Math]::Round($RAMPercentFree, 2)


$TopProcesses = Get-Process | Sort WS -Descending | Select ProcessName, Id, WS -First $Settings.ProcessNumToFetch | ConvertTo-Html -Fragment

### Services
$ServicesReport = @()
foreach ($Service in $(Get-WmiObject -Class Win32_Service | Where {($_.StartMode -eq "Auto") -and ($_.State -eq "Stopped")})) {
	$row = New-Object -Type PSObject -Property @{
	   	Name = $Service.Name
		Status = $Service.State
		StartMode = $Service.StartMode
	}
$ServicesReport += $row
}

$ServicesReport = $ServicesReport | ConvertTo-Html -Fragment
###





break;


foreach ($computer in $settings.computers) {

	#region Event Logs Report
	$SystemEventsReport = @()
	$SystemEvents = Get-EventLog -ComputerName $computer -LogName System -EntryType Error,Warning -Newest $Settings.NumberEvents
	foreach ($event in $SystemEvents) {
		$row = New-Object -Type PSObject -Property @{
			TimeGenerated = $event.TimeGenerated
			EntryType = $event.EntryType
			Source = $event.Source
			Message = $event.Message
		}
		$SystemEventsReport += $row
	}
			
	$SystemEventsReport = $SystemEventsReport | ConvertTo-Html -Fragment
	
	$ApplicationEventsReport = @()
	$ApplicationEvents = Get-EventLog -ComputerName $computer -LogName Application -EntryType Error,Warning -Newest $Settings.NumberEvents
	foreach ($event in $ApplicationEvents) {
		$row = New-Object -Type PSObject -Property @{
			TimeGenerated = $event.TimeGenerated
			EntryType = $event.EntryType
			Source = $event.Source
			Message = $event.Message
		}
		$ApplicationEventsReport += $row
	}
	
	$ApplicationEventsReport = $ApplicationEventsReport | ConvertTo-Html -Fragment
	#endregion
	
	# Create the chart using our Chart Function
	Create-PieChart -FileName ((Get-Location).Path + "\chart-$computer") $FreeRAM, $UsedRAM
	$ListOfAttachments += "chart-$computer.png"
	#region Uptime
	# Fetch the Uptime of the current system using our Get-HostUptime Function.
	$SystemUptime = Get-HostUptime -ComputerName $computer
	#endregion

	# Create HTML Report for the current System being looped through
	$CurrentSystemHTML = @"
	<hr noshade size=3 width="100%">
	<div id="report">
	<p><h2>$computer Report</p></h2>
	<h3>System Info</h3>
	<table class="list">
	<tr>
	<td>System Uptime</td>
	<td>$SystemUptime</td>
	</tr>
	<tr>
	<td>OS</td>
	<td>$OS</td>
	</tr>
	<tr>
	<td>Total RAM (GB)</td>
	<td>$TotalRAM</td>
	</tr>
	<tr>
	<td>Free RAM (GB)</td>
	<td>$FreeRAM</td>
	</tr>
	<tr>
	<td>Percent free RAM</td>
	<td>$RAMPercentFree</td>
	</tr>
	</table>
	
	<IMG SRC="chart-$computer.png" ALT="$computer Chart">
		
	<h3>Disk Info</h3>
	<p>Drive(s) listed below have less than $($settings.FreeDiskSpaceThreshold) % free space. Drives above this threshold will not be listed.</p>
	<table class="normal">$DiskInfo</table>
	<br></br>
	
	<div class="first column">
	<h3>System Processes - Top $ProccessNumToFetch Highest Memory Usage</h3>
	<p>The following $ProccessNumToFetch processes are those consuming the highest amount of Working Set (WS) Memory (bytes) on $computer</p>
	<table class="normal">$TopProcesses</table>
	</div>
	<div class="second column">
	
	<h3>System Services - Automatic Startup but not Running</h3>
	<p>The following services are those which are set to Automatic startup type, yet are currently not running on $computer</p>
	<table class="normal">
	$ServicesReport
	</table>
	</div>
	
	<h3>Events Report - The last $($Settings.NumberEvents) System/Application Log Events that were Warnings or Errors</h3>
	<p>The following is a list of the last $EventNum <b>System log</b> events that had an Event Type of either Warning or Error on $computer</p>
	<table class="normal">$SystemEventsReport</table>

	<p>The following is a list of the last $EventNum <b>Application log</b> events that had an Event Type of either Warning or Error on $computer</p>
	<table class="normal">$ApplicationEventsReport</table>
"@
	# Add the current System HTML Report into the final HTML Report body
	$HTMLMiddle += $CurrentSystemHTML
	
	}

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</div>
</body>
</html>
"@


##############################
## END Smarts
##############################

##############################
## BEGIN Send Email
##############################


# Assemble the final report from all our HTML sections
$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
# Save the report out to a file in the current path
$HTMLmessage | Out-File ((Get-Location).Path + "\report.html")
# Email our report out
send-mailmessage -from $smtp.sender -to $smtp.recipients -subject "Systems Report" -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $smtp.server

##############################
## END Send Email
##############################