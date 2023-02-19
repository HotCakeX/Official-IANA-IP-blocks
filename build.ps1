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
                        'ip'           = $split[3]
                        'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                        'version'      = $split[2]
                    })
            }
            'ipv6' {
                ($using:ipData).Add(@{
                        'country'      = $split[1]
                        'ip'           = $split[3]
                        'prefixlength' = $split[4]
                        'version'      = $split[2]
                    })
            }
        }
    }
} -ThrottleLimit 8
#endregion Process

#region csv

#region csvCountries
Write-Host "csvCountries" -ForegroundColor Green
$ipData | Select-Object country -Unique |
Sort-Object country |
Export-Csv -Path ".\CSV\countries.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
#endregion csvCountries

#region csvGlobal
Write-Host "csvGlobal" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Sort-Object country |
Export-Csv -Path ".\CSV\global.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
#endregion csvGlobal

#region csvGlobalIPV4
Write-Host "csvGlobalIPV4" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv4' } | Select-Object country, ip, prefixlength, version |
Sort-Object country |
Export-Csv -Path ".\CSV\global_ipv4.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
#endregion csvGlobalIPV4

#region csvGlobalIPV6
Write-Host "csvGlobalIPV6" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv6' } | Select-Object country, ip, prefixlength, version |
Sort-Object country |
Export-Csv -Path ".\CSV\global_ipv6.csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
#endregion csvGlobalIPV4

#region csvCountryIPV4
Write-Host "csvCountryIPV4" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv4' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object country, ip, prefixlength, version |
    Sort-Object ip |
    Export-Csv -Path ".\CSV\IPV4\$($_.Name).csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
} -ThrottleLimit 8
#endregion csvCountryIPV4

#region csvCountryIPV6
Write-Host "csvCountryIPV6" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv6' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object country, ip, prefixlength, version |
    Sort-Object ip |
    Export-Csv -Path ".\CSV\IPV6\$($_.Name).csv" -NoTypeInformation -Force -UseQuotes:AsNeeded
} -ThrottleLimit 8
#endregion csvCountryIPV6

#endregion csv

#region json

#region jsonCountries
Write-Host "jsonCountries" -ForegroundColor Green
$ipData | Select-Object country -Unique |
Sort-Object country |
ConvertTo-Json -AsArray | Out-File -Path ".\JSON\countries.json" -Force
#endregion csvCountries

#region jsonGlobal
Write-Host "jsonGlobal" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Sort-Object country | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\global.json" -Force

Write-Host "jsonGlobalCompressed" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Sort-Object country | ConvertTo-Json -AsArray -Compress | Out-File -Path ".\JSON\global_compressed.json" -Force
#endregion jsonGlobal

#region jsonGlobalIPV4
Write-Host "jsonGlobalIPV4" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Where-Object { $_.version -EQ 'ipv4' } |
Sort-Object country | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\global_ipv4.json" -Force

Write-Host "jsonGlobalIPV4Compressed" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Where-Object { $_.version -EQ 'ipv4' } |
Sort-Object country | ConvertTo-Json -AsArray -Compress | Out-File -Path ".\JSON\global_ipv4_compressed.json" -Force
#endregion jsonGlobalIPV4

#region jsonGlobalIPV6
Write-Host "jsonGlobalIPV6" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Where-Object { $_.version -EQ 'ipv6' } |
Sort-Object country | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\global_ipv6.json" -Force

Write-Host "jsonGlobalIPV6Compressed" -ForegroundColor Green
$ipData | Select-Object country, ip, prefixlength, version |
Where-Object { $_.version -EQ 'ipv6' } |
Sort-Object country | ConvertTo-Json -AsArray -Compress | Out-File -Path ".\JSON\global_ipv6_compressed.json" -Force
#endregion jsonGlobalIPV6

#region jsonCountryIPV4
Write-Host "jsonCountryIPV4" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv4' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object country, ip, prefixlength, version |
    Sort-Object ip |
    ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV4\$($_.Name).json" -Force
} -ThrottleLimit 8
#endregion jsonCountryIPV4

#region jsonCountryIPV6
Write-Host "jsonCountryIPV6" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv6' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object country, ip, prefixlength, version |
    Sort-Object ip |
    ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV6\$($_.Name).json" -Force
} -ThrottleLimit 8
#endregion jsonCountryIPV6

#endregion json

#region txt

#region txtCountries
Write-Host "txtCountries" -ForegroundColor Green
$list = ""
$ipData | Select-Object country -Unique |
Sort-Object country |
ForEach-Object {
    $list += "$($_.country)`n"
}
($list).Trim() | Out-File -Path ".\TXT\_countries.txt" -Force
#endregion txtCountries

#region txtCountryIPV4
Write-Host "txtCountryIPV4" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv4' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $list = ""
    $_.Group |
    Select-Object country, ip, prefixlength, version |
    Sort-Object ip |
    ForEach-Object {
        $list += "$($_.ip)\$($_.prefixlength)`n"
    }
    ($list).Trim() | Out-File -Path ".\TXT\IPV4\$($_.Name).txt" -Force
} -ThrottleLimit 8
#endregion txtCountryIPV4

#region txtCountryIPV6
Write-Host "txtCountryIPV6" -ForegroundColor Green
$ipData | Where-Object { $_.version -EQ 'ipv6' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $list = ""
    $_.Group |
    Select-Object country, ip, prefixlength, version |
    Sort-Object ip |
    ForEach-Object {
        $list += "$($_.ip)\$($_.prefixlength)`n"
    }
    ($list).Trim() | Out-File -Path ".\TXT\IPV6\$($_.Name).txt" -Force
} -ThrottleLimit 8
#endregion txtCountryIPV6

#endregion txt
