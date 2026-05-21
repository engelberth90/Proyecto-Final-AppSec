<?php
/*
Plugin Name: BZ Host Header Poisoning
Description: Password-reset link built from $_SERVER['HTTP_HOST'] (host header injection).
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: Host header injection -> account takeover (CWE-20 / OWASP A03)
 *
 * The reset endpoint builds the reset URL from the Host header sent by the
 * attacker, then emails it to the victim. Click -> token leaks to attacker host.
 *
 * Repro:
 *   curl -X POST -H 'Host: attacker.tld' \
 *     -d 'login=victim' \
 *     http://localhost:8080/wp-json/bz/v1/reset
 *   # Inspect wp_options 'bz_hp_last_link' to see the poisoned URL.
 */

if (!defined('ABSPATH')) { exit; }

add_action('rest_api_init', function () {
    register_rest_route('bz/v1', '/reset', [
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => 'bz_hp_reset',
    ]);
});

function bz_hp_reset(WP_REST_Request $req) {
    $login = sanitize_user((string) $req->get_param('login'));
    $user  = get_user_by('login', $login);
    if (!$user) { return new WP_REST_Response(['ok' => true], 200); } // do not leak

    $token = wp_generate_password(20, false);
    update_user_meta($user->ID, 'bz_hp_reset_token', $token);

    // VULN: HTTP_HOST is attacker-controlled
    $host = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'localhost';
    $link = 'http://' . $host . '/wp-json/bz/v1/reset-confirm?u=' . $user->ID . '&t=' . $token;

    update_option('bz_hp_last_link', $link); // for lab inspection (instead of real email)
    return new WP_REST_Response(['ok' => true], 200);
}
