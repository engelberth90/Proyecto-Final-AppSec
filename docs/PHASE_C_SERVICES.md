# Phase C — Exposed Internal Auxiliary Services

Author: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>

This phase adds a handful of intentionally misconfigured auxiliary services
that the WordPress container can reach over the internal Docker network.
They are designed to be chained from a WordPress foothold (SSRF, file
upload, plugin RCE) into deeper post-exploitation: instance-metadata theft,
public S3-style buckets, unauth Elasticsearch dumps, leaked secrets in git
history, etc.

> DO NOT EXPOSE TO THE INTERNET. Lab use only.

## Bring it up

```bash
docker compose -f docker-compose.yml -f docker-compose.aux.yml up -d
```

Tear down:

```bash
docker compose -f docker-compose.yml -f docker-compose.aux.yml down -v
```

## Service / port matrix

| Service              | Container name        | Host port | Internal addr (from `wpvl-wordpress`) | Default creds              |
|----------------------|-----------------------|-----------|---------------------------------------|----------------------------|
| Elasticsearch 6.8.23 | wpvl-elasticsearch    | 31392     | `http://elasticsearch:9200`           | none (xpack disabled)      |
| MinIO (S3)           | wpvl-minio            | 31900 / 31901 | `http://minio:9000`               | `minioadmin` / `minioadmin`|
| Gitea 1.18.5         | wpvl-gitea            | 31300 / 31322 | `http://gitea:3000`               | `gitea_admin` / `r8sA8CPHD9!bt6d`, plus `leakbot` / `leakbot123` |
| Fake AWS IMDS        | wpvl-aws-metadata     | 31254     | `http://aws-metadata/`                | n/a                        |
| MailHog *(reused)*   | wpvl-mailhog          | 31340     | `http://mailhog:8025`, SMTP `mailhog:1025` | none                  |

MailHog is **not** re-declared here — it already exists in the base
`docker-compose.yml` and is reused as-is for any SMTP plugin capture.

## Ground truth — what a scanner SHOULD detect

### Elasticsearch (unauth)
- `GET http://localhost:31392/_cluster/health` returns JSON without auth.
- `GET /_cat/indices?v` lists indices.
- `GET /_nodes` discloses JVM, OS, plugin versions.
- Severity: **HIGH** — unauthenticated read on a search/data store.

### MinIO
- Admin console at `http://localhost:31901` accepts `minioadmin/minioadmin`.
- Bucket `wp-backups` is **public** (anonymous download policy).
- `curl http://localhost:31900/wp-backups/db_dump.sql` returns a fake DB dump
  containing a `wp_users` row with a hashed admin password.
- Severity: **CRITICAL** — default creds + public bucket holding DB dump.

### Gitea
- Open registration (`/user/sign_up`).
- Public org `internal` with public repo `secrets-leak`.
- The file `.env` was committed then "removed", but is still reachable:
  - `git clone http://localhost:31300/internal/secrets-leak.git`
  - `git log --all --full-history -p -- .env`
  - Leaks `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DB_PASSWORD`,
    `WP_AUTH_KEY`.
- Severity: **HIGH** — secrets in VCS history, open signup.

### Fake AWS IMDS (SSRF target)
- From inside the WordPress container (or via any SSRF gadget):
  - `curl http://aws-metadata/latest/meta-data/`
  - `curl http://aws-metadata/latest/meta-data/iam/security-credentials/`
    returns `wpvl-lab-role`.
  - `curl http://aws-metadata/latest/meta-data/iam/security-credentials/wpvl-lab-role`
    returns fake AWS STS credentials.
- Also reachable from the host on `http://localhost:31254/`.
- Severity: **CRITICAL** when reached via SSRF — full chain from
  WordPress SSRF plugin -> IMDS -> AWS credential theft simulation.

### MailHog (reused)
- Web UI at `http://localhost:31340`.
- Captures every mail any WP plugin sends (password resets, contact forms).
- Severity: **MEDIUM** — internal mail relay reachable from anywhere.

## Suggested attack chain (training scenario)

1. Foothold: exploit one of the vulnerable plugins (see `VULNERABILITIES.md`)
   to obtain SSRF inside the `wpvl-wordpress` container.
2. SSRF -> `http://aws-metadata/latest/meta-data/iam/security-credentials/wpvl-lab-role`
   -> harvest fake AWS keys.
3. Use the leaked keys narrative to pivot to MinIO via
   `http://minio:9000/wp-backups/db_dump.sql` (no auth required, public).
4. Parse `db_dump.sql` -> recover hashed admin row.
5. In parallel, scrape Gitea -> clone `internal/secrets-leak` ->
   `git log -p` -> recover `DB_PASSWORD`, confirm credential reuse.
6. Dump Elasticsearch indices with `GET /_search?size=10000`.

Each step has a deterministic, observable artifact a scanner can flag.
