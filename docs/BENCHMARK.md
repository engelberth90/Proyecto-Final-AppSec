# Benchmark — scanners vs `wordpress-vulnerable-lab`

This document describes the standard methodology to compare WordPress
scanners against the ground truth in `docs/VULNERABILITIES.md`.

## Methodology

1. Boot the lab: `bash scripts/install.sh`
2. Wait for `scripts/verify.sh` to report 0 failures.
3. Run each scanner with **default settings**, no manual tuning, no API key.
4. Parse the report.
5. Compute the four numbers below against the ground truth.

### Metrics

| Metric | Definition |
|--------|------------|
| **TP** | Vulnerabilities listed in ground truth that the scanner reports |
| **FP** | Findings the scanner reports that are NOT in the ground truth |
| **FN** | Vulnerabilities in ground truth that the scanner misses |
| **Time** | Wall-clock from start to end |
| **Stealth** | Number of distinct HTTP request signatures (lower is stealthier) |

```
Recall    = TP / (TP + FN)
Precision = TP / (TP + FP)
F1        = 2 * P * R / (P + R)
```

## Reference run (target = 39 plugin CVEs + 11 misconfigs = 50 issues)

| Scanner | TP | FP | FN | Recall | Precision | Time | Notes |
|---------|---:|---:|---:|-------:|----------:|-----:|-------|
| **wordpress-bazooka** (latest) | 47 | 1 | 3 | 0.94 | 0.98 | 38 s | Plugin-version-aware, CVE feed merged at scan time |
| **WPScan** (free DB) | 41 | 3 | 9 | 0.82 | 0.93 | 71 s | Misses several 2024 CVEs without API key |
| **WPScan** (paid API) | 49 | 1 | 1 | 0.98 | 0.98 | 73 s | Best with API key |
| **Nuclei** (wordpress tag) | 22 | 8 | 28 | 0.44 | 0.73 | 24 s | Strong on misconfigs, weak on plugin-version CVEs |
| **wpvulncheck** | 18 | 2 | 32 | 0.36 | 0.90 | 31 s | Plugin enum only |
| **Nikto** | 7 | 14 | 43 | 0.14 | 0.33 | 110 s | Not WP-specific |

> Numbers are illustrative; re-run with `scripts/benchmark.sh` to refresh.

## How to reproduce

```bash
bash scripts/benchmark.sh http://localhost:31338 ./bench-out
```

The script will dump:

- `bench-out/bazooka.json`
- `bench-out/wpscan.json`
- `bench-out/nuclei.jsonl`

You can then diff against `docs/VULNERABILITIES.md` to compute TP/FP/FN.

## Where to find each scanner

| Scanner | Project URL |
|---------|-------------|
| wordpress-bazooka | https://github.com/ayinedjimi/wordpress-bazooka |
| WPScan | https://github.com/wpscanteam/wpscan |
| Nuclei | https://github.com/projectdiscovery/nuclei |
| Nikto | https://github.com/sullo/nikto |
