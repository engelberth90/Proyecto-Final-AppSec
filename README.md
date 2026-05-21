<!-- README — wordpress-vulnerable-lab — by Ayi NEDJIMI -->

<div align="center">

```
██╗    ██╗██████╗     ██╗   ██╗██╗   ██╗██╗     ███╗   ██╗    ██╗      █████╗ ██████╗
██║    ██║██╔══██╗    ██║   ██║██║   ██║██║     ████╗  ██║    ██║     ██╔══██╗██╔══██╗
██║ █╗ ██║██████╔╝    ██║   ██║██║   ██║██║     ██╔██╗ ██║    ██║     ███████║██████╔╝
██║███╗██║██╔═══╝     ╚██╗ ██╔╝██║   ██║██║     ██║╚██╗██║    ██║     ██╔══██║██╔══██╗
╚███╔███╔╝██║          ╚████╔╝ ╚██████╔╝███████╗██║ ╚████║    ███████╗██║  ██║██████╔╝
 ╚══╝╚══╝ ╚═╝           ╚═══╝   ╚═════╝ ╚══════╝╚═╝  ╚═══╝    ╚══════╝╚═╝  ╚═╝╚═════╝
```

# wordpress-vulnerable-lab

### The most complete Docker WordPress vulnerable lab in the world.

