# Actualización automática de TEST (sustituida)

> **Histórico.** La arquitectura GHCR + timer/polling fue sustituida por el
> [despliegue directo por tag](despliegue-directo-test-01.md). No se instala ningún timer,
> no se consulta un registro y no se publican paquetes en GHCR. Las instrucciones de
> versiones anteriores de este documento no deben ejecutarse.

## Auditoría previa al despliegue

`scripts/audit-test-release` revisa el bundle exacto que viajará al VPS:

```bash
./scripts/audit-test-release <artifact.zip|release-dir> --expect-source <sha40>
```

- Verifica `manifest.sha256`, `SHA256SUMS` y los blobs OCI.
- Rechaza estado privado (`database.sqlite`, `test-instance.json`, `seed-manifest.json`),
  credenciales (`.env`, claves privadas, tokens), rutas privadas y symlinks de frontend.
- Comprueba que todos los recursos raíz de `index.html` existen en el frontend.
- Devuelve `2` si hay cualquier bloqueo; en ese caso no se despliega.

La auditoría es local y sin red. No depende de GHCR ni de la visibilidad de paquetes.
El receptor del despliegue vuelve a verificar integridad, frontend y contratos antes de
mutar; la auditoría añade una revisión independiente de secretos y estado.
