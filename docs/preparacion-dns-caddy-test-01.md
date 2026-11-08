# Preparación documental — DNS y Caddy TEST

Fecha: 2026-11-07
Estado: **DRAFT — preparación documental; sin cambios en DNS ni Caddy.**
Referencias: [spec host 02 §7](../specs/02-infra-test-01-host-specification.md),
[paquete de despliegue](paquete-despliegue-myfinanzas-test-01.md) y
[evidencia 2B](evidencia-infra-test-02b.md).

Este documento prepara las fases 3 y 4 sin ejecutarlas. No crea registros DNS, no edita el
`Caddyfile`, no recarga Caddy y no publica TEST.

## 1. DNS TEST

### Estado observado

- Apex `myfinanzas.pp.ua`: A con TTL 14400; sin AAAA/CAA observados.
- `test.myfinanzas.pp.ua`: NXDOMAIN.
- Proveedor DNS: `uadns.com` según la auditoría; confirmar antes de operar.
- La IP pública no se documenta aquí.

### Registro propuesto

```text
test.myfinanzas.pp.ua. 300 IN A    <IP_PUBLICA_VERIFICADA>
test.myfinanzas.pp.ua. 300 IN AAAA <IPv6_PUBLICA_VERIFICADA, si existe>
```

Condiciones:

- Solo el nombre `test`; sin wildcard.
- No modificar `myfinanzas.pp.ua` ni sus registros.
- No copiar un proxy/CDN del apex sin decisión expresa; `test` debe apuntar al VPS.
- TTL 300 para TEST; el apex conserva su TTL.
- Crear el registro no acredita TLS ni entorno operativo.

### Comprobaciones antes/después (solo cuando se autorice)

```bash
dig +short myfinanzas.pp.ua A
dig +short test.myfinanzas.pp.ua A
dig +short test.myfinanzas.pp.ua AAAA
dig @1.1.1.1 +short test.myfinanzas.pp.ua A
dig @8.8.8.8 +short test.myfinanzas.pp.ua A
```

Registrar: IP, TTL, proveedor, respuestas de ambos resolutores y comparación del apex
antes/después.

### Rollback

- Retirar solo el registro `test` creado.
- No tocar el apex, el proveedor ni otros registros.

## 2. Caddy TEST

### Estado observado

- Caddy 2.11.9 activo y con `hold`; solo `CAP_NET_BIND_SERVICE`.
- `Caddyfile` de 68 B con el sitio raíz, `root` y `file_server`; sin `reverse_proxy` ni
  bloque TEST.
- `caddy validate` con 2.11.9 devuelve configuración válida.
- No se edita el sitio raíz ni el *drop-in* de capacidades.

### Bloque candidato

La ubicación exacta (Caddyfile principal o fichero importado) se decide en la fase 4. El
bloque no se aplica hasta que la unidad y el seed estén listos.

```caddyfile
test.myfinanzas.pp.ua {
    encode zstd gzip

    header {
        Strict-Transport-Security "max-age=300"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        X-Frame-Options "DENY"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'"
        X-Robots-Tag "noindex, nofollow"
    }

    handle /api/* {
        reverse_proxy 127.0.0.1:18082
    }

    handle /assets/* {
        header Cache-Control "public, max-age=31536000, immutable"
        root * /var/www/myfinanzas-test/current
        file_server
    }

    handle {
        header Cache-Control "no-store"
        root * /var/www/myfinanzas-test/current
        try_files {path} /index.html
        file_server
    }
}
```

Condiciones:

- `/api/*` no cae a `index.html`; un 404 de API sigue siendo 404.
- Caddy conserva `Host` y añade `X-Forwarded-Proto`.
- HSTS corto (`max-age=300`), sin `includeSubDomains` ni `preload`.
- Sin listado de directorios ni mapas de fuente.
- `style-src 'unsafe-inline'` se revisa tras verificar la build.
- El estático se sirve desde `current`, nunca desde Vite ni desde el directorio de build.

### Procedimiento documental previsto (no ejecutado)

1. Leer el `Caddyfile` completo y localizar imports que afecten al sitio.
2. Registrar hash y backup del fichero principal y de los imports implicados.
3. Preparar el bloque TEST sin tocar el sitio raíz.
4. Validar la configuración candidata con `caddy validate`.
5. Mantener Caddy sin recargar hasta que la unidad esté activa y el seed verificado.
6. Recargar solo con autorización; comprobar primero el sitio raíz y después TEST.
7. Si falla: restaurar el backup, validar y recargar; preservar evidencia.

No se ejecuta `caddy reload`, `systemctl reload caddy` ni ninguna edición en esta fase
documental.

### Verificación posterior

```bash
caddy validate --config <CADDYFILE>
namei -l /var/www/myfinanzas-test/current
runuser -u caddy -- test -r /var/www/myfinanzas-test/current/index.html
curl -I http://test.myfinanzas.pp.ua
curl -D- https://test.myfinanzas.pp.ua/api/health
curl -D- https://myfinanzas.pp.ua
```

Registrar: backup/hash, diff, salida de `validate`, cabeceras TEST, certificado y respuesta
del sitio raíz antes/después. `current` debe apuntar a
`/var/www/myfinanzas-test/releases/<sha>`, nunca a `/srv/myfinanzas-test` `0700`; tras la
primera activación, los directorios públicos son `2750` y los ficheros `0640`, con grupo
`caddy`, para que Caddy lea y `mftest` actualice sin root. La recarga que publica TEST se
ejecuta al final de la fase 5, no en la fase 4.

## 3. Autorizaciones necesarias

| Autorización | Alcance | No incluye |
| --- | --- | --- |
| DNS TEST | Crear solo `test` A/AAAA; verificar resolutores y apex | Wildcard, apex, PROD |
| Caddy TEST | Backup, bloque, `validate` y recarga final | Sitio raíz, certificados de PROD |

Ninguna de las dos está autorizada por este documento. No se ha modificado DNS ni Caddy.
