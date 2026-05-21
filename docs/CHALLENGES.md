# CTF-style challenges

Progressive challenges built around the lab. Each one has a flag in the form
`FLAG{...}` placed somewhere reachable once the vulnerability is exploited.
Flags are seeded by `scripts/install.sh`; reset by re-running it.

> Difficulty: **(easy)** beginner-friendly, **(med)** classic web pentest,
> **(hard)** chain of two or more issues.

## 1. (easy) Discover the version
Find the running WordPress version without using `wp-login.php`.
Hint: `readme.html`, `/wp-json/`, generator meta.

## 2. (easy) Enumerate users
List every user account on the site. Confirm at least three exist
(`admin`, `editor`, `subscriber`).
Hint: `/wp-json/wp/v2/users`, author archives, login error oracle.

## 3. (easy) Read the secret env
The webroot leaks an `.env` file. Extract the `STRIPE_SECRET`.

## 4. (easy) Read the leaked SQL dump
Find the dump in the webroot, identify the password storage scheme used by
the lab (PHPass placeholder).

## 5. (med) Brute the editor
The `editor` user has a *very* weak password. Use `xmlrpc.php` (yes, it's
enabled) to confirm credentials without tripping the login throttler.

## 6. (med) Stored XSS via popup-builder
Trigger CVE-2023-6000. Pop an alert in the admin context.

## 7. (med) SQL injection in wp-statistics
Use CVE-2024-2194 to dump the `wp_users` table over time-based SQLi.

## 8. (med) Privilege escalation in ultimate-member
Use CVE-2023-3460 to create a new administrator from an unauthenticated
session.

## 9. (med) File upload in royal-elementor-addons
Use CVE-2023-5360 to drop a PHP shell.

## 10. (hard) Chain: post-smtp -> admin
1. Hit CVE-2023-6875 to take over the admin email recovery.
2. Issue a password reset.
3. Log in as `admin`.

## 11. (hard) Chain: forminator AFU -> RCE -> Redis
1. CVE-2024-28890 unauth AFU on `/wp-content/uploads/forminator/`.
2. Execute the PHP shell.
3. Pivot to the unauthenticated Redis on port 31379.

## 12. (hard) SAML XXE
Use CVE-2024-2879 (XXE class) in miniorange SAML SSO to read
`/var/www/html/wp-config.php`.

## 13. (hard) WooCommerce auth bypass
Use CVE-2023-28121 to authenticate as `admin` via a crafted `X-WCPAY-PLATFORM-CHECKOUT-USER` header (or equivalent).

## 14. (hard) Network misconfig pivot
From an authenticated subscriber session, identify and exploit the open
Memcached (31211) and Redis (31379) services.

## 15. (boss) Full chain
Starting from no credentials, achieve persistent admin + extract every
password hash + sign a malicious plugin update.
