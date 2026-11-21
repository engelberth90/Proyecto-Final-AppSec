# M-05 — XSS reflejado en Ninja Forms (CVE-2023-37979)

Mitigación del hallazgo **2.5** del informe de pentesting: *Cross-site Scripting Reflejado en el Complemento Ninja Forms*.

| Campo | Valor |
|---|---|
| Severidad | Media-alta. Permite ejecutar JavaScript en la sesión de un administrador. |
| CVE | CVE-2023-37979 |
| CWE | CWE-79 (Neutralización incorrecta de entrada durante la generación de páginas web) |
| OWASP | A03:2021 Inyección |
| STRIDE | Manipulación (Tampering), con posible elevación de privilegios |
| Componente | Complemento Ninja Forms 3.6.25 (corregido en 3.6.26) |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

La acción AJAX `nf_batch_process` del complemento, con `batch_type=import_form_template`, devuelve el parámetro `data` en la respuesta sin escapar los caracteres HTML. La respuesta se sirve con `Content-Type: text/html`, de modo que, al renderizarse en un navegador, el marcado inyectado se ejecuta.

El ataque se entrega mediante una página con un formulario de envío automático: cuando un administrador con sesión activa la abre, su navegador envía la petición con sus propias cookies y el código se ejecuta en el contexto del sitio (patrón reflejado asistido por CSRF).

## 2. Comportamiento vulnerable

Petición (con sesión administrativa activa) y respuesta de la versión 3.6.25:

```http
POST /wp-admin/admin-ajax.php
action=nf_batch_process&batch_type=import_form_template
&extraData[template]=formtemplate-contactformd&method_override=_respond
&data=XSSPROBE<img src=x onerror=alert(document.domain)>

HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8

{"data":{"batch_type":"import_form_template",
 "data":"XSSPROBE<img src=x onerror=alert(document.domain)>",
 "action":"nf_batch_process"},"errors":[],"debug":[]}
```

El payload `<img src=x onerror=...>` se refleja literalmente, sin escapar.

## 3. Mitigación aplicada

La mitigación es la **actualización del complemento a la versión 3.6.26**, que incorpora el saneador del proveedor. No se trata de un cambio de configuración propio, sino de la incorporación del parche oficial; por eso la evidencia principal es el diff del proveedor.

### 3.1 Parche del proveedor (3.6.25 → 3.6.26)

La versión 3.6.26 añade la clase `includes/Handlers/Sanitizer.php`:

```php
class Sanitizer {
    const DISALLOWED_SCRIPT_TRIGGERS = [
        '/<\s*(script)/i',   // etiqueta <script
        '/(onload)/i',       // atributo onload
        '/(onerror)/i',      // atributo onerror
    ];

    public static function preventScriptTriggerInHtmlOutput( string $string ): string {
        $fail = false;
        foreach ( self::DISALLOWED_SCRIPT_TRIGGERS as $disallowed ) {
            if ( preg_match( $disallowed, $string ) ) {
                $fail = true;
            }
        }
        if ( $fail ) {
            $string = htmlspecialchars( $string, \ENT_QUOTES );
        }
        return $string;
    }
}
```

El saneador se invoca en los puntos donde la entrada del usuario se incorpora a la salida HTML (`includes/Display/Render.php` e `includes/Admin/Menus/Forms.php`). La versión 3.6.26 añade además `includes/Admin/RestControllerSafeList.php` y modifica `includes/AJAX/REST/Controller.php`, que restringen el procesamiento de las peticiones a un conjunto controlado.

**Fundamento.** El payload del informe (`<img src=x onerror=...>`) contiene la cadena `onerror`, que coincide con uno de los patrones prohibidos. El saneador aplica entonces `htmlspecialchars(..., ENT_QUOTES)`, que convierte `<`, `>` y las comillas en entidades HTML, de modo que el navegador ya no interpreta el marcado como código.

### 3.2 Estado del complemento en el laboratorio

Ninja Forms (tanto la versión vulnerable 3.6.25 como la parcheada 3.6.26) declara `Requires at least: 6.0`, y el laboratorio ejecuta WordPress 5.3.2. En consecuencia, el complemento **no puede activarse de forma normal** en este entorno: la versión parcheada provoca además un error fatal si se fuerza su activación. Dado que el sitio no utiliza Ninja Forms, la mitigación:

