# Guía visual: Orchestrator y agentes dinámicos — v2.3.1

> **Objetivo:** trabajar con un único coordinador de desarrollo, que distribuye tareas independientes según el estado real del proyecto. No significa que un Skill cree agentes automáticamente ni que los agentes sigan activos fuera de una ejecución de Codex.

**Cómo empezar:** [README](../README.md) · [Política de agentes dinámicos](../specs/methodology/dynamic-agents.md) · [Coordinación de épicas](../specs/methodology/epic-orchestration.md) · [Modelos](../specs/methodology/model-selection.md) · [Tablero](../templates/epic-board.md).

## 1. La arquitectura: un coordinador, agentes bajo demanda

Los roles son **instrucciones reutilizables**. Cada instancia recibe una misión concreta, entrega un resultado y termina. No hay un agente permanente por cada rol. Un rol puede asignarse a varios agentes distintos si sus tareas no se pisan.

```mermaid
flowchart TB
    U["Usuario: decisiones y aprobaciones"] --> O["Orchestrator: planifica y supervisa"]
    O --> B[("Epic Board: estado y dependencias")]
    O --> F["Agente funcional #1: Spec E1.7"]
    O --> D["Agente developer #2: Dev E1.6 aprobada"]
    O --> I["Agente infraestructura #3: Docker / SQLite"]
    O -.->|si queda trabajo listo| Q["Agente QA #4: revisión independiente"]
    F --> O
    D --> O
    I --> O
    Q --> O
    O -->|solicita aprobación| U
```

El gráfico muestra **cuatro ejemplos de tareas**, no cuatro agentes permanentemente ejecutándose. La recomendación inicial es uno a tres agentes activos y aumentar solo cuando compense y el entorno lo permita.

## 2. Cómo decide cuántos agentes crear

No se trata de tener tres agentes y buscarles trabajo, sino de encontrar trabajo **independiente y autorizado** y asignar los recursos justos.

```mermaid
flowchart TD
    A["Reconciliar roadmap, specs, Git, QA y tablero"] --> B{"¿Hay tareas listas y autorizadas?"}
    B -->|No| Z["Registrar bloqueo y pedir decisión concreta"]
    B -->|Sí| C{"¿Se pueden ejecutar independientemente?"}
    C -->|No| S["Ejecutar secuencialmente"]
    C -->|Sí| D{"¿Codex permite subagentes?"}
    D -->|No / desconocido| S
    D -->|Sí| E["Estimar beneficio, coste, colisiones y límite real"]
    E --> F["Crear solo tareas delimitadas útiles"]
    F --> G["Recoger resultados, revisar pruebas y cerrar agentes"]
    S --> G
    G --> A
```

**Reglas:** un ejecutor por defecto; delegación adicional solo con beneficio concreto, capacidad real y aislamiento autorizado. Conserva QA independiente cuando sea exigible. La cantidad depende del trabajo y del cliente, no de un límite universal.

## 3. Varias épicas sin bloqueo en serie

Ejemplo **ilustrativo**, no el estado verificado del repositorio MyFinanzas. E1.6 está esperando una decisión financiera; E1.7 contiene aspectos que se pueden preparar independientemente; SQLite puede investigarse en una línea técnica separada.

```mermaid
flowchart LR
    E16["E1.6: spec pendiente"] --> AP{"Aprobación del usuario"}
    AP -->|pendiente| STOP["Dev E1.6 bloqueado"]
    AP -->|aprobada| DEV["Dev E1.6"]
    DEV --> QA["QA y review E1.6"]
    E17["E1.7: requisitos independientes"] --> DRAFT["Brainstorming y borrador Spec 07"]
    DRAFT --> AP7{"Aprobación Spec 07"}
    INF["SQLite / Docker"] --> CHECK["Investigar y validar entorno"]
    QA --> PR["PR lista para revisión"]
    PR --> MERGE{"Aprobación de merge"}
```

