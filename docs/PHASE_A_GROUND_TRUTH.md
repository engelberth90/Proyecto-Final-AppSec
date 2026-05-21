# Phase A — Ground Truth Fragment

**Lab**: `wordpress-vulnerable-lab`
**Phase**: A (extended 2024-2025 CVE coverage)
**Default URL**: http://localhost:31338
**Maintainer**: Ayi NEDJIMI
**Date**: 2026-05

This fragment lists the **15 plugins** and **5 themes** added in Phase A on top of
the baseline catalog in `docs/VULNERABILITIES.md`. All entries are pinned to
versions that fall strictly within a publicly documented vulnerable range
(verified against the wpvulnerability.net feed and NVD).

> CVE ids follow the canonical `CVE-YYYY-NNNNN` format. Every CVE listed below
> was published in 2024 or 2025.

## How to verify

```bash
curl -sI http://localhost:31338/wp-content/plugins/<slug>/readme.txt   # expect 200
curl -sI http://localhost:31338/wp-content/themes/<slug>/style.css     # expect 200
```

```bash
docker exec -u root wpvl-wordpress \
  wp --path=/var/www/html --allow-root plugin list --format=table
docker exec -u root wpvl-wordpress \
  wp --path=/var/www/html --allow-root theme list --format=table
```

## Plugin matrix (Phase A additions)

Legend: **RCE** remote code exec | **AFU** arbitrary file upload | **SQLi** SQL
injection | **XSS** cross-site scripting | **PE** privilege escalation |
**AB** auth bypass | **BAC** broken access control | **IDOR** insecure
direct object reference | **LFI** local file inclusion | **SSRF** server-side
request forgery | **OR** open redirect | **Deser** PHP object deserialization.

