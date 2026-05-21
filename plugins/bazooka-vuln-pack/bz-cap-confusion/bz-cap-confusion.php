<?php
/*
Plugin Name: BZ Capability Confusion
Description: Uses is_user_logged_in() instead of current_user_can('manage_options') for an admin op.
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: Broken access control / capability misuse (CWE-285 / OWASP A01)
 *
 * The endpoint allows ANY logged-in user (including subscriber) to change a
 * privileged site option because it only checks login status, not capability.
 *
 * Repro (logged in as subscriber):
 *   curl -b COOKIES.txt -X POST \
 *     -d 'action=bz_cap_set_option&key=blogdescription&value=pwned' \
 *     http://localhost:8080/wp-admin/admin-ajax.php
 */

if (!defined('ABSPATH')) { exit; }

add_action('wp_ajax_bz_cap_set_option', 'bz_cap_set_option');

function bz_cap_set_option() {
    // VULN: should be current_user_can('manage_options')
    if (!is_user_logged_in()) {
        wp_send_json_error('login required', 401);
    }
    $key   = isset($_POST['key'])   ? sanitize_key($_POST['key'])  : '';
    $value = isset($_POST['value']) ? wp_unslash($_POST['value']) : '';
    if ($key === '') { wp_send_json_error('bad key', 400); }
    update_option($key, $value);
    wp_send_json_success(['key' => $key, 'value' => $value]);
}