- actualiza los archivos del complemento a la versión 3.6.26, con lo que se sustituye el código vulnerable y se corrige la huella de versión que detectan los escáneres;
- mantiene el complemento **inactivo**, su estado natural en el laboratorio, con lo que su endpoint AJAX no se registra y el vector no es alcanzable.

El uso funcional del complemento requeriría actualizar el núcleo de WordPress a una versión compatible (≥ 6.0), lo que corresponde a M-08. Esta incompatibilidad entre la versión del complemento y la del núcleo es, en sí misma, una manifestación del hallazgo 2.4.

## 4. Verificación

La verificación usa el script [`tests/m05-xss-ninja-forms.sh`](tests/m05-xss-ninja-forms.sh), que comprueba la versión, la presencia del saneador y el comportamiento del vector `nf_batch_process`.

Para medir el estado **anterior** fue necesario forzar la activación del complemento 3.6.25 (inyectándolo en `active_plugins`), porque con WordPress 5.3.2 no se activa por los medios normales; es el estado que reproduce el informe. El estado **posterior** corresponde a la mitigación aplicada: versión 3.6.26 e inactivo.

### Antes de la mitigación ([`evidencia/m05-antes.txt`](evidencia/m05-antes.txt))

```
Ninja Forms: versión 3.6.25 · estado active
== 1. Versión fuera del rango vulnerable ==
  [FALLO] Versión 3.6.25 dentro del rango vulnerable (<= 3.6.25)
== 2. Parche del proveedor presente en el código ==
  [FALLO] Clase Sanitizer ausente (código vulnerable)
== 3. Vector del informe (nf_batch_process) ==
  Respuesta (120): {"data":{"batch_type":"import_form_template","data":"XSSPROBE<img src=x onerror=alert(document.domain)>"...
  [FALLO] El payload se refleja SIN escapar (XSS explotable)
```

### Después de la mitigación ([`evidencia/m05-despues.txt`](evidencia/m05-despues.txt))

```
Ninja Forms: versión 3.6.26 · estado inactive
== 1. Versión fuera del rango vulnerable ==
  [OK]    Versión 3.6.26 posterior a 3.6.25 (fuera del rango de CVE-2023-37979)
== 2. Parche del proveedor presente en el código ==
  [OK]    Clase Sanitizer presente (saneador introducido en 3.6.26)
== 3. Vector del informe (nf_batch_process) ==
  Respuesta (120): 0
  [OK]    El payload no se refleja sin escapar
```

El valor `0` de la respuesta posterior es la respuesta estándar de `admin-ajax.php` cuando la acción no está registrada: con el complemento inactivo, el endpoint `nf_batch_process` no existe y el vector no es alcanzable. La corrección del código se evidencia de forma independiente mediante la presencia de la clase `Sanitizer` y el diff del proveedor.

### Sin regresiones

La prueba de humo (`tests/smoke.sh`) pasó todas las comprobaciones, sin errores fatales de PHP ni de Apache.

## 5. Riesgo residual y recomendaciones

- **Verificación funcional completa.** La confirmación de que la versión 3.6.26, ya activa, escapa el payload en tiempo de ejecución requiere un núcleo de WordPress compatible (≥ 6.0). Esa comprobación integrada se realiza junto con la actualización del núcleo en M-08.
- **Complementos incompatibles con el núcleo.** Ninja Forms es uno de varios complementos cuya versión instalada requiere un WordPress más reciente que el del laboratorio. La causa de fondo —un núcleo obsoleto— se corrige en M-08, donde se actualizan de forma coordinada el núcleo y los complementos.
- **Complementos no utilizados.** Si el sitio no necesita Ninja Forms, la opción más segura es eliminarlo por completo, lo que reduce la superficie de ataque y la huella para los escáneres. Aquí se optó por actualizarlo y mantenerlo inactivo para conservar el inventario del laboratorio que evalúa el informe.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`apply/m05-xss-ninja-forms.sh`](apply/m05-xss-ninja-forms.sh) | Actualiza el complemento a 3.6.26 y asegura su estado inactivo |
| [`tests/m05-xss-ninja-forms.sh`](tests/m05-xss-ninja-forms.sh) | Verifica versión, presencia del saneador y comportamiento del vector |
