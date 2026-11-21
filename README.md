<div align="center">

# 🛡️ Proyecto Final — Seguridad en Aplicaciones

### Pentesting, mitigación y re-evaluación de un sitio WordPress vulnerable

**Universidad Mariano Gálvez de Guatemala** · Facultad de Ingeniería en Sistemas de la Información · Programa de Posgrados · 2026

</div>

---

> ⚠️ **Aviso.** Este repositorio contiene un laboratorio **intencionalmente vulnerable**. Debe ejecutarse únicamente en un equipo o red aislados y nunca exponerse a Internet.

## 📌 Descripción

El proyecto aplica el ciclo completo de gestión de vulnerabilidades sobre una aplicación web real:

```
🔍 Pentesting  →  📋 Informe de hallazgos  →  🔧 Mitigación  →  ✅ Re-evaluación
```

1. **Pentesting.** Se evaluó un sitio WordPress con componentes y configuraciones vulnerables y se documentaron los hallazgos con su prueba de concepto, su clasificación OWASP Top 10 2021 / STRIDE / CWE y su nivel de riesgo.
2. **Mitigación.** Cada hallazgo se corrigió en su causa raíz, con controles adicionales de defensa en profundidad, y se verificó con la misma prueba antes y después del cambio.
3. **Re-evaluación.** El autor del pentesting repite sus pruebas sobre cada corrección. Cada mitigación se integra mediante un *pull request* que se aprueba solo después de esa verificación independiente.

## 🧪 Laboratorio evaluado

El objetivo de las pruebas es [**wordpress-vulnerable-lab v2.0.0**](https://github.com/ayinedjimi/wordpress-vulnerable-lab), un entorno de entrenamiento de código abierto creado por **Ayi Nedjimi** (licencia MIT). Se despliega con Docker Compose e incluye:

| Componente | Detalle |
|---|---|
| Núcleo | WordPress 5.3.2 sobre PHP 7.4 y Apache 2.4.38 |
| Base de datos | MySQL 5.7 |
| Complementos | 45 complementos y temas instalados en versiones con CVE conocidas (2019–2025) |
| Configuraciones inseguras | Archivos sensibles en el webroot, listado de directorios, XML-RPC habilitado, enumeración de usuarios |
| Servicios auxiliares | phpMyAdmin, Adminer, MailHog, Redis y Memcached |

La documentación original del laboratorio se conserva en [`docs/README-lab-original.md`](docs/README-lab-original.md).

## 🔎 Hallazgos y estado de mitigación

| Hallazgo | Vulnerabilidad | OWASP 2021 | Mitigación | Estado |
|---|---|---|---|---|
| 2.1 | Enumeración de usuarios mediante la REST API | A01 | [M-03](hardening/M-03-enumeracion-usuarios.md) | 🔁 En re-evaluación |
| 2.2 | Fuerza bruta de credenciales mediante XML-RPC | A07 | [M-04](hardening/M-04-fuerza-bruta.md) | 🔁 En re-evaluación |
| 2.3 | Exposición de archivos sensibles por mala configuración | A05 | [M-01](hardening/M-01-archivos-sensibles.md) | 🔁 En re-evaluación |
| 2.4 | Uso de componentes desactualizados y vulnerables | A06 | M-08 | ⏳ Pendiente |
| 2.5 | XSS reflejado en Ninja Forms (CVE-2023-37979) | A03 | M-05 | ⏳ Pendiente |
| 2.6 | Inyección SQL ciega sin autenticación en WP Fastest Cache (CVE-2023-6063) | A03 | M-06 | ⏳ Pendiente |
| 2.7 | Escalada de privilegios sin autenticación en Ultimate Member (CVE-2023-3460) | A01 | M-07 | ⏳ Pendiente |
| 2.8 | Listado de directorios habilitado | A05 | [M-02](hardening/M-02-directory-listing.md) | 🔁 En re-evaluación |

**Leyenda:** ⏳ Pendiente · 🔧 En desarrollo · 🔁 En re-evaluación · ✅ Mitigado y re-evaluado

El detalle técnico de cada mitigación (causa raíz, código vulnerable, cambio aplicado, fundamento y evidencia antes y después) está en [`hardening/`](hardening/README.md).

## 🗂️ Estructura del repositorio

```
.
├── README.md                 Descripción del proyecto (este archivo)
├── docker-compose.yml        Despliegue original del laboratorio (estado vulnerable)
├── Dockerfile                Imagen original del laboratorio (estado vulnerable)
├── assets/                   Archivos del laboratorio original
├── scripts/                  Instalación, verificación y reinicio del laboratorio
├── docs/                     Documentación original del laboratorio
└── hardening/                Trabajo de mitigación
    ├── M-0X-*.md             Documento técnico de cada mitigación
    ├── src/                  Dockerfile, docker-compose y configuraciones endurecidas
    ├── apply/                Scripts que aplican cada mitigación
    ├── tests/                Pruebas de verificación (antes y después)
    └── evidencia/            Resultados de las pruebas
```

## 🚀 Uso

**Requisitos:** Docker Engine con Compose v2, `bash`, `curl` y `openssl` (Linux, WSL2 o macOS).

```bash
git clone git@github.com:engelberth90/Proyecto-Final-AppSec.git
cd Proyecto-Final-AppSec

# 1. Levantar el laboratorio en su estado vulnerable
bash scripts/install.sh

# 2. Comprobar un hallazgo (estado anterior)
bash hardening/tests/m01-archivos-sensibles.sh

# 3. Aplicar la mitigación correspondiente
bash hardening/apply/m01-archivos-sensibles.sh

# 4. Repetir la prueba (estado posterior)
bash hardening/tests/m01-archivos-sensibles.sh
```

| Servicio | URL |
|---|---|
| WordPress | http://localhost:31338 |
| phpMyAdmin | http://localhost:31339 |
| MailHog | http://localhost:31340 |
| Adminer | http://localhost:31341 |

> 💡 Para evaluar el estado original sin ninguna mitigación, use la etiqueta `v0-vulnerable`: `git checkout v0-vulnerable`.

## 🔀 Flujo de trabajo

| Elemento | Uso en el proyecto |
|---|---|
| 🏷️ Etiqueta `v0-vulnerable` | Estado del laboratorio evaluado en el pentesting (línea base) |
| 🐞 *Issue* | Un issue por hallazgo del informe |
| 🌿 Rama `fix/mXX-*` | Una rama por mitigación |
| 📥 *Pull request* | Corrección, documentación y evidencia; cierra el issue del hallazgo |
| 👀 Revisión | Re-evaluación del pentester; condición para integrar el cambio |
| 🏷️ Etiqueta `v1-hardened` | Estado final con todas las mitigaciones integradas |

## 👥 Equipo

| Integrante | Rol |
|---|---|
| [Nombre] | 🔍 Pentesting y re-evaluación |
| [Nombre] | 🔧 Mitigación de vulnerabilidades |

## 📄 Créditos y licencia

- Laboratorio base: [wordpress-vulnerable-lab](https://github.com/ayinedjimi/wordpress-vulnerable-lab) © 2026 Ayi Nedjimi, distribuido bajo licencia MIT. Se conserva su historial de commits y su archivo [`LICENSE`](LICENSE).
- El trabajo de mitigación de este repositorio se distribuye bajo la misma licencia MIT.
