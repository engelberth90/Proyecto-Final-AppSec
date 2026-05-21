# CTF Kill-Chain Walkthroughs

**Lab**: `wordpress-vulnerable-lab`
**Author**: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>
**Default target**: http://localhost:31338

This directory contains five end-to-end attack chains designed to be replayed
in the lab. Each chain stitches together at least three independent
vulnerabilities from `docs/VULNERABILITIES.md` into a single realistic
kill-chain, with copy-paste-ready commands, expected output, defender
visibility notes and hardening guidance.

Plant the flags first:

```bash
bash scripts/plant-flags.sh
```

## Index

| # | Title | Entry vuln | Pivot | Impact | Flag |
|---|-------|------------|-------|--------|------|
| 1 | From `.git` to RCE | Exposed `.git/` | `wp-config` creds | Backup-Migration RCE | `FLAG{wpvulnlab-chain1-a1f3c9e2}` |
| 2 | Subdomain takeover to admin cookie | Orphan CNAME (sim) | Stored XSS | Admin session hijack | `FLAG{wpvulnlab-chain2-b7d2e8f4}` |
| 3 | Open redirect to OAuth phish | Open redirect | OAuth code intercept | Admin REST takeover | `FLAG{wpvulnlab-chain3-c4a9b1d6}` |
| 4 | SSRF to cloud metadata to S3 dump | Pingback/avatar SSRF | AWS IMDSv1 | S3 backup exfil | `FLAG{wpvulnlab-chain4-d8e5f2a3}` |
| 5 | XML-RPC brute to persistent backdoor | xmlrpc multicall | SVG XSS | Backdoor plugin install | `FLAG{wpvulnlab-chain5-e2b6c4f9}` |

## Conventions

- All commands are `bash`/`curl` from the host machine.
- Replace `TARGET=http://localhost:31338` if you remapped the port.
- Cookies are stored in `/tmp/cj-chainN.txt` to keep chains isolated.
- Each chain ends with a `FLAG{wpvulnlab-chainN-<hex>}` string planted by
  `scripts/plant-flags.sh`.
- Detection notes assume the Apache `access.log` / `error.log` shipped with
  the base image and the MySQL general log enabled in `config/my.cnf`.

## Difficulty

| Chain | Skill | Time |
|-------|-------|------|
| 1 | Beginner | ~15 min |
| 2 | Intermediate | ~25 min |
| 3 | Intermediate | ~20 min |
| 4 | Advanced | ~35 min |
| 5 | Advanced | ~40 min |

See `docs/PHASE_E_CTF.md` for the ground-truth fragment used by graders.
