<?php
/*
Plugin Name: BZ No Clickjacking Protection
Description: Admin action page deliberately strips X-Frame-Options / CSP frame-ancestors.
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: Clickjacking / missing framebusting (CWE-1021 / OWASP A05)
 *
 * Adds a one-click admin action page and explicitly removes X-Frame-Options so
 * a malicious site can iframe it and trick an authenticated admin into clicking.
 *
 * Repro (victim is logged-in admin, opens attacker page):
 *   <iframe src="http://localhost:8080/wp-admin/admin.php?page=bz-clickjack"
 *           style="opacity:0.01;position:absolute;top:0;left:0;width:100%;height:100%"></iframe>
 *   <button style="position:absolute;top:120px;left:80px;z-index:-1">Win a prize</button>
 *   # Admin clicks the visible button which actually clicks the iframe's "Delete all" form.
 */

if (!defined('ABSPATH')) { exit; }

// VULN: strip framebusting headers on our admin page
add_action('admin_init', function () {
    if (isset($_GET['page']) && $_GET['page'] === 'bz-clickjack') {
        header_remove('X-Frame-Options');
        header_remove('Content-Security-Policy');
    }
});

add_action('admin_menu', function () {
    add_menu_page('BZ Clickjack', 'BZ Clickjack', 'manage_options', 'bz-clickjack', 'bz_cj_page');
});

function bz_cj_page() {
    if (!empty($_POST['bz_cj_action']) && $_POST['bz_cj_action'] === 'wipe') {
        // safe-by-default: just bump a counter, do not actually delete anything
        $n = (int) get_option('bz_cj_clicks', 0) + 1;
        update_option('bz_cj_clicks', $n);
        echo '<div class="notice notice-warning"><p>Action executed (' . esc_html($n) . ' total).</p></div>';
    }
    ?>
    <div class="wrap">
        <h1>BZ Clickjack target</h1>
        <p>Frameable admin action (would be destructive in real life).</p>
        <form method="post">
            <input type="hidden" name="bz_cj_action" value="wipe" />
            <button class="button button-primary">Confirm critical action</button>
        </form>
    </div>
    <?php
}
