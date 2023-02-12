Clear-Variable StateSponsorsofTerrorism -ErrorAction SilentlyContinue
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\IR.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\IR.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\CU.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\CU.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\KP.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\KN.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV4\SY.txt
$StateSponsorsofTerrorism += Get-Content .\CIDR-IPAddress\IPV6\SY.txt
Set-Content .\Curated-Lists\StateSponsorsOfTerrorism.txt -Value $StateSponsorsofTerrorism -Force



# Pushing the sources and list to main
git config --global user.email "118815227+HotCakeX@users.noreply.github.com"
git config --global user.name "HotCakeX"
git add --all
git commit -m "updating Curated lists"
git push