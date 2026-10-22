# Claude Code · Mi VPS Infraestructura

Este proyecto utiliza las instrucciones canónicas de [AGENTS.md](AGENTS.md). Lee también [arquitectura](docs/arquitectura.md), [inventario](docs/estado-actual.md), [operaciones](docs/operaciones.md) y [metodología](docs/metodologia-agentes.md).

Las skills de Claude en `.claude/skills/` son **adaptadores ligeros** a las mismas skills de Codex en `.agents/skills/`. Puedes solicitar `/orchestrate` cuando Claude Code las reconozca, o leer el archivo `.agents/skills/orchestrate/SKILL.md` expresamente.

**Reglas críticas:** no acceder al VPS ni siquiera en solo lectura sin autorización expresa para ese alcance; no modificar servicios, DNS, firewall, backups ni datos sin permiso específico; no hacer merge ni desplegar sin autorización explícita e independiente. «ok», «dale» o «continúa» **no aprueban operaciones protegidas**. Si falta evidencia de aprobación, detener la operación afectada.

Este archivo no habilita ejecución remota, subagentes ni hooks. Ver [adopción del harness](docs/harness.md).
