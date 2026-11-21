# M-06 — Inyección SQL ciega basada en tiempo en WP Fastest Cache (CVE-2023-6063)

Mitigación del hallazgo **2.6** del informe de pentesting: *Inyección SQL ciega Basada en Tiempo sin Autenticación*.

| Campo | Valor |
|---|---|
| Severidad | Alta (CVSS 3.1: 7.5). Explotable sin autenticación; permite extraer datos de la base. |
| CVE | CVE-2023-6063 |
| CWE | CWE-89 (Neutralización incorrecta de elementos especiales en una sentencia SQL) |
| OWASP | A03:2021 Inyección |
| STRIDE | Divulgación de información (principal) y manipulación (secundaria) |
| Componente | Complemento WP Fastest Cache 1.2.1 (corregido en 1.2.2) |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

La función `is_user_admin()` del complemento (archivo `inc/cache.php`) extrae el nombre de usuario de la cookie `wordpress_logged_in` y lo inserta **sin sanear** en una consulta SQL:

```php
public function is_user_admin(){
    global $wpdb;
    foreach ((array)$_COOKIE as $cookie_key => $cookie_value){
        if(preg_match("/wordpress_logged_in/i", $cookie_key)){
            $username = preg_replace("/^([^\|]+)\|.+/", "$1", $cookie_value);
            break;
        }
    }
    if(isset($username) && $username){
        $res = $wpdb->get_var("SELECT ... FROM `$wpdb->users`
                               INNER JOIN `$wpdb->usermeta`
                               ON `$wpdb->users`.`user_login` = \"$username\" AND ...");
        return $res;
    }
    return false;
}
```

El valor `$username` proviene por completo del cliente (la cookie) y se concatena dentro de la cadena `user_login = "$username"`. Un atacante que cierre la comilla doble puede alterar la lógica de la consulta.

La función se invoca desde `createCache()`, que solo se ejecuta cuando la caché del complemento está habilitada (`wpFastestCacheStatus`), es decir, en el modo normal de uso del complemento. No requiere autenticación: basta con enviar la cookie en una petición a cualquier página.

## 2. Comportamiento vulnerable

Enviando en la cookie una subconsulta `SLEEP(2)` —que MySQL evalúa una sola vez— la respuesta se retrasa de forma medible:

```
Cookie: wordpress_logged_in_t=x" OR (SELECT 1 FROM (SELECT SLEEP(2))z) OR "
```

Consulta resultante (simplificada):

```sql
... ON `wp_users`.`user_login` = "x" OR (SELECT 1 FROM (SELECT SLEEP(2))z) OR "" AND ...
```

Como el retardo es controlable y observable, el atacante puede sustituir `SLEEP(2)` por condiciones booleanas (`IF(condición, SLEEP(2), 0)`) e inferir, bit a bit, el contenido de la base de datos.

## 3. Mitigación aplicada

La mitigación es la **actualización del complemento a la versión 1.2.2**. A diferencia de Ninja Forms (M-05), WP Fastest Cache 1.2.2 declara `Requires at least: 3.3` y es **compatible con WordPress 5.3.2**, por lo que el complemento permanece activo y funcional tras la actualización.

### Parche del proveedor (1.2.1 → 1.2.2)

El diff de `inc/cache.php` entre ambas versiones:

```diff
  if(isset($username) && $username){
+     $username = esc_sql($username);
      $res = $wpdb->get_var("SELECT ... ON `$wpdb->users`.`user_login` = \"$username\" AND ...");
```

**Fundamento.** La función `esc_sql()` de WordPress escapa los caracteres especiales de SQL (entre ellos la comilla doble) en el valor tomado de la cookie. Con el valor escapado, el payload deja de romper la cadena `user_login = "..."` y se interpreta como un literal inerte, de modo que `SLEEP(2)` nunca se ejecuta.

## 4. Verificación

