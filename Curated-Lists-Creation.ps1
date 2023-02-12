Clear-Variable StateSponsorsofTerrorism -ErrorAction SilentlyContinue
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\IR.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\IR.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\CU.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\CU.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\KP.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\KN.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\SY.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\SY.txt
Remove-Item .\Curated-Lists\StateSponsorsOfTerrorism.txt -Force -ErrorAction SilentlyContinue
Set-Content .\Curated-Lists\StateSponsorsOfTerrorism.txt -Value $StateSponsorsofTerrorism -Force


Clear-Variable OFACSanctioned -ErrorAction SilentlyContinue
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\IR.txt #Iran
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\IR.txt #Iran
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\CU.txt #Cuba
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\CU.txt #Cuba
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\KP.txt #North korea
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\KN.txt #North korea
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\SY.txt #Syria
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\SY.txt #Syria
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\RU.txt #Russia
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\RU.txt #Russia
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\BY.txt #Belarus
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\BY.txt #Belarus
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\YE.txt #Yemen
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\YE.txt #Yemen
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\IQ.txt #Iraq
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\IQ.txt #Iraq
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\MM.txt #Myanmar
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\MM.txt #Myanmar
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\CF.txt #Central African Republic (the)
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\CD.txt #Congo, Dem. Rep. of
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\CD.txt #Congo, Dem. Rep. of
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\ET.txt #Ethiopia
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\ET.txt #Ethiopia
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\HK.txt #Hong Kong
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\HK.txt #Hong Kong
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\LB.txt #Lebanon
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\LB.txt #Lebanon
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\LY.txt #Libya
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\LY.txt #Libya
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\SD.txt #Sudan (the)
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV6\SD.txt #Sudan (the)
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv4\VE.txt #Venezuela (Bolivarian Republic of)
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\VE.txt #Venezuela (Bolivarian Republic of)
$OFACSanctioned += Get-Content .\CIDR-IPAddress\IPV4\ZW.txt #Zimbabwe
$OFACSanctioned += Get-Content .\CIDR-IPAddress\ipv6\ZW.txt #Zimbabwe
Remove-Item .\Curated-Lists\OFACSanctioned.txt -Force -ErrorAction SilentlyContinue
Set-Content .\Curated-Lists\OFACSanctioned.txt -Value $OFACSanctioned -Force



# Pushing the sources and list to main
git config --global user.email "118815227+HotCakeX@users.noreply.github.com"
git config --global user.name "HotCakeX"
git add --all
git commit -m "updating Curated lists"
git push