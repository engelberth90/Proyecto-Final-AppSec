# Phase F — WordPress Version Benchmark Matrix

**Author**: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>
**File**: `docker-compose.matrix.yml`

This compose overlay spins up four WordPress versions in parallel against
the existing `mysql:5.7` service so that scanners (BAZOOKA, WPScan,
Nuclei, ...) can be benchmarked across version-dependent CVE without
provisioning four databases.

## Usage

```bash
# Start the main lab + the matrix
docker compose -f docker-compose.yml -f docker-compose.matrix.yml up -d

# Check status
docker compose -f docker-compose.yml -f docker-compose.matrix.yml ps

# Tear down only the matrix (keep main lab running)
docker compose -f docker-compose.matrix.yml down -v
```

The one-shot `matrix-install` container will `wp core install` each WP
instance with credentials `admin / admin`.

## Port allocation

| Port  | Target            | WP version | PHP | Database | Admin       | Purpose                              |
|-------|-------------------|------------|-----|----------|-------------|--------------------------------------|
| 31352 | http://localhost  | 5.2        | 7.2 | `wp52`   | admin/admin | CVE-2019-17671 REST API user leak    |
| 31353 | http://localhost  | 5.3        | 7.4 | `wp53`   | admin/admin | Parity with main lab default         |
| 31361 | http://localhost  | 6.1        | 8.0 | `wp61`   | admin/admin | CVE-2023-2745 directory traversal    |
| 31368 | http://localhost  | 6.8        | 8.2 | `wp68`   | admin/admin | Hardened baseline / false-positive   |

## Ground truth — which CVE each version exposes

| Version | CVE                | Title                              | Endpoint to validate                                          | Expected indicator                                  |
|---------|--------------------|------------------------------------|---------------------------------------------------------------|-----------------------------------------------------|
| 5.2     | CVE-2019-17671     | Unauth REST user enumeration leak  | `GET /wp-json/wp/v2/users/?per_page=1&_fields=id,name,slug`   | JSON array with all users incl. drafts             |
| 5.2     | CVE-2019-16223     | Stored XSS in shortcode preview    | `POST /wp-admin/admin-ajax.php?action=parse-embed`            | Reflected payload survives unescaped               |
| 5.3     | CVE-2020-11026     | XSS in upload (legacy)             | `POST /wp-admin/async-upload.php` w/ crafted filename         | Filename stored verbatim                            |
| 5.3     | (see main lab)     | 173+ historical CVE                | see `docs/VULNERABILITIES.md`                                 | n/a                                                 |
| 6.1     | CVE-2023-2745      | Directory traversal in translations | `GET /wp-admin/load-scripts.php?load[]=../../etc/passwd`     | Path traversal triggers warning / 200             |
| 6.1     | CVE-2023-38000     | Stored XSS in block editor         | authenticated block insertion                                 | Persisted JS                                        |
| 6.8     | none expected      | Hardened baseline                  | full scanner pass                                             | 0 critical findings (use to measure FP rate)        |

## Smoke-testing the matrix

```bash
for p in 31352 31353 31361 31368; do
  echo "--- :$p"
  curl -sI http://localhost:$p/ | head -n1
  curl -s   http://localhost:$p/?rest_route=/ | python3 -c 'import sys,json;d=json.load(sys.stdin);print("WP",d.get("name"),"namespaces:",d.get("namespaces",[])[:3])'
done
```

## Benchmark harness

`scripts/benchmark.sh` already iterates a list of targets; extend it with:

```bash
TARGETS=(
  "http://localhost:31338"   # main lab
  "http://localhost:31352"
  "http://localhost:31353"
  "http://localhost:31361"
  "http://localhost:31368"
)
```

Each scanner run should write a per-target JSON so you can compute:

- Coverage = (CVE found / CVE expected for that version)
- Precision = (true-positives / (true-positives + false-positives))
- The 6.8 box is the FP-control: any non-informational finding there counts
  against precision.

## Notes / adjustments

- The WP 5.2 image (`wordpress:5.2-php7.2-apache`) does **not** ship with
  the lab's `wp-cerber` / `litespeed-cache` plugins because their minimum
  WP requirement is 5.6+. The bind mount of `./plugins` is still added so
  scanners that probe `/wp-content/plugins/<slug>/readme.txt` will see the
  same fingerprint surface; plugins simply won't activate.
- The bind mount is *read-only* (`:ro`) so accidental writes from one
  container cannot corrupt another's plugin tree.
- All four DBs live inside the existing `db` service, so back-ups taken
  via `mysqldump --all-databases` capture the entire matrix in one shot.
- The `matrix-install` container exits 0 after provisioning. Re-running
  `up -d` is idempotent.
