<?php
/*
Plugin Name: BZ Type Juggling Login
Description: Custom login endpoint using == on md5() hashes; magic "0e" hashes bypass.
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: PHP type juggling (CWE-697 / OWASP A07)
 *
 * The endpoint compares md5(input) == storedHash with loose equality. Any input
 * whose md5 starts with "0e" followed by digits is treated as scientific
 * notation 0.0, equal to the stored "0e..." hash.
 *
 * Stored hash = md5('240610708') = '0e462097431906509019562988736854'
 *
 * Repro - bypass with "QNKCDZO" (md5 = 0e830400451993494058024219903391):
 *   curl -X POST -d 'user=admin&pass=QNKCDZO' \
 *     http://localhost:8080/wp-json/bz/v1/tjlogin
 */

if (!defined('ABSPATH')) { exit; }

add_action('rest_api_init', function () {
    register_rest_route('bz/v1', '/tjlogin', [
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => 'bz_tj_login',
    ]);
});

function bz_tj_login(WP_REST_Request $req) {
    $user = (string) $req->get_param('user');
    $pass = (string) $req->get_param('pass');

    // Stored "password" hash for user "admin" -> md5("240610708")
    $stored = '0e462097431906509019562988736854';

    if ($user !== 'admin') {
        return new WP_REST_Response(['ok' => false, 'reason' => 'unknown user'], 401);
    }

    // VULN: loose comparison enables magic-hash bypass
    if (md5($pass) == $stored) {
        return new WP_REST_Response(['ok' => true, 'token' => 'BZ-FAKE-JWT-' . wp_generate_password(8, false)], 200);
    }
    return new WP_REST_Response(['ok' => false], 401);
}
