# MAIN BRANCH

# IPV4
$LIST_IPV4 = @()
$null = Get-ChildItem .\CIDR-IPAddress\IPV4 -Filter '*.txt' | Select-Object * | ForEach-Object {
    $LIST_IPV4 += "`n<a href=""https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV4/$($_.BaseName).txt"">$($_.BaseName)_ipv4</a><br>`n"
}

# IPV6
$LIST_IPV6 = @()
$null = Get-ChildItem .\CIDR-IPAddress\IPV6 -Filter '*.txt' | Select-Object * | ForEach-Object {
    $LIST_IPV6 += "`n`<a href=""https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV6/$($_.BaseName).txt"">$($_.BaseName)_ipv6</a><br>`n"
}

# GH BRANCH
git fetch origin gh-pages
git checkout gh-pages

$content = Get-Content .\index.html -Raw
$content = $content -replace "(?s)(?<=<!-- Country-IP-List-IPV4:START -->).*(?=<!-- Country-IP-List-IPV4:END -->)", $LIST_IPV4
$content = $content -replace "(?s)(?<=<!-- Country-IP-List-IPV6:START -->).*(?=<!-- Country-IP-List-IPV6:END -->)", $LIST_IPV6
$null = Set-Content .\index.html -Value $content.TrimEnd()

# Pushing the sources and list to main
git config --global user.email "118815227+HotCakeX@users.noreply.github.com"
git config --global user.name "HotCakeX"
git add --all
git commit -m "updating list in index"
git push
