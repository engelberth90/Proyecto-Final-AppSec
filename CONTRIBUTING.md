# Contributing

Thanks for considering a contribution to **wordpress-vulnerable-lab**.

The goal of this project is to be **the most complete Docker WordPress
vulnerable lab in the world**. Every PR should push that goal forward.

## What we want

- New CVE entries (2023 onward preferred) with a publicly available plugin
  version on `downloads.wordpress.org`.
- Pre-built exploit walkthroughs in `docs/ATTACK_PATHS.md`.
- New CTF-style challenges in `docs/CHALLENGES.md`.
- Better benchmark methodology in `docs/BENCHMARK.md`.
- CI improvements (faster boot, smaller image, better verification).

## What we do NOT want

- Live exploit code targeting production systems.
- Plugins delisted from .org (unless mirrored with explicit author permission).
- Anything that mentions or implies hostility toward a specific live website.

## Workflow

1. Fork, branch, commit.
2. Run `scripts/verify.sh` locally.
3. Open a PR with a description that includes:
   - CVE id(s)
   - Plugin slug + version
   - Vulnerability class (RCE / SQLi / XSS / PE / AB / IDOR / LFI)
   - A 1-line repro hint (the lab itself, NOT a real target).

## Author

Maintained by **Ayi NEDJIMI** — <ayinedjimi@users.noreply.github.com>
