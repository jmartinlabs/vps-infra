# Diseño de despliegue directo de PROD por tag

Fecha: 2026-11-08
Estado: **DISEÑO — no implementado, no habilitado, no ejecutado.** No autoriza acceso al
VPS, credenciales, tags ni despliegues.

Complementa [despliegue por tags](despliegue-por-tags.md) y [despliegue directo TEST](despliegue-directo-test-01.md).
Sustituye cualquier referencia a GitHub Environments o aprobación por revisores: la creación
del tag `deploy-prod-v*` por un actor autorizado es la orden de despliegue.

## Flujo

```text
tag deploy-prod-vX.Y.Z (actor autorizado, anotado e inmutable)
        ▼
validar tag, actor, SHA ancestro de main y promoción desde test
        ▼
CI + qa + Rootless sobre el SHA exacto
        ▼
release idéntica a la que superó TEST (SHA y manifest sha256)
        ▼
preflight PROD + copia cifrada + restore verificado
        ▼
SSH dedicado PROD → receptor PROD → smoke → éxito o rollback
```

Los merges a `test` o `main` no despliegan. Sin GHCR, sin timer, sin polling, sin
Environment.

## Aislamiento

| Elemento | TEST | PROD |
| --- | --- | --- |
| Usuario SSH | `mftest` | `mfprod` (distinto, sin sudo) |
| Clave | `TEST_DEPLOY_KEY` | `PROD_DEPLOY_KEY` (distinta) |
| Release | `/srv/myfinanzas-test` | `/srv/myfinanzas-prod` |
| Datos | `/srv/myfinanzas-test/data` (ficticios) | `/srv/myfinanzas-prod/data` (reales) |
| Frontend | `/var/www/myfinanzas-test` | `/var/www/myfinanzas-prod` |
| Unidad | `myfinanzas-test-api` | `myfinanzas-prod-api` |
| Loopback | `127.0.0.1:18082` | `127.0.0.1:18081` |
| Origen del tag | `test` | `main`, promovido desde `test` |
| Interruptor | `MYFINANZAS_TEST_DEPLOY` | `MYFINANZAS_PROD_DEPLOY` (desactivado) |

PROD no comparte usuario, clave, rutas, unidad, puerto, Caddy, logs ni copias con TEST.

## Gates

1. Tag `deploy-prod-vX.Y.Z`, anotado, inmutable, creado por un actor de la allowlist; el
   workflow comprueba además el actor (`MYFINANZAS_DEPLOY_ACTORS`).
2. Commit del tag = SHA completo, ancestro de `origin/main`, promovido desde `test` con
   merge aprobado; no se acepta `HEAD` móvil ni merge ref.
3. `required`, `qa` y Rootless en `SUCCESS` sobre ese SHA.
4. Misma versión, SHA y `manifest_sha256` que la release TEST verificada; PROD no reconstruye
   un artefacto distinto. Si TEST no tiene evidencia vigente, se detiene.
5. Contrato de esquema/datos idéntico al instalado. Una migración exige procedimiento
   separado, autorización y ventana; no forma parte de este flujo inicial.
6. Copia cifrada previa e integridad verificada; restauración ensayada según SPEC31. Sin
   copia válida no se muta.
7. Preflight de host: disco, memoria, puertos, loopback, unidad, Caddy, DNS y permisos.
8. Bloqueo exclusivo PROD; un segundo despliegue se rechaza.

## Receptor PROD

Reutiliza la verificación de `scripts/deploy-test-release` (manifiesto, `SHA256SUMS`,
frontend y recursos, OCI, contratos) con configuración PROD y estas diferencias:

- exige `--environment prod`, `--version` y el par de backup;
- crea la copia cifrada antes de detener la unidad y verifica su hash;
- no ejecuta seed ni migraciones;
- activa unidad y frontend como conjunto, con smoke PROD;
- ante fallo, restaura unidad + `current` y arranca; si el rollback falla, detiene la unidad
  y preserva estado, copia y logs;
- registra `deployment_id`, versión, SHA, manifiesto, backup, smoke y resultado.

La implementación PROD no se crea hasta autorización específica; este documento fija el
contrato para revisarlo.

## Backup y recuperación

- Copia cifrada con la política de SPEC31, incluyendo WAL/SHM de forma consistente.
- Verificación de hash y `PRAGMA integrity_check` sobre una restauración temporal.
- Custodia externa y retención según DEP7.
- Rollback app-only automático; recuperación de datos solo desde la copia, con autorización
  separada.
- Un rollback fallido deja el servicio parado y no se reintenta automáticamente.

## Habilitación

1. Receptor, usuario, clave, rutas y Caddy PROD creados con autorización operativa.
2. Workflow PROD fusionado pero inerte: `MYFINANZAS_PROD_DEPLOY` ausente o `false`.
3. Allowlist de actores y ruleset de tags verificados con una prueba negativa.
4. Copia/restore ensayados y aceptación funcional de PROD.
5. Solo entonces se activa la variable y se crea el primer `deploy-prod-vX.Y.Z`.

Ningún paso de esta lista está ejecutado.
