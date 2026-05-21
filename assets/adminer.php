<?php
// wordpress-vulnerable-lab — intentional bait file.
// In a real audit this would be a live Adminer instance dropped by an admin.
// We only emit a banner so scanners fingerprint it.
header('Content-Type: text/html; charset=utf-8');
echo "<title>Login - Adminer 4.7.6</title>";
echo "<h1>Adminer 4.7.6</h1>";
echo "<p>Database administration tool — wordpress-vulnerable-lab bait endpoint.</p>";
