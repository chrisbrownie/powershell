#This was a quick and dirty one for pulling data out of IIS logs for Exchange 2010 OWA
# Didn't have LogParser handy at the time - would highly recommend it in place of this.

$Logfiles = @("\\ex02\c$\inetpub\logs\LogFiles\W3SVC1\u_ex110508.log",
                "\\ex02\c$\inetpub\logs\LogFiles\W3SVC1\u_ex110509.log",
                "\\ex02\c$\inetpub\logs\LogFiles\W3SVC1\u_ex110510.log"
             )
$username = "*kim.akers*"

$results = @()

foreach ($file in $logFiles) { 
    Write-Host "Analysing $file"
    $rows = 0
	gc $file | % {
		$parts = $_.Split()
                
		if ($parts[5] -ilike $username) {
			$result = "" | Select-Object "Date","Time","Method","url","Data","User","IP","Protocol","UAString","Referrer","ReqStatus"
			$result.Date = $parts[0]
			$result.Time = $parts[1]
			$result.Method = $parts[2]
			$result.url = $parts[3]
			$result.Data = $parts[4]
			$result.user = $parts[5]
			$result.IP = $parts[6]
			$result.Protocol = $parts[7]
			$result.UAstring = $parts[8]
			$result.Referrer = $parts[9]
			$result.ReqStatus = $parts[10]
			$results += $result
		}
	
        $rows++;
        if (($rows % 10000) -eq 0) {
            Write-Host "Processed $rows rows of this file"
        }
	}
}


if ($results) { $results | Out-GridView } else {"No results!"}