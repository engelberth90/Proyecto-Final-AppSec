<?php
/*
Plugin Name: BZ XXE SOAP
Description: REST endpoint that parses XML with external entities enabled (XXE).
Version: 1.0.0
Author: Ayi NEDJIMI
Author URI: https://github.com/ayi-nedjimi
License: GPL-2.0
*/

/*
 * VULN CLASS: XML External Entity (XXE) - CWE-611 / OWASP A05
 *
 * The REST endpoint POST /wp-json/bz/v1/xxe accepts a raw XML body and parses it
 * with simplexml_load_string($body, null, LIBXML_NOENT) which expands external
 * entities (file://, http://, etc).
 *
 * Repro:
 *   curl -X POST -H 'Content-Type: application/xml' \
 *     --data-binary @- http://localhost:8080/wp-json/bz/v1/xxe <<'EOF'
 *   <?xml version="1.0"?>
 *   <!DOCTYPE r [ <!ENTITY x SYSTEM "file:///etc/hostname"> ]>
 *   <r><name>&x;</name></r>
 *   EOF
 */

if (!defined('ABSPATH')) { exit; }

add_action('rest_api_init', function () {
    register_rest_route('bz/v1', '/xxe', [
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => 'bz_xxe_handle',
    ]);
});

function bz_xxe_handle(WP_REST_Request $req) {
    $body = $req->get_body();
    if ($body === '' || $body === null) {
        return new WP_REST_Response(['error' => 'empty body'], 400);
    }
    // VULN: LIBXML_NOENT expands external entities
    libxml_use_internal_errors(true);
    $xml = @simplexml_load_string($body, 'SimpleXMLElement', LIBXML_NOENT | LIBXML_DTDLOAD);
    if ($xml === false) {
        return new WP_REST_Response(['error' => 'bad xml'], 400);
    }
    return new WP_REST_Response(['parsed' => (string) $xml->name], 200);
}
