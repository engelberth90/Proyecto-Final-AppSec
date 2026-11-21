# M-08 — Uso de componentes desactualizados y vulnerables

Mitigación del hallazgo **2.4** del informe de pentesting: *Uso de Componentes Desactualizados y Vulnerables*.

| Campo | Valor |
|---|---|
| Severidad | Alta. Riesgo transversal: cada componente obsoleto aporta vulnerabilidades conocidas con exploits públicos. |
| CWE | CWE-1104 (Uso de componentes de terceros sin mantenimiento), CWE-1035 / OWASP A06 |
| OWASP | A06:2021 Componentes vulnerables y desactualizados |
| STRIDE | Habilita varias categorías según el componente |
| Componentes | Núcleo de WordPress, PHP, Apache y la totalidad de complementos y temas |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

El sitio operaba sobre una plataforma sin soporte y con decenas de componentes obsoletos:

- **Núcleo WordPress 5.3.2** (2019), marcado como inseguro.
- **PHP 7.4.4** y **Apache 2.4.38**, ambos sin soporte oficial.
- Complementos fijados a versiones con CVE publicados (los que trata el informe y muchos más).

Cada componente desactualizado incorpora fallos conocidos y amplía la superficie de ataque; es la condición que hace posibles el resto de los hallazgos de plugins (2.5, 2.6, 2.7). Por eso esta mitigación es la última de la serie y la que cierra las verificaciones de M-05 y M-07.

## 2. Estado vulnerable (según el informe, Tabla 1)

| Componente | Versión instalada | Problema |
|---|---|---|
| WordPress (núcleo) | 5.3.2 (2019) | Múltiples CVE; versión marcada insegura |
| PHP | 7.4.4 | Sin soporte oficial |
| Apache | 2.4.38 | Desactualizado, con CVE conocidas |
| wp-statistics | 13.2.10 | CVE-2024-2194 |
| ultimate-member | 2.6.6 | CVE-2023-3460 |
| royal-elementor-addons | 1.3.78 | CVE-2023-5360 |
| popup-builder | 4.2.3 | CVE-2023-6000 |
| woocommerce | 7.0.0 | CVE-2023-28121 |

Además, el servidor revelaba sus versiones en la cabecera `Server` (`Apache/2.4.38 (Debian)`), en `X-Powered-By` (`PHP/7.4.4`) y en la etiqueta `<meta name="generator">` (`WordPress 5.3.2`).

## 3. Mitigación aplicada

La mitigación actualiza la plataforma completa a versiones con soporte y oculta la información de versión. Se compone de cinco medidas.

### 3.1 Imagen base soportada (PHP y Apache)

`hardening/src/Dockerfile`:

```diff
-FROM wordpress:5.3-php7.4-apache
+FROM wordpress:php8.3-apache
```

El contenedor pasa de **PHP 7.4 / Apache 2.4.38** a **PHP 8.3 / Apache 2.4.65**, ambos con soporte. Se retiró además la configuración de apt apuntando al archivo de Debian Buster (EOL), ya innecesaria.

### 3.2 Actualización del núcleo de WordPress

```bash
wp core update        # 5.3.2 -> 7.1.5
wp core update-db
```

El núcleo pasa de **5.3.2 a 7.1.5** (rama con soporte). La base de datos se migra con `core update-db`.

### 3.3 Actualización de todos los complementos y temas

```bash
wp plugin update --all
wp theme update --all
```

Todos los complementos y temas quedan en su última versión. Los complementos con CVE del informe se actualizan a versiones posteriores al rango vulnerable:

| Componente | Antes | Después |
|---|---|---|
| wp-statistics | 13.2.10 | 14.16.20 |
| ultimate-member | 2.6.6 | 2.14.2 |
| royal-elementor-addons | 1.3.78 | 1.7.1072 |
| woocommerce | 7.0.0 | 11.3.1 |
| ninja-forms (M-05) | 3.6.25 | 3.16.1 |
| wp-fastest-cache (M-06) | 1.2.1 | 1.5.5 |

### 3.4 Eliminación de un complemento retirado del repositorio

El complemento **popup-builder** (CVE-2023-6000) fue **cerrado en WordPress.org** y no recibe actualizaciones. Al no existir una versión parcheada y no ser necesario para el sitio, se elimina por completo, lo que retira tanto el código vulnerable como la huella para los escáneres.

```bash
wp plugin delete popup-builder
```

### 3.5 Ocultación de la información de versión

- **Apache** (`hardening/src/apache/zz-hardening.conf`): `ServerTokens Prod` y `ServerSignature Off` → la cabecera `Server` queda en `Apache`, sin versión ni sistema. `Header unset X-Powered-By` retira la cabecera de PHP.
- **PHP** (`hardening/src/php/zz-hardening.ini`): `expose_php = Off`.
- **WordPress** (`hardening/src/mu-plugins/m08-ocultar-version.php`): retira la etiqueta `<meta name="generator">` y el parámetro `?ver=` del núcleo.

El ajuste de PHP incluye también `memory_limit = 256M`, que los componentes actualizados (Elementor, WooCommerce) requieren por encima del valor por defecto de 128M.

**Fundamento.** Ocultar la versión no sustituye a la actualización, pero reduce la información que un escáner (WPScan, Nuclei) usa para seleccionar exploits. La mitigación real es ejecutar versiones con soporte; la ocultación es defensa en profundidad.

### 3.6 Confirmación en vivo de M-05 y M-07