| # | Slug | Version | CVE | CVSS | Type | Repro hint |
|---|------|---------|-----|------|------|------------|
| 1  | wp-automatic | 3.92.0 | [CVE-2024-27956](https://nvd.nist.gov/vuln/detail/CVE-2024-27956) | 9.8 | SQLi -> AdminCreate | `POST /wp-content/plugins/wp-automatic/inc/csv.php` with crafted `auth` query, then INSERT into `wp_users` to seed an admin |
| 2  | masterstudy-lms-learning-management-system | 3.2.5 | [CVE-2024-1512](https://nvd.nist.gov/vuln/detail/CVE-2024-1512) | 8.8 | BAC / PE | Subscriber-auth call to `stm_lms_register_user` REST route promotes self to instructor/admin |
| 3  | fluent-smtp | 2.2.80 | [CVE-2024-9511](https://nvd.nist.gov/vuln/detail/CVE-2024-9511) | 8.8 | BAC | Subscriber can hit `/wp-admin/admin-ajax.php?action=fluentsmtp-admin-ajax-actions` to read/modify SMTP creds |
| 4  | otter-blocks | 2.6.4 | [CVE-2024-2226](https://nvd.nist.gov/vuln/detail/CVE-2024-2226) | 6.4 | Stored XSS | Contributor injects payload via Otter `form-input` block attribute, fires on post view |
| 5  | nextend-facebook-connect | 3.1.12 | [CVE-2024-1775](https://nvd.nist.gov/vuln/detail/CVE-2024-1775) | 9.8 | AB | Forged OAuth `state` allows logging in as arbitrary account via `/wp-login.php?loginSocial=facebook` |
| 6  | download-manager | 3.2.98 | [CVE-2024-8284](https://nvd.nist.gov/vuln/detail/CVE-2024-8284) | 7.5 | LFI / IDOR | `?wpdmpro-download=../../wp-config.php` via download endpoint reveals arbitrary files |
| 7  | wp-ultimate-csv-importer | 7.20.0 | [CVE-2025-2007](https://nvd.nist.gov/vuln/detail/CVE-2025-2007) | 9.9 | AFU -> RCE | Authd (subscriber+) upload of PHP file disguised as CSV via `wp-admin/admin-ajax.php?action=wp_uci_uploader` |
| 8  | mailpoet | 5.5.1 | [CVE-2024-12743](https://nvd.nist.gov/vuln/detail/CVE-2024-12743) | 6.4 | Stored XSS | Contributor crafts a newsletter block with malicious `href`, payload renders in preview/inbox |
| 9  | wp-job-manager | 2.2.0 | [CVE-2024-34549](https://nvd.nist.gov/vuln/detail/CVE-2024-34549) | 5.3 | BAC | Unauth `GET /?job_application=NN&download_resume=1` exfiltrates uploaded resumes |
| 10 | seo-by-rank-math | 1.0.228 | [CVE-2024-9161](https://nvd.nist.gov/vuln/detail/CVE-2024-9161) | 6.1 | OR / SSRF | `?rank_math_redirection=https://attacker.tld` bypasses host allowlist |
| 11 | jetpack | 13.8 | [CVE-2024-9926](https://nvd.nist.gov/vuln/detail/CVE-2024-9926) | 6.4 | BAC | Contact-form submissions readable by any logged-in user via Jetpack feedback module |
| 12 | wp-recall | 16.26.5 | [CVE-2024-32709](https://nvd.nist.gov/vuln/detail/CVE-2024-32709) | 8.5 | SQLi (authd) | Subscriber crafts `id` param to `wp-admin/admin-ajax.php?action=rcl_chat_messages_get` for time-based SQLi |
| 13 | wp-time-capsule | 1.22.20 | [CVE-2024-38770](https://nvd.nist.gov/vuln/detail/CVE-2024-38770) | 9.8 | Deserialization | Unauth POST to `/wp-content/plugins/wp-time-capsule/wp-tcapsule-bridge/upload/php/index.php` triggers unsafe `unserialize()` |
| 14 | ws-form | 1.9.243 | [CVE-2024-47320](https://nvd.nist.gov/vuln/detail/CVE-2024-47320) | 6.4 | Stored XSS | Contributor stores payload in form `label` attribute; renders when admin views submissions |
| 15 | simple-membership | 4.4.1 | [CVE-2024-22308](https://nvd.nist.gov/vuln/detail/CVE-2024-22308) | 8.8 | AB | `swpm_login` action accepts forged member id parameter, bypassing password check |

## Theme matrix (Phase A additions)

Only **hello-elementor** is activated; the other four are installed-but-inactive
yet remain fingerprintable via `/wp-content/themes/<slug>/style.css`.

| # | Slug | Version | CVE | CVSS | Type | Activated | Repro hint |
|---|------|---------|-----|------|------|-----------|------------|
| 1 | hello-elementor | 3.0.0 | [CVE-2024-31289](https://nvd.nist.gov/vuln/detail/CVE-2024-31289) | 6.4 | Stored XSS | yes | Contributor injects payload via `header_layout` customizer field; renders on every page |
| 2 | astra | 4.6.8 | [CVE-2024-2347](https://nvd.nist.gov/vuln/detail/CVE-2024-2347) | 4.3 | Stored XSS | no | Authd `astra-sites-import` endpoint accepts unsanitized HTML in starter site title |
| 3 | blocksy | 2.0.40 | [CVE-2024-3747](https://nvd.nist.gov/vuln/detail/CVE-2024-3747) | 6.4 | Stored XSS | no | Contributor stores payload in Blocksy About/Team block `name` field |
| 4 | oceanwp | 3.5.4 | [CVE-2024-2476](https://nvd.nist.gov/vuln/detail/CVE-2024-2476) | 6.4 | Stored XSS | no | Contributor injects payload in OceanWP icon-box shortcode `link` attribute |
| 5 | hestia | 3.1.2 | [CVE-2024-37467](https://nvd.nist.gov/vuln/detail/CVE-2024-37467) | 6.5 | BAC | no | Subscriber calls Hestia welcome-notice dismiss endpoint to flip arbitrary site options |

## Notes & adjustments

- `wp-automatic` 3.92.0 is downloadable from wordpress.org plugin archive; the vendor later removed
  current branches from listing but archived versions stay accessible via
  `https://downloads.wordpress.org/plugin/wp-automatic.3.92.0.zip` — install.sh
  fallback path handles this.
- `fluent-smtp` was pinned to 2.2.80 (rather than 2.2.5) so the dominant
  vulnerability is the 2024 BAC (CVE-2024-9511, fixed in 2.2.83) rather than
  the older 2023 issues already represented elsewhere in the lab.
- `nextend-facebook-connect` 3.1.12 sits inside the CVE-2024-1775 range
  (fixed in 3.1.13). The newer CVE-2025-58031 (fixed in 3.1.20) also applies
  but we cite the 2024 CVE as the canonical id.
- `wp-ultimate-csv-importer` 7.20.0 covers the early-2025 cluster
  (CVE-2025-2007 / CVE-2025-2008). The plugin author yanked some intermediate
  versions; 7.20.0 is the lowest version that is still present on the
  wordpress.org download mirror at time of writing.
- All themes selected exist on `wordpress.org/themes/<slug>/` and `wp theme install --version=` works
  unmodified. If the lab is rebuilt and a specific version disappears from the
  mirror, the install.sh ZIP fallback downloads from
  `downloads.wordpress.org/theme/<slug>.<ver>.zip`.
- One Phase A activation note: activating `hello-elementor` while the
  `elementor` plugin (3.5.5, baseline) is also active increases the attack
  surface because the theme's stored-XSS sink renders inside Elementor
  templates — this is intentional for chained-exploit training scenarios.

## OWASP / CWE mapping (deltas)

| Phase A class | OWASP 2021 | CWE |
|---------------|-----------|-----|
| AFU / RCE (wp-ultimate-csv-importer, wp-time-capsule) | A06 | CWE-434 / CWE-502 |
| SQLi (wp-automatic, wp-recall) | A03 | CWE-89 |
| Stored XSS (otter-blocks, mailpoet, ws-form, hello-elementor, astra, blocksy, oceanwp) | A03 | CWE-79 |
| BAC / IDOR (fluent-smtp, otter-blocks, jetpack, wp-job-manager, hestia) | A01 | CWE-639 / CWE-862 |
| Auth bypass / PE (masterstudy-lms, nextend-facebook-connect, simple-membership) | A07 | CWE-287 / CWE-269 |
| LFI (download-manager) | A05 | CWE-22 |
| Open Redirect / SSRF (seo-by-rank-math) | A01 | CWE-601 / CWE-918 |

## Summary

| Type | Phase A count |
|------|---------------|
| Plugin RCE / AFU / Deser | 2 |
| Plugin SQLi | 2 |
| Plugin Stored XSS | 3 |
| Plugin BAC / IDOR | 4 |
| Plugin Auth bypass / PE | 3 |
| Plugin LFI | 1 |
| Plugin Open Redirect / SSRF | 1 |
| Theme Stored XSS | 4 |
| Theme BAC | 1 |
| **Total Phase A entries** | **20** (15 plugins + 5 themes) |