La investigación técnica **solo bloquea** una épica si se ha documentado una dependencia real. Mientras una especificación espera tu decisión, preparar otra especificación o pruebas provisionales no necesita bloquearse también.

## 4. El ciclo de vida de cada subagente

```mermaid
stateDiagram-v2
    [*] --> Pendiente
    Pendiente --> Asignado: paquete autorizado
    Asignado --> Ejecutando: herramienta disponible
    Asignado --> Secuencial: sin herramienta multiagente
    Ejecutando --> Bloqueado: falta permiso o dependencia
    Ejecutando --> Entregado: trabajo y evidencia
    Secuencial --> Entregado: resultado y evidencia
    Bloqueado --> Reasignado: nueva tarea independiente
    Bloqueado --> Cerrado: deja de aportar valor
    Reasignado --> Asignado
    Entregado --> Cerrado: coordinator verifica
    Cerrado --> [*]
```

Cada paquete debe indicar **qué quiere conseguir, qué archivos puede escribir, sus dependencias, las pruebas obligatorias y cómo devolverá resultados**. Usa [el contrato reutilizable](../templates/agent-work-packet.md).

## 5. Las aprobaciones siguen protegidas

```mermaid
flowchart TD
    A["Functional: brainstorming"] --> B["Spec propuesta"]
    B --> C{"Usuario aprueba spec"}
    C -->|No / pendiente| D["Solo documentación y trabajo independiente"]
    C -->|Sí| E["Developer: implementación"]
    E --> F["QA: pruebas reales y review"]
    F --> G{"¿Checks superados?"}
    G -->|No| E
    G -->|Sí| H["PR publicada dentro del alcance autorizado"]
    H --> I{"Usuario aprueba merge"}
    I -->|No| J["Mantener PR abierta"]
    I -->|Sí| K["Merge autorizado"]
```

Se requiere tu autorización para decisiones financieras y contables, contratos importantes, migraciones destructivas, producción y merges. La aprobación de una spec **no autoriza** operaciones destructivas o despliegues.

## 6. Proteger ramas y archivos entre agentes

```mermaid
flowchart LR
    CO["Coordinador: cola y tablero"] --> BR1["Rama / checkout: functional"]
    CO --> BR2["Rama / checkout: dev"]
    CO --> BR3["Rama / checkout: infra"]
    BR1 --> D1["Docs E1.7"]
    BR2 --> D2["Código E1.6"]
    BR3 --> D3["Docker / CI"]
    D1 --> RV["Revisión de cambios"]
    D2 --> RV
    D3 --> RV
    RV --> TEST["Integración y QA"]
    TEST --> P["PR publicada; merge solo aprobado"]
```

**No presupongas que cada agente recibe automáticamente una rama o worktree.** Los cambios paralelos necesitan ownership sin solapamiento e aislamiento explícitamente autorizado. Si dos tareas van a editar el mismo archivo, se serializan o se negocia una separación real. La investigación de solo lectura puede compartir repositorio.

## 7. Migrar dos chats existentes a un coordinador

No es posible convertir mágicamente dos chats ya abiertos en subagentes del nuevo coordinador. Hay que conservar primero lo que saben mediante checkpoints verificables.

```mermaid
flowchart TD
    F["Chat actual: Finanzas"] --> CF["Checkpoint: specs, ramas, decisiones, tests"]
    I["Chat actual: Despliegue"] --> CI["Checkpoint: infraestructura, ramas, riesgos"]
    CF --> R["Orchestrator inspecciona repo + checkpoints"]
    CI --> R
    R --> B["Reconcilia Epic Board y dependencias"]
    B --> X{"¿Subagentes disponibles?"}
    X -->|Sí| N["Crea nuevas tareas funcional, dev, infra y QA según necesidad"]
    X -->|No| S["Usa el mismo backlog en ejecución secuencial"]
    N --> H["Handoff con evidencias y control de aprobaciones"]
    S --> H
```

**Secuencia práctica:**

