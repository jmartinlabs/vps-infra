# Release gate local · Dry-run

`scripts/release-gate` valida una solicitud de despliegue y un paquete de release
**sin red, sin acceso al VPS y sin ejecutar código de la aplicación**. Es la primera pieza
implementable del [contrato de despliegue por tags](despliegue-por-tags.md); no activa ni
sustituye el procedimiento manual.

> **Estado:** solo `dry-run`. `--mode apply` se rechaza de forma explícita. No crea tags,
> workflows, credenciales, unidades, servicios ni cambios en el host.

## Interfaz

- Solicitud: [`schemas/deploy-request.v1.json`](../schemas/deploy-request.v1.json).
- Ejemplo no operativo: [`templates/deploy-request.example.json`](../templates/deploy-request.example.json).
- Resultado: JSON por `--output` o por `stdout`, con `result`, `checks`, `blockers` y
  `verification`.

La solicitud es un envoltorio mínimo. El manifiesto del paquete sigue siendo la fuente de
verdad para `inputs.source`, `inputs.contracts`, `oci_manifest_digest`,
`oci_archive_sha256`, `seed` y `frontend_files`. El gate no reimplementa `release.py`:
verifica esos campos y la integridad del paquete.

La solicitud incorpora `release_ref` (`myfinanzas-app/test` para TEST,
`myfinanzas-app/main` para PROD), `package_format`
(`myfinanzas-test-artifact-zip.v1`), `package_sha256` y `seed_image`. El artifact ZIP contiene
`manifest.json`, `manifest.sha256`, `image.oci.tar`, `image.seed.oci.tar`, `frontend/` y
`SHA256SUMS`.
El `seed-manifest.json` es un artefacto de ejecución posterior a `seed apply`, no parte del
paquete de build.

## Uso

Preflight, antes de modificar estado. La solicitud TEST lleva
`seed_manifest_sha256: null` porque el manifiesto aún no existe:

```bash
./scripts/release-gate check \
  --request /ruta/deploy-request.json \
  --release-dir /ruta/privada/release \
  --package /ruta/privada/myfinanzas-test-<sha>.zip \
  --state /ruta/state-fixture.json \
  --evidence /ruta/evidence-fixture.json \
  --mode dry-run \
  --output /ruta/result.json
```

Verificación posterior de FT-1, después de `seed apply` y antes de activar la unidad:

```bash
./scripts/release-gate verify-seed \
  --request /ruta/deploy-request.json \
  --release-dir /ruta/privada/release \
  --seed-manifest /srv/myfinanzas-test/data/seed-manifest.json \
  --output /ruta/result-seed.json
```

- `--release-dir` es una entrada de confianza separada; no se acepta una ruta del JSON.
- `--package` es obligatorio en `check` y verifica el SHA-256 del paquete recibido contra
  `package_sha256`.
- `--state` simula el estado del host (instalado/bloqueo). Es obligatorio: sin este fixture
  el gate bloquea y no puede validar concurrencia ni rollback.
- `--evidence` simula CI, Rootless, QA, ascendencia Git y aprobación PROD. Sin este fixture
  el gate bloquea: no declara verificado nada que no haya comprobado localmente.
- `--seed-manifest` es obligatorio en `verify-seed` y prohibido en PROD.
- Códigos de salida: `0` éxito, `2` bloqueado antes de mutar, `3` error interno.

## Verificación local frente a simulación

| Grupo | Qué significa |
| --- | --- |
| `verification.local` | Comprobado por el gate: formato, tag/versión, entorno, `release_ref`, hash del paquete, SHA declarado, hash del manifiesto, `manifest.sha256`, `inputs.source`, contratos, OCI de app y seed, frontend y seed. |
| `verification.simulated` | Evaluado a partir de fixtures: CI, Rootless, QA, ascendencia Git, aprobación PROD y estado del host. **No** se consultó GitHub, Git ni el VPS. |
| `verification.real_world_not_verified` | Lista explícita de lo que sigue sin verificar en una activación real. |

Un `result: success` en `dry-run` significa «habría pasado las comprobaciones locales y los
fixtures dados». No significa que GitHub, QA, Rootless o una autorización PROD estén
verificados.

## Comprobaciones principales

- Formato estricto, campos desconocidos y claves con aspecto de secreto.
- `version` SemVer estable, tag `deploy-(test|prod)-vX.Y.Z` y coincidencia tag/entorno/versión.
- SHA de 40 caracteres, hash de manifiesto y digest OCI.
- `release_ref` coherente con el entorno; `package_format` y `package_sha256` válidos.
- Integridad de `manifest.json`, `manifest.sha256`, `image.oci.tar`, `image.seed.oci.tar`,
  `index.json`, blobs OCI, `frontend_files` y `SHA256SUMS`.
- Estructura mínima del manifiesto OCI: `schemaVersion`, `config`, `layers` y descriptores con
  digest, tamaño y blob presentes.
- `inputs.contracts` presente; el gate no fija una versión de esquema.
- Seed bloque `manifest.seed` con `image`, `source`, `contracts`, lock, hashes y digest;
  coincide con `seed_image` y con `inputs`.
- `seed-manifest.json` con `source.commit`, `source.schema`, `source.data_contract`,
  `source.seed_image` y dataset `FT-1`; hash y contratos coincidentes. Se valida en
  `verify-seed`, después de `seed apply`.
  Si el manifiesto de release no está disponible o no es válido, la compatibilidad de
  esquema queda bloqueada, no marcada como PASS.
- Rutas relativas seguras y rechazo de symlinks en el paquete.
- Estado simulado: bloqueo de entorno, versión ya activa y par de rollback.
- Evidencia simulada: CI, Rootless, QA, ascendencia y aprobación PROD; cada fallo produce un
  blocker con código propio.

## Pruebas

```bash
./scripts/test-release-gate
```

Los 61 casos cubren solicitudes válidas TEST/PROD, preflight sin seed y `verify-seed`, y
rechazos de tag, entorno, versión, SHA, `release_ref`, paquete, seed, `SHA256SUMS`,
manifiesto, estructura e integridad OCI, frontend, seed, incompatibilidad o no verificación
del esquema seed/release, aprobación, evidencia simulada, rutas inseguras, symlinks, entradas
extra, estado ausente/incompleto/bloqueado, rollback y modo `apply`. También comprueban que el
CLI no modifica el estado simulado.

## Límites para una activación real

- La evidencia GitHub/QA/Rootless y la ascendencia Git requieren un adaptador de solo lectura
  o una atestación; hoy solo se simulan con fixtures.
- El hash del paquete verifica integridad de transporte, no autentica su procedencia ni al
  publicador; esa garantía debe venir del canal y del run de GitHub.
- La recepción del paquete único y el despliegue manual se documentan en
  [paquete TEST](paquete-test-recepcion-01.md); no hay adaptador automático de recepción ni
  de ejecución.
- La activación real, bloqueo, copia, cambio de unidad y smoke pertenecen a un adaptador de
  host posterior; no están implementados.
- La aprobación PROD real debe validarse contra GitHub Environments.
- El contrato de esquema/seed por SHA sigue sujeto a la reconciliación D11 de MyFinanzas.
- La versión de aplicación no está en el manifiesto actual; se toma de la solicitud y del tag.
