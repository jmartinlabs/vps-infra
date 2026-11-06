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
`oci_archive_sha256` y `frontend_files`. El gate no reimplementa `release.py`: verifica esos
campos y la integridad del paquete.

## Uso

```bash
./scripts/release-gate check \
  --request /ruta/deploy-request.json \
  --release-dir /ruta/privada/release \
  --seed-manifest /ruta/privada/seed-manifest.json \
  --state /ruta/state-fixture.json \
  --evidence /ruta/evidence-fixture.json \
  --mode dry-run \
  --output /ruta/result.json
```

- `--release-dir` es una entrada de confianza separada; no se acepta una ruta del JSON.
- `--state` simula el estado del host (instalado/bloqueo). Es obligatorio: sin este fixture
  el gate bloquea y no puede validar concurrencia ni rollback.
- `--evidence` simula CI, Rootless, QA, ascendencia Git y aprobación PROD. Sin este fixture
  el gate bloquea: no declara verificado nada que no haya comprobado localmente.
- `--seed-manifest` es obligatorio en TEST y prohibido en PROD.
- Códigos de salida: `0` éxito, `2` bloqueado antes de mutar, `3` error interno.

## Verificación local frente a simulación

| Grupo | Qué significa |
| --- | --- |
| `verification.local` | Comprobado por el gate: formato, tag/versión, entorno, SHA declarado, hash del manifiesto, `manifest.sha256`, `inputs.source`, contratos, OCI, frontend y seed. |
| `verification.simulated` | Evaluado a partir de fixtures: CI, Rootless, QA, ascendencia Git, aprobación PROD y estado del host. **No** se consultó GitHub, Git ni el VPS. |
| `verification.real_world_not_verified` | Lista explícita de lo que sigue sin verificar en una activación real. |

Un `result: success` en `dry-run` significa «habría pasado las comprobaciones locales y los
fixtures dados». No significa que GitHub, QA, Rootless o una autorización PROD estén
verificados.

## Comprobaciones principales

- Formato estricto, campos desconocidos y claves con aspecto de secreto.
- `version` SemVer estable, tag `deploy-(test|prod)-vX.Y.Z` y coincidencia tag/entorno/versión.
- SHA de 40 caracteres, hash de manifiesto y digest OCI.
- Integridad de `manifest.json`, `manifest.sha256`, `image.oci.tar`, `index.json`, blobs OCI y
  `frontend_files`.
- `inputs.contracts` presente; el gate no fija una versión de esquema.
- Seed obligatorio en TEST, hash verificado y `commit` coherente si está declarado.
- Rutas relativas seguras y rechazo de symlinks en el paquete.
- Estado simulado: bloqueo de entorno, versión ya activa y par de rollback.
- Evidencia simulada: CI, Rootless, QA, ascendencia y aprobación PROD; cada fallo produce un
  blocker con código propio.

## Pruebas

```bash
./scripts/test-release-gate
```

Los 42 casos cubren solicitudes válidas TEST/PROD y rechazos de tag, entorno, versión, SHA,
manifiesto, OCI, frontend, seed, aprobación, evidencia simulada, rutas inseguras, symlinks,
entradas extra, estado ausente/incompleto/bloqueado, rollback y modo `apply`. También
comprueban que el CLI no modifica el estado simulado.

## Límites para una activación real

- La evidencia GitHub/QA/Rootless y la ascendencia Git requieren un adaptador de solo lectura
  o una atestación; hoy solo se simulan con fixtures.
- El transporte privado de la release y el mecanismo de ejecución siguen pendientes
  (DEP2/DEP4).
- La activación real, bloqueo, copia, cambio de unidad y smoke pertenecen a un adaptador de
  host posterior; no están implementados.
- La aprobación PROD real debe validarse contra GitHub Environments.
- El contrato de esquema/seed por SHA sigue sujeto a la reconciliación D11 de MyFinanzas.
- La versión de aplicación no está en el manifiesto actual; se toma de la solicitud y del tag.
