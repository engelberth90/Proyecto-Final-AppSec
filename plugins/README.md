# plugins/

This directory is **intentionally empty** in the repo.

Vulnerable plugin ZIPs are downloaded at install time from the official
WordPress plugin CDN (`downloads.wordpress.org`), so we never ship binaries
that might violate distribution licences.

To override (e.g. add a delisted plugin you have lawful access to):

1. Drop `slug.version.zip` here.
2. The install script will prefer the local copy if present.
