$ErrorActionPreference = 'Stop'

# A dictionary of regions and their respective URLs
$Regions_Delegated = [System.Collections.Hashtable]@{
    'delegated-apnic-latest'         = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-latest'
    'delegated-arin-extended-latest' = 'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest'
    'delegated-ripencc-latest'       = 'https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest'
    'delegated-afrinic-latest'       = 'https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest'
    'delegated-lacnic-latest'        = 'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest'
}

# Create the required directories if they don't exist
if (-NOT (Test-Path -Path '.\IANASources')) { New-Item -Path '.\IANASources' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\CSV')) { New-Item -Path '.\CSV' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\CSV\IPV4')) { New-Item -Path '.\CSV\IPV4' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\CSV\IPV6')) { New-Item -Path '.\CSV\IPV6' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\JSON')) { New-Item -Path '.\JSON' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\JSON\IPV4')) { New-Item -Path '.\JSON\IPV4' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\JSON\IPV6')) { New-Item -Path '.\JSON\IPV6' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\TXT')) { New-Item -Path '.\TXT' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\TXT\IPV4')) { New-Item -Path '.\TXT\IPV4' -ItemType Directory -Force | Out-Null }
if (-NOT (Test-Path -Path '.\TXT\IPV6')) { New-Item -Path '.\TXT\IPV6' -ItemType Directory -Force | Out-Null }

#region download
$Regions_Delegated.GetEnumerator() | ForEach-Object -Parallel {
    Write-Host -Object "Downloading $($_.Key)" -ForegroundColor Cyan
    $Content = Invoke-RestMethod -Uri $_.Value
    Set-Content -Path ".\IANASources\$($_.Key).txt" -Value $Content -Force
} -ThrottleLimit 5
#endregion download

#region process
$IpData = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()

# Loop over each continent's name from the HashTable
$Regions_Delegated.GetEnumerator() | ForEach-Object -Parallel {

    Write-Host -Object $_.Key -ForegroundColor DarkMagenta

    # Loop over each line in the continent's IP info
    $null = foreach ($Item in Get-Content -Path ".\IANASources\$($_.Key).txt") {

        if ($Item -match 'allocated|assigned' ) {

            [System.String[]]$Split = $Item.Split('|')

            switch ($Split[2]) {
                'ipv4' {
                    ($using:ipData).Add(@{
                            'country'      = $Split[1]
                            'version'      = $Split[2]
                            'ip'           = $Split[3]
                            'prefixlength' = [System.String][math]::Round((32 - [Math]::Log($Split[4], 2)))
                        })
                }
                'ipv6' {
                    ($using:ipData).Add(@{
                            'country'      = $Split[1]
                            'version'      = $Split[2]
                            'ip'           = $Split[3]
                            'prefixlength' = $Split[4]
                        })
                }
            }

        }
    }
} -ThrottleLimit 32
#endregion Process

#region Sorting
Write-Host -Object 'Sorting IpData' -ForegroundColor Yellow
$IpData = $IpData | Sort-Object -Property country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [System.Version]
    }
    else {
        [System.Int64]('0x' + $_.ip.Replace(':', ''))
    }
}
#endregion Sorting

#region Countries
Write-Host -Object 'Countries' -ForegroundColor Green
[System.Object[]]$ToExport = $IpData | Select-Object -Property country -Unique
$ToExport | Export-Csv -Path '.\CSV\countries.csv' -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json | Out-File -Path '.\JSON\countries.json' -Force

[System.String[]]$list = foreach ($Item in $ToExport) {
    "$($Item.country)`n"
}

$list.Trim() | Out-File -Path '.\TXT\countries.txt' -Force
#endregion Countries

#region Global
Write-Host -Object 'Global' -ForegroundColor Green
$ToExport = $IpData | Select-Object -Property country, ip, prefixlength, version
$ToExport | Export-Csv -Path '.\CSV\global.csv' -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json -AsArray | Out-File -Path '.\JSON\global.json' -Force
$ToExport | ConvertTo-Json -AsArray -Compress | Out-File -Path '.\JSON\global_compressed.json' -Force
#endregion Global

#region GlobalIPV4
Write-Host -Object 'GlobalIPV4' -ForegroundColor Green
$ToExport = $IpData | Where-Object -FilterScript { $_.version -EQ 'ipv4' } | Select-Object -Property country, ip, prefixlength, version
$ToExport | Export-Csv -Path '.\CSV\global_ipv4.csv' -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json -AsArray | Out-File -Path '.\JSON\global_ipv4.json' -Force
$ToExport | ConvertTo-Json -AsArray -Compress | Out-File -Path '.\JSON\global_ipv4_compressed.json' -Force
#endregion

#region GlobalIPV6
Write-Host -Object 'GlobalIPV6' -ForegroundColor Green
$ToExport = foreach ($Item in $IpData) {
    if ($Item.version -eq 'ipv6') {
        $Item
    }
}
$ToExport = $ToExport | Select-Object -Property country, ip, prefixlength, version

$ToExport | Export-Csv -Path '.\CSV\global_ipv6.csv' -Force -UseQuotes:AsNeeded
$ToExport | ConvertTo-Json -AsArray | Out-File -Path '.\JSON\global_ipv6.json' -Force
$ToExport | ConvertTo-Json -AsArray -Compress | Out-File -Path '.\JSON\global_ipv6_compressed.json' -Force
#endregion GlobalIPV6

#region CountryIPV4
Write-Host -Object 'CountryIPV4' -ForegroundColor Green
$IpData | Where-Object -FilterScript { $_.version -EQ 'ipv4' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group | Select-Object -Property country, ip, prefixlength, version | Export-Csv -Path ".\CSV\IPV4\$($_.Name).csv" -Force -UseQuotes:AsNeeded
    $_.Group | Select-Object -Property country, ip, prefixlength, version | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV6\$($_.Name).json" -Force
    $list = ''
    $_.Group | Select-Object -Property country, ip, prefixlength, version | ForEach-Object -Process { $list += "$($_.ip)/$($_.prefixlength)`n" }
    $list.Trim() | Out-File -Path ".\TXT\IPV4\$($_.Name).txt" -Force
} -ThrottleLimit 32
#endregion CountryIPV4

#region CountryIPV6
Write-Host -Object 'CountryIPV6' -ForegroundColor Green
$IpData | Where-Object -FilterScript { $_.version -EQ 'ipv6' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group | Select-Object -Property country, ip, prefixlength, version | Export-Csv -Path ".\CSV\IPV6\$($_.Name).csv" -Force -UseQuotes:AsNeeded
    $_.Group | Select-Object -Property country, ip, prefixlength, version | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV6\$($_.Name).json" -Force
    $list = ''
    $_.Group | Select-Object -Property country, ip, prefixlength, version | ForEach-Object -Process { $list += "$($_.ip)/$($_.prefixlength)`n" }
    $list.Trim() | Out-File -Path ".\TXT\IPV6\$($_.Name).txt" -Force
} -ThrottleLimit 32
#endregion CountryIPV6
