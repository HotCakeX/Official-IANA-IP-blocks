$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
namespace IPConfig
{
    public class Package
    {
        public string Country { get; set; }
        public string IP { get; set; }
        public string PrefixLength { get; set; }
        public string Version { get; set; }
        public Package(string country, string ip, string prefixlength, string version )
        {
            Country = country;
            IP = ip;
            PrefixLength = prefixlength;
            Version = version;
        }
    }
}
'@

# A HashTable of regions and their respective URLs
$Regions_Delegated = [System.Collections.Hashtable]@{
    'delegated-apnic-latest'         = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-latest'
    'delegated-arin-extended-latest' = 'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest'
    'delegated-ripencc-latest'       = 'https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest'
    'delegated-afrinic-latest'       = 'https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest'
    'delegated-lacnic-latest'        = 'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest'
}

Write-Host -Object 'Creating directories' -ForegroundColor Cyan
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
$IpData = [System.Collections.Concurrent.ConcurrentBag[IPConfig.Package]]::new()

$Pattern = 'allocated|assigned'
$Regex = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)

# Loop over each continent's name from the HashTable
$Regions_Delegated.GetEnumerator() | ForEach-Object -Parallel {

    Write-Host -Object $_.Key -ForegroundColor DarkMagenta

    # Loop over each line in the continent's IP info
    $null = foreach ($Item in Get-Content -Path ".\IANASources\$($_.Key).txt") {

        if (($using:regex).IsMatch($Item)) {

            [System.String[]]$Split = $Item.Split('|')

            switch ($Split[2]) {
                'ipv4' {
                    ($using:ipData).Add([IPConfig.Package]::New(
                            $Split[1],
                            $Split[3],
                            [System.String][math]::Round((32 - [Math]::Log($Split[4], 2))),
                            $Split[2]
                        ))
                }
                'ipv6' {
                    ($using:ipData).Add([IPConfig.Package]::New(
                            $Split[1],
                            $Split[3],
                            $Split[4],
                            $Split[2]
                        ))
                }
            }

        }
    }
} -ThrottleLimit ($Regions_Delegated.Count)
#endregion Process

#region Sorting
Write-Host -Object 'Sorting IpData' -ForegroundColor Yellow
[System.Collections.Generic.List[IPConfig.Package]]$SortedIpData = $IpData | Sort-Object -Property country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [System.Version]
    }
    else {
        [System.Int64]('0x' + $_.ip.Replace(':', ''))
    }
}
#endregion Sorting

#region Countries
Write-Host -Object 'Exporting Countries Lists' -ForegroundColor Green
[System.Object[]]$CountriesList = $SortedIpData | Select-Object -Property country -Unique
$CountriesList | Export-Csv -Path '.\CSV\countries.csv' -Force -UseQuotes:AsNeeded
$CountriesList | ConvertTo-Json | Out-File -Path '.\JSON\countries.json' -Force

[System.String[]]$CountriesListText = foreach ($Item in $CountriesList) {
    "$($Item.country)`n"
}

$CountriesListText.Trim() | Out-File -Path '.\TXT\countries.txt' -Force
#endregion Countries

#region Global
Write-Host -Object 'Exporting Aggregated Global Data' -ForegroundColor Green
$SortedIpData | Export-Csv -Path '.\CSV\global.csv' -Force -UseQuotes:AsNeeded
$SortedIpData | ConvertTo-Json -AsArray | Out-File -Path '.\JSON\global.json' -Force
$SortedIpData | ConvertTo-Json -AsArray -Compress | Out-File -Path '.\JSON\global_compressed.json' -Force
#endregion Global

#region GlobalIPV4
Write-Host -Object 'GlobalIPV4' -ForegroundColor Green

$GlobalDataIPv4 = foreach ($Item in $SortedIpData) {
    if ($Item.version -eq 'ipv4') {
        $Item
    }
}
$GlobalDataIPv4 | Export-Csv -Path '.\CSV\global_ipv4.csv' -Force -UseQuotes:AsNeeded
$GlobalDataIPv4 | ConvertTo-Json -AsArray | Out-File -Path '.\JSON\global_ipv4.json' -Force
$GlobalDataIPv4 | ConvertTo-Json -AsArray -Compress | Out-File -Path '.\JSON\global_ipv4_compressed.json' -Force
#endregion GlobalIPV4

#region GlobalIPV6
Write-Host -Object 'GlobalIPV6' -ForegroundColor Green

$GlobalDataIPv6 = foreach ($Item in $SortedIpData) {
    if ($Item.version -eq 'ipv6') {
        $Item
    }
}
$GlobalDataIPv6 | Export-Csv -Path '.\CSV\global_ipv6.csv' -Force -UseQuotes:AsNeeded
$GlobalDataIPv6 | ConvertTo-Json -AsArray | Out-File -Path '.\JSON\global_ipv6.json' -Force
$GlobalDataIPv6 | ConvertTo-Json -AsArray -Compress | Out-File -Path '.\JSON\global_ipv6_compressed.json' -Force
#endregion GlobalIPV6

#region CountryIPV4
Write-Host -Object 'CountryIPV4' -ForegroundColor Green
# loop over data grouped by country in parallel
$SortedIpData | Where-Object -FilterScript { $_.version -EQ 'ipv4' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group | Export-Csv -Path ".\CSV\IPV4\$($_.Name).csv" -Force -UseQuotes:AsNeeded
    $_.Group | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV4\$($_.Name).json" -Force

    $List = foreach ($Item in ($_.Group)) {
        "$($Item.ip)/$($Item.prefixlength)`n"
    }
    $List.Trim() | Out-File -Path ".\TXT\IPV4\$($_.Name).txt" -Force

} -ThrottleLimit 32
#endregion CountryIPV4

#region CountryIPV6
Write-Host -Object 'CountryIPV6' -ForegroundColor Green
# loop over data grouped by country in parallel
$SortedIpData | Where-Object -FilterScript { $_.version -EQ 'ipv6' } | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group | Export-Csv -Path ".\CSV\IPV6\$($_.Name).csv" -Force -UseQuotes:AsNeeded
    $_.Group | ConvertTo-Json -AsArray | Out-File -Path ".\JSON\IPV6\$($_.Name).json" -Force

    $List = foreach ($Item in ($_.Group)) {
        "$($Item.ip)/$($Item.prefixlength)`n"
    }
    $List.Trim() | Out-File -Path ".\TXT\IPV6\$($_.Name).txt" -Force

} -ThrottleLimit 32
#endregion CountryIPV6
