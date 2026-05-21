<?php
/*
Plugin Name: BZ Race Coupon
Description: Single-use coupon endpoint with TOCTOU window between read and write.
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: Race condition / TOCTOU (CWE-367 / OWASP A04)
 *
 * The endpoint reads coupon state, sleeps briefly to widen the window, then
 * marks it used and credits the wallet. Parallel requests can all pass the
 * "unused" check and each credit the wallet.
 *
 * Setup (creates coupon "WELCOME10" with value 10, once):
 *   curl http://localhost:8080/wp-json/bz/v1/coupon/seed
 *
 * Repro (10 parallel redemptions -> wallet credited multiple times):
 *   seq 1 10 | xargs -n1 -P10 -I{} curl -s -X POST \
 *     http://localhost:8080/wp-json/bz/v1/coupon/redeem?code=WELCOME10
 *   curl http://localhost:8080/wp-json/bz/v1/coupon/wallet
 */

if (!defined('ABSPATH')) { exit; }

add_action('rest_api_init', function () {
    register_rest_route('bz/v1', '/coupon/seed', [
        'methods' => 'GET', 'permission_callback' => '__return_true',
        'callback' => function () {
            update_option('bz_rc_coupon_WELCOME10', ['value' => 10, 'used' => 0]);
            update_option('bz_rc_wallet', 0);
            return ['ok' => true];
        },
    ]);
    register_rest_route('bz/v1', '/coupon/wallet', [
        'methods' => 'GET', 'permission_callback' => '__return_true',
        'callback' => function () {
            return ['wallet' => (int) get_option('bz_rc_wallet', 0)];
        },
    ]);
    register_rest_route('bz/v1', '/coupon/redeem', [
        'methods' => 'POST', 'permission_callback' => '__return_true',
        'callback' => 'bz_rc_redeem',
    ]);
});

function bz_rc_redeem(WP_REST_Request $req) {
    $code = sanitize_key((string) $req->get_param('code'));
    $key  = 'bz_rc_coupon_' . strtoupper($code);
    $c    = get_option($key, null);
    if (!$c) { return new WP_REST_Response(['error' => 'no such coupon'], 404); }

    // VULN: TOCTOU window - check, sleep, then mutate. No DB-level lock.
    if (!empty($c['used'])) {
        return new WP_REST_Response(['error' => 'already used'], 409);
    }
    usleep(150000); // 150ms widens race window

    $wallet = (int) get_option('bz_rc_wallet', 0);
    $wallet += (int) $c['value'];
    update_option('bz_rc_wallet', $wallet);

    $c['used'] = 1;
    update_option($key, $c);

    return new WP_REST_Response(['ok' => true, 'wallet' => $wallet], 200);
}
