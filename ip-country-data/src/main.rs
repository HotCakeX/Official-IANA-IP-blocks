mod download;

use regex::Regex;
use serde::Serialize;
use std::borrow::Cow;
use std::collections::HashMap;
use std::error::Error;
use std::fs;
use std::net::{Ipv4Addr, Ipv6Addr};
use std::path::Path;
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering as AtomicOrdering};
use std::thread;

type Result<T> = std::result::Result<T, Box<dyn Error + Send + Sync>>;

/// Adds a human readable context message to an error.
trait Context<T> {
    fn context(self, message: impl FnOnce() -> String) -> Result<T>;
}

impl<T, E: Error + Send + Sync + 'static> Context<T> for std::result::Result<T, E> {
    fn context(self, message: impl FnOnce() -> String) -> Result<T> {
        self.map_err(|e| format!("{}: {}", message(), e).into())
    }
}

const IPV4: &str = "ipv4";
const IPV6: &str = "ipv6";

const REGIONS_DELEGATED: [(&str, &str); 5] = [
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
];

/// Prefix lengths 0..=32 as strings so IPv4 records do not need an allocation each.
const PREFIX_STRINGS: [&str; 33] = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16",
    "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32",
];

#[derive(Debug, Serialize)]
struct Package<'a> {
    #[serde(rename = "Country")]
    country: &'a str,
    #[serde(rename = "IP")]
    ip: &'a str,
    #[serde(rename = "PrefixLength")]
    prefix_length: Cow<'a, str>,
    #[serde(rename = "Version")]
    version: &'static str,
    /// Numeric value of the parsed IP address, used for sorting only.
    #[serde(skip)]
    address: Option<u128>,
    /// Rank of the country and version combination, used for sorting only.
    #[serde(skip)]
    group_rank: u32,
}

#[derive(Debug, Serialize)]
struct CountryInfo<'a> {
    country: &'a str,
}

fn main() -> Result<()> {
    // --offline processes the existing files in ./IANASources instead of downloading them.
    let offline: bool = std::env::args()
        .skip(1)
        .any(|arg| arg.eq_ignore_ascii_case("--offline"));

    println!("Creating directories");
    create_directories()?;

    // Download files
    let contents: Vec<String> = download_files(offline)?;

    // Process files
    let ip_data: Vec<Package> = process_files(&contents)?;

    println!("Sorting IpData");
    let sorted_ip_data: Vec<Package> = sort_ip_data(ip_data);

    println!("Exporting Countries Lists");
    println!("Exporting Aggregated Global Data");
    println!("GlobalIPV4");
    println!("GlobalIPV6");
    println!("CountryIPV4");
    println!("CountryIPV6");
    export_all(&sorted_ip_data)?;

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
            fs::create_dir_all(dir).context(|| format!("Failed to create directory: {}", dir))?;
        }
    }

    Ok(())
}

/// Decodes a response body for UTF-8 content: a leading BOM is removed and invalid sequences are replaced with U+FFFD.
fn decode_text(mut bytes: Vec<u8>) -> String {
    if bytes.starts_with(b"\xEF\xBB\xBF") {
        bytes.drain(..3);
    }
    match String::from_utf8(bytes) {
        Ok(text) => text,
        Err(e) => String::from_utf8_lossy(e.as_bytes()).into_owned(),
    }
}

/// Downloads all of the sources in parallel and saves them to ./IANASources.
/// Returns the content of each source in the order of REGIONS_DELEGATED.
fn download_files(offline: bool) -> Result<Vec<String>> {
    thread::scope(|scope| {
        let handles: Vec<_> = REGIONS_DELEGATED
            .iter()
            .map(|&(key, url)| {
                scope.spawn(move || -> Result<String> {
                    let file_path: String = format!("./IANASources/{}.txt", key);

                    if offline {
                        return fs::read_to_string(&file_path)
                            .context(|| format!("Failed to read file: {}", file_path));
                    }

                    println!("Downloading {}", key);
                    let body: Vec<u8> =
                        download::get(url).context(|| format!("Failed to download: {}", url))?;
                    let content: String = decode_text(body);

                    fs::write(&file_path, &content)
                        .context(|| format!("Failed to write file: {}", file_path))?;

                    Ok(content)
                })
            })
            .collect();

        handles
            .into_iter()
            .map(|handle| handle.join().map_err(|_| "Download thread panicked")?)
            .collect()
    })
}

