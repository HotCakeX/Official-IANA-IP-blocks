$ProgressPreference = 'SilentlyContinue'
$regions = [ordered]@{
    'apnic'   = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-latest'
    'arin'    = 'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest'
    'ripe'    = 'https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest'
    'afrinic' = 'https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest'
    'lacnic'  = 'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest'
}
# Deleting countries ip ranges lists
if (Get-ChildItem .\CIDR-IPAddress\IPV4 -Filter '*.txt' -ErrorAction SilentlyContinue) { Remove-Item .\CIDR-IPAddress\IPV4\*.txt }
if (Get-ChildItem .\CIDR-IPAddress\IPV6 -Filter '*.txt' -ErrorAction SilentlyContinue) { Remove-Item .\CIDR-IPAddress\IPV6\*.txt }

# Download all sources
$regions.GetEnumerator() | ForEach-Object {
    Write-Host $_.Key = $_.Value -ForegroundColor DarkMagenta
    try {
        # Saving file to a variable and then saving to a file, to not delete the last source in case error occur during request
        $content = Invoke-RestMethod -Uri $_.Value
        Set-Content ".\IANASources\$($_.Key).txt" -Value $content
    } catch {
        Write-Error $_.Key
    }
}

$ipv4Data = @{}
$ipv6Data = @{}

$regions.GetEnumerator() | ForEach-Object {
    Write-Host "region : $($_.Key)" -ForegroundColor DarkMagenta
    # Read each region files
    $null = Get-Content "IANASources/$($_.Key).txt" |
    Where-Object { $_ -like '*ipv*' -and $_ -like '*allocated*' -or $_ -like '*assigned*' } |
    ForEach-Object {
        $split = $_.Split('|')
        <#
        $split[1] = country code
        $split[2] = ip version
        $split[3] = cidr
        $split[4] = prefixlength
        #>
        switch ($split[2]) {
            'ipv4' {
                # Checking if country exist as an array name
                if (!$ipv4Data.ContainsKey($split[1])) { $ipv4Data[$split[1]] = @() }
                # Adding this ip range to the correct array name (country) and converting the raw number of addresses to cidr notation
                $ipv4Data[$split[1]] += ($split[3] + "/" + [math]::Round((32 - [Math]::Log($split[4], 2))))
            }
            'ipv6' {
                # Checking if country exist as an array name
                if (!$ipv6Data.ContainsKey($split[1])) { $ipv6Data[$split[1]] = @() }
                # Adding this ip range to the correct array name (country)
                $ipv6Data[$split[1]] += ($split[3] + "/" + $split[4])
            }
        }
    }
}

# Writing hashtable to files where name = {country}.txt
$ipv4Data.GetEnumerator() | ForEach-Object {
    Add-Content "CIDR-IPAddress\IPV4\$($_.Key).txt" -Value $_.Value -Force
}
$ipv6Data.GetEnumerator() | ForEach-Object {
    Add-Content "CIDR-IPAddress\IPV6\$($_.Key).txt" -Value $_.Value -Force
}

# Pushing the sources and list to main
git config --global user.email "118815227+HotCakeX@users.noreply.github.com"
git config --global user.name "HotCakeX"
git add --all
git commit -m "updating sources and list"
git push
