Clear-Variable * -ErrorAction SilentlyContinue
$StateSponsorsofTerrorism = Get-Content .\TXT\IPV4\IR.txt #Iran
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV6\IR.txt #Iran
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV4\CU.txt #Cuba
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV6\CU.txt #Cuba
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV4\KP.txt #North korea
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV6\KN.txt #North korea
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV4\SY.txt #Syria
$StateSponsorsofTerrorism += Get-Content .\TXT\IPV6\SY.txt #Syria
Set-Content .\Curated-Lists\StateSponsorsOfTerrorism.txt -Value $StateSponsorsofTerrorism -Force

$OFACSanctioned = Get-Content .\TXT\IPV4\IR.txt #Iran
$OFACSanctioned += Get-Content .\TXT\IPV6\IR.txt #Iran
$OFACSanctioned += Get-Content .\TXT\IPV4\CU.txt #Cuba
$OFACSanctioned += Get-Content .\TXT\IPV6\CU.txt #Cuba
$OFACSanctioned += Get-Content .\TXT\IPV4\KP.txt #North korea
$OFACSanctioned += Get-Content .\TXT\IPV6\KN.txt #North korea
$OFACSanctioned += Get-Content .\TXT\IPV4\SY.txt #Syria
$OFACSanctioned += Get-Content .\TXT\IPV6\SY.txt #Syria
$OFACSanctioned += Get-Content .\TXT\IPV4\RU.txt #Russia
$OFACSanctioned += Get-Content .\TXT\IPV6\RU.txt #Russia
$OFACSanctioned += Get-Content .\TXT\IPV4\BY.txt #Belarus
$OFACSanctioned += Get-Content .\TXT\IPV6\BY.txt #Belarus
$OFACSanctioned += Get-Content .\TXT\IPV4\YE.txt #Yemen
$OFACSanctioned += Get-Content .\TXT\IPV6\YE.txt #Yemen
$OFACSanctioned += Get-Content .\TXT\IPV4\IQ.txt #Iraq
$OFACSanctioned += Get-Content .\TXT\IPV6\IQ.txt #Iraq
$OFACSanctioned += Get-Content .\TXT\IPV4\MM.txt #Myanmar
$OFACSanctioned += Get-Content .\TXT\IPV6\MM.txt #Myanmar
$OFACSanctioned += Get-Content .\TXT\IPV4\CF.txt #Central African Republic (the)
$OFACSanctioned += Get-Content .\TXT\IPV4\CD.txt #Congo, Dem. Rep. of
$OFACSanctioned += Get-Content .\TXT\IPV6\CD.txt #Congo, Dem. Rep. of
$OFACSanctioned += Get-Content .\TXT\IPV4\ET.txt #Ethiopia
$OFACSanctioned += Get-Content .\TXT\IPV6\ET.txt #Ethiopia
$OFACSanctioned += Get-Content .\TXT\IPV4\HK.txt #Hong Kong
$OFACSanctioned += Get-Content .\TXT\IPV6\HK.txt #Hong Kong
$OFACSanctioned += Get-Content .\TXT\IPV4\LB.txt #Lebanon
$OFACSanctioned += Get-Content .\TXT\IPV6\LB.txt #Lebanon
$OFACSanctioned += Get-Content .\TXT\IPV4\LY.txt #Libya
$OFACSanctioned += Get-Content .\TXT\IPV6\LY.txt #Libya
$OFACSanctioned += Get-Content .\TXT\IPV4\SD.txt #Sudan (the)
$OFACSanctioned += Get-Content .\TXT\IPV6\SD.txt #Sudan (the)
$OFACSanctioned += Get-Content .\TXT\IPV4\VE.txt #Venezuela (Bolivarian Republic of)
$OFACSanctioned += Get-Content .\TXT\IPV6\VE.txt #Venezuela (Bolivarian Republic of)
$OFACSanctioned += Get-Content .\TXT\IPV4\ZW.txt #Zimbabwe
$OFACSanctioned += Get-Content .\TXT\IPV6\ZW.txt #Zimbabwe
Set-Content .\Curated-Lists\OFACSanctioned.txt -Value $OFACSanctioned -Force

# Pushing the sources and list to main
git config --global user.email 'spynetgirl@outlook.com'
git config --global user.name 'HotCakeX'
git add --all
git commit -m 'updating Curated lists'
git push