fn process_files(contents: &[String]) -> Result<Vec<Package<'_>>> {
    let regex: Regex = Regex::new(r"allocated|assigned")?;

    let per_region: Vec<Vec<Package>> = thread::scope(|scope| {
        let handles: Vec<_> = REGIONS_DELEGATED
            .iter()
            .zip(contents)
            .map(|(&(key, _), content)| {
                let regex: &Regex = &regex;
                scope.spawn(move || {
                    println!("{}", key);
                    parse_source(content, regex)
                })
            })
            .collect();

        handles
            .into_iter()
            .map(|handle| handle.join().map_err(|_| "Processing thread panicked".into()))
            .collect::<Result<Vec<_>>>()
    })?;

    let mut ip_data: Vec<Package> = Vec::with_capacity(per_region.iter().map(Vec::len).sum());
    for packages in per_region {
        ip_data.extend(packages);
    }

    Ok(ip_data)
}

fn parse_source<'a>(content: &'a str, regex: &Regex) -> Vec<Package<'a>> {
    let mut packages: Vec<Package<'a>> = Vec::new();

    for line in content.lines() {
        if !regex.is_match(line) {
            continue;
        }

        let mut split = line.split('|');
        let (Some(_), Some(country), Some(version), Some(ip), Some(value)) = (
            split.next(),
            split.next(),
            split.next(),
            split.next(),
            split.next(),
        ) else {
            continue;
        };

        // Filter out empty or whitespace-only country codes
        let country: &str = country.trim();
        if country.is_empty() {
            continue;
        }

        match version {
            IPV4 => {
                if let Ok(count) = value.parse::<f64>() {
                    let prefix: f64 = (32.0 - count.log2()).round();
                    let prefix_length: Cow<'a, str> =
                        if prefix.is_sign_positive() && prefix <= 32.0 && prefix.fract() == 0.0 {
                            Cow::Borrowed(PREFIX_STRINGS[prefix as usize])
                        } else {
                            Cow::Owned(prefix.to_string())
                        };
                    packages.push(Package {
                        country,
                        ip,
                        prefix_length,
                        version: IPV4,
                        address: ip.parse::<Ipv4Addr>().ok().map(|a| u32::from(a) as u128),
                        group_rank: 0,
                    });
                }
            }
            IPV6 => {
                packages.push(Package {
                    country,
                    ip,
                    prefix_length: Cow::Borrowed(value),
                    version: IPV6,
                    address: ip.parse::<Ipv6Addr>().ok().map(u128::from),
                    group_rank: 0,
                });
            }
            _ => {}
        }
    }

    packages
}

/// Sorts by country, then version, then IP address.
/// IP addresses are parsed once during processing rather than on every comparison and
/// country + version pairs are replaced with a numeric rank that preserves their order.
fn sort_ip_data(mut ip_data: Vec<Package>) -> Vec<Package> {
    let mut countries: Vec<&str> = ip_data.iter().map(|p| p.country).collect();
    countries.sort_unstable();
    countries.dedup();
    let ranks: HashMap<&str, u32> = countries
        .iter()
        .enumerate()
        .map(|(rank, &country)| (country, rank as u32))
        .collect();

    for p in &mut ip_data {
        // "ipv4" sorts before "ipv6"
        p.group_rank = ranks[p.country] * 2 + u32::from(p.version == IPV6);
    }

    ip_data.sort_by(|a, b| {
        a.group_rank
            .cmp(&b.group_rank)
            .then_with(|| match (a.address, b.address) {
                (Some(addr_a), Some(addr_b)) => addr_a.cmp(&addr_b),
                _ => a.ip.cmp(b.ip),
            })
    });

    ip_data
}

fn to_csv<T: Serialize>(records: impl IntoIterator<Item = T>, capacity: usize) -> Result<Vec<u8>> {
    let mut csv_writer = csv::Writer::from_writer(Vec::with_capacity(capacity));
    for record in records {
        csv_writer.serialize(record)?;
    }
    csv_writer.into_inner().map_err(|e| e.into_error().into())
}

