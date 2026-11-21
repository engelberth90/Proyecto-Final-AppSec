# M-07 — Escalada de privilegios sin autenticación en Ultimate Member (CVE-2023-3460)

Mitigación del hallazgo **2.7** del informe de pentesting: *Escalada de Privilegios sin Autenticar*.

| Campo | Valor |
|---|---|
| Severidad | Crítica (CVSS 3.1: 9.8). Un visitante sin autenticación puede registrarse como administrador. |
| CVE | CVE-2023-3460 |
| CWE | CWE-269 (Gestión inadecuada de privilegios) |
| OWASP | A01:2021 Pérdida de control de acceso |
| STRIDE | Elevación de privilegios |
| Componente | Complemento Ultimate Member 2.6.6 (corregido en 2.6.7) |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

Durante el registro, Ultimate Member guarda como metadatos del nuevo usuario los campos enviados en el formulario. Para impedir que se fijen metadatos sensibles, el complemento usaba una **lista de bloqueo** de claves prohibidas (entre ellas `wp_capabilities`, que define el rol). Esa lista podía evadirse manipulando la clave —por ejemplo, añadiendo barras o alterando mayúsculas—, de modo que la clave efectiva llegaba a la base de datos sin coincidir con la entrada bloqueada.

Aprovechando esta evasión, un visitante sin autenticación puede fijar `wp_capabilities` con el valor de administrador durante el registro y obtener control total del sitio.

La debilidad de fondo es el uso de una lista de bloqueo (enumerar lo prohibido) en lugar de una lista blanca (enumerar lo permitido): cualquier variante no contemplada en la lista de bloqueo pasa el control.

## 2. Comportamiento vulnerable

El informe confirmó la versión instalada (2.6.6) mediante el archivo `readme.txt` y la contrastó con el rango afectado por CVE-2023-3460 (corregido en 2.6.7). La explotación consiste en enviar al formulario de registro un campo cuya clave, tras la evasión de la lista de bloqueo, se resuelve como `wp_capabilities` con el rol `administrator`.

## 3. Mitigación aplicada

La mitigación es la **actualización del complemento a la versión 2.6.7**, que reemplaza la lista de bloqueo por una lista blanca de claves de metadatos permitidas.

### Parche del proveedor (2.6.6 → 2.6.7)

La versión 2.6.7 añade en `includes/core/class-user.php` el método `is_metakey_banned()`, que trabaja con una lista blanca (`usermeta_whitelist`):

```php
public function is_metakey_banned( $meta_key, $context = '' ) {
    ...
    if ( ! $is_banned && 'submission' === $context
         && ! in_array( $meta_key, UM()->form()->usermeta_whitelist, true ) ) {
        $is_banned = true;   // Si la clave no está en la lista blanca, se rechaza.
    }
    ...
}
```

Y aplica la comprobación al procesar los campos enviados:

```php
if ( $this->is_metakey_banned( $key, ( 'account' !== $context ) ? 'submission' : '' ) ) {
    // se descarta la clave
}
```

Además, `includes/core/um-actions-register.php` incorpora la validación explícita del rol en el registro (`um_registration_user_role`), «to properly validate role for security reasons».

**Fundamento.** Con la lista blanca, solo se aceptan las claves de metadatos definidas por el formulario; cualquier otra —incluida `wp_capabilities` y sus variantes evadidas— se rechaza. El cambio de modelo (de lista de bloqueo a lista blanca) elimina la clase de evasión que hacía posible el ataque.

### Estado del complemento en el laboratorio

Ultimate Member (tanto 2.6.6 como 2.6.7) declara `Requires at least: 5.5`, y el laboratorio ejecuta WordPress 5.3.2. Por tanto el complemento **no puede activarse de forma normal** en este entorno. Dado que el sitio no lo utiliza, la mitigación:

- actualiza los archivos a la versión 2.6.7, con lo que se sustituye el código vulnerable y se corrige la huella de versión que detectan los escáneres;
- mantiene el complemento **inactivo**, su estado natural en el laboratorio, con lo que el formulario de registro de Ultimate Member no está disponible y el vector no es alcanzable.

El uso funcional del complemento requeriría actualizar el núcleo de WordPress a una versión compatible (≥ 5.5), lo que corresponde a M-08. Esta incompatibilidad entre la versión del complemento y la del núcleo es, en sí misma, una manifestación del hallazgo 2.4.

## 4. Verificación

La verificación usa el script [`tests/m07-pe-ultimate-member.sh`](tests/m07-pe-ultimate-member.sh), que comprueba la versión instalada y la presencia del control de lista blanca introducido por el parche. Al igual que el informe —que confirmó este hallazgo por número de versión— la verificación no ejecuta el registro en vivo, porque el complemento no se activa en WordPress 5.3.2; la comprobación funcional completa corresponde a M-08.

### Antes de la mitigación ([`evidencia/m07-antes.txt`](evidencia/m07-antes.txt))

```
Ultimate Member: versión 2.6.6 · estado inactive
== 1. Versión fuera del rango vulnerable ==
  [FALLO] Versión 2.6.6 dentro del rango vulnerable (<= 2.6.6)
== 2. Control de la versión parcheada: lista blanca de claves de metadatos ==
  [FALLO] Ausente el control de lista blanca (lógica de lista de bloqueo evadible)
```

### Después de la mitigación ([`evidencia/m07-despues.txt`](evidencia/m07-despues.txt))

```
Ultimate Member: versión 2.6.7 · estado inactive
== 1. Versión fuera del rango vulnerable ==
  [OK]    Versión 2.6.7 posterior a 2.6.6 (fuera del rango de CVE-2023-3460)
== 2. Control de la versión parcheada: lista blanca de claves de metadatos ==
  [OK]    Presente is_metakey_banned() con lista blanca usermeta_whitelist
== 3. Estado en el laboratorio ==
  [OK]    Complemento inactivo: el vector de registro no es alcanzable en este entorno
```

### Sin regresiones

La prueba de humo (`tests/smoke.sh`) pasó todas las comprobaciones, sin errores fatales de PHP ni de Apache.

## 5. Riesgo residual y recomendaciones

- **Verificación funcional completa.** La confirmación de que la versión 2.6.7, ya activa, rechaza una clave `wp_capabilities` enviada en el registro requiere un núcleo de WordPress compatible (≥ 5.5). Esa comprobación integrada se realiza junto con la actualización del núcleo en M-08.
- **Auditoría de cuentas.** Tras una vulnerabilidad de escalada de privilegios debe revisarse que no se hayan creado cuentas de administrador no autorizadas. En el laboratorio, las cuentas existentes son `admin`, `editor` y `subscriber` (verificado en M-03); no hay administradores adicionales.
- **Complementos no utilizados.** Si el sitio no necesita Ultimate Member, la opción más segura es eliminarlo. Aquí se actualizó y se mantuvo inactivo para conservar el inventario que evalúa el informe.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`apply/m07-pe-ultimate-member.sh`](apply/m07-pe-ultimate-member.sh) | Actualiza el complemento a 2.6.7 y asegura su estado inactivo |
| [`tests/m07-pe-ultimate-member.sh`](tests/m07-pe-ultimate-member.sh) | Verifica versión y presencia del control de lista blanca |