[![CI](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/ci.yml)
[![Verify CVEs](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/verify.yml/badge.svg)](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-compose-blue?logo=docker)](docker-compose.yml)
[![CVEs](https://img.shields.io/badge/CVEs-39%2B-red)](docs/VULNERABILITIES.md)
[![Years](https://img.shields.io/badge/years-2020–2024-orange)](docs/VULNERABILITIES.md)
[![Author](https://img.shields.io/badge/author-Ayi%20NEDJIMI-black)](https://ayinedjimi-consultants.fr)

**39+ CVE-pinned plugins · WordPress 5.3 + PHP 7.4 · phpMyAdmin · MailHog · Adminer · Redis · Memcached · 11 intentional misconfigs**

[Quickstart](#quickstart-30-seconds) ·
[CVE list](docs/VULNERABILITIES.md) ·
[Attack paths](docs/ATTACK_PATHS.md) ·
[Challenges](docs/CHALLENGES.md) ·
[Benchmark](docs/BENCHMARK.md) ·
[Français](#français)

</div>

---

> ⚠️ **DISCLAIMER — READ THIS FIRST**
>
> This project is **intentionally insecure**. It is designed for:
> - security training & education,
> - capture-the-flag exercises,
> - benchmarking WordPress security scanners.
>
> **Never expose this stack to the public internet.** Run it on `localhost`
> only, or behind a firewall, on an isolated VM/network. Spinning this up on
> a publicly reachable IP is a serious risk to *you* — anyone on the
> internet can be admin in under 60 seconds.

---

## Quickstart (30 seconds)

```bash
git clone https://github.com/ayinedjimi/wordpress-vulnerable-lab.git
cd wordpress-vulnerable-lab
bash scripts/install.sh        # boots stack + installs 39 vulnerable plugins
```

Then:

| Service | URL | Credentials |
|---|---|---|
| WordPress | http://localhost:31338 | `admin` / `admin` |
| phpMyAdmin | http://localhost:31339 | `root` / `root` |
| MailHog | http://localhost:31340 | — |
| Adminer | http://localhost:31341 | server `db`, user `root`, pass `root` |
| MySQL | `localhost:31306` | `wordpress` / `wordpress` |
| Redis | `localhost:31379` | no auth |
| Memcached | `localhost:31211` | no auth |

Validate everything is online:

```bash
bash scripts/verify.sh http://localhost:31338
```

Tear down + rebuild from scratch:

```bash
bash scripts/reset.sh
```

---

## What's inside

### 39+ vulnerable plugins (CVE 2020 → 2024)

A full table — slug, version, CVE id, type, NVD link — is in
[`docs/VULNERABILITIES.md`](docs/VULNERABILITIES.md). Here is the breakdown:

<table>
<tr><th>Category</th><th>Count</th><th>Notable CVEs</th></tr>
<tr><td>🔴 RCE / Arbitrary file upload</td><td>9</td>
    <td>CVE-2024-28890 (forminator) · CVE-2023-5360 (royal-elementor-addons) · CVE-2020-25213 (wp-file-manager) · CVE-2023-6553 (backup-migration) · CVE-2023-48777 (elementor) · CVE-2023-6449 (contact-form-7) · CVE-2023-3342 (user-registration) · CVE-2023-6553 (mw-wp-form)</td></tr>
<tr><td>🟠 SQL injection</td><td>9</td>
    <td>CVE-2024-2194 (wp-statistics) · CVE-2024-1071 (email-subscribers) · CVE-2023-6063 (wp-fastest-cache) · CVE-2024-1207 (give) · CVE-2024-1981 (easy-digital-downloads) · CVE-2024-3120 (lifterlms) · CVE-2023-39979 (all-in-one-seo-pack)</td></tr>
<tr><td>🟡 Cross-site scripting</td><td>12</td>
    <td>CVE-2023-6961 (really-simple-ssl) · CVE-2024-0383 (wpforms-lite) · CVE-2023-26540 (fluentform) · CVE-2024-31077 (advanced-custom-fields) · CVE-2023-6000 (popup-builder, Balada Injector) · CVE-2023-37979 (ninja-forms) · CVE-2024-2298 (essential-blocks) · CVE-2024-2544 (popup-maker) · CVE-2024-1313 (translatepress) · CVE-2023-6378 (ml-slider)</td></tr>
<tr><td>🟣 Privilege escalation</td><td>7</td>
    <td>CVE-2024-28000 (litespeed-cache) · CVE-2023-3460 (ultimate-member) · CVE-2023-32243 (essential-addons-for-elementor-lite) · CVE-2024-37255 (user-role-editor) · CVE-2023-7228 (advanced-access-manager)</td></tr>
<tr><td>🔵 Auth bypass / account takeover</td><td>5</td>
    <td>CVE-2023-6875 (post-smtp) · CVE-2024-2697 (wp-cerber) · CVE-2023-40004 (all-in-one-wp-migration) · CVE-2024-2879 (miniorange SAML) · CVE-2023-28121 (woocommerce)</td></tr>
<tr><td>⚪ Info disclosure / IDOR</td><td>4</td>
    <td>CVE-2023-6114 (duplicator) · CVE-2024-1054 (wp-mail-smtp) · CVE-2023-25024 (fluentform)</td></tr>
</table>

### 11 intentional misconfigurations

| URL or port | Issue |
|---|---|
| `/info.php` | phpinfo() |
| `/adminer.php` | Adminer bait |
| `/debug.log` | Stack traces + secrets |
| `/wp-config.php.bak` | Backup leak |
| `/dump.sql` | SQL dump |
| `/.env` | Env file leak |
| `/.git/{HEAD,config}` | Git dir leak |
| `/wp-content/uploads/` | Directory listing |
| `/xmlrpc.php` | Enabled |
| `/wp-json/wp/v2/users` | User enumeration |
| MySQL :31306, Redis :31379, Memcached :31211 | No-auth network services |

### Extras

- WP-CLI pre-installed inside the container.
- MailHog wired for SMTP capture (port 31325 → UI 31340).
- Three accounts with deliberately weak passwords (admin/admin,
  editor/editor, subscriber/password123).
- Reset script wipes DB volumes and re-seeds in one command.

---

## Compare WordPress scanners against this lab

The lab is built specifically to *score* WordPress security tools. Run
the included benchmark:

```bash
bash scripts/benchmark.sh http://localhost:31338 ./bench-out
```

| Scanner | Recall | Precision | F1 | Time |
|---|---:|---:|---:|---:|
| [**wordpress-bazooka**](https://github.com/ayinedjimi/wordpress-bazooka) | **0.94** | 0.98 | **0.96** | 38 s |
| WPScan (free DB) | 0.82 | 0.93 | 0.87 | 71 s |
| WPScan (paid API) | 0.98 | 0.98 | 0.98 | 73 s |
| Nuclei (wordpress tag) | 0.44 | 0.73 | 0.55 | 24 s |
| Nikto | 0.14 | 0.33 | 0.20 | 110 s |

Full methodology: [`docs/BENCHMARK.md`](docs/BENCHMARK.md).

---

## CTF challenges

15 progressive challenges, easy → boss, in
[`docs/CHALLENGES.md`](docs/CHALLENGES.md):

1. (easy) discover the WP version
2. (easy) enumerate users
3. (easy) read the leaked `.env`
4. (med) brute the editor account via xmlrpc
5. (med) stored XSS via popup-builder (CVE-2023-6000)
6. (med) time-based SQLi via wp-statistics (CVE-2024-2194)
7. (med) PE via ultimate-member (CVE-2023-3460)
8. (med) file upload via royal-elementor-addons (CVE-2023-5360)
9. (hard) chain: post-smtp → admin
10. (hard) chain: forminator AFU → RCE → Redis
11. (hard) SAML XXE (CVE-2024-2879)
12. (hard) WooCommerce auth bypass (CVE-2023-28121)
13. (hard) network misconfig pivot (Redis/Memcached)
14. (boss) full chain to persistent admin

---

## Roadmap

- [x] 39 CVE plugins seeded
- [x] 11 misconfig endpoints
- [x] CI: lab boots
- [x] CI: CVE endpoints verified weekly
- [ ] Theme CVEs: revslider 4.x bundle
- [ ] Multisite mode (subdomain)
- [ ] WP 6.4 + PHP 8.2 "modern" branch with 2024–2025 CVEs only
- [ ] BAZOOKA / WPScan / Nuclei automated benchmark CI

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Related projects by the same author

- **[wordpress-bazooka](https://github.com/ayinedjimi/wordpress-bazooka)** — the WordPress scanner this lab benchmarks.
- **[ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)** — WordPress security guides, hardening checklists, audits.

---

## Author

**Ayi NEDJIMI** · <ayinedjimi@users.noreply.github.com> · [ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)

If this saved you time, ⭐ the repo and follow [@ayinedjimi](https://github.com/ayinedjimi).

---

<a id="français"></a>

# 🇫🇷 Version française

## wordpress-vulnerable-lab — le lab WordPress vulnérable Docker le plus complet du monde

> ⚠️ **AVERTISSEMENT** : ce projet est **intentionnellement vulnérable**. À
> n'utiliser que sur `localhost` ou dans un réseau isolé. **Jamais sur une
> IP publique.** Toute exposition Internet vous transforme en cible
> pour les bots Balada Injector et consorts en moins d'une minute.

### À quoi ça sert ?

- **formation sécurité WordPress** (étudiants, RSSI, pentesters juniors),
- **CTF** internes ou compétitions,
- **benchmarking de scanners** (BAZOOKA, WPScan, Nuclei, Nikto…),
- **reproduction d'attaques réelles** observées dans la nature en 2023-2024.

### Démarrage rapide

```bash
git clone https://github.com/ayinedjimi/wordpress-vulnerable-lab.git
cd wordpress-vulnerable-lab
bash scripts/install.sh
```

Puis :

| Service | URL | Identifiants |
|---|---|---|
| WordPress | http://localhost:31338 | `admin` / `admin` |
| phpMyAdmin | http://localhost:31339 | `root` / `root` |
| MailHog | http://localhost:31340 | — |
| Adminer | http://localhost:31341 | `root` / `root` |

### Contenu

- **39+ plugins** WordPress épinglés sur des versions avec CVE publique
  (2020 → 2024) — voir [`docs/VULNERABILITIES.md`](docs/VULNERABILITIES.md).
- **11 misconfigurations** classiques (`.env`, `.git/`, `debug.log`,
  `wp-config.php.bak`, `dump.sql`, phpinfo, etc.).
- **3 comptes utilisateurs** à mots de passe faibles.
- **Services réseau** exposés sans auth : MySQL, Redis, Memcached.
- **MailHog** pour capturer les emails sortants.
- **15 challenges CTF** progressifs dans [`docs/CHALLENGES.md`](docs/CHALLENGES.md).
- **Walk-through d'exploitation** pas-à-pas pour chaque CVE dans
  [`docs/ATTACK_PATHS.md`](docs/ATTACK_PATHS.md).
- **Méthodologie de benchmark** comparant les scanners dans
  [`docs/BENCHMARK.md`](docs/BENCHMARK.md).

### Classement par catégorie de vulnérabilité

| Catégorie | Nombre |
|---|---:|
| RCE / upload arbitraire | 9 |
| Injection SQL | 9 |
| XSS | 12 |
| Élévation de privilèges | 7 |
| Bypass d'authentification / takeover | 5 |
| Divulgation d'information / IDOR | 4 |
| Misconfigurations exposées | 11 |

### Projets liés

- **[wordpress-bazooka](https://github.com/ayinedjimi/wordpress-bazooka)** — le scanner WordPress que ce lab sert à benchmarker.
- **[ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)** — guides de sécurisation WordPress, checklists de hardening, audits sur devis.

### Auteur

**Ayi NEDJIMI** — <ayinedjimi@users.noreply.github.com> — [ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)

Si ce projet vous a fait gagner du temps, mettez une ⭐ et suivez
[@ayinedjimi](https://github.com/ayinedjimi).

---

<div align="center">

**Built with 🔒 by [Ayi NEDJIMI](https://ayinedjimi-consultants.fr) — Paris**

</div>
