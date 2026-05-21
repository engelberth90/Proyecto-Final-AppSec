# Vulnerabilities — Ground Truth

**Lab**: `wordpress-vulnerable-lab`
**Default URL**: http://localhost:31338
**WP**: 5.3 + PHP 7.4
**Date of build**: 2026-05
**Maintainer**: Ayi NEDJIMI

This is the *authoritative* list of vulnerabilities pre-installed in the lab.
Use it as the **ground truth** when benchmarking scanners (BAZOOKA, WPScan,
Nuclei, ...).

> Use only in isolated environments. Every plugin below is pinned to a
> publicly documented vulnerable version.

## How to verify

```bash
curl -sI http://localhost:31338/wp-content/plugins/<slug>/readme.txt
# expect 200 (or 301 for all-in-one-seo-pack rewrite)
```

```bash
docker exec -u root wpvl-wordpress \
  wp --path=/var/www/html --allow-root plugin list --status=active --format=table
```

Or run the included script:

```bash
bash scripts/verify.sh http://localhost:31338
```

## Plugin matrix

Legend: **RCE** remote code exec | **AFU** arbitrary file upload | **SQLi**
SQL injection | **XSS** cross-site scripting | **PE** privilege escalation |
**AB** auth bypass | **IDOR** broken access control | **LFI** local file
inclusion | **XXE** XML external entity.