Con el núcleo en 7.1.5, Ninja Forms y Ultimate Member —que no se activaban en WordPress 5.3.2— se activan y permiten verificar sus mitigaciones en condiciones reales (ver sección 4).

## 4. Verificación

La verificación usa el script [`tests/m08-componentes-desactualizados.sh`](tests/m08-componentes-desactualizados.sh).

### Estado posterior ([`evidencia/m08-despues.txt`](evidencia/m08-despues.txt))

```
Núcleo WordPress: 7.1.5 · PHP: 8.3
== 1. Núcleo en rama soportada ==
  [OK]    WordPress 7.1.5 (rama con soporte)
== 2. PHP 8.x y Apache sin versión divulgada ==
  [OK]    PHP 8.3 (con soporte)
  [OK]    Cabecera Server sin versión: Apache
== 3. Sin actualizaciones pendientes ==
  [OK]    Todos los complementos al día
  [OK]    Todos los temas al día
== 4. Complementos con CVE del informe, fuera del rango vulnerable ==
  [OK]    wp-statistics 14.16.20 (> 13.2.10)
  [OK]    ultimate-member 2.14.2 (> 2.6.6)
  [OK]    royal-elementor-addons 1.7.1072 (> 1.3.78)
  [OK]    popup-builder eliminado (superficie de ataque retirada)
  [OK]    woocommerce 11.3.1 (> 7.0.0)
  [OK]    ninja-forms 3.16.1 (> 3.6.25)
  [OK]    wp-fastest-cache 1.5.5 (> 1.2.1)
== 5. La versión de WordPress no se divulga (meta generator) ==
  [OK]    Sin meta generator de WordPress
  [OK]    Sin cabecera X-Powered-By
```

### Confirmación en vivo de M-05 y M-07

Con los complementos ya activos sobre el núcleo actualizado:

- **M-05 (Ninja Forms):** la petición `nf_batch_process` del informe deja de reflejar el payload. La respuesta es `{"data":[],"errors":["Requested method override is not allowed"],...}`: la versión 3.16.1 rechaza el `method_override` y no refleja la entrada.
- **M-07 (Ultimate Member):** el complemento 2.14.2 se activa y funciona; incorpora la lista blanca de claves de metadatos (`is_metakey_banned` / `usermeta_whitelist`) que cierra la escalada de privilegios.

### Regresión de todas las mitigaciones

Tras la actualización, se reejecutaron las pruebas de M-01 a M-07 sobre el stack nuevo:

| Mitigación | Resultado en el stack actualizado |
|---|---|
| M-01 Archivos sensibles | 0 de 15 rutas expuestas |
| M-02 Listado de directorios | 0 directorios con listado |
| M-03 Enumeración de usuarios | 0 respuestas con fuga |
| M-04 Fuerza bruta | `xmlrpc.php` 404; límite de intentos activo (bloqueo en el intento 6) |
| M-05 XSS Ninja Forms | Payload no reflejado (complemento activo) |
| M-06 SQLi WP Fastest Cache | Sin retardo (SQLi no explotable) |
| M-07 Escalada Ultimate Member | Versión parcheada, complemento activo |

La prueba de humo (`tests/smoke.sh`) pasó todas las comprobaciones, sin errores fatales de PHP ni de Apache.

> **Nota sobre las pruebas de M-04 y M-06.** WordPress 7.1 cambió el marcado del mensaje de error de inicio de sesión y WP Fastest Cache 1.5.5 reubicó su función interna. Se ajustaron las dos pruebas (extracción del mensaje y localización del saneado) para que sigan siendo válidas en el stack actualizado; las mitigaciones no cambiaron.

## 5. Riesgo residual y recomendaciones

- **Mantenimiento continuo.** La actualización corrige el estado actual, pero la obsolescencia es recurrente. Se recomienda habilitar las actualizaciones automáticas de seguridad del núcleo y revisar periódicamente complementos y temas.
- **Huella de versión de complementos.** Algunos complementos añaden su propia etiqueta `generator` o exponen su versión en archivos `readme.txt`. Al estar ahora todos actualizados, esa información ya no señala versiones vulnerables.
- **Reducción de superficie.** El sitio conserva muchos complementos heredados del laboratorio. En un entorno real se recomienda desinstalar los que no se utilicen; cada complemento activo es superficie de ataque. Como ejemplo, en esta mitigación se eliminó popup-builder.
- **Caché.** El complemento de caché (litespeed-cache) puede servir páginas cacheadas; conviene purgar la caché tras cambios de seguridad y revisar sus exclusiones.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`src/Dockerfile`](src/Dockerfile) | Imagen base soportada (WordPress/PHP 8.3/Apache) |
| [`src/php/zz-hardening.ini`](src/php/zz-hardening.ini) | `expose_php=Off`, errores a registro, `memory_limit=256M` |
| [`src/apache/zz-hardening.conf`](src/apache/zz-hardening.conf) | `ServerTokens Prod`, `ServerSignature Off`, retirada de `X-Powered-By` |
| [`src/mu-plugins/m08-ocultar-version.php`](src/mu-plugins/m08-ocultar-version.php) | Oculta la versión de WordPress (generator y `?ver=`) |
| [`apply/m08-componentes-desactualizados.sh`](apply/m08-componentes-desactualizados.sh) | Actualiza núcleo, complementos y temas; elimina componentes retirados |
| [`tests/m08-componentes-desactualizados.sh`](tests/m08-componentes-desactualizados.sh) | Verifica versiones soportadas, ausencia de pendientes y no divulgación |
