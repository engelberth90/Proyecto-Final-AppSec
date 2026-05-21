<?php
/*
Plugin Name: BZ Broken Nonce
Description: Generates a nonce but never validates it on the AJAX handler (CSRF).
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: CSRF / missing nonce verification (CWE-352)
 *
 * The AJAX action `bz_broken_nonce_delete` is registered for both logged-in and
 * non-priv users and performs a state-changing operation without calling
 * check_ajax_referer() or wp_verify_nonce(). A nonce is emitted in the admin UI
 * for show, but the handler never checks it.
 *
 * Repro (logged in as any subscriber, cookie in COOKIES.txt):
 *   curl -b COOKIES.txt -X POST \
 *     -d 'action=bz_broken_nonce_delete&id=42' \
 *     http://localhost:8080/wp-admin/admin-ajax.php
 */

if (!defined('ABSPATH')) { exit; }

add_action('wp_ajax_bz_broken_nonce_delete',       'bz_bn_delete');
add_action('wp_ajax_nopriv_bz_broken_nonce_delete','bz_bn_delete');

function bz_bn_delete() {
    // VULN: no check_ajax_referer('bz_broken_nonce_action','_wpnonce');
    $id = isset($_POST['id']) ? intval($_POST['id']) : 0;
    update_option('bz_broken_nonce_last_deleted', $id);
    wp_send_json_success(['deleted' => $id]);
}

add_action('admin_menu', function () {
    add_menu_page('BZ Broken Nonce', 'BZ Broken Nonce', 'read', 'bz-broken-nonce', function () {
        $nonce = wp_create_nonce('bz_broken_nonce_action');
        echo '<div class="wrap"><h1>BZ Broken Nonce</h1>';
        echo '<p>Nonce (unused server-side): <code>' . esc_html($nonce) . '</code></p>';
        echo '<p>Last deleted id: <code>' . esc_html(get_option('bz_broken_nonce_last_deleted', '0')) . '</code></p>';
        echo '</div>';
    });
});