La verificación usa el script [`tests/m06-sqli-wp-fastest-cache.sh`](tests/m06-sqli-wp-fastest-cache.sh), ejecutado antes y después de la mitigación. El script comprueba la versión, la presencia de `esc_sql()` en el código y, sobre todo, el comportamiento en tiempo de ejecución: mide el tiempo de respuesta de una petición con una cookie benigna frente a otra con el payload `SLEEP(2)`.

Para que el vector sea alcanzable, la prueba habilita la caché del complemento (`wpFastestCacheStatus`), que es su modo normal de operación. El laboratorio, tal como lo instala `scripts/install.sh`, no tiene la caché configurada; el informe reprodujo el hallazgo, lo que implica que el complemento estaba en uso.

### Antes de la mitigación ([`evidencia/m06-antes.txt`](evidencia/m06-antes.txt))

```
WP Fastest Cache: versión 1.2.1 · estado active
== 1. Versión fuera del rango vulnerable ==
  [FALLO] Versión 1.2.1 dentro del rango vulnerable (<= 1.2.1)
== 2. Saneado esc_sql() presente en is_user_admin() ==
  [FALLO] La consulta usa el valor de la cookie sin esc_sql()
== 3. Inyección SQL ciega basada en tiempo (cookie, sin autenticación) ==
  tiempo benigno   : 0.086345s
  tiempo inyectado : 2.337194s
  diferencia       : 2.25085s
  [FALLO] El payload SLEEP(2) induce un retardo (SQLi explotable)
```

### Después de la mitigación ([`evidencia/m06-despues.txt`](evidencia/m06-despues.txt))

```
WP Fastest Cache: versión 1.2.2 · estado active
== 1. Versión fuera del rango vulnerable ==
  [OK]    Versión 1.2.2 posterior a 1.2.1 (fuera del rango de CVE-2023-6063)
== 2. Saneado esc_sql() presente en is_user_admin() ==
  [OK]    La consulta sanea el valor de la cookie con esc_sql()
== 3. Inyección SQL ciega basada en tiempo (cookie, sin autenticación) ==
  tiempo benigno   : 0.049329s
  tiempo inyectado : 0.064385s
  diferencia       : 0.015056s
  [OK]    El payload no induce retardo (SQLi no explotable)
```

El retardo inducido por el payload cae de **2.25 s a 0.015 s**: tras el parche, la consulta trata el valor de la cookie como un literal y no ejecuta `SLEEP(2)`.

### Sin regresiones

La prueba de humo (`tests/smoke.sh`) pasó todas las comprobaciones, sin errores fatales de PHP ni de Apache. Tras la verificación, la caché del complemento se deshabilita y se purga para no dejar páginas cacheadas que interfieran con otras pruebas.

## 5. Riesgo residual y recomendaciones

- **Otros valores tomados de cookies o cabeceras.** La actualización corrige la función señalada. Como práctica general, toda entrada del cliente que llegue a una consulta debe pasar por `$wpdb->prepare()` o `esc_sql()`; la versión 1.2.2 aplica el saneado en este punto concreto.
- **Caché y datos sensibles.** Un complemento de caché mal configurado puede servir a un visitante una página cacheada para un usuario autenticado. Conviene revisar las exclusiones de caché (páginas de administración, carrito, áreas privadas) si el complemento se usa en producción.
- **Mantenimiento de versiones.** La causa de fondo —un complemento desactualizado— forma parte del hallazgo 2.4. Se recomienda mantener el complemento en su última versión estable; aquí se actualizó a 1.2.2, la primera versión parcheada.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`apply/m06-sqli-wp-fastest-cache.sh`](apply/m06-sqli-wp-fastest-cache.sh) | Actualiza el complemento a 1.2.2 |
| [`tests/m06-sqli-wp-fastest-cache.sh`](tests/m06-sqli-wp-fastest-cache.sh) | Verifica versión, saneado y retardo inducido por el payload |