fn to_json_pretty<T: Serialize + ?Sized>(value: &T, capacity: usize) -> Result<Vec<u8>> {
    let mut buffer: Vec<u8> = Vec::with_capacity(capacity);
    serde_json::to_writer_pretty(&mut buffer, value)?;
    Ok(buffer)
}

fn to_json<T: Serialize + ?Sized>(value: &T, capacity: usize) -> Result<Vec<u8>> {
    let mut buffer: Vec<u8> = Vec::with_capacity(capacity);
    serde_json::to_writer(&mut buffer, value)?;
    Ok(buffer)
}

fn write_file(path: &str, content: &[u8]) -> Result<()> {
    fs::write(path, content).context(|| format!("Failed to write file: {}", path))
}

/// Writes the CSV, JSON and TXT files of a single country and IP version.
fn export_country_data(packages: &[Package]) -> Result<()> {
    let country: &str = packages[0].country;
    let folder: &str = if packages[0].version == IPV4 {
        "IPV4"
    } else {
        "IPV6"
    };

    write_file(
        &format!("./CSV/{}/{}.csv", folder, country),
        &to_csv(packages, packages.len() * 48)?,
    )?;

    write_file(
        &format!("./JSON/{}/{}.json", folder, country),
        &to_json_pretty(packages, packages.len() * 128)?,
    )?;

    // TXT with CRLF line endings and no trailing line break
    let mut txt_content: Vec<u8> = Vec::with_capacity(packages.len() * 48);
    for (i, p) in packages.iter().enumerate() {
        if i > 0 {
            txt_content.extend_from_slice(b"\r\n");
        }
        txt_content.extend_from_slice(p.ip.as_bytes());
        txt_content.push(b'/');
        txt_content.extend_from_slice(p.prefix_length.as_bytes());
    }
    write_file(&format!("./TXT/{}/{}.txt", folder, country), &txt_content)
}

fn export_countries_list(sorted_ip_data: &[Package]) -> Result<()> {
    // The data is sorted by country so removing consecutive duplicates yields a sorted unique list.
    let mut countries: Vec<&str> = sorted_ip_data
        .iter()
        .map(|p| p.country)
        .filter(|country| !country.trim().is_empty()) // Filter out empty countries
        .collect();
    countries.dedup();

    let countries_info: Vec<CountryInfo> = countries
        .iter()
        .map(|&country| CountryInfo { country })
        .collect();

    // Export CSV
    write_file(
        "./CSV/countries.csv",
        &to_csv(&countries_info, countries_info.len() * 4 + 8)?,
    )?;

    // Export JSON
    write_file(
        "./JSON/countries.json",
        &to_json_pretty(&countries_info, countries_info.len() * 32)?,
    )?;

    // Export TXT
    write_file("./TXT/countries.txt", countries.join("\r\n").as_bytes())
}

type Job<'a> = Box<dyn FnOnce() -> Result<()> + Send + 'a>;

/// Writes every global and country specific output file, spreading the work over all CPU cores.
fn export_all(sorted_ip_data: &[Package]) -> Result<()> {
    let ipv4_data: Vec<&Package> = sorted_ip_data
        .iter()
        .filter(|p| p.version == IPV4)
        .collect();
    let ipv6_data: Vec<&Package> = sorted_ip_data
        .iter()
        .filter(|p| p.version == IPV6)
        .collect();
    let all_len: usize = sorted_ip_data.len();
    let ipv4_data: &[&Package] = &ipv4_data;
    let ipv6_data: &[&Package] = &ipv6_data;

    // The largest jobs are queued first so the work is evenly balanced across threads.
    let mut jobs: Vec<Job> = vec![
        Box::new(move || {
            write_file(
                "./JSON/global.json",
                &to_json_pretty(sorted_ip_data, all_len * 128)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./JSON/global_ipv4.json",
                &to_json_pretty(ipv4_data, ipv4_data.len() * 128)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./JSON/global_compressed.json",
                &to_json(sorted_ip_data, all_len * 96)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./JSON/global_ipv6.json",
                &to_json_pretty(ipv6_data, ipv6_data.len() * 128)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./JSON/global_ipv4_compressed.json",
                &to_json(ipv4_data, ipv4_data.len() * 96)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./CSV/global.csv",
                &to_csv(sorted_ip_data, all_len * 48)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./JSON/global_ipv6_compressed.json",
                &to_json(ipv6_data, ipv6_data.len() * 96)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./CSV/global_ipv4.csv",
                &to_csv(ipv4_data, ipv4_data.len() * 48)?,
            )
        }),
        Box::new(move || {
            write_file(
                "./CSV/global_ipv6.csv",
                &to_csv(ipv6_data, ipv6_data.len() * 48)?,
            )
        }),
        Box::new(move || export_countries_list(sorted_ip_data)),
    ];

    // The sorted data is grouped by country and version, so each group is a contiguous slice.
    let mut groups: Vec<&[Package]> = sorted_ip_data
        .chunk_by(|a, b| a.country == b.country && a.version == b.version)
        .collect();
    groups.sort_by_key(|group| std::cmp::Reverse(group.len()));
    jobs.extend(
        groups
            .into_iter()
            .map(|group| Box::new(move || export_country_data(group)) as Job),
    );

    run_jobs(jobs)
}