| # | Slug | Version | CVE(s) | Type | Notes |
|---|------|---------|--------|------|-------|
| 1  | really-simple-ssl | 7.0.5 | [CVE-2023-6961](https://nvd.nist.gov/vuln/detail/CVE-2023-6961) | XSS | Unauth stored XSS via `X-Forwarded-For` |
| 2  | litespeed-cache | 6.3.0.1 | [CVE-2024-28000](https://nvd.nist.gov/vuln/detail/CVE-2024-28000) | PE | Unauth privilege escalation, weak security hash |
| 3  | wpforms-lite | 1.8.5.4 | [CVE-2024-0383](https://nvd.nist.gov/vuln/detail/CVE-2024-0383) | XSS | Stored XSS, authd |
| 4  | wp-statistics | 13.2.10 | [CVE-2024-2194](https://nvd.nist.gov/vuln/detail/CVE-2024-2194) | SQLi | Unauth time-based SQLi in `current_page_id` |
| 5  | forminator | 1.24.6 | [CVE-2024-28890](https://nvd.nist.gov/vuln/detail/CVE-2024-28890), CVE-2024-30543, CVE-2024-31077 | AFU/SQLi/XSS | Unauth AFU -> RCE |
| 6  | ultimate-member | 2.6.6 | [CVE-2023-3460](https://nvd.nist.gov/vuln/detail/CVE-2023-3460) | PE | Unauth admin account creation |
| 7  | mw-wp-form | 4.4.2 | [CVE-2023-6553](https://nvd.nist.gov/vuln/detail/CVE-2023-6553), CVE-2023-32246 | AFU/RCE | Unauth upload via form attachment |
| 8  | email-subscribers | 5.7.13 | [CVE-2024-1071](https://nvd.nist.gov/vuln/detail/CVE-2024-1071) | SQLi | Unauth UNION SQLi via `hash` |
| 9  | elementor | 3.5.5 | [CVE-2023-48777](https://nvd.nist.gov/vuln/detail/CVE-2023-48777), CVE-2022-29455 | AFU/XSS | Authd AFU -> RCE |
| 10 | contact-form-7 | 5.7.5.1 | [CVE-2023-6449](https://nvd.nist.gov/vuln/detail/CVE-2023-6449) | AFU/XSS | CF7 < 5.7.6 file-type bypass |
| 11 | essential-addons-for-elementor-lite | 5.7.1 | [CVE-2023-32243](https://nvd.nist.gov/vuln/detail/CVE-2023-32243) | PE | Unauth password reset -> account takeover |
| 12 | wp-fastest-cache | 1.2.1 | [CVE-2023-6063](https://nvd.nist.gov/vuln/detail/CVE-2023-6063) | SQLi | Unauth SQLi via cookie parsing |
| 13 | fluentform | 5.0.2 | [CVE-2023-26540](https://nvd.nist.gov/vuln/detail/CVE-2023-26540), CVE-2023-25024 | XSS/IDOR | Stored XSS on form submission |
| 14 | wp-google-maps | 9.0.27 | CVE-2024-1071-class, CVE-2023-1119 | SQLi | Unauth SQLi via REST |
| 15 | royal-elementor-addons | 1.3.78 | [CVE-2023-5360](https://nvd.nist.gov/vuln/detail/CVE-2023-5360) | AFU/RCE | Mass-exploited Oct 2023 |
| 16 | advanced-custom-fields | 6.2.5 | [CVE-2024-31077](https://nvd.nist.gov/vuln/detail/CVE-2024-31077), [CVE-2023-30777](https://nvd.nist.gov/vuln/detail/CVE-2023-30777) | XSS | Reflected XSS in ACF / ACF Pro |
| 17 | popup-builder | 4.2.3 | [CVE-2023-6000](https://nvd.nist.gov/vuln/detail/CVE-2023-6000) | XSS | Balada Injector mass-exploited |
| 18 | ninja-forms | 3.6.25 | [CVE-2023-37979](https://nvd.nist.gov/vuln/detail/CVE-2023-37979), CVE-2023-37985, CVE-2023-37986 | XSS/IDOR | Reflected XSS + export IDOR |
| 19 | give | 2.24.0 | [CVE-2024-1207](https://nvd.nist.gov/vuln/detail/CVE-2024-1207) | SQLi | Unauth SQLi via REST |
| 20 | user-registration | 3.0.2 | [CVE-2023-3342](https://nvd.nist.gov/vuln/detail/CVE-2023-3342), CVE-2024-2417 | AFU/RCE | Authd AFU via profile picture |
| 21 | loginpress | 3.0.2 | [CVE-2023-2466](https://nvd.nist.gov/vuln/detail/CVE-2023-2466) | XSS | Stored XSS via settings |
| 22 | ml-slider | 3.50.0 | [CVE-2023-6378](https://nvd.nist.gov/vuln/detail/CVE-2023-6378) | XSS | Reflected XSS in preview |
| 23 | all-in-one-seo-pack | 4.5.8 | [CVE-2023-39979](https://nvd.nist.gov/vuln/detail/CVE-2023-39979), CVE-2023-5359 | PE/SQLi | Authd SQLi + PE |
| 24 | duplicator | 1.5.7.1 | [CVE-2023-6114](https://nvd.nist.gov/vuln/detail/CVE-2023-6114), CVE-2023-6905 | IDOR | Backup info disclosure |
| 25 | wp-mail-smtp | 3.11.0 | [CVE-2024-1054](https://nvd.nist.gov/vuln/detail/CVE-2024-1054) | IDOR | Authd info disclosure |
| 26 | post-smtp | 2.8.7 | [CVE-2023-6875](https://nvd.nist.gov/vuln/detail/CVE-2023-6875) | AB | Unauth API bypass -> account takeover |
| 27 | lifterlms | 7.4.1 | CVE-2024-1207-family, CVE-2024-3120 | SQLi | Authd SQLi |
| 28 | essential-blocks | 4.3.0 | [CVE-2024-2298](https://nvd.nist.gov/vuln/detail/CVE-2024-2298) | XSS | Stored XSS via block attributes |
| 29 | wp-cerber | 9.5 | [CVE-2024-2697](https://nvd.nist.gov/vuln/detail/CVE-2024-2697) | AB | REST API auth bypass (logic) |
| 30 | easy-digital-downloads | 3.2.6 | [CVE-2024-1981](https://nvd.nist.gov/vuln/detail/CVE-2024-1981) | SQLi | Authd SQLi in reports |
| 31 | user-role-editor | 4.64 | [CVE-2024-37255](https://nvd.nist.gov/vuln/detail/CVE-2024-37255) | PE | Capability self-assignment |
| 32 | all-in-one-wp-migration | 7.78 | [CVE-2023-40004](https://nvd.nist.gov/vuln/detail/CVE-2023-40004) | AB/IDOR | Unauthorized export download |
| 33 | advanced-access-manager | 6.9.18 | [CVE-2023-7228](https://nvd.nist.gov/vuln/detail/CVE-2023-7228) | PE | Policy import misconfig |
| 34 | popup-maker | 1.18.0 | [CVE-2024-2544](https://nvd.nist.gov/vuln/detail/CVE-2024-2544) | XSS | Stored XSS via conditions |
| 35 | translatepress-multilingual | 2.7.3 | [CVE-2024-1313](https://nvd.nist.gov/vuln/detail/CVE-2024-1313) | XSS | Stored XSS via translations |
| 36 | miniorange-saml-20-single-sign-on | 5.0.7 | [CVE-2024-2879](https://nvd.nist.gov/vuln/detail/CVE-2024-2879) | AB/XXE | SAML auth bypass / XXE |
| 37 | woocommerce | 7.0.0 | [CVE-2023-28121](https://nvd.nist.gov/vuln/detail/CVE-2023-28121) | AB | Auth bypass (mass-exploited 2023) |
| 38 | wp-file-manager | 7.0 | [CVE-2020-25213](https://nvd.nist.gov/vuln/detail/CVE-2020-25213) | RCE | Legacy unauth RCE (elFinder connector) |
| 39 | backup-migration | 1.3.6 | [CVE-2023-6553](https://nvd.nist.gov/vuln/detail/CVE-2023-6553) | RCE | Unauth RCE in BackupBuddy / Backup Migration |

## Themes (vulnerable / legacy)

| Slug | Version | Notes |
|------|---------|-------|
| twentyeleven | latest 5.3-era | Legacy theme, default for the lab |
| twentyfifteen | latest 5.3-era | Bundled, leaves enumeration footprint |
| twentyseventeen | latest 5.3-era | Bundled |

> Historical RevSlider, RealEstate, Newspaper themes are deliberately **not**
> shipped because their distribution licence does not permit redistribution.
> A `themes/INSTALL.md` placeholder explains how to inject them locally for
> private research.

## Intentional misconfigurations & exposed files

| URL | Type |
|-----|------|
| `/info.php` | phpinfo() leak |
| `/adminer.php` | Adminer bait |
| `/debug.log` | Stack trace + secrets in logs |
| `/wp-config.php.bak` | Backup leak |
| `/dump.sql` | SQL dump leak |
| `/.env` | Env leak |
| `/.git/HEAD`, `/.git/config` | Git directory leak |
| `/wp-content/uploads/` | Directory listing enabled |
| `/xmlrpc.php` | Enabled |
| `/wp-json/wp/v2/users` | User enumeration |
| `/wp-cron.php` | Reachable |
| `/readme.html` | Core version leak |

## Network-level misconfigurations

| Port | Service | Note |
|------|---------|------|
| 31306 | MySQL | Public, weak root password |
| 31379 | Redis | No auth, NOSCRIPT free |
| 31211 | Memcached | No ACL |
| 31325 | SMTP (MailHog) | Open relay |
| 31339 | phpMyAdmin | root/root |
| 31341 | Adminer | direct DB |

## Summary by vulnerability class

| Type | Count |
|------|-------|
| RCE / AFU | 9 |
| SQLi | 9 |
| XSS | 12 |
| PE  | 7 |
| AB / Account takeover | 5 |
| IDOR / Info disclosure | 4 |
| Misconfig / leaked file | 11 |

## Caveats

- Some CVE labels say "family" or "class": the installed version sits within
  a documented vulnerable range but the canonical CVE id may point at a
  sibling release in the same series.
- The lab targets *fingerprintability*. Some plugins emit PHP notices because
  the base image runs an older PHP. This does not affect detection.
- Plugins delisted from `downloads.wordpress.org` (e.g. Bricks RCE
  CVE-2024-25600 in non-archived versions) are intentionally excluded.
