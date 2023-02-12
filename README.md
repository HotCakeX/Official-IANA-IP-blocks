# Official-IANA-IP-blocks
Internet Assigned Numbers Authority [(IANA)](https://www.iana.org/numbers) official IP address blocks

<br>
<br>

This repository is Automated with GitHub workflows, using PowerShell and running on latest Windows OS
- [Build workflow](https://github.com/HotCakeX/Official-IANA-IP-blocks/actions/workflows/Build.yml): Grabs the latest list from the 5 Global Registeries for each continent and creates country specific text files from them and stores them in this repository - runs every day at `22:00`
- [gh-pages workflow](https://github.com/HotCakeX/Official-IANA-IP-blocks/actions/workflows/gh-pages.yml): Lists the country names and their corresponding files on [our GitHub pages website](https://hotcakex.github.io/Official-IANA-IP-blocks/) - runs every day at `23:00`
- [pages-build-deployment workflow](https://github.com/HotCakeX/Official-IANA-IP-blocks/actions/workflows/pages/pages-build-deployment): Updates the GitHub pages website - runs automatically whenever the HTML file changes
- [CuratedLists workflow](https://github.com/HotCakeX/Official-IANA-IP-blocks/actions/workflows/CuratedLists.yml): Creates curated lists - runs every day at `15:00`
  - [State Sponsors of Terrorism countries cumulative list](https://github.com/HotCakeX/Official-IANA-IP-blocks/blob/main/Curated-Lists/StateSponsorsOfTerrorism.txt) - [_official website_](https://www.state.gov/state-sponsors-of-terrorism/)
  - [OFAC Sanctioned Countries cumulative list](https://github.com/HotCakeX/Official-IANA-IP-blocks/blob/main/Curated-Lists/OFACSanctioned.txt) - [_official website_](https://orpa.princeton.edu/export-controls/sanctioned-countries)

<br>

<p align="center"><img src="https://raw.githubusercontent.com/HotCakeX/Official-IANA-IP-blocks/main/rir-map.svg" width="500"></p>

<br>

#### [You can use this `CSV` formatted reference file to identify full country names from their abbreviated forms](https://github.com/HotCakeX/Official-IANA-IP-blocks/blob/gh-pages/Country%20Alpha-2%20code%20Alpha-3%20code%20Numeri.csv)

<br>

### Sources used by this GitHub repository (5 Regional Internet Registries in the world)

- **APNIC** ( _[Asia Pacific Network Information Centre](https://www.apnic.net/)_ )
  - https://ftp.apnic.net/stats/apnic/delegated-apnic-latest
- **ARIN** ( _[American Registry for Internet Numbers](https://www.arin.net/)_ )
  - https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest
- **RIPENCC** ( _[Réseaux IP Européens Network Coordination Centre](https://www.ripe.net/)_ )
  - https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest
- **AFRINIC** ( _[African Network Information Centre](https://www.afrinic.net/)_ )
  - https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest
- **LACNIC** ( _[Latin America and Caribbean Network Information Centre](https://www.lacnic.net/)_ )
  - https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest

<br>

You can also use our website to easily get the newest IP addresses for each country in `CIDR` format: https://hotcakex.github.io/Official-IANA-IP-blocks/