/// Runs the jobs on a pool of scoped threads and returns the first error, if any.
fn run_jobs(jobs: Vec<Job>) -> Result<()> {
    let jobs: Vec<Mutex<Option<Job>>> = jobs.into_iter().map(|j| Mutex::new(Some(j))).collect();
    let next: AtomicUsize = AtomicUsize::new(0);
    let thread_count: usize = thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .min(jobs.len())
        .max(1);

    thread::scope(|scope| {
        let handles: Vec<_> = (0..thread_count)
            .map(|_| {
                scope.spawn(|| -> Result<()> {
                    loop {
                        let index: usize = next.fetch_add(1, AtomicOrdering::Relaxed);
                        let Some(slot) = jobs.get(index) else {
                            return Ok(());
                        };
                        let job: Option<Job> = slot.lock().map_err(|_| "Job lock poisoned")?.take();
                        if let Some(job) = job {
                            job()?;
                        }
                    }
                })
            })
            .collect();

        let mut first_error: Option<Box<dyn Error + Send + Sync>> = None;
        for handle in handles {
            let result: Result<()> = handle
                .join()
                .unwrap_or_else(|_| Err("Export thread panicked".into()));
            if let Err(e) = result {
                first_error.get_or_insert(e);
            }
        }
        first_error.map_or(Ok(()), Err)
    })
}

/// Appends every line of the given TXT file, each followed by CRLF.
fn append_lines(path: &str, output: &mut String) {
    if let Ok(txt) = fs::read_to_string(path) {
        for line in txt.lines() {
            output.push_str(line);
            output.push_str("\r\n");
        }
    }
}

/// Read the specified TXT/IPV4 and TXT/IPV6 files for each code,
/// concatenate their lines, and write two output files under ./Curated-Lists
/// with CRLF line endings.
fn build_curated_list(codes: &[&str]) -> String {
    let mut content: String = String::new();
    for &code in codes {
        // IPv4
        append_lines(&format!("./TXT/IPV4/{}.txt", code), &mut content);
        // IPv6 — note North Korea uses KN in the IPv6 folder
        let ipv6_code: &str = if code == "KP" { "KN" } else { code };
        append_lines(&format!("./TXT/IPV6/{}.txt", ipv6_code), &mut content);
    }
    // Lines are joined with CRLF and the file always ends with a trailing CRLF
    if content.is_empty() {
        content.push_str("\r\n");
    }
    content
}

fn export_curated_lists() -> Result<()> {
    // 1) Ensure output dir exists
    let curated_dir: &str = "./Curated-Lists";
    if !Path::new(curated_dir).exists() {
        fs::create_dir_all(curated_dir)
            .context(|| format!("Failed to create directory: {}", curated_dir))?;
    }

    // 2) Codes for each list
    let terror_codes: [&str; 4] = ["IR", "CU", "KP", "SY"];
    let ofac_codes: [&str; 18] = [
        "IR", "CU", "KP", "SY", "RU", "BY", "YE", "IQ", "MM", "CF", "CD", "ET", "HK", "LB", "LY",
        "SD", "VE", "ZW",
    ];

    write_file(
        "./Curated-Lists/StateSponsorsOfTerrorism.txt",
        build_curated_list(&terror_codes).as_bytes(),
    )?;
    write_file(
        "./Curated-Lists/OFACSanctioned.txt",
        build_curated_list(&ofac_codes).as_bytes(),
    )
}
