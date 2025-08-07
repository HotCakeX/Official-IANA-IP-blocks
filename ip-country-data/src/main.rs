use anyhow::{Context, Result};
use futures::future::join_all;
use rayon::prelude::*;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::net::{Ipv4Addr, Ipv6Addr};
use std::path::Path;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Package {
    #[serde(rename = "Country")]
    country: String,
    #[serde(rename = "IP")]
    ip: String,
    #[serde(rename = "PrefixLength")]
    prefix_length: String,
    #[serde(rename = "Version")]
    version: String,
}

impl Package {
    fn new(country: String, ip: String, prefix_length: String, version: String) -> Self {
        Self {
            country,
            ip,
            prefix_length,
            version,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
struct CountryInfo {
    country: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    println!("Creating directories");
    create_directories()?;

    let regions_delegated: HashMap<&str, &str> = [
        (
            "delegated-apnic-latest",
            "https://ftp.apnic.net/stats/apnic/delegated-apnic-latest",
        ),
        (
            "delegated-arin-extended-latest",
            "https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest",
        ),
        (
            "delegated-ripencc-latest",
            "https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest",
        ),
        (
            "delegated-afrinic-latest",
            "https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest",
        ),
        (
            "delegated-lacnic-latest",
            "https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest",
        ),
    ]
    .iter()
    .cloned()
    .collect();

    // Download files
    download_files(&regions_delegated).await?;

    // Process files
    let ip_data: Arc<Mutex<Vec<Package>>> = Arc::new(Mutex::new(Vec::new()));
    process_files(&regions_delegated, ip_data.clone()).await?;

    let ip_data_vec: Vec<Package> = ip_data.lock().await.clone();

    println!("Sorting IpData");
    let sorted_ip_data: Vec<Package> = sort_ip_data(ip_data_vec);

    // Export countries list
    println!("Exporting Countries Lists");
    export_countries_list(&sorted_ip_data)?;

    // Export global data
    println!("Exporting Aggregated Global Data");
    export_global_data(&sorted_ip_data)?;

    // Export global IPv4 data
    println!("GlobalIPV4");
    export_global_ipv4_data(&sorted_ip_data)?;

    // Export global IPv6 data
    println!("GlobalIPV6");
    export_global_ipv6_data(&sorted_ip_data)?;

    // Export country-specific IPv4 data
    println!("CountryIPV4");
    export_country_ipv4_data(&sorted_ip_data)?;

    // Export country-specific IPv6 data
    println!("CountryIPV6");
    export_country_ipv6_data(&sorted_ip_data)?;

    // Export curated lists
    println!("Exporting Curated Lists");
    export_curated_lists()?;

    Ok(())
}

fn create_directories() -> Result<()> {
    let directories: [&str; 11] = [
        "./IANASources",
        "./CSV",
        "./CSV/IPV4",
        "./CSV/IPV6",
        "./JSON",
        "./JSON/IPV4",
        "./JSON/IPV6",
        "./TXT",
        "./TXT/IPV4",
        "./TXT/IPV6",
        "./Curated-Lists",
    ];

    for dir in &directories {
        if !Path::new(dir).exists() {
            fs::create_dir_all(dir)
                .with_context(|| format!("Failed to create directory: {}", dir))?;
        }
    }

    Ok(())
}

async fn download_files(regions_delegated: &HashMap<&str, &str>) -> Result<()> {
    let client: reqwest::Client = reqwest::Client::new();
    let download_tasks: Vec<_> = regions_delegated
        .iter()
        .map(|(key, url)| {
            let client_clone: reqwest::Client = client.clone();
            let key_str: String = key.to_string();
            let url_str: String = url.to_string();

            async move {
                println!("Downloading {}", key_str);
                let content: String = client_clone.get(&url_str).send().await?.text().await?;

                let file_path: String = format!("./IANASources/{}.txt", key_str);
                fs::write(&file_path, content)
                    .with_context(|| format!("Failed to write file: {}", file_path))?;

                Ok::<(), anyhow::Error>(())
            }
        })
        .collect();

    let results: Vec<Result<()>> = join_all(download_tasks).await;
    for result in results {
        result?;
    }

    Ok(())
}

async fn process_files(
    regions_delegated: &HashMap<&str, &str>,
    ip_data: Arc<Mutex<Vec<Package>>>,
) -> Result<()> {
    let pattern: &str = r"allocated|assigned";
    let regex: Regex = Regex::new(pattern)?;

    let process_tasks: Vec<_> = regions_delegated
        .keys()
        .map(|key| {
            let key_str: String = key.to_string();
            let regex_clone: Regex = regex.clone();
            let ip_data_clone: Arc<Mutex<Vec<Package>>> = ip_data.clone();

            async move {
                println!("{}", key_str);

                let file_path: String = format!("./IANASources/{}.txt", key_str);
                let content: String = fs::read_to_string(&file_path)
                    .with_context(|| format!("Failed to read file: {}", file_path))?;

                let mut local_packages: Vec<Package> = Vec::new();

                for line in content.lines() {
                    if regex_clone.is_match(line) {
                        let split: Vec<&str> = line.split('|').collect();
                        if split.len() >= 5 {
                            // Filter out empty or whitespace-only country codes
                            let country: &str = split[1].trim();
                            if country.is_empty() {
                                continue;
                            }

                            match split[2] {
                                "ipv4" => {
                                    if let Ok(count) = split[4].parse::<f64>() {
                                        let prefix_length: String =
                                            (32.0 - count.log2()).round().to_string();
                                        local_packages.push(Package::new(
                                            country.to_string(),
                                            split[3].to_string(),
                                            prefix_length,
                                            split[2].to_string(),
                                        ));
                                    }
                                }
                                "ipv6" => {
                                    local_packages.push(Package::new(
                                        country.to_string(),
                                        split[3].to_string(),
                                        split[4].to_string(),
                                        split[2].to_string(),
                                    ));
                                }
                                _ => {}
                            }
                        }
                    }
                }

                let mut ip_data_guard = ip_data_clone.lock().await;
                ip_data_guard.extend(local_packages);

                Ok::<(), anyhow::Error>(())
            }
        })
        .collect();

    let results: Vec<Result<()>> = join_all(process_tasks).await;
    for result in results {
        result?;
    }

    Ok(())
}

fn sort_ip_data(mut ip_data: Vec<Package>) -> Vec<Package> {
    ip_data.sort_by(|a, b| {
        // First sort by country
        let country_cmp = a.country.cmp(&b.country);
        if country_cmp != std::cmp::Ordering::Equal {
            return country_cmp;
        }

        // Then sort by version
        let version_cmp = a.version.cmp(&b.version);
        if version_cmp != std::cmp::Ordering::Equal {
            return version_cmp;
        }

        // Finally sort by IP address
        match a.version.as_str() {
            "ipv4" => {
                let ip_a: Result<Ipv4Addr, _> = a.ip.parse();
                let ip_b: Result<Ipv4Addr, _> = b.ip.parse();
                match (ip_a, ip_b) {
                    (Ok(addr_a), Ok(addr_b)) => addr_a.cmp(&addr_b),
                    _ => a.ip.cmp(&b.ip),
                }
            }
            "ipv6" => {
                let ip_a: Result<Ipv6Addr, _> = a.ip.parse();
                let ip_b: Result<Ipv6Addr, _> = b.ip.parse();
                match (ip_a, ip_b) {
                    (Ok(addr_a), Ok(addr_b)) => addr_a.cmp(&addr_b),
                    _ => a.ip.cmp(&b.ip),
                }
            }
            _ => a.ip.cmp(&b.ip),
        }
    });

    ip_data
}

fn export_countries_list(sorted_ip_data: &[Package]) -> Result<()> {
    let mut countries: Vec<String> = sorted_ip_data
        .iter()
        .map(|p| p.country.clone())
        .filter(|country| !country.trim().is_empty()) // Filter out empty countries
        .collect();
    countries.sort();
    countries.dedup();

    let countries_info: Vec<CountryInfo> = countries
        .iter()
        .map(|country| CountryInfo {
            country: country.clone(),
        })
        .collect();

    // Export CSV
    let mut csv_writer = csv::Writer::from_path("./CSV/countries.csv")?;
    for country in &countries_info {
        csv_writer.serialize(country)?;
    }
    csv_writer.flush()?;

    // Export JSON
    let json_content: String = serde_json::to_string_pretty(&countries_info)?;
    fs::write("./JSON/countries.json", json_content)?;

    // Export TXT
    let txt_content: String = countries.join("\r\n");
    fs::write("./TXT/countries.txt", txt_content)?;

    Ok(())
}

fn export_global_data(sorted_ip_data: &[Package]) -> Result<()> {
    // Export CSV
    let mut csv_writer = csv::Writer::from_path("./CSV/global.csv")?;
    for package in sorted_ip_data {
        csv_writer.serialize(package)?;
    }
    csv_writer.flush()?;

    // Export JSON
    let json_content: String = serde_json::to_string_pretty(sorted_ip_data)?;
    fs::write("./JSON/global.json", json_content)?;

    // Export compressed JSON
    let json_compressed: String = serde_json::to_string(sorted_ip_data)?;
    fs::write("./JSON/global_compressed.json", json_compressed)?;

    Ok(())
}

fn export_global_ipv4_data(sorted_ip_data: &[Package]) -> Result<()> {
    let ipv4_data: Vec<&Package> = sorted_ip_data
        .iter()
        .filter(|p| p.version == "ipv4")
        .collect();

    // Export CSV
    let mut csv_writer = csv::Writer::from_path("./CSV/global_ipv4.csv")?;
    for package in &ipv4_data {
        csv_writer.serialize(package)?;
    }
    csv_writer.flush()?;

    // Export JSON
    let json_content: String = serde_json::to_string_pretty(&ipv4_data)?;
    fs::write("./JSON/global_ipv4.json", json_content)?;

    // Export compressed JSON
    let json_compressed: String = serde_json::to_string(&ipv4_data)?;
    fs::write("./JSON/global_ipv4_compressed.json", json_compressed)?;

    Ok(())
}

fn export_global_ipv6_data(sorted_ip_data: &[Package]) -> Result<()> {
    let ipv6_data: Vec<&Package> = sorted_ip_data
        .iter()
        .filter(|p| p.version == "ipv6")
        .collect();

    // Export CSV
    let mut csv_writer = csv::Writer::from_path("./CSV/global_ipv6.csv")?;
    for package in &ipv6_data {
        csv_writer.serialize(package)?;
    }
    csv_writer.flush()?;

    // Export JSON
    let json_content: String = serde_json::to_string_pretty(&ipv6_data)?;
    fs::write("./JSON/global_ipv6.json", json_content)?;

    // Export compressed JSON
    let json_compressed: String = serde_json::to_string(&ipv6_data)?;
    fs::write("./JSON/global_ipv6_compressed.json", json_compressed)?;

    Ok(())
}

fn export_country_ipv4_data(sorted_ip_data: &[Package]) -> Result<()> {
    let ipv4_data: Vec<&Package> = sorted_ip_data
        .iter()
        .filter(|p| p.version == "ipv4")
        .collect();

    // Group by country
    let mut country_groups: BTreeMap<String, Vec<&Package>> = BTreeMap::new();
    for package in ipv4_data {
        country_groups
            .entry(package.country.clone())
            .or_insert_with(Vec::new)
            .push(package);
    }

    // Process each country in parallel
    country_groups
        .par_iter()
        .try_for_each(|(country, packages)| -> Result<()> {
            // Export CSV
            let csv_path: String = format!("./CSV/IPV4/{}.csv", country);
            let mut csv_writer = csv::Writer::from_path(&csv_path)?;
            for package in packages {
                csv_writer.serialize(package)?;
            }
            csv_writer.flush()?;

            // Export JSON
            let json_path: String = format!("./JSON/IPV4/{}.json", country);
            let json_content: String = serde_json::to_string_pretty(packages)?;
            fs::write(&json_path, json_content)?;

            // Export TXT
            let txt_path: String = format!("./TXT/IPV4/{}.txt", country);
            let txt_content: String = packages
                .iter()
                .map(|p| format!("{}/{}", p.ip, p.prefix_length))
                .collect::<Vec<String>>()
                .join("\r\n");
            fs::write(&txt_path, txt_content)?;

            Ok(())
        })?;

    Ok(())
}

fn export_country_ipv6_data(sorted_ip_data: &[Package]) -> Result<()> {
    let ipv6_data: Vec<&Package> = sorted_ip_data
        .iter()
        .filter(|p| p.version == "ipv6")
        .collect();

    // Group by country
    let mut country_groups: BTreeMap<String, Vec<&Package>> = BTreeMap::new();
    for package in ipv6_data {
        country_groups
            .entry(package.country.clone())
            .or_insert_with(Vec::new)
            .push(package);
    }

    // Process each country in parallel
    country_groups
        .par_iter()
        .try_for_each(|(country, packages)| -> Result<()> {
            // Export CSV
            let csv_path: String = format!("./CSV/IPV6/{}.csv", country);
            let mut csv_writer = csv::Writer::from_path(&csv_path)?;
            for package in packages {
                csv_writer.serialize(package)?;
            }
            csv_writer.flush()?;

            // Export JSON
            let json_path: String = format!("./JSON/IPV6/{}.json", country);
            let json_content: String = serde_json::to_string_pretty(packages)?;
            fs::write(&json_path, json_content)?;

            // Export TXT with CRLF line endings
            let txt_path: String = format!("./TXT/IPV6/{}.txt", country);
            let txt_content: String = packages
                .iter()
                .map(|p| format!("{}/{}", p.ip, p.prefix_length))
                .collect::<Vec<String>>()
                .join("\r\n");
            fs::write(&txt_path, txt_content)?;

            Ok(())
        })?;

    Ok(())
}

/// Read the specified TXT/IPV4 and TXT/IPV6 files for each code,
/// concatenate their lines, and write two output files under ./Curated-Lists
/// with CRLF line endings.
fn export_curated_lists() -> Result<()> {
    // 1) Ensure output dir exists
    let curated_dir = "./Curated-Lists";
    if !Path::new(curated_dir).exists() {
        fs::create_dir_all(curated_dir)
            .with_context(|| format!("Failed to create directory: {}", curated_dir))?;
    }

    // 2) Codes for each list
    let terror_codes: [&str; 4] = ["IR", "CU", "KP", "SY"];
    let ofac_codes: [&str; 18] = [
        "IR", "CU", "KP", "SY", "RU", "BY", "YE", "IQ", "MM", "CF", "CD", "ET", "HK", "LB", "LY",
        "SD", "VE", "ZW",
    ];

    // Helper to collect lines for a given set of codes
    let mut state_lines: Vec<String> = Vec::new();
    for &code in &terror_codes {
        // IPv4
        let v4 = format!("./TXT/IPV4/{}.txt", code);
        if let Ok(txt) = fs::read_to_string(&v4) {
            state_lines.extend(txt.lines().map(String::from));
        }
        // IPv6 — note North Korea uses KN in the IPv6 folder
        let ipv6_code = if code == "KP" { "KN" } else { code };
        let v6 = format!("./TXT/IPV6/{}.txt", ipv6_code);
        if let Ok(txt) = fs::read_to_string(&v6) {
            state_lines.extend(txt.lines().map(String::from));
        }
    }
    // Write StateSponsorsOfTerrorism.txt with CRLF line endings and a trailing CRLF
    let state_content = state_lines.join("\r\n") + "\r\n";
    fs::write(
        "./Curated-Lists/StateSponsorsOfTerrorism.txt",
        state_content,
    )?;

    // Repeat for OFACSanctioned
    let mut ofac_lines: Vec<String> = Vec::new();
    for &code in &ofac_codes {
        let v4 = format!("./TXT/IPV4/{}.txt", code);
        if let Ok(txt) = fs::read_to_string(&v4) {
            ofac_lines.extend(txt.lines().map(String::from));
        }
        let ipv6_code = if code == "KP" { "KN" } else { code };
        let v6 = format!("./TXT/IPV6/{}.txt", ipv6_code);
        if let Ok(txt) = fs::read_to_string(&v6) {
            ofac_lines.extend(txt.lines().map(String::from));
        }
    }
    let ofac_content = ofac_lines.join("\r\n") + "\r\n";
    fs::write("./Curated-Lists/OFACSanctioned.txt", ofac_content)?;

    Ok(())
}
