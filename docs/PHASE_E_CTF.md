# Phase E — CTF Ground Truth

**Author**: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>

Grader-facing ground-truth fragment for the five CTF kill chains under
`docs/CTF/`. Each row maps the chain to its flag, step count and the
OWASP-2021 / CWE class exercised at each step.

## Chains

| # | Title                                                    | Flag                                | Steps | OWASP per step                                              | CWE per step                              |
|---|----------------------------------------------------------|-------------------------------------|-------|-------------------------------------------------------------|-------------------------------------------|
| 1 | From `.git` Leak to Full RCE                             | `FLAG{wpvulnlab-chain1-a1f3c9e2}`   | 5     | A05, A05, A07, A06                                          | CWE-538, CWE-200, CWE-521, CWE-94          |
| 2 | Subdomain Takeover Sim to Admin Cookie Theft             | `FLAG{wpvulnlab-chain2-b7d2e8f4}`   | 5     | A05, A07, A03, A01, A02                                     | CWE-350, CWE-521, CWE-79, CWE-352, CWE-614 |
| 3 | Open Redirect to OAuth Code Phish to Admin REST Takeover | `FLAG{wpvulnlab-chain3-c4a9b1d6}`   | 6     | A01, A07, A07, A07, A01, A01                                | CWE-601, CWE-287, CWE-290, CWE-287, CWE-862, CWE-798 |
| 4 | SSRF to AWS IMDS to S3 Backup Dump                       | `FLAG{wpvulnlab-chain4-d8e5f2a3}`   | 5     | A10, A10, A05, A01, A05                                     | CWE-918, CWE-918, CWE-668, CWE-522, CWE-200 |
| 5 | XML-RPC Multicall Brute to SVG XSS to Backdoor Plugin    | `FLAG{wpvulnlab-chain5-e2b6c4f9}`   | 5     | A07, A04, A03, A01, A06                                     | CWE-307, CWE-434, CWE-79, CWE-352, CWE-506 |

## Step-by-step vulnerability index

### Chain 1
1. Exposed `.git/` (CWE-538, A05)
2. Backup-file leak `wp-config.php.bak` (CWE-200, A05)
3. Weak admin credentials (CWE-521, A07)
4. backup-migration 1.3.6 unauth RCE CVE-2023-6553 (CWE-94, A06)
5. Flag read on filesystem

### Chain 2
1. Orphan CNAME + `/etc/hosts` takeover sim (CWE-350, A05)
2. Editor/subscriber weak password (CWE-521, A07)
3. popup-builder 4.2.3 stored XSS CVE-2023-6000 (CWE-79, A03)
4. Missing CSRF defenses on admin AJAX (CWE-352, A01)
5. Cookie missing HttpOnly/SameSite (CWE-614, A02)

### Chain 3
1. Open redirect `redirect_to` (CWE-601, A01)
2. miniorange-saml CVE-2024-2879 auth bypass (CWE-287, A07)
3. Assertion replay (CWE-290, A07)
4. SAML signature not verified (CWE-287, A07)
5. wp-cerber CVE-2024-2697 REST auth bypass (CWE-862, A01)
6. Long-lived Application Password persistence (CWE-798, A01)

### Chain 4
1. WP pingback SSRF CVE-2022-3590 (CWE-918, A10)
2. Apache mod_proxy SSRF CVE-2021-40438 (CWE-918, A10)
3. IMDSv1 reachable from container (CWE-668, A05)
4. Hardcoded/long-lived AWS creds (CWE-522, A01)
5. Public S3 bucket containing dump (CWE-200, A05)

### Chain 5
1. XML-RPC system.multicall brute amplification (CWE-307, A07)
2. SVG upload with active content (CWE-434, A04)
3. Stored XSS via SVG in admin view (CWE-79, A03)
4. Admin nonce + cookie exfil over CSRF-able admin endpoints (CWE-352, A01)
5. Malicious plugin install (CWE-506, A06)

## Grading hints

- Each flag is deterministic and produced by `scripts/plant-flags.sh`.
- Partial credit table (suggested):
  - 100% — flag submitted + write-up touching every step
  - 70%  — flag submitted, write-up missing detection/hardening
  - 40%  — partial chain (foothold but no flag)
- Cross-check `docs/CTF/flags.md` for the precise persistence location of
  each flag.

## MITRE ATT&CK coverage across the five chains

`T1190` Exploit Public-Facing App · `T1078` Valid Accounts · `T1110.001`
Password Brute Force · `T1059` Command Execution · `T1505.003` Web Shell ·
`T1552.001` Credentials in Files · `T1539` Steal Web Session Cookie ·
`T1557` Adversary-in-the-Middle (DNS takeover sim) · `T1606.001` Forge
Web Credentials (SAML) · `T1580` Cloud Infrastructure Discovery ·
`T1530` Data from Cloud Storage Object · `T1546` Event Triggered Execution
(backdoor plugin).
