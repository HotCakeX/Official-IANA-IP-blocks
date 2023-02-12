$StateSponsorsofTerrorism = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV4/IR.txt"
$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV6/IR.txt"

$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV4/CU.txt"
$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV6/CU.txt"

$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV4/KP.txt"
$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV6/KN.txt"
 
$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV4/SY.txt"
$StateSponsorsofTerrorism += Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/CIDR-IPAddress/IPV6/SY.txt" | Out-File .\Curated-Lists\StateSponsorsOfTerrorism.txt



# Pushing the sources and list to main
git config --global user.email "118815227+HotCakeX@users.noreply.github.com"
git config --global user.name "HotCakeX"
git add 'StateSponsorsOfTerrorism.txt'
git commit -m "updating Curated lists"
git push