1. Solicita a ambos chats un checkpoint; no los cierres hasta salvar cambios no confirmados en Git.
2. Actualiza la metodología del proyecto usando [$adopt-project](../.agents/skills/adopt-project/SKILL.md) y copia solo las partes necesarias, sin sobreescribir reglas existentes.
3. Abre un nuevo chat, escribe `$orchestrate` y solicita reconciliar ramas, roadmap, aprobaciones y checkpoints.
4. Confirma Standard / Full salvo autorización explícita ya válida. Quick solo procede sin confirmación adicional si el cambio está claramente solicitado, es reversible, de bajo riesgo y sin gates protegidos ni restricciones más estrictas. Consultar o estar en Plan no autoriza editar. El coordinador administra el tablero y selecciona tareas ya autorizadas.
5. Cuando el traspaso esté verificado, deja los dos chats antiguos solo como histórico. **El coordinador no puede tomar control, cerrar o enviar mensajes a esos chats automáticamente.**

## 8. Asignación de modelo por dificultad, no por rol fijo

```mermaid
flowchart TD
    T["Tarea lista"] --> R{"¿Riesgo o ambigüedad altos?"}
    R -->|Sí| A["Capacidad avanzada dentro de política"]
    R -->|No| C{"¿Trabajo rutinario y acotado?"}
    C -->|Sí| E["Capacidad eficiente dentro de política"]
    C -->|No| M["Capacidad equilibrada dentro de política"]
    A --> V["Validación real y code review"]
    E --> V
    M --> V
```

La selección respeta la [política canónica de modelos](../specs/methodology/model-selection.md) y las capacidades verificadas del cliente. Los subagentes Codex tienen un techo absoluto de GPT-6.1 Sol Light; el coordinador conserva su modelo. Si no puede garantizarse la selección permitida, no se crea el subagente. Nunca sustituir pruebas por capacidad o razonamiento.

## 9. ¿Qué instala realmente esta template?

| Pieza | Incluida | Límites |
| --- | --- | --- |
| Skill `$orchestrate` | Sí | Coordina por instrucciones; necesita herramientas reales para delegar |
| Roles Functional / Developer / QA / Infra | Sí | Son perfiles, no procesos residentes |
| Gestión dinámica / scheduler | Sí, como contrato | No es un servicio de ejecución en segundo plano |
| Epic Board | Plantilla opcional | Estado persistido por el coordinador, no autoridad de aprobación |
| Paquete de trabajo | Sí | Define ownership, verificaciones y handoff |
| Merge/Deploy automático | No | Requiere aprobación correspondiente |
| Sesiones Codex independientes antiguas | No gestionadas directamente | Se migran mediante checkpoint/Git |

La documentación de [OpenAI sobre multiagentes en Agents API](https://developers.openai.com/api/docs/guides/agents-api/multi-agent) describe una plataforma que se **configura por separado**. Que exista no prueba que tu Codex Desktop/Web tenga las mismas herramientas activadas.

## 10. Preguntas frecuentes

**¿Hay que activar `/plan`?** No. Puedes invocar `$orchestrate` directamente. Plan Mode es opcional.

**¿Tengo que llamar manualmente a `$spec` y `$dev`?** No necesariamente: dentro de una ejecución autorizada, el coordinador puede encadenar pasos aprobados. Jamás autoaprobará una especificación.

**¿Son obligatorios tres agentes?** No. Puede funcionar con uno, dos, tres o más tareas simultáneas si el entorno y el beneficio lo permiten.

**¿Funciona mientras no tengo abierto el chat?** La template no programa ejecuciones ni garantiza trabajo de fondo. Recupera estado y reanuda cuando vuelvas a iniciar una tarea.

**¿Cómo sé que ha funcionado?** Ejecuta los [escenarios de aceptación](../specs/methodology/acceptance-scenarios.md) y comprueba tareas delegadas realmente, commits, pruebas y decisiones.

---

**Mantenimiento:** cuando cambien las Skills o los contratos de agentes, actualizar los diagramas, las rutas y los escenarios de aceptación; evitar documentación que afirme capacidades no comprobadas.
