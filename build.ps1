$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$regions_delegated = [ordered]@{
    'delegated-apnic-latest'         = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-latest'
    'delegated-arin-extended-latest' = 'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest'
    'delegated-ripencc-latest'       = 'https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest'
    'delegated-afrinic-latest'       = 'https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest'
    'delegated-lacnic-latest'        = 'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest'
}

# directories
if (!(Test-Path ".\IANASources")) { $null = New-Item ".\IANASources" -ItemType Directory -Force }
if (!(Test-Path ".\CSV")) { $null = New-Item ".\CSV" -ItemType Directory -Force }
if (!(Test-Path ".\CSV\IPV4")) { $null = New-Item ".\CSV\IPV4" -ItemType Directory -Force }
if (!(Test-Path ".\CSV\IPV6")) { $null = New-Item ".\CSV\IPV6" -ItemType Directory -Force }
if (!(Test-Path ".\JSON")) { $null = New-Item ".\JSON" -ItemType Directory -Force }
if (!(Test-Path ".\JSON\IPV4")) { $null = New-Item ".\JSON\IPV4" -ItemType Directory -Force }
if (!(Test-Path ".\JSON\IPV6")) { $null = New-Item ".\JSON\IPV6" -ItemType Directory -Force }
if (!(Test-Path ".\TXT")) { $null = New-Item ".\TXT" -ItemType Directory -Force }
if (!(Test-Path ".\TXT\IPV4")) { $null = New-Item ".\TXT\IPV4" -ItemType Directory -Force }
if (!(Test-Path ".\TXT\IPV6")) { $null = New-Item ".\TXT\IPV6" -ItemType Directory -Force }

#region download
$regions_delegated.GetEnumerator() | ForEach-Object -Parallel {
    Write-Host $_.Key = $_.Value -ForegroundColor Cyan
    $content = Invoke-RestMethod -Uri $_.Value
    Set-Content ".\IANASources\$($_.Key).txt" -Value $content -Force
} -ThrottleLimit 5
#endregion download

#region process
$ipData = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$regions_delegated.GetEnumerator() | ForEach-Object -Parallel {
    Write-Host $_.Key -ForegroundColor DarkMagenta
    $null = Get-Content ".\IANASources\$($_.Key).txt" | Where-Object { $_ -match 'allocated|assigned' } | ForEach-Object {
        $split = $_.Split('|')
        switch ($split[2]) {
            'ipv4' {
                ($using:ipData).Add(@{
                        'country'      = $split[1]
                        'version'      = $split[2]
                        'ip'           = $split[3]
                        'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                    })
            }
            'ipv6' {
                ($using:ipData).Add(@{
                        'country'      = $split[1]
                        'version'      = $split[2]
                        'ip'           = $split[3]
                        'prefixlength' = $split[4]
                    })
            }
        }
    }
} -ThrottleLimit 32
#endregion Process

#region Sorting
Write-Output "Sorting ipData"
$ipData = $ipData |
Sort-Object country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    }
    else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}
#endregion Sorting

#region Countries
Write-Host "Countries" -ForegroundColor Green
$ToExport = $ipData | Select-Object country -Unique
$ToExport | Export-Csv -Path ".\CSV\countries.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json | Out-File -Path ".\JSON\countries.json" -Force
$list = ""
$ToExport | ForEach-Object {
    $list += "$($_.country)`n"
}
$list.Trim() | Out-File -Path ".\TXT\countries.txt" -Force
#endregion Countries

#region Global
Write-Host "Global" -ForegroundColor Green
$ToExport = $ipData | Select-Object country, ip, prefixlength, version
$ToExport | Export-Csv -Path ".\CSV\global.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\global.json" -Force
$ToExport | ConvertTo-Json -AsArray -Compress | Out-File -Path ".\JSON\global_compressed.json" -Force
#endregion Global

#region GlobalIPV4
Write-Host "GlobalIPV4" -ForegroundColor Green
$ToExport = $ipData | Where-Object { $_.version -EQ 'ipv4' } | Select-Object country, ip, prefixlength, version
$ToExport | Export-Csv -Path ".\CSV\global_ipv4.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\global_ipv4.json" -Force
$ToExport | ConvertTo-Json -AsArray -Compress | Out-File -Path ".\JSON\global_ipv4_compressed.json" -Force
#endregion

#region GlobalIPV6
Write-Host "GlobalIPV6" -ForegroundColor Green
$ToExport = $ipData | Where-Object { $_.version -EQ 'ipv6' } | Select-Object country, ip, prefixlength, version
$ToExport | Export-Csv -Path ".\CSV\global_ipv6.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\global_ipv6.json" -Force
$ToExport | ConvertTo-Json -AsArray -Compress | Out-File -Path ".\JSON\global_ipv6_compressed.json" -Force
#endregion GlobalIPV6

#region CountryIPV4
Write-Host "CountryIPV4" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv4' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group | Select-Object country, ip, prefixlength, version | Export-Csv -Path ".\CSV\IPV4\$($_.Name).csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
    $_.Group | Select-Object country, ip, prefixlength, version | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV6\$($_.Name).json" -Force
    $list = ""
    $_.Group | Select-Object country, ip, prefixlength, version | ForEach-Object { $list += "$($_.ip)/$($_.prefixlength)`n" }
    $list.Trim() | Out-File -Path ".\TXT\IPV4\$($_.Name).txt" -Force
} -ThrottleLimit 32
#endregion CountryIPV4

#region CountryIPV6
Write-Host "CountryIPV6" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv6' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group | Select-Object country, ip, prefixlength, version | Export-Csv -Path ".\CSV\IPV6\$($_.Name).csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
    $_.Group | Select-Object country, ip, prefixlength, version | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV6\$($_.Name).json" -Force
    $list = ""
    $_.Group | Select-Object country, ip, prefixlength, version | ForEach-Object { $list += "$($_.ip)/$($_.prefixlength)`n" }
    $list.Trim() | Out-File -Path ".\TXT\IPV6\$($_.Name).txt" -Force
} -ThrottleLimit 32
#endregion CountryIPV6
