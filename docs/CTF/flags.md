# CTF Flags — Ground Truth

**Author**: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>
**Format**: `FLAG{wpvulnlab-chainN-<random8>}`

Planted by `scripts/plant-flags.sh` once the WordPress container is up.

| Chain | Flag | Planted Location | Container Path / SQL |
|-------|------|------------------|----------------------|
| 1 | `FLAG{wpvulnlab-chain1-a1f3c9e2}` | Filesystem inside `wpvl-wordpress` | `/flag-chain1.txt` (mode 0644, owner `www-data`) |
| 2 | `FLAG{wpvulnlab-chain2-b7d2e8f4}` | `wp_options` row | `option_name='ctf_flag_chain2'` (autoload=no) |
| 3 | `FLAG{wpvulnlab-chain3-c4a9b1d6}` | `wp_options` row exposed via REST settings | `option_name='ctf_flag_chain3'` registered to `rest_api_init` |
| 4 | `FLAG{wpvulnlab-chain4-d8e5f2a3}` | MinIO S3 backup | `s3://wp-backups/backups/wp-dump.sql.gz` — inserted into `wp_postmeta` `(meta_key='_ctf_flag_chain4')` before the dump is taken |
| 5 | `FLAG{wpvulnlab-chain5-e2b6c4f9}` | Backdoor plugin response + uploads canary | Plugin route `/?ctf=flag` and file `/var/www/html/wp-content/uploads/.ctf-chain5` |

## Verifying plant

```bash
# Chain 1
docker exec wpvl-wordpress cat /flag-chain1.txt

# Chain 2 + 3
docker exec wpvl-wordpress \
  wp --path=/var/www/html --allow-root \
  option get ctf_flag_chain2
docker exec wpvl-wordpress \
  wp --path=/var/www/html --allow-root \
  option get ctf_flag_chain3

# Chain 4
docker exec wpvl-minio mc cat local/wp-backups/backups/wp-dump.sql.gz \
  | gunzip | grep -oE 'FLAG\{[^}]+\}'

# Chain 5
docker exec wpvl-wordpress cat /var/www/html/wp-content/uploads/.ctf-chain5
```

## Regenerating random tokens

The `<random8>` suffixes above are deterministic so graders can reproduce
matching strings. If you want fresh tokens, edit the variables at the top
of `scripts/plant-flags.sh` and rerun it. Update this file and the
`chain-*.md` walkthroughs accordingly.
