<?php
/*
Plugin Name: BZ CRLF Injection Redirect
Description: Redirect endpoint that puts $_GET['url'] directly in a Location header.
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: CRLF / HTTP response splitting + open redirect (CWE-113 / CWE-601)
 *
 * Note: modern PHP/SAPIs reject \r\n in header() since 5.1.2 (CVE-2006-0207
 * mitigation). The lab uses the lower-level header() with a raw string to
 * demonstrate the SOURCE pattern even when the platform may block injection,
 * and unambiguously demonstrates the open-redirect side-effect.
 *
 * Repro (open redirect):
 *   curl -i 'http://localhost:8080/?bz_crlf=1&url=https://evil.tld/'
 *
 * Repro (CRLF attempt - rejected by hardened SAPIs, accepted by older ones):
 *   curl -i 'http://localhost:8080/?bz_crlf=1&url=/safe%0d%0aX-Injected:%20yes'
 */

if (!defined('ABSPATH')) { exit; }

add_action('init', function () {
    if (!isset($_GET['bz_crlf'])) { return; }
    $url = isset($_GET['url']) ? (string) $_GET['url'] : '/';

    // VULN: no validation, no wp_safe_redirect, no urlencode
    header('Location: ' . $url);
    exit;
});
