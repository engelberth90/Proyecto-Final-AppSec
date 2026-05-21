# bazooka-vuln-pack

Ten mini WordPress plugins, each illustrating exactly **one** class of vulnerability
that is hard to teach via off-the-shelf CVE plugins. Part of `wordpress-vulnerable-lab`.

Author: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>
License: GPL-2.0

> Intentionally vulnerable. Run only inside the lab Docker environment.

## Install

Each subdirectory is an independent plugin. With `wp-cli`:

```bash
for p in bz-broken-nonce bz-cap-confusion bz-xxe-soap bz-type-juggling \
         bz-mass-assignment bz-host-poisoning bz-crlf-injection \
         bz-postmessage-xss bz-no-clickjacking bz-race-coupon; do
  wp plugin activate "$p"
done
```

## Plugins

| # | Slug | Vuln class | Quick repro |
|---|------|------------|-------------|
| 1 | bz-broken-nonce       | CSRF / missing nonce check                | `curl -b c.txt -d 'action=bz_broken_nonce_delete&id=42' /wp-admin/admin-ajax.php` |
| 2 | bz-cap-confusion      | Capability misuse (login != admin)        | `curl -b sub.txt -d 'action=bz_cap_set_option&key=blogdescription&value=pwned' /wp-admin/admin-ajax.php` |
| 3 | bz-xxe-soap           | XXE via simplexml + LIBXML_NOENT          | `curl -X POST -H 'Content-Type: application/xml' --data-binary @xxe.xml /wp-json/bz/v1/xxe` |
| 4 | bz-type-juggling      | `==` on md5 magic-hash bypass             | `curl -d 'user=admin&pass=QNKCDZO' /wp-json/bz/v1/tjlogin` |
| 5 | bz-mass-assignment    | REST accepts `role` field                 | `curl -u sub:APP -d '{"role":"administrator"}' /wp-json/bz/v1/profile` |
| 6 | bz-host-poisoning     | Reset link from `HTTP_HOST`               | `curl -H 'Host: evil.tld' -d 'login=admin' /wp-json/bz/v1/reset` |
| 7 | bz-crlf-injection     | Raw `Location:` from `$_GET['url']`       | `curl -i '/?bz_crlf=1&url=https://evil.tld/'` |
| 8 | bz-postmessage-xss    | `addEventListener('message')` -> innerHTML| postMessage payload from framing page |
| 9 | bz-no-clickjacking    | Strips X-Frame-Options on admin action    | Iframe `/wp-admin/admin.php?page=bz-clickjack` |
|10 | bz-race-coupon        | TOCTOU on single-use coupon               | `seq 1 10 \| xargs -n1 -P10 curl -X POST '/wp-json/bz/v1/coupon/redeem?code=WELCOME10'` |

See `docs/PHASE_B_GROUND_TRUTH.md` for OWASP/CWE mappings and full repro snippets.
