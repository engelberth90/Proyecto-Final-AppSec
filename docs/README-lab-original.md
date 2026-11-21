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

# wordpress-vulnerable-lab — **v2.0.0**

### The most complete Docker WordPress vulnerable lab in the world.

[![CI](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/ci.yml)
[![Verify CVEs](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/verify.yml/badge.svg)](https://github.com/ayinedjimi/wordpress-vulnerable-lab/actions/workflows/verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-compose-blue?logo=docker)](docker-compose.yml)
[![Vulns](https://img.shields.io/badge/vulns-141%2B-red)](docs/VULNERABILITIES.md)
[![CVE years](https://img.shields.io/badge/CVE_years-2019–2025-orange)](docs/VULNERABILITIES.md)
[![Kill chains](https://img.shields.io/badge/kill_chains-5-purple)](docs/CTF/)
[![WP matrix](https://img.shields.io/badge/WP_matrix-5.2/5.3/6.1/6.8-success)](docs/PHASE_F_MATRIX.md)
[![Stacks](https://img.shields.io/badge/stacks-Apache+nginx-blue)](docs/PHASE_D_NGINX.md)
[![Author](https://img.shields.io/badge/author-Ayi%20NEDJIMI-black)](https://ayinedjimi-consultants.fr)

**54 CVE-pinned plugins & themes (2019-2025) · 10 custom didactic mini-plugins · WP 5.2 / 5.3 / 6.1 / 6.8 matrix · Apache + nginx stacks · Auxiliary services (Elasticsearch / MinIO / Gitea / fake AWS IMDS) · 5 fully-documented kill-chains · 11 intentional misconfigs**

[Quickstart](#quickstart-30-seconds) ·
[All vulns](docs/VULNERABILITIES.md) ·
[CVE 2024-25 pack](docs/PHASE_A_GROUND_TRUTH.md) ·
[Custom mini-plugins](docs/PHASE_B_GROUND_TRUTH.md) ·
[Aux services](docs/PHASE_C_SERVICES.md) ·
[nginx stack](docs/PHASE_D_NGINX.md) ·
[Kill chains](docs/CTF/) ·
[WP matrix](docs/PHASE_F_MATRIX.md) ·
[Français](#français)

</div>

---

> ⚠️ **DISCLAIMER — READ THIS FIRST**
>
> This project is **intentionally insecure**. It is designed for:
> - security training & education,
> - capture-the-flag exercises,
> - benchmarking WordPress security scanners,
> - defensive blue-team training (detection / hardening).
>
> **Never expose this stack to the public internet.** Run it on `localhost`
> only, or behind a firewall, on an isolated VM/network. Spinning this up on
> a publicly reachable IP is a serious risk to *you* — anyone on the
> internet can be admin in under 60 seconds.

---

## 🆕 What's new in v2.0.0

| Phase | Scope | Files |
|-------|-------|-------|
| **A** | 15 CVE-pinned plugins (CVE-2024-* / CVE-2025-*) + 5 vulnerable themes | [`docs/PHASE_A_GROUND_TRUTH.md`](docs/PHASE_A_GROUND_TRUTH.md) |
| **B** | 10 custom didactic mini-plugins, one per vuln class (nonce, type-juggling, mass-assignment, host-poisoning, CRLF, SOAP-XXE, race coupon…) | [`plugins/bazooka-vuln-pack/`](plugins/bazooka-vuln-pack/) · [`docs/PHASE_B_GROUND_TRUTH.md`](docs/PHASE_B_GROUND_TRUTH.md) |
| **C** | Auxiliary services compose: Elasticsearch / MinIO / Gitea / fake AWS IMDS — usable for SSRF → metadata → S3 dump chains | [`docker-compose.aux.yml`](docker-compose.aux.yml) · [`docs/PHASE_C_SERVICES.md`](docs/PHASE_C_SERVICES.md) |
| **D** | Alternative stack: nginx 1.18 + PHP 8.1-FPM + ModSec-lite (3 intentional nginx misconfigs) | [`docker-compose.nginx.yml`](docker-compose.nginx.yml) · [`docs/PHASE_D_NGINX.md`](docs/PHASE_D_NGINX.md) |
| **E** | 5 fully-documented multi-step CTF kill-chains, each with curl/wpscan/sqlmap commands + planted flags | [`docs/CTF/`](docs/CTF/) · [`scripts/plant-flags.sh`](scripts/plant-flags.sh) |
| **F** | WordPress version matrix: 5.2 / 5.3 / 6.1 / 6.8 in parallel on 4 ports — benchmark scanners across versions | [`docker-compose.matrix.yml`](docker-compose.matrix.yml) · [`docs/PHASE_F_MATRIX.md`](docs/PHASE_F_MATRIX.md) |

> **141 total verifiable vulnerabilities · 5 multi-step kill-chains · 4 WP versions · 2 server stacks · 8 auxiliary services**

---

## Quickstart (30 seconds)

```bash
git clone https://github.com/ayinedjimi/wordpress-vulnerable-lab.git
cd wordpress-vulnerable-lab
bash scripts/install.sh        # boots stack + installs 54 vulnerable plugins/themes
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

### Optional compose stacks (v2.0.0)

```bash
# Auxiliary services (Elasticsearch, MinIO, Gitea, fake AWS IMDS) alongside the base:
docker compose -f docker-compose.yml -f docker-compose.aux.yml up -d

# Alternative nginx 1.18 + PHP 8.1 stack (port 31888) alongside Apache:
docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d

# Full WP version matrix (5.2 / 5.3 / 6.1 / 6.8 on ports 31352-31368):
docker compose -f docker-compose.yml -f docker-compose.matrix.yml up -d

# Plant CTF flags after stack is up (required for chain walkthroughs):
bash scripts/plant-flags.sh
```

---

## What's inside

### 54 vulnerable plugins & themes (CVE 2019 → 2025)

| Phase | Component | Count | Doc |
|---|---|---|---|
| Original | Plugins CVE 2020-2024 | 39 | [`docs/VULNERABILITIES.md`](docs/VULNERABILITIES.md) |
| **A** | Plugins CVE 2024-2025 | 15 | [`docs/PHASE_A_GROUND_TRUTH.md`](docs/PHASE_A_GROUND_TRUTH.md) |
| **A** | Themes CVE 2024 | 5 | [`docs/PHASE_A_GROUND_TRUTH.md`](docs/PHASE_A_GROUND_TRUTH.md) |
| **B** | Custom mini-plugins (didactic) | 10 | [`docs/PHASE_B_GROUND_TRUTH.md`](docs/PHASE_B_GROUND_TRUTH.md) |

Full ground-truth tables (slug, version, CVE id, CVSS, type, NVD link) live in
the per-phase docs above.

### 10 custom didactic mini-plugins (Phase B)

Each illustrates exactly **one** class of vulnerability that is hard to teach
via off-the-shelf CVE plugins. Activate them via:

```bash
docker compose exec wp wp plugin activate bazooka-vuln-pack/bz-broken-nonce --allow-root
```

| # | Plugin | Vuln class | CWE |
|---|---|---|---|
| 1 | `bz-broken-nonce` | AJAX action with nonce generated but never validated | CWE-352 |
| 2 | `bz-cap-confusion` | `is_user_logged_in()` instead of `current_user_can()` | CWE-285 |
| 3 | `bz-xxe-soap` | SOAP/XML endpoint with `LIBXML_NOENT \| LIBXML_DTDLOAD` | CWE-611 |
| 4 | `bz-type-juggling` | `md5($pw) == '0e…'` magic-hash bypass | CWE-697 |
| 5 | `bz-mass-assignment` | REST POST accepts arbitrary `role` field | CWE-915 |
| 6 | `bz-host-poisoning` | Password reset built from `$_SERVER['HTTP_HOST']` | CWE-20 |
| 7 | `bz-crlf-injection` | `Location:` header from unsanitized `$_GET['url']` | CWE-113 / CWE-601 |
| 8 | `bz-postmessage-xss` | Admin page sinks `event.data` into `innerHTML` | CWE-79 |
| 9 | `bz-no-clickjacking` | Admin action with `X-Frame-Options` stripped | CWE-1021 |
| 10 | `bz-race-coupon` | TOCTOU between coupon read & write (parallel-curl race) | CWE-367 |

### Auxiliary services (Phase C)

Reachable from the WordPress container by service name on the Docker network —
perfect for SSRF chain practice (e.g. `wp-content/plugins/xxx → http://aws-metadata/latest/meta-data/iam/security-credentials/`).

| Service | Host port | Container | Misconfig |
|---|---|---|---|
| Fake AWS IMDS | 31254 | `aws-metadata` | Always-on metadata responses |
| Gitea (HTTP / SSH) | 31300 / 31322 | `gitea` | Public `internal/secrets-leak` repo with fake `.env` |
| Elasticsearch 6.8 | 31392 | `elasticsearch` | No auth, `/_cat/indices` readable |
| MinIO API / Console | 31900 / 31901 | `minio` | Default creds, public `wp-backups` bucket with `db_dump.sql` |

### Alternative nginx stack (Phase D)

Same WordPress files served by **nginx 1.18 + PHP 8.1-FPM** on port **31888**
with 3 intentional bugs (alias path traversal, source disclosure via `.php~`,
verbose `Server:` header) plus a deliberately loose `ModSec-lite` ruleset.

### WordPress version matrix (Phase F)

| WP | PHP | Port | Highlight |
|----|-----|------|-----------|
| 5.2 | 7.2 | 31352 | CVE-2019-17671 REST API user leak |
| 5.3 | 7.4 | 31353 | Parity with the main lab (5.3.2 baseline) |
| 6.1 | 8.0 | 31361 | CVE-2023-2745 directory traversal |
| 6.8 | 8.2 | 31368 | Hardened — false-positive control box |

Use it to benchmark recall vs. precision of scanners across WP versions.

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

---

## 5 fully-documented CTF kill-chains (Phase E)

Each chain combines **3+ vulnerabilities** from the lab into a realistic
end-to-end attack, with copy-paste curl/wpscan/sqlmap commands at each step,
expected output, planted flag, **and** the defender's view (detection +
hardening).

| # | Title | Flag | Walkthrough |
|---|---|---|---|
| 1 | From `.git` leak to full RCE | `FLAG{wpvulnlab-chain1-a1f3c9e2}` | [`docs/CTF/chain-1.md`](docs/CTF/chain-1.md) |
| 2 | Subdomain takeover → admin cookie theft | `FLAG{wpvulnlab-chain2-b7d2e8f4}` | [`docs/CTF/chain-2.md`](docs/CTF/chain-2.md) |
| 3 | Open redirect → OAuth phish → REST takeover | `FLAG{wpvulnlab-chain3-c4a9b1d6}` | [`docs/CTF/chain-3.md`](docs/CTF/chain-3.md) |
| 4 | SSRF → AWS IMDS → S3 backup dump | `FLAG{wpvulnlab-chain4-d8e5f2a3}` | [`docs/CTF/chain-4.md`](docs/CTF/chain-4.md) |
| 5 | XML-RPC multicall brute → SVG XSS → backdoor plugin | `FLAG{wpvulnlab-chain5-e2b6c4f9}` | [`docs/CTF/chain-5.md`](docs/CTF/chain-5.md) |

Plant the flags after the stack is up:

```bash
bash scripts/plant-flags.sh
```

---

## Compare WordPress scanners against this lab

The lab is built specifically to *score* WordPress security tools. Run the
included benchmark:

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

> v2.0.0 benchmark refresh against the 141-vuln catalogue is in progress —
> numbers above are from the v1.x baseline (82 vulns).

---

## CTF challenges (single-vuln, beginner-friendly)

In addition to the 5 v2.0.0 kill-chains, the original **15 progressive
single-vuln challenges** are documented in [`docs/CHALLENGES.md`](docs/CHALLENGES.md):

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

- [x] 39 CVE plugins seeded (v1.0)
- [x] 11 misconfig endpoints (v1.0)
- [x] CI: lab boots / weekly CVE-endpoint verify (v1.0)
- [x] **v2.0.0** — 15 more CVE plugins (2024-2025)
- [x] **v2.0.0** — 5 vulnerable themes
- [x] **v2.0.0** — 10 custom didactic mini-plugins (`bazooka-vuln-pack`)
- [x] **v2.0.0** — Auxiliary services compose (Elasticsearch / MinIO / Gitea / fake IMDS)
- [x] **v2.0.0** — nginx 1.18 + PHP 8.1 alternative stack
- [x] **v2.0.0** — 5 documented multi-step CTF kill-chains
- [x] **v2.0.0** — WP version matrix (5.2 / 5.3 / 6.1 / 6.8)
- [ ] v2.1 — BAZOOKA / WPScan / Nuclei automated benchmark CI on the 141-vuln catalogue
- [ ] v2.1 — Multisite mode (subdomain) + per-tenant CVE matrix
- [ ] v2.1 — Real ModSecurity v3 (custom Dockerfile) replacing ModSec-lite
- [ ] v2.1 — Optional injectable Wordfence/iThemes plugin scenarios

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Related projects by the same author

- **[wordpress-bazooka](https://github.com/ayinedjimi/wordpress-bazooka)** — the WordPress scanner this lab benchmarks. Ships with a single 89 MB portable `bazooka.exe`, embedded multi-source CVE DB, Tor proxy, and a real-time GUI.
- **[ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)** — WordPress security guides, hardening checklists, audits.

---

## Author

**Ayi NEDJIMI** · <ayinedjimi@users.noreply.github.com> · [ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)

If this saved you time, ⭐ the repo and follow [@ayinedjimi](https://github.com/ayinedjimi).

---

<a id="français"></a>

# 🇫🇷 Version française

## wordpress-vulnerable-lab v2.0.0 — le lab WordPress vulnérable Docker le plus complet du monde

> ⚠️ **AVERTISSEMENT** : ce projet est **intentionnellement vulnérable**. À
> n'utiliser que sur `localhost` ou dans un réseau isolé. **Jamais sur une
> IP publique.** Toute exposition Internet vous transforme en cible
> pour les bots Balada Injector et consorts en moins d'une minute.

### À quoi ça sert

- **formation sécurité WordPress** (étudiants, RSSI, pentesters juniors),
- **CTF** internes ou compétitions,
- **benchmarking de scanners** (BAZOOKA, WPScan, Nuclei, Nikto…),
- **reproduction d'attaques réelles** observées en 2023-2025,
- **entraînement blue-team** (détection + hardening).

### Quoi de neuf en v2.0.0

| Phase | Contenu |
|-------|---------|
| **A** | 15 plugins CVE 2024-2025 + 5 thèmes vulnérables |
| **B** | 10 mini-plugins maison didactiques (un par classe de bug : nonce cassé, type-juggling, mass-assignment, host-header poisoning, CRLF, XXE SOAP, race condition coupon…) |
| **C** | Services annexes : Elasticsearch / MinIO / Gitea / faux AWS IMDS — pour pratiquer les chaînes SSRF → metadata → S3 dump |
| **D** | Stack alternative nginx 1.18 + PHP 8.1-FPM + ModSec-lite avec 3 misconfigs nginx volontaires |
| **E** | 5 kill-chains CTF complètement documentées (curl/wpscan/sqlmap copy-paste, sortie attendue, flag, détection blue-team, hardening) |
| **F** | Matrice de versions WP : 5.2 / 5.3 / 6.1 / 6.8 en parallèle sur 4 ports |

**141 vulnérabilités vérifiables · 5 kill-chains documentées · 4 versions WP · 2 stacks serveur · 8 services annexes**

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

Stacks optionnels v2.0.0 :

```bash
docker compose -f docker-compose.yml -f docker-compose.aux.yml    up -d   # services annexes
docker compose -f docker-compose.yml -f docker-compose.nginx.yml  up -d   # stack nginx
docker compose -f docker-compose.yml -f docker-compose.matrix.yml up -d   # matrice WP
bash scripts/plant-flags.sh                                                # planter les flags CTF
```

### Classement par catégorie de vulnérabilité

| Catégorie | Compte |
|---|---:|
| RCE / upload arbitraire | 11 |
| Injection SQL | 11 |
| XSS (stored + reflected) | 18 |
| Élévation de privilèges / BAC | 14 |
| Bypass d'authentification | 9 |
| Désérialisation | 2 |
| Open Redirect / SSRF | 2 |
| XSS / BAC sur thèmes | 5 |
| Mini-plugins didactiques | 10 |
| IDOR / divulgation d'information | 4 |
| Misconfigurations exposées | 11 |
| CVE WP core | 12 |
| CVE infrastructure (Apache / PHP / nginx) | 14 |
| Comptes faibles | 5 |
| Services annexes mal configurés | 8 |
| **Total** | **141** |

### Projets liés

- **[wordpress-bazooka](https://github.com/ayinedjimi/wordpress-bazooka)** — scanner WP, exe portable Windows 89 MB avec base CVE multi-source embarquée, proxy Tor bundlé, GUI temps réel.
- **[ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)** — guides de sécurisation WordPress, checklists de hardening, audits sur devis.

### Auteur

**Ayi NEDJIMI** — <ayinedjimi@users.noreply.github.com> — [ayinedjimi-consultants.fr](https://ayinedjimi-consultants.fr)

⭐ Si ce projet vous a fait gagner du temps, mettez une étoile et suivez
[@ayinedjimi](https://github.com/ayinedjimi).

---

<div align="center">

**Built with 🔒 by [Ayi NEDJIMI](https://ayinedjimi-consultants.fr) — Paris**

</div>
