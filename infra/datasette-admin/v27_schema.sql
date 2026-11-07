-- Schema v27 derived from myfinanzas-app a9ae4101ec625875b930bf9b015a46f51ff052aa.
-- Schema only: no application data. Generated for isolated synthetic tests.
PRAGMA foreign_keys=OFF;
CREATE TABLE annual_plan_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE annual_plan_audit(id INTEGER PRIMARY KEY,ejercicio INTEGER NOT NULL,partida TEXT NOT NULL REFERENCES partidas(id),revision INTEGER NOT NULL,actor TEXT NOT NULL,instante TEXT NOT NULL,motivo TEXT,delta TEXT NOT NULL) STRICT;
CREATE TABLE annual_plan_lines(
    ejercicio INTEGER NOT NULL CHECK(ejercicio BETWEEN 1 AND 9999),
    partida TEXT NOT NULL REFERENCES partidas(id), presupuesto INTEGER CHECK(presupuesto IS NULL OR presupuesto>=0),
    periodo TEXT, esencial TEXT NOT NULL CHECK(esencial IN ('Sí','No','Pendiente')),
    revision INTEGER NOT NULL CHECK(revision>0), PRIMARY KEY(ejercicio,partida)
  ) STRICT;
CREATE TABLE anticipo_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE anticipo_audit(id INTEGER PRIMARY KEY, referencia TEXT NOT NULL REFERENCES fichas_anticipos(referencia), accion TEXT NOT NULL,
    anterior TEXT, posterior TEXT NOT NULL, motivo TEXT, instante TEXT NOT NULL, actor TEXT NOT NULL) STRICT;
CREATE TABLE audit(id INTEGER PRIMARY KEY, entidad TEXT NOT NULL, accion TEXT NOT NULL,
        revision INTEGER NOT NULL, campos TEXT NOT NULL, instante TEXT NOT NULL,
        revision_previa INTEGER NOT NULL, actor TEXT NOT NULL, motivo TEXT) STRICT;
CREATE TABLE auth_events(id INTEGER PRIMARY KEY, accion TEXT NOT NULL, instante INTEGER NOT NULL) STRICT;
CREATE TABLE auth_limits(id INTEGER PRIMARY KEY CHECK(id=1), failures INTEGER NOT NULL,
        window INTEGER NOT NULL, blocked INTEGER NOT NULL) STRICT;
CREATE TABLE bootstrap(hash TEXT PRIMARY KEY, expires INTEGER NOT NULL) STRICT;
CREATE TABLE budget_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE budget_contract(id INTEGER PRIMARY KEY CHECK(id=1), contract TEXT NOT NULL CHECK(contract='e2.2-presupuestos-v8')) STRICT;
CREATE TABLE categorias (
      id TEXT PRIMARY KEY, nombre TEXT NOT NULL CHECK(length(nombre)>0), grupo TEXT,
      anual TEXT CHECK(anual IN ('Ingreso','Gasto','No aplica')),
      mensual TEXT CHECK(mensual IN ('Ingreso','Gasto','Gasto compartido neto','No aplica')),
      referencia INTEGER CHECK(referencia IN (0,1)),
      estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')),
      revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL
    ) STRICT;
CREATE TABLE challenges(hash TEXT PRIMARY KEY, expires INTEGER NOT NULL, attempts INTEGER NOT NULL) STRICT;
CREATE TABLE ciclos(
    id TEXT PRIMARY KEY,
    inicio TEXT NOT NULL UNIQUE CHECK(length(inicio)=10 AND inicio GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(inicio) IS NOT NULL AND date(inicio)=inicio),
    mes_financiado TEXT GENERATED ALWAYS AS (date(substr(inicio,1,7)||'-01','+1 month')) VIRTUAL NOT NULL UNIQUE,
    saldo_comida INTEGER NOT NULL,
    creado TEXT NOT NULL
  , revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0), actualizado TEXT) STRICT;
CREATE TABLE cierre_attempts(
      key TEXT PRIMARY KEY,
      hash TEXT NOT NULL,
      response TEXT NOT NULL,
      expires INTEGER NOT NULL
    ) STRICT;
CREATE TABLE cierre_audit(
      id INTEGER PRIMARY KEY,
      ciclo TEXT NOT NULL,
      version INTEGER NOT NULL,
      accion TEXT NOT NULL
        CHECK(accion IN ('cierre','cierre_fuera_de_orden')),
      anterior TEXT,
      posterior TEXT NOT NULL CHECK(json_valid(posterior)),
      motivo TEXT,
      instante TEXT NOT NULL CHECK(
        length(instante)=24
        AND instante GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
      ),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0 AND length(actor)<=200),
      FOREIGN KEY(ciclo,version) REFERENCES cierres(ciclo,version)
        ON DELETE RESTRICT,
      CHECK(anterior IS NULL OR json_valid(anterior)),
      CHECK(
        accion='cierre'
        OR (motivo IS NOT NULL AND length(trim(motivo))>0)
      )
    ) STRICT;
CREATE TABLE cierre_vinculos(
      ciclo TEXT NOT NULL,
      version_origen INTEGER NOT NULL CHECK(version_origen>0),
      version_destino INTEGER NOT NULL CHECK(version_destino=version_origen+1),
      reapertura_id INTEGER NOT NULL REFERENCES reaperturas(id)
        ON DELETE RESTRICT,
      correlacion TEXT,
      PRIMARY KEY(ciclo,version_destino),
      FOREIGN KEY(ciclo,version_origen) REFERENCES cierres(ciclo,version)
        ON DELETE RESTRICT,
      FOREIGN KEY(ciclo,version_destino) REFERENCES cierres(ciclo,version)
        ON DELETE RESTRICT
    ) STRICT;
CREATE TABLE cierres(
      ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
      version INTEGER NOT NULL CHECK(version>0),
      inicio TEXT NOT NULL CHECK(
        length(inicio)=10
        AND inicio GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(inicio) IS NOT NULL
        AND date(julianday(inicio))=inicio
      ),
      fin TEXT NOT NULL CHECK(
        length(fin)=10
        AND fin GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(fin) IS NOT NULL
        AND date(julianday(fin))=fin
      ),
      saldo_inicial INTEGER NOT NULL
        CHECK(saldo_inicial>=-9007199254740991 AND saldo_inicial<=9007199254740991),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0 AND length(actor)<=200),
      creado_utc TEXT NOT NULL CHECK(
        length(creado_utc)=24
        AND creado_utc GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
      ),
      motivo TEXT CHECK(
        motivo IS NULL OR (length(trim(motivo))>0 AND length(motivo)<=1000)
      ),
      fingerprint TEXT NOT NULL CHECK(
        length(fingerprint)=64 AND fingerprint NOT GLOB '*[^a-f0-9]*'
      ),
      estado TEXT NOT NULL CHECK(estado='Cerrado'),
      PRIMARY KEY(ciclo,version),
      CHECK(fin>=inicio),
      FOREIGN KEY(ciclo,version) REFERENCES fotos_cierre(ciclo,version)
        ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED
    ) STRICT;
CREATE TABLE classification_attempts (
      key TEXT PRIMARY KEY, entidad TEXT NOT NULL, hash TEXT NOT NULL,
      id TEXT NOT NULL, expires INTEGER NOT NULL
    ) STRICT;
CREATE TABLE comida_devolucion_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE comida_metadata_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE comida_regimen_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE comida_rol_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE compartido_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE compartido_audit(id INTEGER PRIMARY KEY, referencia TEXT NOT NULL REFERENCES fichas_compartidos(referencia),
    accion TEXT NOT NULL, anterior TEXT, posterior TEXT NOT NULL, motivo TEXT, instante TEXT NOT NULL, actor TEXT NOT NULL) STRICT;
CREATE TABLE conciliacion_attempts(
      key TEXT PRIMARY KEY, hash TEXT NOT NULL, response TEXT NOT NULL, expires INTEGER NOT NULL
    ) STRICT;
CREATE TABLE conciliaciones_deuda(
      id TEXT PRIMARY KEY CHECK(id GLOB 'C[0-9]*' AND substr(id,2) NOT GLOB '*[^0-9]*' AND length(id)>=4),
      deuda TEXT NOT NULL REFERENCES deudas(id) ON DELETE RESTRICT,
      fecha_corte TEXT NOT NULL
        CHECK(fecha_corte GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND fecha_corte=date(fecha_corte)),
      capital_declarado INTEGER NOT NULL,
      fuente TEXT CHECK(fuente IS NULL OR length(fuente)<=200),
      nota TEXT CHECK(nota IS NULL OR length(nota)<=1000),
      estado TEXT NOT NULL CHECK(estado IN ('Vigente','Anulada')),
      revision INTEGER NOT NULL CHECK(revision>0),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0),
      creado TEXT NOT NULL,
      actualizado TEXT NOT NULL
    ) STRICT;
CREATE TABLE conciliaciones_deuda_audit(
      id INTEGER PRIMARY KEY,
      conciliacion TEXT NOT NULL REFERENCES conciliaciones_deuda(id) ON DELETE RESTRICT,
      accion TEXT NOT NULL CHECK(accion IN ('alta','corrección','anulación')),
      revision INTEGER NOT NULL CHECK(revision>0),
      anterior TEXT,
      posterior TEXT NOT NULL,
      motivo TEXT,
      instante TEXT NOT NULL,
      actor TEXT NOT NULL CHECK(length(trim(actor))>0)
    ) STRICT;
CREATE TABLE counters(name TEXT PRIMARY KEY, next INTEGER NOT NULL CHECK(next>0)) STRICT;
CREATE TABLE cycle_attempts(
    key TEXT PRIMARY KEY, hash TEXT NOT NULL, ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
    expires INTEGER NOT NULL
  ) STRICT;
CREATE TABLE cycle_audit(ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT, revision INTEGER NOT NULL, accion TEXT NOT NULL, motivo TEXT NOT NULL, instante TEXT NOT NULL, actor TEXT NOT NULL, anterior TEXT, posterior TEXT NOT NULL, PRIMARY KEY(ciclo,revision)) STRICT;
CREATE TABLE cycle_operation_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE cycle_operation_guard(id INTEGER PRIMARY KEY CHECK(id=1)) STRICT;
CREATE TABLE cycle_plan_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE cycle_plan_audit(id INTEGER PRIMARY KEY,ciclo TEXT NOT NULL REFERENCES ciclos(id),presupuesto TEXT NOT NULL REFERENCES presupuestos(id),revision INTEGER NOT NULL,actor TEXT NOT NULL,instante TEXT NOT NULL,motivo TEXT,delta TEXT NOT NULL) STRICT;
CREATE TABLE cycle_plan_lines(ciclo TEXT NOT NULL REFERENCES cycle_plans(ciclo),presupuesto TEXT NOT NULL REFERENCES presupuestos(id),base INTEGER CHECK(base IS NULL OR base>=0),esencial INTEGER CHECK(esencial IS NULL OR esencial>=0),del_mes INTEGER CHECK(del_mes IS NULL OR del_mes>=0),PRIMARY KEY(ciclo,presupuesto)) STRICT;
CREATE TABLE cycle_plans(ciclo TEXT PRIMARY KEY REFERENCES ciclos(id),revision INTEGER NOT NULL CHECK(revision>0)) STRICT;
CREATE TABLE database_origin(
    id INTEGER PRIMARY KEY CHECK(id=1), contract INTEGER NOT NULL CHECK(contract=1),
    origin TEXT NOT NULL CHECK(origin IN ('demo','production')), key_hash TEXT,
    CHECK((origin='demo' AND key_hash IS NULL) OR (origin='production' AND length(key_hash)=64))
  ) STRICT;
CREATE TABLE debt_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE deudas(
 id TEXT PRIMARY KEY CHECK(id GLOB 'D[0-9]*' AND substr(id,2) NOT GLOB '*[^0-9]*' AND length(id)>=4),
 nombre TEXT NOT NULL CHECK(length(trim(nombre))>0), inicio TEXT, apertura INTEGER,
 estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')), revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL
 , tipo_deuda TEXT
      CHECK(tipo_deuda IS NULL OR tipo_deuda IN ('Hipotecaria','No hipotecaria')), tin INTEGER
      CHECK(tin IS NULL OR (tin BETWEEN -9007199254740991 AND 9007199254740991)), tae INTEGER
      CHECK(tae IS NULL OR (tae BETWEEN -9007199254740991 AND 9007199254740991)), cuota_contractual INTEGER
      CHECK(cuota_contractual IS NULL OR cuota_contractual>=0), condiciones TEXT
      CHECK(condiciones IS NULL OR length(condiciones)<=1000), capital_inicial INTEGER, capital_amortizado_historico INTEGER, amortizacion_extra_historica INTEGER, capital_historico_cuotas INTEGER, intereses_historicos INTEGER, total_pagado_historico INTEGER, precontrol_cuotas INTEGER
      CHECK(precontrol_cuotas IS NULL OR precontrol_cuotas>=0), precontrol_capital INTEGER, precontrol_amortizacion_extra INTEGER, precontrol_ejercicio INTEGER
      CHECK(precontrol_ejercicio IS NULL OR precontrol_ejercicio BETWEEN 1 AND 9999)) STRICT;
CREATE TABLE dprima_apertura_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE dprima_apertura_audit(
    id INTEGER PRIMARY KEY,
    apertura TEXT NOT NULL REFERENCES dprima_aperturas(id),
    accion TEXT NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE dprima_aperturas(
    id TEXT PRIMARY KEY CHECK(id GLOB 'AP[0-9]*' AND substr(id,3) NOT GLOB '*[^0-9]*' AND length(id)>=5),
    planificacion TEXT NOT NULL REFERENCES dprima_planificaciones(id) ON DELETE RESTRICT,
    ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
    total INTEGER,
    gasto_neto INTEGER,
    saldo INTEGER,
    pendiente INTEGER,
    restantes INTEGER CHECK(restantes IS NULL OR restantes>0),
    sugerida INTEGER,
    importe INTEGER,
    fuente TEXT NOT NULL CHECK(fuente IN ('Gasto real','Aportación a saldo','No aplica')),
    corte TEXT NOT NULL,
    huella TEXT NOT NULL,
    confirmado TEXT NOT NULL,
    creado TEXT NOT NULL,
    UNIQUE(planificacion,ciclo)
  ) STRICT;
CREATE TABLE dprima_exclusiones(
    id INTEGER PRIMARY KEY,
    apertura TEXT NOT NULL REFERENCES dprima_aperturas(id),
    linea TEXT NOT NULL REFERENCES dprima_lineas(id),
    motivo TEXT NOT NULL CHECK(length(trim(motivo))>0),
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE dprima_linea_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE dprima_linea_audit(
    id INTEGER PRIMARY KEY,
    linea TEXT NOT NULL REFERENCES dprima_lineas(id),
    accion TEXT NOT NULL,
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE dprima_lineas(
    id TEXT PRIMARY KEY CHECK(id GLOB 'LP[0-9]*' AND substr(id,3) NOT GLOB '*[^0-9]*' AND length(id)>=5),
    planificacion TEXT NOT NULL REFERENCES dprima_planificaciones(id) ON DELETE RESTRICT,
    hija TEXT NOT NULL REFERENCES partidas(id) ON DELETE RESTRICT,
    importe INTEGER CHECK(importe IS NULL OR importe>=0),
    fecha TEXT CHECK(fecha IS NULL OR (length(fecha)=10 AND fecha GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(fecha)=fecha)),
    esencial INTEGER NOT NULL CHECK(esencial IN (0,1)),
    anulada INTEGER NOT NULL DEFAULT 0 CHECK(anulada IN (0,1)),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE dprima_mapping(
    id INTEGER PRIMARY KEY,
    presupuesto TEXT REFERENCES presupuestos(id) ON DELETE RESTRICT,
    partida TEXT REFERENCES partidas(id) ON DELETE RESTRICT,
    relacion TEXT NOT NULL CHECK(relacion IN ('Raíz','Hija','Presupuesto sin Partida','Partida sin planificación')),
    motivo TEXT NOT NULL CHECK(length(trim(motivo))>0),
    evidencia TEXT,
    estado TEXT NOT NULL CHECK(estado IN ('Propuesta','Confirmada')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL,
    CHECK((relacion IN ('Presupuesto sin Partida','Partida sin planificación')) OR partida IS NOT NULL)
  ) STRICT;
CREATE TABLE dprima_mapping_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE dprima_mapping_audit(
    id INTEGER PRIMARY KEY,
    mapping INTEGER NOT NULL REFERENCES dprima_mapping(id),
    accion TEXT NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE dprima_mensual_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE dprima_partida_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE dprima_plan_mensual(
    ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
    raiz TEXT NOT NULL REFERENCES partidas(id) ON DELETE RESTRICT,
    fuente TEXT NOT NULL CHECK(fuente IN ('Gasto real','Aportación a saldo','No aplica')),
    destino TEXT REFERENCES saldos(id) ON DELETE RESTRICT,
    base INTEGER CHECK(base IS NULL OR base>=0),
    esencial INTEGER CHECK(esencial IS NULL OR esencial>=0),
    del_mes INTEGER CHECK(del_mes IS NULL OR del_mes>=0),
    corte_sugerencia TEXT,
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL,
    PRIMARY KEY(ciclo,raiz)
  ) STRICT;
CREATE TABLE dprima_planificacion_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE dprima_planificacion_audit(
    id INTEGER PRIMARY KEY,
    planificacion TEXT NOT NULL REFERENCES dprima_planificaciones(id),
    accion TEXT NOT NULL,
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE dprima_planificaciones(
    id TEXT PRIMARY KEY CHECK(id GLOB 'DP[0-9]*' AND substr(id,3) NOT GLOB '*[^0-9]*' AND length(id)>=5),
    padre TEXT NOT NULL REFERENCES partidas(id) ON DELETE RESTRICT,
    saldo TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
    mes_inicial TEXT NOT NULL CHECK(length(mes_inicial)=10 AND mes_inicial GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-01'),
    mes_final TEXT NOT NULL CHECK(length(mes_final)=10 AND mes_final GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-01'),
    saldo_inicial INTEGER NOT NULL,
    saldo_evidencia TEXT NOT NULL CHECK(length(trim(saldo_evidencia)) BETWEEN 1 AND 500),
    estado TEXT NOT NULL CHECK(estado IN ('Borrador','Activa','Finalizada')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL,
    CHECK(mes_inicial<=mes_final)
  ) STRICT;
CREATE TABLE fichas_anticipos(
    referencia TEXT PRIMARY KEY REFERENCES referencias(id), apertura TEXT, evidencia TEXT,
    creado TEXT NOT NULL, actualizado TEXT NOT NULL,
    CHECK((apertura IS NULL AND evidencia IS NULL) OR (apertura IS NOT NULL AND length(trim(evidencia))>0))
  ) STRICT;
CREATE TABLE fichas_compartidos(
    referencia TEXT PRIMARY KEY REFERENCES referencias(id),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL, actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE fichas_vehiculo(
    referencia TEXT PRIMARY KEY REFERENCES referencias(id) ON DELETE RESTRICT,
    matricula TEXT CHECK(matricula IS NULL OR (length(matricula)>0 AND length(matricula)<=32)),
    proxima_itv TEXT CHECK(proxima_itv IS NULL OR (length(proxima_itv)=10 AND proxima_itv GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(proxima_itv) IS NOT NULL AND date(proxima_itv)=proxima_itv)),
    fecha_cita TEXT CHECK(fecha_cita IS NULL OR (length(fecha_cita)=10 AND fecha_cita GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(fecha_cita) IS NOT NULL AND date(fecha_cita)=fecha_cita)),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL, actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE foto_periodo_componentes(
      periodo_id INTEGER NOT NULL
        REFERENCES fotos_periodo(id) ON DELETE RESTRICT,
      ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
      version_foto INTEGER CHECK(version_foto IS NULL OR version_foto>0),
      fingerprint_foto TEXT CHECK(
        fingerprint_foto IS NULL OR (
          length(fingerprint_foto)=64
          AND fingerprint_foto NOT GLOB '*[^a-f0-9]*'
        )
      ),
      estado TEXT NOT NULL CHECK(
        estado IN ('Incluido','ExcluidoSinCierre','PendienteReCierre')
      ),
      motivo TEXT CHECK(
        motivo IS NULL OR (length(trim(motivo))>0 AND length(motivo)<=1000)
      ),
      PRIMARY KEY(periodo_id,ciclo),
      CHECK(
        (
          estado='Incluido'
          AND version_foto IS NOT NULL
          AND fingerprint_foto IS NOT NULL
        )
        OR (
          estado IN ('ExcluidoSinCierre','PendienteReCierre')
          AND version_foto IS NULL
          AND fingerprint_foto IS NULL
        )
      ),
      FOREIGN KEY(ciclo,version_foto) REFERENCES fotos_cierre(ciclo,version)
        ON DELETE RESTRICT
    ) STRICT;
CREATE TABLE fotos_cierre(
      ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
      version INTEGER NOT NULL CHECK(version>0),
      creado_utc TEXT NOT NULL CHECK(
        length(creado_utc)=24
        AND creado_utc GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
      ),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0 AND length(actor)<=200),
      motivo TEXT CHECK(
        motivo IS NULL OR (length(trim(motivo))>0 AND length(motivo)<=1000)
      ),
      fingerprint TEXT NOT NULL CHECK(
        length(fingerprint)=64 AND fingerprint NOT GLOB '*[^a-f0-9]*'
      ),
      app_version TEXT NOT NULL CHECK(
        length(trim(app_version))>0 AND length(app_version)<=200
      ),
      schema_version INTEGER NOT NULL CHECK(schema_version>0),
      ventana_inicio TEXT NOT NULL CHECK(
        length(ventana_inicio)=10
        AND ventana_inicio GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(ventana_inicio) IS NOT NULL
        AND date(julianday(ventana_inicio))=ventana_inicio
      ),
      ventana_fin TEXT NOT NULL CHECK(
        length(ventana_fin)=10
        AND ventana_fin GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(ventana_fin) IS NOT NULL
        AND date(julianday(ventana_fin))=ventana_fin
      ),
      saldo_inicial INTEGER NOT NULL
        CHECK(saldo_inicial>=-9007199254740991 AND saldo_inicial<=9007199254740991),
      estado_temporal TEXT NOT NULL CHECK(estado_temporal='Cerrado'),
      estado_hechos TEXT NOT NULL CHECK(estado_hechos IN ('Con hechos','Sin hechos')),
      estado_plan TEXT NOT NULL CHECK(estado_plan IN ('SinPlan','Capturado')),
      hechos TEXT NOT NULL CHECK(json_valid(hechos)),
      plan TEXT NOT NULL CHECK(json_valid(plan)),
      clasificacion TEXT NOT NULL CHECK(json_valid(clasificacion)),
      inversion TEXT NOT NULL CHECK(json_valid(inversion)),
      auxiliares TEXT NOT NULL CHECK(json_valid(auxiliares)),
      cobertura TEXT NOT NULL CHECK(json_valid(cobertura)),
      backup TEXT NOT NULL CHECK(json_valid(backup)),
      no_disponible TEXT NOT NULL CHECK(json_valid(no_disponible)),
      PRIMARY KEY(ciclo,version),
      CHECK(ventana_fin>=ventana_inicio)
    ) STRICT;
CREATE TABLE fotos_neto_apertura(
    referencia TEXT NOT NULL REFERENCES fichas_anticipos(referencia), ciclo TEXT NOT NULL REFERENCES ciclos(id), inicio TEXT NOT NULL,
    importe INTEGER NOT NULL, evidencia TEXT NOT NULL, procedencia TEXT NOT NULL, cobertura TEXT NOT NULL,
    confirmado TEXT NOT NULL, revision INTEGER NOT NULL, PRIMARY KEY(referencia,ciclo)
  ) STRICT;
CREATE TABLE fotos_periodo(
      id INTEGER PRIMARY KEY,
      tipo TEXT NOT NULL CHECK(tipo IN ('Trimestre','Anio')),
      ejercicio INTEGER NOT NULL CHECK(ejercicio>=1000 AND ejercicio<=9999),
      trimestre INTEGER CHECK(
        trimestre IS NULL OR (trimestre>=1 AND trimestre<=4)
      ),
      inicio TEXT NOT NULL CHECK(
        length(inicio)=10
        AND inicio GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(inicio) IS NOT NULL
        AND date(julianday(inicio))=inicio
      ),
      fin TEXT NOT NULL CHECK(
        length(fin)=10
        AND fin GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(fin) IS NOT NULL
        AND date(julianday(fin))=fin
      ),
      version TEXT NOT NULL CHECK(
        length(version) BETWEEN 2 AND 20
        AND version GLOB 'A[0-9]*'
        AND substr(version,2) NOT GLOB '*[^0-9]*'
        AND CAST(substr(version,2) AS INTEGER)>0
        AND version='A'||CAST(CAST(substr(version,2) AS INTEGER) AS TEXT)
      ),
      creado_utc TEXT NOT NULL CHECK(
        length(creado_utc)=24
        AND creado_utc GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
      ),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0 AND length(actor)<=200),
      motivo TEXT CHECK(
        motivo IS NULL OR (length(trim(motivo))>0 AND length(motivo)<=1000)
      ),
      fingerprint TEXT NOT NULL CHECK(
        length(fingerprint)=64 AND fingerprint NOT GLOB '*[^a-f0-9]*'
      ),
      app_version TEXT NOT NULL CHECK(
        length(trim(app_version))>0 AND length(app_version)<=200
      ),
      schema_version INTEGER NOT NULL CHECK(schema_version>0),
      regla_composicion TEXT NOT NULL CHECK(
        length(trim(regla_composicion))>0
        AND length(regla_composicion)<=200
      ),
      seleccion_aplicada TEXT NOT NULL CHECK(json_valid(seleccion_aplicada)),
      cobertura TEXT NOT NULL CHECK(json_valid(cobertura)),
      valores TEXT NOT NULL CHECK(json_valid(valores)),
      no_disponible TEXT NOT NULL CHECK(json_valid(no_disponible)),
      CHECK(fin>=inicio),
      CHECK(
        (tipo='Trimestre' AND trimestre IS NOT NULL)
        OR (tipo='Anio' AND trimestre IS NULL)
      )
    ) STRICT;
CREATE TABLE idempotency(key TEXT PRIMARY KEY, hash TEXT NOT NULL, saldo TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
        expires INTEGER NOT NULL) STRICT;
CREATE TABLE instrumento_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE instrumento_audit(
    instrumento TEXT NOT NULL REFERENCES instrumentos(id),
    revision INTEGER NOT NULL,
    accion TEXT NOT NULL CHECK(accion IN ('alta','edición','desactivación','reactivación')),
    motivo TEXT, instante TEXT NOT NULL, actor TEXT NOT NULL,
    anterior TEXT, posterior TEXT NOT NULL,
    PRIMARY KEY(instrumento,revision)
  ) STRICT;
CREATE TABLE instrumentos(
    id TEXT PRIMARY KEY CHECK(id GLOB 'I[0-9]*' AND substr(id,2) NOT GLOB '*[^0-9]*' AND length(id)>=5),
    nombre TEXT NOT NULL CHECK(length(nombre)>=1 AND length(nombre)<=120),
    isin TEXT CHECK(isin IS NULL OR (length(isin)=12 AND isin NOT GLOB '*[^A-Z0-9]*')),
    isin_evidencia TEXT CHECK(isin_evidencia IS NULL OR (length(isin_evidencia)>=1 AND length(isin_evidencia)<=200)),
    divisa_referencia TEXT CHECK(divisa_referencia IS NULL OR (length(divisa_referencia)=3 AND divisa_referencia NOT GLOB '*[^A-Z]*')),
    estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado_en TEXT NOT NULL, actualizado_en TEXT NOT NULL,
    CHECK((isin IS NULL AND isin_evidencia IS NULL) OR (isin IS NOT NULL AND isin_evidencia IS NOT NULL))
  ) STRICT;
CREATE TABLE movement_attempts(key TEXT PRIMARY KEY, hash TEXT NOT NULL, response TEXT NOT NULL, expires INTEGER NOT NULL) STRICT;
CREATE TABLE movement_audit(
    id TEXT NOT NULL REFERENCES movimientos(id), revision INTEGER NOT NULL,
    accion TEXT NOT NULL CHECK(accion IN ('alta','rectificación','anulación')),
    motivo TEXT, instante TEXT NOT NULL, actor TEXT NOT NULL,
    anterior TEXT, posterior TEXT NOT NULL, PRIMARY KEY(id,revision)
  ) STRICT;
CREATE TABLE movimiento_anticipo(
    movimiento TEXT PRIMARY KEY REFERENCES movimientos(id), referencia TEXT NOT NULL REFERENCES fichas_anticipos(referencia),
    rol TEXT NOT NULL CHECK(rol IN ('Adelanto','Devolución')), origen TEXT NOT NULL REFERENCES saldos(id), destino TEXT NOT NULL REFERENCES saldos(id),
    revision_movimiento INTEGER NOT NULL, evidencia TEXT NOT NULL CHECK(length(trim(evidencia))>0), procedencia TEXT NOT NULL CHECK(length(trim(procedencia))>0),
    revision INTEGER NOT NULL, actualizado TEXT NOT NULL, CHECK(origen!=destino)
  ) STRICT;
CREATE TABLE movimiento_compartido(
    movimiento TEXT PRIMARY KEY REFERENCES movimientos(id) ON DELETE RESTRICT,
    referencia TEXT NOT NULL REFERENCES fichas_compartidos(referencia) ON DELETE RESTRICT,
    participante TEXT NOT NULL REFERENCES participantes_compartido(id) ON DELETE RESTRICT,
    evidencia TEXT NOT NULL CHECK(length(trim(evidencia)) BETWEEN 10 AND 500),
    procedencia TEXT NOT NULL CHECK(procedencia IN ('Registro del titular','Documento bancario','Importación histórica autorizada')),
    revision_movimiento INTEGER NOT NULL CHECK(revision_movimiento>0),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL, actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE movimiento_devolucion(
    movimiento TEXT PRIMARY KEY REFERENCES movimientos(id) ON DELETE RESTRICT,
    compra TEXT REFERENCES movimientos(id) ON DELETE RESTRICT,
    partida TEXT REFERENCES partidas(id) ON DELETE RESTRICT,
    ciclo_origen TEXT REFERENCES ciclos(id) ON DELETE RESTRICT,
    evidencia_relacion TEXT CHECK(evidencia_relacion IS NULL OR length(trim(evidencia_relacion)) BETWEEN 1 AND 500),
    evidencia_origen_temporal TEXT CHECK(evidencia_origen_temporal IS NULL OR length(trim(evidencia_origen_temporal)) BETWEEN 1 AND 500),
    elegibilidad TEXT NOT NULL CHECK(elegibilidad IN ('Acreditada','No acreditada')),
    estado TEXT NOT NULL CHECK(estado IN ('Sin vínculo','Verificado','Revisar')),
    revision_movimiento INTEGER NOT NULL CHECK(revision_movimiento>0),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL,
    CHECK(compra IS NULL OR compra<>movimiento),
    CHECK((estado='Sin vínculo' AND compra IS NULL AND evidencia_relacion IS NULL AND evidencia_origen_temporal IS NULL AND partida IS NULL AND ciclo_origen IS NULL)
      OR (estado='Verificado' AND compra IS NOT NULL AND length(trim(evidencia_relacion))>0)
      OR (estado='Revisar' AND (compra IS NOT NULL OR evidencia_relacion IS NOT NULL OR evidencia_origen_temporal IS NOT NULL OR partida IS NOT NULL OR ciclo_origen IS NOT NULL)))
    ,CHECK(elegibilidad<>'Acreditada' OR (length(trim(evidencia_origen_temporal))>0 AND ciclo_origen IS NOT NULL AND (partida IS NOT NULL OR compra IS NOT NULL)))
  ) STRICT;
CREATE TABLE movimiento_devolucion_audit(
    id INTEGER PRIMARY KEY,
    movimiento TEXT NOT NULL REFERENCES movimiento_devolucion(movimiento),
    accion TEXT NOT NULL CHECK(accion IN ('alta','rectificación')),
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE movimiento_revision_comida(
    movimiento TEXT PRIMARY KEY REFERENCES movimientos(id) ON DELETE RESTRICT,
    etiqueta TEXT CHECK(etiqueta IS NULL OR etiqueta IN ('Comida','Pendiente revisar','Ocio','Niños','Otros','Fuera presupuesto')),
    evidencia_bancaria TEXT CHECK(evidencia_bancaria IS NULL OR length(trim(evidencia_bancaria)) BETWEEN 1 AND 500),
    evidencia_comercial TEXT CHECK(evidencia_comercial IS NULL OR length(trim(evidencia_comercial)) BETWEEN 1 AND 500),
    estado_revision TEXT NOT NULL CHECK(estado_revision IN ('Pendiente revisar','Revisada')),
    revision_movimiento INTEGER NOT NULL CHECK(revision_movimiento>0),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE movimiento_revision_comida_audit(
    id INTEGER PRIMARY KEY,
    movimiento TEXT NOT NULL REFERENCES movimiento_revision_comida(movimiento),
    accion TEXT NOT NULL CHECK(accion IN ('alta','rectificación')),
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE "movimiento_rol_financiacion"(
      movimiento TEXT PRIMARY KEY REFERENCES movimientos(id) ON DELETE RESTRICT,
      rol TEXT NOT NULL CHECK(rol IN ('Financiación','Reposición','Devolución Anticipo')),
      obligacion_ciclo TEXT REFERENCES ciclos(id) ON DELETE RESTRICT,
      evidencia TEXT NOT NULL CHECK(length(trim(evidencia)) BETWEEN 1 AND 500),
      revision_movimiento INTEGER NOT NULL CHECK(revision_movimiento>0),
      revision INTEGER NOT NULL CHECK(revision>0),
      creado TEXT NOT NULL,
      actualizado TEXT NOT NULL
    ) STRICT;
CREATE TABLE movimiento_rol_financiacion_audit(
    id INTEGER PRIMARY KEY,
    movimiento TEXT NOT NULL REFERENCES movimiento_rol_financiacion(movimiento),
    accion TEXT NOT NULL CHECK(accion IN ('alta','rectificación','anulación')),
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE "movimientos"(
      id TEXT PRIMARY KEY CHECK(id NOT GLOB '*[^0-9]*' AND length(id)>0 AND substr(id,1,1)!='0'),
      fecha TEXT NOT NULL CHECK(length(fecha)=10 AND fecha GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(fecha) IS NOT NULL AND date(fecha)=fecha),
      tipo TEXT NOT NULL CHECK(tipo IN ('Ingreso','Gasto','Transferencia','Amortización deuda','Devolución de gasto')),
      importe INTEGER NOT NULL CHECK(importe>0),
      origen TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
      destino TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
      subtipo TEXT CHECK(subtipo IN ('Nómina','Bonus','Intereses','Promoción')),
      partida TEXT REFERENCES partidas(id) ON DELETE RESTRICT,
      concepto TEXT NOT NULL, nota TEXT NOT NULL,
      anulado INTEGER NOT NULL DEFAULT 0 CHECK(anulado IN (0,1)),
      revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL,
      referencia TEXT REFERENCES referencias(id) ON DELETE RESTRICT, capital INTEGER CHECK(capital>0), intereses INTEGER CHECK(intereses>=0),
      CHECK((tipo='Ingreso' AND origen='S000' AND destino!='S000' AND subtipo IS NOT NULL AND partida IS NULL)
        OR (tipo IN ('Gasto','Amortización deuda') AND destino='S000' AND origen!='S000' AND partida IS NOT NULL AND subtipo IS NULL)
        OR (tipo='Transferencia' AND destino!='S000' AND origen!=destino AND partida IS NULL AND subtipo IS NULL)
        OR (tipo='Devolución de gasto' AND origen='S000' AND destino!='S000' AND subtipo IS NULL AND capital IS NULL AND intereses IS NULL))
    ) STRICT;
CREATE TABLE operacion_attempts(key TEXT PRIMARY KEY,hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE operacion_inversion_audit(
    operacion TEXT NOT NULL REFERENCES operaciones_inversion(id),
    revision INTEGER NOT NULL,
    accion TEXT NOT NULL CHECK(accion IN ('alta','rectificación','anulación')),
    motivo TEXT, instante TEXT NOT NULL, actor TEXT NOT NULL,
    anterior TEXT, posterior TEXT NOT NULL,
    PRIMARY KEY(operacion,revision)
  ) STRICT;
CREATE TABLE "operaciones_inversion"(
    id TEXT PRIMARY KEY CHECK(id NOT GLOB '*[^0-9]*' AND length(id)>0 AND substr(id,1,1)!='0'),
    clase TEXT NOT NULL CHECK(clase IN ('Compra','Venta')),
    fecha TEXT NOT NULL CHECK(length(fecha)=10 AND fecha GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(fecha) IS NOT NULL AND date(fecha)=fecha),
    instrumento TEXT NOT NULL REFERENCES instrumentos(id) ON DELETE RESTRICT,
    saldo_efectivo TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
    saldo_inversion TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
    cantidad INTEGER NOT NULL CHECK(cantidad>0 AND cantidad<=9007199254740991),
    precio_divisa INTEGER NOT NULL CHECK(precio_divisa>0 AND precio_divisa<=9007199254740991),
    divisa TEXT NOT NULL CHECK(length(divisa)=3 AND divisa NOT GLOB '*[^A-Z]*'),
    cambio INTEGER CHECK(cambio IS NULL OR (cambio>0 AND cambio<=9007199254740991)),
    importe_eur INTEGER NOT NULL CHECK(importe_eur>0),
    comision_eur INTEGER CHECK(comision_eur IS NULL OR (comision_eur>=0 AND comision_eur<=importe_eur)),
    concepto TEXT CHECK(concepto IS NULL OR length(concepto)<=2000),
    nota TEXT CHECK(nota IS NULL OR length(nota)<=2000),
    estado TEXT NOT NULL CHECK(estado IN ('Vigente','Anulada')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL, actualizado TEXT NOT NULL,
    CHECK(saldo_efectivo<>saldo_inversion),
    CHECK((divisa='EUR' AND (cambio IS NULL OR cambio=1000000)) OR (divisa!='EUR' AND cambio IS NOT NULL))
  ) STRICT;
CREATE TABLE owner(id INTEGER PRIMARY KEY CHECK(id=1), password TEXT NOT NULL, secret TEXT NOT NULL,
        enabled INTEGER NOT NULL CHECK(enabled IN(0,1)), last_step INTEGER NOT NULL) STRICT;
CREATE TABLE participantes_compartido(
    id TEXT PRIMARY KEY CHECK(id GLOB 'CP[0-9]*' AND substr(id,3) NOT GLOB '*[^0-9]*' AND length(id)>=5),
    referencia TEXT NOT NULL REFERENCES fichas_compartidos(referencia),
    nombre TEXT NOT NULL CHECK(length(trim(nombre))>0),
    rol TEXT NOT NULL CHECK(rol IN ('Titular','Tercero')),
    partes INTEGER NOT NULL CHECK(partes>=0 AND partes<=1000000),
    estado TEXT NOT NULL CHECK(estado IN ('Activa','Baja')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL, actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE partidas (
      id TEXT PRIMARY KEY, nombre TEXT NOT NULL CHECK(length(nombre)>0),
      padre TEXT NOT NULL REFERENCES subcategorias(id) ON DELETE RESTRICT,
      estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')),
      revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL
    , deuda TEXT REFERENCES deudas(id) ON DELETE RESTRICT, presupuesto TEXT REFERENCES presupuestos(id) ON DELETE RESTRICT, padre_partida TEXT REFERENCES partidas(id) ON DELETE RESTRICT, fuente TEXT CHECK(fuente IS NULL OR fuente IN ('Gasto real','Aportación a saldo','No aplica'))) STRICT;
CREATE TABLE payroll(id TEXT PRIMARY KEY, revision INTEGER NOT NULL CHECK(revision>0), data TEXT NOT NULL) STRICT;
CREATE TABLE payroll_allocations(paga TEXT NOT NULL REFERENCES payroll(id), movimiento TEXT NOT NULL REFERENCES movimientos(id), importe TEXT NOT NULL, revision_movimiento INTEGER NOT NULL, evidencia TEXT NOT NULL, PRIMARY KEY(paga,movimiento)) STRICT;
CREATE TABLE payroll_attempts(key TEXT PRIMARY KEY, hash TEXT NOT NULL,response TEXT NOT NULL,expires INTEGER NOT NULL) STRICT;
CREATE TABLE payroll_audit(id INTEGER PRIMARY KEY,paga TEXT REFERENCES payroll(id),actor TEXT NOT NULL,instante TEXT NOT NULL,motivo TEXT NOT NULL,delta TEXT NOT NULL) STRICT;
CREATE TABLE periodo_attempts(
      key TEXT PRIMARY KEY,
      hash TEXT NOT NULL,
      response TEXT NOT NULL,
      expires INTEGER NOT NULL
    ) STRICT;
CREATE TABLE presupuestos(
      id TEXT PRIMARY KEY CHECK(id GLOB 'PRE[0-9]*' AND substr(id,4) NOT GLOB '*[^0-9]*' AND length(id)>=6),
      nombre TEXT NOT NULL CHECK(length(trim(nombre))>0),
      fuente TEXT NOT NULL CHECK(fuente IN ('Gasto real','Aportación a saldo','No aplica')),
      destino TEXT REFERENCES saldos(id) ON DELETE RESTRICT,
      estado TEXT NOT NULL CHECK(estado IN ('Activo','Inactivo')),
      revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL,
      CHECK((fuente='No aplica' AND destino IS NULL) OR (fuente!='No aplica' AND destino IS NOT NULL AND destino!='S000'))
    ) STRICT;
CREATE TABLE reapertura_activa(
      id INTEGER PRIMARY KEY CHECK(id=1),
      ciclo TEXT NOT NULL,
      reapertura_id INTEGER NOT NULL REFERENCES reaperturas(id)
        ON DELETE RESTRICT,
      FOREIGN KEY(ciclo,reapertura_id) REFERENCES reaperturas(ciclo,id)
        ON DELETE RESTRICT
    ) STRICT;
CREATE TABLE reapertura_attempts(
      operacion TEXT NOT NULL
        CHECK(operacion IN ('reapertura','cancelacion','recierre')),
      key TEXT NOT NULL,
      hash TEXT NOT NULL,
      response TEXT NOT NULL,
      expires INTEGER NOT NULL,
      PRIMARY KEY(operacion,key)
    ) STRICT;
CREATE TABLE reaperturas(
      id INTEGER PRIMARY KEY,
      ciclo TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
      version_origen INTEGER NOT NULL CHECK(version_origen>0),
      tipo TEXT NOT NULL CHECK(tipo IN ('reapertura','cancelacion')),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0 AND length(actor)<=200),
      creado_utc TEXT NOT NULL CHECK(
        length(creado_utc)=24
        AND creado_utc GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]Z'
      ),
      motivo TEXT NOT NULL CHECK(
        length(trim(motivo))>0 AND length(motivo)<=1000
      ),
      fingerprint_peticion TEXT NOT NULL CHECK(
        length(fingerprint_peticion)=64
        AND fingerprint_peticion NOT GLOB '*[^a-f0-9]*'
      ),
      version_esperada INTEGER NOT NULL CHECK(version_esperada=version_origen),
      clave_intento TEXT NOT NULL CHECK(length(trim(clave_intento))>0),
      correlacion TEXT,
      reapertura_origen INTEGER REFERENCES reaperturas(id) ON DELETE RESTRICT,
      resultado TEXT NOT NULL CHECK(length(trim(resultado))>0),
      CHECK(tipo<>'cancelacion' OR reapertura_origen IS NOT NULL),
      CHECK(tipo='cancelacion' OR reapertura_origen IS NULL),
      UNIQUE(ciclo,id),
      FOREIGN KEY(ciclo,version_origen) REFERENCES cierres(ciclo,version)
        ON DELETE RESTRICT
    ) STRICT;
CREATE TABLE recovery(hash TEXT PRIMARY KEY) STRICT;
CREATE TABLE reference_attempts(key TEXT PRIMARY KEY, hash TEXT NOT NULL, response TEXT NOT NULL, expires INTEGER NOT NULL) STRICT;
CREATE TABLE referencias(
    id TEXT PRIMARY KEY CHECK(id GLOB 'REF[0-9]*' AND substr(id,4) NOT GLOB '*[^0-9]*' AND length(id)>=6),
    nombre TEXT NOT NULL CHECK(length(trim(nombre))>0),
    tipo TEXT NOT NULL CHECK(tipo IN ('Viaje','Evento','Anticipo','Vehículo','Gasto compartido')),
    estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')),
    revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE regimen_comida(
    saldo TEXT PRIMARY KEY REFERENCES saldos(id) ON DELETE RESTRICT,
    ciclo_corte TEXT NOT NULL REFERENCES ciclos(id) ON DELETE RESTRICT,
    apertura INTEGER NOT NULL,
    evidencia TEXT NOT NULL CHECK(length(trim(evidencia)) BETWEEN 1 AND 500),
    cobertura TEXT NOT NULL CHECK(cobertura IN ('Verificable','Parcial')),
    estado TEXT NOT NULL CHECK(estado IN ('Preparado','Activo','Suspendido')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL
  ) STRICT;
CREATE TABLE regimen_comida_audit(
    id INTEGER PRIMARY KEY,
    saldo TEXT NOT NULL REFERENCES regimen_comida(saldo),
    accion TEXT NOT NULL CHECK(accion IN ('preparación','activación','suspensión')),
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT NOT NULL,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE revision_comida(
    id TEXT PRIMARY KEY,
    tipo TEXT NOT NULL CHECK(tipo IN ('Detalle','Reposicion')),
    fecha TEXT NOT NULL CHECK(length(fecha)=10 AND fecha GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(fecha)=fecha),
    concepto TEXT NOT NULL CHECK(length(trim(concepto))>0),
    importe INTEGER NOT NULL CHECK(importe>0),
    direccion TEXT NOT NULL CHECK(direccion IN ('Salida','Entrada')),
    es_devolucion INTEGER NOT NULL CHECK(es_devolucion IN (0,1)),
    clasificacion TEXT CHECK(clasificacion IN ('Comida','Pendiente revisar','Ocio','Niños','Otros','Fuera presupuesto')),
    fuera_presupuesto_historico INTEGER CHECK(fuera_presupuesto_historico IS NULL OR fuera_presupuesto_historico=1),
    evidencia_bancaria TEXT CHECK(evidencia_bancaria IS NULL OR length(trim(evidencia_bancaria))>0),
    evidencia_relacion_compra TEXT CHECK(evidencia_relacion_compra IS NULL OR length(trim(evidencia_relacion_compra))>0),
    cuenta_origen TEXT CHECK(cuenta_origen IS NULL OR length(trim(cuenta_origen))>0),
    tipo_vinculo TEXT CHECK(tipo_vinculo IN ('Individual','Agregado terminal')),
    estado_vinculo TEXT NOT NULL CHECK(estado_vinculo IN ('Sin vínculo','Verificado')),
    evidencia_vinculo TEXT CHECK(evidencia_vinculo IS NULL OR length(trim(evidencia_vinculo))>0),
    movimiento TEXT REFERENCES movimientos(id),
    revision_movimiento INTEGER CHECK(revision_movimiento IS NULL OR revision_movimiento>0),
    estado_registro TEXT NOT NULL CHECK(estado_registro IN ('Vigente','Anulado')),
    estado_trazabilidad TEXT NOT NULL CHECK(estado_trazabilidad IN ('Asignada','Sin asignación')),
    revision INTEGER NOT NULL CHECK(revision>0),
    creado TEXT NOT NULL,
    actualizado TEXT NOT NULL,
    CHECK((tipo='Detalle' AND clasificacion IS NOT NULL) OR (tipo='Reposicion' AND clasificacion IS NULL)),
    CHECK((tipo='Detalle' AND direccion='Salida' AND es_devolucion=0) OR (tipo='Detalle' AND direccion='Entrada' AND es_devolucion=1) OR (tipo='Reposicion' AND direccion='Entrada' AND es_devolucion=0)),
    CHECK(tipo<>'Reposicion' OR length(trim(evidencia_bancaria))>0),
    CHECK(estado_trazabilidad<>'Asignada' OR tipo='Reposicion'),
    CHECK(fuera_presupuesto_historico IS NULL OR (clasificacion IS NOT NULL AND clasificacion<>'Fuera presupuesto')),
    CHECK((estado_vinculo='Sin vínculo' AND movimiento IS NULL AND tipo_vinculo IS NULL AND evidencia_vinculo IS NULL AND revision_movimiento IS NULL)
      OR (estado_vinculo='Verificado' AND movimiento IS NOT NULL AND tipo_vinculo IS NOT NULL AND length(trim(evidencia_vinculo))>0 AND revision_movimiento IS NOT NULL))
  ) STRICT;
CREATE TABLE revision_comida_attempts(
    key TEXT PRIMARY KEY,
    hash TEXT NOT NULL,
    response TEXT NOT NULL,
    expires INTEGER NOT NULL
  ) STRICT;
CREATE TABLE revision_comida_audit(
    id INTEGER PRIMARY KEY,
    operacion TEXT NOT NULL REFERENCES revision_comida(id),
    accion TEXT NOT NULL,
    revision INTEGER NOT NULL,
    anterior TEXT,
    posterior TEXT NOT NULL,
    motivo TEXT,
    instante TEXT NOT NULL,
    actor TEXT NOT NULL
  ) STRICT;
CREATE TABLE saldos(
        id TEXT PRIMARY KEY, nombre TEXT NOT NULL, tipo TEXT NOT NULL CHECK(tipo IN ('Exterior','Efectivo','Inversión')),
        control TEXT NOT NULL CHECK(control IN ('Exterior','Movimientos','Terminal','No controlado','Inversiones','Manual')),
        estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')), finalidad TEXT,
        liquidez INTEGER CHECK(liquidez IN (0,1)), bolsa INTEGER CHECK(bolsa IN (0,1)), exterior INTEGER CHECK(exterior IN (0,1)),
        apertura INTEGER, fecha_apertura TEXT, objetivo INTEGER, manual INTEGER,
        revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL
      ) STRICT;
CREATE TABLE schema_version(version INTEGER PRIMARY KEY) STRICT;
CREATE TABLE sessions(hash TEXT PRIMARY KEY, csrf TEXT NOT NULL, created INTEGER NOT NULL, seen INTEGER NOT NULL) STRICT;
CREATE TABLE subcategorias (
      id TEXT PRIMARY KEY, nombre TEXT NOT NULL CHECK(length(nombre)>0),
      padre TEXT NOT NULL REFERENCES categorias(id) ON DELETE RESTRICT,
      estado TEXT NOT NULL CHECK(estado IN ('Activa','Inactiva')),
      revision INTEGER NOT NULL CHECK(revision>0), creado TEXT NOT NULL, actualizado TEXT NOT NULL
    ) STRICT;
CREATE TABLE valoracion_attempts(
      key TEXT PRIMARY KEY, hash TEXT NOT NULL, response TEXT NOT NULL, expires INTEGER NOT NULL
    ) STRICT;
CREATE TABLE valoracion_inversion(
      id TEXT PRIMARY KEY CHECK(
        length(id)=16
        AND id GLOB 'VAL-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
      ),
      saldo_inversion TEXT NOT NULL REFERENCES saldos(id) ON DELETE RESTRICT,
      instrumento TEXT NOT NULL REFERENCES instrumentos(id) ON DELETE RESTRICT,
      fecha_vigencia TEXT NOT NULL CHECK(
        length(fecha_vigencia)=10
        AND fecha_vigencia GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND julianday(fecha_vigencia) IS NOT NULL
        AND date(julianday(fecha_vigencia))=fecha_vigencia
      ),
      tipo TEXT NOT NULL CHECK(tipo IN ('Manual','Automática')),
      valor_eur INTEGER NOT NULL
        CHECK(valor_eur>=0 AND valor_eur<=9007199254740991),
      precio_unitario INTEGER
        CHECK(precio_unitario IS NULL OR
          (precio_unitario>0 AND precio_unitario<=9007199254740991)),
      divisa TEXT
        CHECK(divisa IS NULL OR
          (length(divisa)=3 AND divisa NOT GLOB '*[^A-Z]*')),
      cambio INTEGER
        CHECK(cambio IS NULL OR
          (cambio>0 AND cambio<=9007199254740991)),
      cantidad_base INTEGER
        CHECK(cantidad_base IS NULL OR
          (cantidad_base>0 AND cantidad_base<=9007199254740991)),
      procedencia TEXT NOT NULL
        CHECK(length(trim(procedencia))>0 AND length(procedencia)<=200),
      cobertura TEXT NOT NULL CHECK(cobertura='Completa'),
      actor TEXT NOT NULL CHECK(length(trim(actor))>0),
      creado_utc TEXT NOT NULL,
      actualizado_utc TEXT NOT NULL,
      revision INTEGER NOT NULL CHECK(revision>0),
      motivo_correccion TEXT
        CHECK(motivo_correccion IS NULL OR
          (length(trim(motivo_correccion))>0 AND length(motivo_correccion)<=1000)),
      CHECK(actualizado_utc>=creado_utc),
      CHECK(
        (tipo='Manual'
          AND precio_unitario IS NULL AND divisa IS NULL
          AND cambio IS NULL AND cantidad_base IS NULL)
        OR
        (tipo='Automática'
          AND precio_unitario IS NOT NULL AND divisa IS NOT NULL
          AND cambio IS NOT NULL AND cantidad_base IS NOT NULL
          AND (divisa!='EUR' OR cambio=1000000))
      )
    ) STRICT;
CREATE TABLE valoracion_inversion_audit(
      valoracion TEXT NOT NULL REFERENCES valoracion_inversion(id) ON DELETE RESTRICT,
      revision INTEGER NOT NULL CHECK(revision>0),
      accion TEXT NOT NULL CHECK(accion IN ('alta','corrección')),
      anterior TEXT,
      posterior TEXT NOT NULL CHECK(length(posterior)>0),
      motivo TEXT,
      instante TEXT NOT NULL,
      actor TEXT NOT NULL CHECK(length(trim(actor))>0),
      PRIMARY KEY(valoracion,revision),
      CHECK(
        (accion='alta' AND revision=1 AND anterior IS NULL AND motivo IS NULL)
        OR
        (accion='corrección' AND revision>1
          AND anterior IS NOT NULL AND length(anterior)>0
          AND motivo IS NOT NULL AND length(trim(motivo))>0)
      )
    ) STRICT;
CREATE UNIQUE INDEX budget_contribution_destination ON presupuestos(destino) WHERE fuente='Aportación a saldo';
CREATE INDEX conciliacion_historial
      ON conciliaciones_deuda(deuda,estado,fecha_corte);
CREATE UNIQUE INDEX conciliacion_vigente_unica
      ON conciliaciones_deuda(deuda,fecha_corte) WHERE estado='Vigente';
CREATE INDEX dprima_lineas_planificacion ON dprima_lineas(planificacion);
CREATE INDEX dprima_planificaciones_padre ON dprima_planificaciones(padre);
CREATE INDEX fichas_vehiculo_matricula ON fichas_vehiculo(matricula);
CREATE UNIQUE INDEX fotos_periodo_anio_unico
      ON fotos_periodo(tipo,ejercicio,version)
      WHERE tipo='Anio';
CREATE UNIQUE INDEX fotos_periodo_trimestre_unico
      ON fotos_periodo(tipo,ejercicio,trimestre,version)
      WHERE tipo='Trimestre';
CREATE UNIQUE INDEX instrumentos_isin ON instrumentos(isin) WHERE isin IS NOT NULL;
CREATE INDEX instrumentos_nombre ON instrumentos(nombre);
CREATE INDEX movimiento_compartido_participante ON movimiento_compartido(participante);
CREATE INDEX movimiento_compartido_referencia ON movimiento_compartido(referencia);
CREATE INDEX movimiento_devolucion_ciclo ON movimiento_devolucion(ciclo_origen);
CREATE INDEX movimiento_devolucion_compra ON movimiento_devolucion(compra);
CREATE INDEX movimiento_devolucion_partida ON movimiento_devolucion(partida);
CREATE INDEX movimiento_revision_comida_etiqueta ON movimiento_revision_comida(etiqueta);
CREATE INDEX movimiento_rol_financiacion_rol ON movimiento_rol_financiacion(rol,obligacion_ciclo);
CREATE INDEX movimientos_destino ON movimientos(destino);
CREATE INDEX movimientos_fecha ON movimientos(fecha);
CREATE INDEX movimientos_origen ON movimientos(origen);
CREATE INDEX movimientos_partida ON movimientos(partida);
CREATE INDEX movimientos_referencia ON movimientos(referencia);
CREATE INDEX operaciones_inversion_efectivo ON operaciones_inversion(saldo_efectivo);
CREATE INDEX operaciones_inversion_fecha ON operaciones_inversion(fecha);
CREATE INDEX operaciones_inversion_instrumento ON operaciones_inversion(instrumento);
CREATE INDEX operaciones_inversion_inversion ON operaciones_inversion(saldo_inversion);
CREATE INDEX participantes_compartido_referencia ON participantes_compartido(referencia);
CREATE UNIQUE INDEX participantes_compartido_titular ON participantes_compartido(referencia) WHERE rol='Titular' AND estado='Activa';
CREATE INDEX partidas_padre ON partidas(padre);
CREATE INDEX partidas_padre_partida ON partidas(padre_partida);
CREATE INDEX partidas_presupuesto ON partidas(presupuesto);
CREATE INDEX revision_comida_estado ON revision_comida(estado_registro,tipo);
CREATE INDEX revision_comida_fecha ON revision_comida(fecha);
CREATE INDEX revision_comida_movimiento ON revision_comida(movimiento);
CREATE INDEX subcategorias_padre ON subcategorias(padre);
CREATE UNIQUE INDEX valoracion_posicion_fecha
      ON valoracion_inversion(saldo_inversion,instrumento,fecha_vigencia);
CREATE TRIGGER annual_audit_no_delete BEFORE DELETE ON annual_plan_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
CREATE TRIGGER annual_audit_no_update BEFORE UPDATE ON annual_plan_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
CREATE TRIGGER annual_line_identity BEFORE UPDATE OF ejercicio,partida ON annual_plan_lines BEGIN SELECT RAISE(ABORT,'immutable identity'); END;
CREATE TRIGGER annual_line_no_delete BEFORE DELETE ON annual_plan_lines BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER anticipo_audit_no_delete BEFORE DELETE ON anticipo_audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER anticipo_audit_no_update BEFORE UPDATE ON anticipo_audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER anticipo_cycle_photo BEFORE UPDATE OF inicio ON ciclos WHEN NEW.inicio!=OLD.inicio AND EXISTS(SELECT 1 FROM fotos_neto_apertura WHERE ciclo=OLD.id) BEGIN SELECT RAISE(ABORT,'protected anticipo opening'); END;
CREATE TRIGGER anticipo_no_delete BEFORE DELETE ON fichas_anticipos BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER anticipo_photo_no_delete BEFORE DELETE ON fotos_neto_apertura BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER audit_ficha_no_delete BEFORE DELETE ON audit
    WHEN OLD.entidad='ficha_vehiculo' BEGIN SELECT RAISE(ABORT,'immutable vehicle audit'); END;
CREATE TRIGGER audit_ficha_no_update BEFORE UPDATE ON audit
    WHEN OLD.entidad='ficha_vehiculo' BEGIN SELECT RAISE(ABORT,'immutable vehicle audit'); END;
CREATE TRIGGER categorias_id_immutable BEFORE UPDATE OF id ON categorias
      WHEN NEW.id != OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER categorias_no_delete BEFORE DELETE ON categorias
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER ciclo_append BEFORE INSERT ON ciclos WHEN EXISTS(SELECT 1 FROM ciclos WHERE inicio>=NEW.inicio) AND NOT EXISTS(SELECT 1 FROM cycle_operation_guard) BEGIN SELECT RAISE(ABORT,'cycle must follow latest start'); END;
CREATE TRIGGER ciclo_id_immutable BEFORE UPDATE OF id ON ciclos WHEN NEW.id IS NOT OLD.id BEGIN SELECT RAISE(ABORT,'immutable cycle id'); END;
CREATE TRIGGER ciclo_no_delete BEFORE DELETE ON ciclos BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER ciclo_no_update BEFORE UPDATE ON ciclos WHEN NOT EXISTS(SELECT 1 FROM cycle_operation_guard) BEGIN SELECT RAISE(ABORT,'cycle correction requires reviewed procedure'); END;
CREATE TRIGGER cierre_audit_no_delete
      BEFORE DELETE ON cierre_audit
      BEGIN SELECT RAISE(ABORT,'immutable closure audit'); END;
CREATE TRIGGER cierre_audit_no_update
      BEFORE UPDATE ON cierre_audit
      BEGIN SELECT RAISE(ABORT,'immutable closure audit'); END;
CREATE TRIGGER cierre_audit_recierre_motivo
      BEFORE INSERT ON cierre_audit
      WHEN NEW.accion='cierre'
        AND NEW.version>1
        AND (NEW.motivo IS NULL OR length(trim(NEW.motivo)) = 0)
      BEGIN SELECT RAISE(ABORT,'re-closure requires a motive'); END;
CREATE TRIGGER cierre_cycle_identity
      BEFORE INSERT ON cierres
      WHEN NOT EXISTS (
        SELECT 1 FROM ciclos c
        WHERE c.id=NEW.ciclo
          AND c.inicio=NEW.inicio
          AND c.saldo_comida=NEW.saldo_inicial
      )
      BEGIN SELECT RAISE(ABORT,'closure must match its cycle window and S0'); END;
CREATE TRIGGER cierre_no_delete
      BEFORE DELETE ON cierres
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER cierre_no_update
      BEFORE UPDATE ON cierres
      BEGIN SELECT RAISE(ABORT,'immutable closure'); END;
CREATE TRIGGER cierre_version_sequence
      BEFORE INSERT ON cierres
      WHEN NEW.version != (
        SELECT COALESCE(MAX(version),0)+1 FROM cierres WHERE ciclo=NEW.ciclo
      )
      BEGIN SELECT RAISE(ABORT,'closure version must follow the previous one'); END;
CREATE TRIGGER cierre_vinculo_coherente
      BEFORE INSERT ON cierre_vinculos
      WHEN NOT EXISTS (
        SELECT 1 FROM reaperturas r
        WHERE r.id=NEW.reapertura_id
          AND r.ciclo=NEW.ciclo
          AND r.version_origen=NEW.version_origen
          AND r.tipo='reapertura'
      )
      BEGIN SELECT RAISE(ABORT,'closure link must reference its reopening'); END;
CREATE TRIGGER cierre_vinculo_no_delete
      BEFORE DELETE ON cierre_vinculos
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER cierre_vinculo_no_update
      BEFORE UPDATE ON cierre_vinculos
      BEGIN SELECT RAISE(ABORT,'immutable closure link'); END;
CREATE TRIGGER compartido_audit_no_delete BEFORE DELETE ON compartido_audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER compartido_audit_no_update BEFORE UPDATE ON compartido_audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER compartido_no_delete BEFORE DELETE ON fichas_compartidos BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER conciliacion_audit_no_delete BEFORE DELETE ON conciliaciones_deuda_audit
      BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER conciliacion_audit_no_update BEFORE UPDATE ON conciliaciones_deuda_audit
      BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER conciliacion_deuda_immutable BEFORE UPDATE OF deuda ON conciliaciones_deuda
      WHEN NEW.deuda!=OLD.deuda BEGIN SELECT RAISE(ABORT,'immutable debt'); END;
CREATE TRIGGER conciliacion_id_immutable BEFORE UPDATE OF id ON conciliaciones_deuda
      WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER conciliacion_no_delete BEFORE DELETE ON conciliaciones_deuda
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER cycle_audit_no_delete BEFORE DELETE ON cycle_audit BEGIN SELECT RAISE(ABORT,'immutable cycle audit'); END;
CREATE TRIGGER cycle_audit_no_update BEFORE UPDATE ON cycle_audit BEGIN SELECT RAISE(ABORT,'immutable cycle audit'); END;
CREATE TRIGGER cycle_plan_audit_immutable_delete BEFORE DELETE ON cycle_plan_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
CREATE TRIGGER cycle_plan_audit_immutable_update BEFORE UPDATE ON cycle_plan_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
CREATE TRIGGER deuda_id_immutable BEFORE UPDATE OF id ON deudas WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER deuda_no_delete BEFORE DELETE ON deudas BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER deuda_used_opening BEFORE UPDATE OF inicio,apertura ON deudas WHEN (NEW.inicio IS NOT OLD.inicio OR NEW.apertura IS NOT OLD.apertura) AND EXISTS(SELECT 1 FROM movimientos m JOIN partidas p ON p.id=m.partida WHERE p.deuda=OLD.id) BEGIN SELECT RAISE(ABORT,'used debt opening'); END;
CREATE TRIGGER dprima_apertura_audit_no_delete BEFORE DELETE ON dprima_apertura_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_apertura_audit_no_update BEFORE UPDATE ON dprima_apertura_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_apertura_no_delete BEFORE DELETE ON dprima_aperturas
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER dprima_exclusion_no_delete BEFORE DELETE ON dprima_exclusiones
    BEGIN SELECT RAISE(ABORT,'immutable exclusion'); END;
CREATE TRIGGER dprima_exclusion_no_update BEFORE UPDATE ON dprima_exclusiones
    BEGIN SELECT RAISE(ABORT,'immutable exclusion'); END;
CREATE TRIGGER dprima_linea_audit_no_delete BEFORE DELETE ON dprima_linea_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_linea_audit_no_update BEFORE UPDATE ON dprima_linea_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_linea_hija BEFORE INSERT ON dprima_lineas
    WHEN NOT EXISTS(
      SELECT 1 FROM partidas h JOIN dprima_planificaciones p ON p.id=NEW.planificacion
      WHERE h.id=NEW.hija AND (h.padre_partida=p.padre OR h.id=p.padre)
        AND p.estado<>'Finalizada'
    ) BEGIN SELECT RAISE(ABORT,'line must use an active daughter'); END;
CREATE TRIGGER dprima_linea_hija_update BEFORE UPDATE OF hija,planificacion ON dprima_lineas
    WHEN NOT EXISTS(
      SELECT 1 FROM partidas h JOIN dprima_planificaciones p ON p.id=NEW.planificacion
      WHERE h.id=NEW.hija AND (h.padre_partida=p.padre OR h.id=p.padre)
        AND p.estado<>'Finalizada'
    ) BEGIN SELECT RAISE(ABORT,'line must use an active daughter'); END;
CREATE TRIGGER dprima_linea_id_immutable BEFORE UPDATE OF id ON dprima_lineas
    WHEN NEW.id<>OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER dprima_linea_no_delete BEFORE DELETE ON dprima_lineas
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER dprima_mapping_audit_no_delete BEFORE DELETE ON dprima_mapping_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_mapping_audit_no_update BEFORE UPDATE ON dprima_mapping_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_mapping_no_delete BEFORE DELETE ON dprima_mapping
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER dprima_mensual_destination BEFORE INSERT ON dprima_plan_mensual
    WHEN NEW.fuente='Aportación a saldo' AND NEW.destino IS NULL
    BEGIN SELECT RAISE(ABORT,'destination required'); END;
CREATE TRIGGER dprima_mensual_root BEFORE INSERT ON dprima_plan_mensual
    WHEN NOT EXISTS(SELECT 1 FROM partidas p WHERE p.id=NEW.raiz AND p.padre_partida IS NULL)
    BEGIN SELECT RAISE(ABORT,'monthly line requires a root'); END;
CREATE TRIGGER dprima_planificacion_audit_no_delete BEFORE DELETE ON dprima_planificacion_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_planificacion_audit_no_update BEFORE UPDATE ON dprima_planificacion_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER dprima_planificacion_id_immutable BEFORE UPDATE OF id ON dprima_planificaciones
    WHEN NEW.id<>OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER dprima_planificacion_no_delete BEFORE DELETE ON dprima_planificaciones
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER dprima_planificacion_overlap BEFORE INSERT ON dprima_planificaciones
    WHEN EXISTS(SELECT 1 FROM dprima_planificaciones p
      WHERE p.padre=NEW.padre AND NEW.mes_inicial<=p.mes_final AND p.mes_inicial<=NEW.mes_final)
    BEGIN SELECT RAISE(ABORT,'overlapping forecast'); END;
CREATE TRIGGER dprima_planificacion_overlap_update BEFORE UPDATE OF padre,mes_inicial,mes_final ON dprima_planificaciones
    WHEN EXISTS(SELECT 1 FROM dprima_planificaciones p
      WHERE p.id<>OLD.id AND p.padre=NEW.padre AND NEW.mes_inicial<=p.mes_final AND p.mes_inicial<=NEW.mes_final)
    BEGIN SELECT RAISE(ABORT,'overlapping forecast'); END;
CREATE TRIGGER dprima_planificacion_root BEFORE INSERT ON dprima_planificaciones
    WHEN NOT EXISTS(SELECT 1 FROM partidas p WHERE p.id=NEW.padre AND p.padre_partida IS NULL)
    BEGIN SELECT RAISE(ABORT,'forecast requires a root'); END;
CREATE TRIGGER exterior_protected BEFORE UPDATE ON saldos
        WHEN OLD.id='S000' BEGIN SELECT RAISE(ABORT,'protected system saldo'); END;
CREATE TRIGGER ficha_vehiculo_identity BEFORE UPDATE OF referencia ON fichas_vehiculo
    WHEN NEW.referencia!=OLD.referencia BEGIN SELECT RAISE(ABORT,'immutable vehicle reference'); END;
CREATE TRIGGER ficha_vehiculo_no_delete BEFORE DELETE ON fichas_vehiculo
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER ficha_vehiculo_type BEFORE INSERT ON fichas_vehiculo
    WHEN (SELECT tipo FROM referencias WHERE id=NEW.referencia) IS NOT 'Vehículo'
    BEGIN SELECT RAISE(ABORT,'invalid vehicle reference type'); END;
CREATE TRIGGER foto_cierre_no_delete
      BEFORE DELETE ON fotos_cierre
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER foto_cierre_no_update
      BEFORE UPDATE ON fotos_cierre
      BEGIN SELECT RAISE(ABORT,'immutable closure photo'); END;
CREATE TRIGGER foto_cierre_requires_closure
      BEFORE INSERT ON fotos_cierre
      WHEN NOT EXISTS (
        SELECT 1 FROM cierres c
        WHERE c.ciclo=NEW.ciclo
          AND c.version=NEW.version
          AND c.inicio=NEW.ventana_inicio
          AND c.fin=NEW.ventana_fin
          AND c.saldo_inicial=NEW.saldo_inicial
          AND c.actor=NEW.actor
          AND c.creado_utc=NEW.creado_utc
          AND c.fingerprint=NEW.fingerprint
          AND c.motivo IS NEW.motivo
      )
      BEGIN SELECT RAISE(ABORT,'photo must match its closure identity'); END;
CREATE TRIGGER foto_periodo_componente_foto
      BEFORE INSERT ON foto_periodo_componentes
      WHEN NEW.estado='Incluido'
        AND NOT EXISTS (
          SELECT 1 FROM fotos_cierre f
          WHERE f.ciclo=NEW.ciclo
            AND f.version=NEW.version_foto
            AND f.fingerprint=NEW.fingerprint_foto
        )
      BEGIN SELECT RAISE(ABORT,'included component must match its closure photo'); END;
CREATE TRIGGER foto_periodo_componente_motivo
      BEFORE INSERT ON foto_periodo_componentes
      WHEN NEW.estado<>'Incluido'
        AND (NEW.motivo IS NULL OR length(trim(NEW.motivo))=0)
      BEGIN SELECT RAISE(ABORT,'excluded component requires a motive'); END;
CREATE TRIGGER foto_periodo_componente_no_delete
      BEFORE DELETE ON foto_periodo_componentes
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER foto_periodo_componente_no_update
      BEFORE UPDATE ON foto_periodo_componentes
      BEGIN SELECT RAISE(ABORT,'immutable period component'); END;
CREATE TRIGGER fotos_periodo_no_delete
      BEFORE DELETE ON fotos_periodo
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER fotos_periodo_no_update
      BEFORE UPDATE ON fotos_periodo
      BEGIN SELECT RAISE(ABORT,'immutable period photo'); END;
CREATE TRIGGER fotos_periodo_secuencia
      BEFORE INSERT ON fotos_periodo
      WHEN (
        CAST(substr(NEW.version,2) AS INTEGER)=1
        AND EXISTS (
          SELECT 1 FROM fotos_periodo f
          WHERE f.tipo=NEW.tipo
            AND f.ejercicio=NEW.ejercicio
            AND (NEW.tipo='Anio' OR f.trimestre=NEW.trimestre)
        )
      ) OR (
        CAST(substr(NEW.version,2) AS INTEGER)>1
        AND NOT EXISTS (
          SELECT 1 FROM fotos_periodo f
          WHERE f.tipo=NEW.tipo
            AND f.ejercicio=NEW.ejercicio
            AND (NEW.tipo='Anio' OR f.trimestre=NEW.trimestre)
            AND CAST(substr(f.version,2) AS INTEGER)
              = CAST(substr(NEW.version,2) AS INTEGER)-1
        )
      )
      BEGIN SELECT RAISE(ABORT,'period photo version must follow the previous one'); END;
CREATE TRIGGER instrumento_audit_no_delete BEFORE DELETE ON instrumento_audit
    BEGIN SELECT RAISE(ABORT,'immutable instrument audit'); END;
CREATE TRIGGER instrumento_audit_no_update BEFORE UPDATE ON instrumento_audit
    BEGIN SELECT RAISE(ABORT,'immutable instrument audit'); END;
CREATE TRIGGER instrumento_id_immutable BEFORE UPDATE OF id ON instrumentos
    WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable instrument id'); END;
CREATE TRIGGER instrumento_no_delete BEFORE DELETE ON instrumentos
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER movement_audit_no_delete BEFORE DELETE ON movement_audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movement_audit_no_update BEFORE UPDATE ON movement_audit BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_annulled_immutable BEFORE UPDATE ON movimientos WHEN OLD.anulado=1 BEGIN SELECT RAISE(ABORT,'annulled record is immutable'); END;
CREATE TRIGGER movimiento_compartido_id_immutable BEFORE UPDATE OF movimiento ON movimiento_compartido
    WHEN NEW.movimiento!=OLD.movimiento BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER movimiento_compartido_no_delete BEFORE DELETE ON movimiento_compartido
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER movimiento_compartido_participant BEFORE INSERT ON movimiento_compartido
    WHEN NOT EXISTS(
      SELECT 1 FROM participantes_compartido p
      WHERE p.id=NEW.participante AND p.referencia=NEW.referencia
        AND p.rol='Tercero' AND p.estado='Activa'
    ) BEGIN SELECT RAISE(ABORT,'participant mismatch'); END;
CREATE TRIGGER movimiento_compartido_reference_immutable BEFORE UPDATE OF referencia ON movimiento_compartido
    WHEN NEW.referencia!=OLD.referencia BEGIN SELECT RAISE(ABORT,'immutable reference'); END;
CREATE TRIGGER movimiento_compartido_shape BEFORE INSERT ON movimiento_compartido
    WHEN NOT EXISTS(
      SELECT 1 FROM movimientos m JOIN referencias r ON r.id=m.referencia
      WHERE m.id=NEW.movimiento AND m.tipo='Transferencia' AND m.origen='S000'
        AND m.destino!='S000' AND m.anulado=0 AND m.referencia=NEW.referencia
        AND r.tipo='Gasto compartido'
        AND EXISTS(SELECT 1 FROM saldos s WHERE s.id=m.destino AND s.tipo!='Exterior' AND s.control!='Exterior')
    ) BEGIN SELECT RAISE(ABORT,'invalid D5 movement'); END;
CREATE TRIGGER movimiento_compartido_update_participant BEFORE UPDATE ON movimiento_compartido
    WHEN NOT EXISTS(
      SELECT 1 FROM participantes_compartido p
      WHERE p.id=NEW.participante AND p.referencia=NEW.referencia
        AND p.rol='Tercero'
        AND (p.estado='Activa' OR NEW.participante=OLD.participante)
    ) BEGIN SELECT RAISE(ABORT,'participant mismatch'); END;
CREATE TRIGGER movimiento_compartido_update_shape BEFORE UPDATE ON movimiento_compartido
    WHEN NOT EXISTS(
      SELECT 1 FROM movimientos m JOIN referencias r ON r.id=m.referencia
      WHERE m.id=NEW.movimiento AND m.tipo='Transferencia' AND m.origen='S000'
        AND m.destino!='S000' AND m.anulado=0 AND m.referencia=NEW.referencia
        AND r.tipo='Gasto compartido'
        AND EXISTS(SELECT 1 FROM saldos s WHERE s.id=m.destino AND s.tipo!='Exterior' AND s.control!='Exterior')
    ) BEGIN SELECT RAISE(ABORT,'invalid D5 movement'); END;
CREATE TRIGGER movimiento_devolucion_audit_no_delete BEFORE DELETE ON movimiento_devolucion_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_devolucion_audit_no_update BEFORE UPDATE ON movimiento_devolucion_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_devolucion_id_immutable BEFORE UPDATE OF movimiento ON movimiento_devolucion
    WHEN NEW.movimiento!=OLD.movimiento BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER movimiento_devolucion_integrity BEFORE INSERT ON movimiento_devolucion
    WHEN NEW.estado='Verificado' AND NEW.compra IS NOT NULL AND (
      SELECT COALESCE(SUM(d.dev_importe),0) FROM (
        SELECT m.importe dev_importe FROM movimiento_devolucion x
          JOIN movimientos m ON m.id=x.movimiento
        WHERE x.compra=NEW.compra AND x.estado='Verificado' AND x.movimiento<>NEW.movimiento AND m.anulado=0
      ) d
    ) + (SELECT importe FROM movimientos WHERE id=NEW.movimiento) >
      (SELECT importe FROM movimientos WHERE id=NEW.compra)
    BEGIN SELECT RAISE(ABORT,'devolution exceeds purchase'); END;
CREATE TRIGGER movimiento_devolucion_no_delete BEFORE DELETE ON movimiento_devolucion
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER movimiento_devolucion_purchase BEFORE INSERT ON movimiento_devolucion
    WHEN NEW.compra IS NOT NULL AND NOT EXISTS(
      SELECT 1 FROM movimientos c JOIN saldos s ON s.id=c.origen
      WHERE c.id=NEW.compra AND c.anulado=0 AND c.tipo='Gasto'
        AND s.control<>'Terminal'
    ) BEGIN SELECT RAISE(ABORT,'invalid purchase attribution'); END;
CREATE TRIGGER movimiento_devolucion_shape BEFORE INSERT ON movimiento_devolucion
    WHEN NOT EXISTS(
      SELECT 1 FROM movimientos m
      WHERE m.id=NEW.movimiento AND m.anulado=0 AND m.tipo='Devolución de gasto'
    ) BEGIN SELECT RAISE(ABORT,'invalid devolution movement'); END;
CREATE TRIGGER movimiento_devolucion_update_integrity BEFORE UPDATE ON movimiento_devolucion
    WHEN NEW.estado='Verificado' AND NEW.compra IS NOT NULL AND (
      SELECT COALESCE(SUM(d.dev_importe),0) FROM (
        SELECT m.importe dev_importe FROM movimiento_devolucion x
          JOIN movimientos m ON m.id=x.movimiento
        WHERE x.compra=NEW.compra AND x.estado='Verificado' AND x.movimiento<>NEW.movimiento AND m.anulado=0
      ) d
    ) + (SELECT importe FROM movimientos WHERE id=NEW.movimiento) >
      (SELECT importe FROM movimientos WHERE id=NEW.compra)
    BEGIN SELECT RAISE(ABORT,'devolution exceeds purchase'); END;
CREATE TRIGGER movimiento_devolucion_update_purchase BEFORE UPDATE ON movimiento_devolucion
    WHEN NEW.compra IS NOT NULL AND NOT EXISTS(
      SELECT 1 FROM movimientos c JOIN saldos s ON s.id=c.origen
      WHERE c.id=NEW.compra AND c.tipo='Gasto'
        AND s.control<>'Terminal'
    ) BEGIN SELECT RAISE(ABORT,'invalid purchase attribution'); END;
CREATE TRIGGER movimiento_devolucion_update_shape BEFORE UPDATE ON movimiento_devolucion
    WHEN NOT EXISTS(
      SELECT 1 FROM movimientos m
      WHERE m.id=NEW.movimiento AND m.anulado=0 AND m.tipo='Devolución de gasto'
    ) BEGIN SELECT RAISE(ABORT,'invalid devolution movement'); END;
CREATE TRIGGER movimiento_id_immutable BEFORE UPDATE OF id ON movimientos WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER movimiento_no_delete BEFORE DELETE ON movimientos BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER movimiento_partida_root_group BEFORE INSERT ON movimientos
    WHEN NEW.tipo='Gasto' AND EXISTS(
      SELECT 1 FROM partidas p WHERE p.id=NEW.partida AND p.padre_partida IS NULL
    ) AND EXISTS(
      SELECT 1 FROM partidas h WHERE h.padre_partida=NEW.partida
    ) BEGIN SELECT RAISE(ABORT,'dprima grouped root does not accept new Gasto'); END;
CREATE TRIGGER movimiento_partida_root_group_update BEFORE UPDATE OF partida ON movimientos
    WHEN NEW.tipo='Gasto' AND NEW.partida IS NOT OLD.partida AND EXISTS(
      SELECT 1 FROM partidas p WHERE p.id=NEW.partida AND p.padre_partida IS NULL
    ) AND EXISTS(
      SELECT 1 FROM partidas h WHERE h.padre_partida=NEW.partida
    ) BEGIN SELECT RAISE(ABORT,'dprima grouped root does not accept new Gasto'); END;
CREATE TRIGGER movimiento_revision_comida_audit_no_delete BEFORE DELETE ON movimiento_revision_comida_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_revision_comida_audit_no_update BEFORE UPDATE ON movimiento_revision_comida_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_revision_comida_id_immutable BEFORE UPDATE OF movimiento ON movimiento_revision_comida
    WHEN NEW.movimiento!=OLD.movimiento BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER movimiento_revision_comida_no_delete BEFORE DELETE ON movimiento_revision_comida
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER movimiento_revision_comida_shape BEFORE INSERT ON movimiento_revision_comida
    WHEN NOT EXISTS(
      SELECT 1 FROM movimientos m
      WHERE m.id=NEW.movimiento AND m.anulado=0
        AND m.tipo IN ('Gasto','Devolución de gasto')
    ) BEGIN SELECT RAISE(ABORT,'invalid comida movement'); END;
CREATE TRIGGER movimiento_revision_comida_update_shape BEFORE UPDATE ON movimiento_revision_comida
    WHEN NOT EXISTS(
      SELECT 1 FROM movimientos m
      WHERE m.id=NEW.movimiento AND m.anulado=0
        AND m.tipo IN ('Gasto','Devolución de gasto')
    ) BEGIN SELECT RAISE(ABORT,'invalid comida movement'); END;
CREATE TRIGGER movimiento_rol_financiacion_audit_no_delete BEFORE DELETE ON movimiento_rol_financiacion_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_rol_financiacion_audit_no_update BEFORE UPDATE ON movimiento_rol_financiacion_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER movimiento_rol_financiacion_no_delete BEFORE DELETE ON movimiento_rol_financiacion
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER movimiento_rol_financiacion_reposicion_insert
      BEFORE INSERT ON movimiento_rol_financiacion
      WHEN NEW.rol='Reposición' AND NEW.obligacion_ciclo IS NULL
      BEGIN
        SELECT RAISE(ABORT,'reposición sin obligación requiere cobro acreditado')
        WHERE NOT EXISTS(
          SELECT 1 FROM movimientos m JOIN regimen_comida r ON r.saldo=m.destino
          WHERE m.id=NEW.movimiento AND m.anulado=0 AND m.tipo='Transferencia'
            AND r.estado='Activo'
        );
      END;
CREATE TRIGGER movimiento_rol_financiacion_reposicion_update
      BEFORE UPDATE ON movimiento_rol_financiacion
      WHEN NEW.rol='Reposición' AND NEW.obligacion_ciclo IS NULL
      BEGIN
        SELECT RAISE(ABORT,'reposición sin obligación requiere cobro acreditado')
        WHERE NOT EXISTS(
          SELECT 1 FROM movimientos m JOIN regimen_comida r ON r.saldo=m.destino
          WHERE m.id=NEW.movimiento AND m.anulado=0 AND m.tipo='Transferencia'
            AND r.estado='Activo'
        );
      END;
CREATE TRIGGER movimiento_rol_financiacion_shape BEFORE INSERT ON movimiento_rol_financiacion
      WHEN NOT EXISTS(
        SELECT 1 FROM movimientos m WHERE m.id=NEW.movimiento AND m.anulado=0
          AND m.tipo IN ('Transferencia','Amortización deuda')
      ) BEGIN SELECT RAISE(ABORT,'invalid financing role'); END;
CREATE TRIGGER operacion_inversion_annulled_immutable BEFORE UPDATE ON operaciones_inversion
    WHEN OLD.estado='Anulada' BEGIN SELECT RAISE(ABORT,'annulled operation is immutable'); END;
CREATE TRIGGER operacion_inversion_audit_no_delete BEFORE DELETE ON operacion_inversion_audit
    BEGIN SELECT RAISE(ABORT,'immutable operation audit'); END;
CREATE TRIGGER operacion_inversion_audit_no_update BEFORE UPDATE ON operacion_inversion_audit
    BEGIN SELECT RAISE(ABORT,'immutable operation audit'); END;
CREATE TRIGGER operacion_inversion_id_immutable BEFORE UPDATE OF id ON operaciones_inversion
    WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable operation id'); END;
CREATE TRIGGER operacion_inversion_identity_immutable BEFORE UPDATE OF instrumento,saldo_efectivo,saldo_inversion,clase ON operaciones_inversion
    WHEN NEW.instrumento!=OLD.instrumento OR NEW.saldo_efectivo!=OLD.saldo_efectivo OR NEW.saldo_inversion!=OLD.saldo_inversion OR NEW.clase!=OLD.clase
    BEGIN SELECT RAISE(ABORT,'immutable operation identity'); END;
CREATE TRIGGER operacion_inversion_no_delete BEFORE DELETE ON operaciones_inversion
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER operacion_inversion_saldos_type BEFORE INSERT ON operaciones_inversion
    WHEN (SELECT tipo FROM saldos WHERE id=NEW.saldo_efectivo) IS NOT 'Efectivo'
      OR (SELECT control FROM saldos WHERE id=NEW.saldo_efectivo) IS NOT 'Inversiones'
      OR (SELECT tipo FROM saldos WHERE id=NEW.saldo_inversion) IS NOT 'Inversión'
      OR (SELECT control FROM saldos WHERE id=NEW.saldo_inversion) IS NOT 'Inversiones'
    BEGIN SELECT RAISE(ABORT,'invalid investment saldo pair'); END;
CREATE TRIGGER origin_no_delete BEFORE DELETE ON database_origin BEGIN SELECT RAISE(ABORT,'immutable origin'); END;
CREATE TRIGGER origin_no_update BEFORE UPDATE ON database_origin BEGIN SELECT RAISE(ABORT,'immutable origin'); END;
CREATE TRIGGER participante_compartido_id_immutable BEFORE UPDATE OF id ON participantes_compartido WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER participante_compartido_no_delete BEFORE DELETE ON participantes_compartido BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER partida_dprima_fuente_used BEFORE UPDATE OF fuente ON partidas
    WHEN NEW.fuente IS NOT OLD.fuente AND EXISTS(
      SELECT 1 FROM dprima_plan_mensual WHERE raiz=OLD.id
    ) BEGIN SELECT RAISE(ABORT,'dprima source of used partida'); END;
CREATE TRIGGER partida_dprima_inactive_used BEFORE UPDATE OF estado ON partidas
    WHEN NEW.estado='Inactiva' AND NEW.estado IS NOT OLD.estado AND (
      EXISTS(SELECT 1 FROM dprima_lineas l JOIN dprima_planificaciones p ON p.id=l.planificacion
        WHERE l.hija=OLD.id AND l.anulada=0 AND p.estado<>'Finalizada')
      OR EXISTS(SELECT 1 FROM dprima_plan_mensual m WHERE m.raiz=OLD.id)
      OR EXISTS(SELECT 1 FROM dprima_planificaciones p WHERE p.padre=OLD.id AND p.estado<>'Finalizada')
    ) BEGIN SELECT RAISE(ABORT,'dprima used daughter cannot be deactivated'); END;
CREATE TRIGGER partida_dprima_parent_root BEFORE INSERT ON partidas
    WHEN NEW.padre_partida IS NOT NULL AND NOT EXISTS(
      SELECT 1 FROM partidas p WHERE p.id=NEW.padre_partida AND p.padre_partida IS NULL
    ) BEGIN SELECT RAISE(ABORT,'dprima parent must be a root'); END;
CREATE TRIGGER partida_dprima_parent_update BEFORE UPDATE OF padre_partida ON partidas
    WHEN NEW.padre_partida IS NOT NULL AND (
      NEW.padre_partida=NEW.id OR NOT EXISTS(
        SELECT 1 FROM partidas p WHERE p.id=NEW.padre_partida AND p.padre_partida IS NULL
      )
    ) BEGIN SELECT RAISE(ABORT,'dprima parent must be a root'); END;
CREATE TRIGGER partida_dprima_parent_used BEFORE UPDATE OF padre_partida ON partidas
    WHEN NEW.padre_partida IS NOT OLD.padre_partida AND (
      EXISTS(SELECT 1 FROM movimientos WHERE partida=OLD.id)
      OR EXISTS(SELECT 1 FROM dprima_lineas WHERE hija=OLD.id)
      OR EXISTS(SELECT 1 FROM dprima_plan_mensual WHERE raiz=OLD.id)
    ) BEGIN SELECT RAISE(ABORT,'dprima reparent of used partida'); END;
CREATE TRIGGER partida_used_debt BEFORE UPDATE OF deuda ON partidas WHEN NEW.deuda IS NOT OLD.deuda AND EXISTS(SELECT 1 FROM movimientos WHERE partida=OLD.id) BEGIN SELECT RAISE(ABORT,'used debt relation'); END;
CREATE TRIGGER partidas_id_immutable BEFORE UPDATE OF id ON partidas
      WHEN NEW.id != OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER partidas_no_delete BEFORE DELETE ON partidas
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER payroll_audit_no_delete BEFORE DELETE ON payroll_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
CREATE TRIGGER payroll_audit_no_update BEFORE UPDATE ON payroll_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
CREATE TRIGGER payroll_identity BEFORE UPDATE OF id ON payroll BEGIN SELECT RAISE(ABORT,'immutable identity'); END;
CREATE TRIGGER payroll_no_delete BEFORE DELETE ON payroll BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER presupuesto_id_immutable BEFORE UPDATE OF id ON presupuestos WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable budget id'); END;
CREATE TRIGGER presupuesto_no_delete BEFORE DELETE ON presupuestos BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER reapertura_cancelacion_coherente
      BEFORE INSERT ON reaperturas
      WHEN NEW.tipo='cancelacion'
        AND NOT EXISTS (
          SELECT 1 FROM reaperturas r
          WHERE r.id=NEW.reapertura_origen
            AND r.ciclo=NEW.ciclo
            AND r.version_origen=NEW.version_origen
            AND r.tipo='reapertura'
        )
      BEGIN SELECT RAISE(ABORT,'cancellation must reference its reopening'); END;
CREATE TRIGGER reapertura_no_delete
      BEFORE DELETE ON reaperturas
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER reapertura_no_update
      BEFORE UPDATE ON reaperturas
      BEGIN SELECT RAISE(ABORT,'immutable reopening'); END;
CREATE TRIGGER referencia_id_immutable BEFORE UPDATE OF id ON referencias WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER referencia_no_delete BEFORE DELETE ON referencias BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER referencia_used_type BEFORE UPDATE OF tipo ON referencias WHEN NEW.tipo!=OLD.tipo AND EXISTS(SELECT 1 FROM movimientos WHERE referencia=OLD.id) BEGIN SELECT RAISE(ABORT,'used reference type'); END;
CREATE TRIGGER referencia_vehicle_type BEFORE UPDATE OF tipo ON referencias
    WHEN OLD.tipo='Vehículo' AND NEW.tipo!='Vehículo'
      AND EXISTS(SELECT 1 FROM fichas_vehiculo WHERE referencia=OLD.id)
    BEGIN SELECT RAISE(ABORT,'vehicle reference type locked'); END;
CREATE TRIGGER regimen_comida_audit_no_delete BEFORE DELETE ON regimen_comida_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER regimen_comida_audit_no_update BEFORE UPDATE ON regimen_comida_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER regimen_comida_no_delete BEFORE DELETE ON regimen_comida
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER regimen_comida_saldo_immutable BEFORE UPDATE OF saldo ON regimen_comida
    WHEN NEW.saldo!=OLD.saldo BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER revision_comida_annulled_locked BEFORE UPDATE ON revision_comida
    WHEN OLD.estado_registro='Anulado' BEGIN SELECT RAISE(ABORT,'annulled record is immutable'); END;
CREATE TRIGGER revision_comida_audit_no_delete BEFORE DELETE ON revision_comida_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER revision_comida_audit_no_update BEFORE UPDATE ON revision_comida_audit
    BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
CREATE TRIGGER revision_comida_created_immutable BEFORE UPDATE OF creado ON revision_comida
    WHEN NEW.creado!=OLD.creado BEGIN SELECT RAISE(ABORT,'immutable created'); END;
CREATE TRIGGER revision_comida_id_immutable BEFORE UPDATE OF id ON revision_comida
    WHEN NEW.id!=OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER revision_comida_no_delete BEFORE DELETE ON revision_comida
    BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER revision_comida_tipo_immutable BEFORE UPDATE OF tipo ON revision_comida
    WHEN NEW.tipo!=OLD.tipo BEGIN SELECT RAISE(ABORT,'immutable type'); END;
CREATE TRIGGER saldo_id_immutable BEFORE UPDATE OF id ON saldos
        WHEN NEW.id != OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER saldo_no_delete BEFORE DELETE ON saldos BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER subcategorias_id_immutable BEFORE UPDATE OF id ON subcategorias
      WHEN NEW.id != OLD.id BEGIN SELECT RAISE(ABORT,'immutable id'); END;
CREATE TRIGGER subcategorias_no_delete BEFORE DELETE ON subcategorias
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER valoracion_audit_no_delete
      BEFORE DELETE ON valoracion_inversion_audit
      BEGIN SELECT RAISE(ABORT,'immutable valuation audit'); END;
CREATE TRIGGER valoracion_audit_no_update
      BEFORE UPDATE ON valoracion_inversion_audit
      BEGIN SELECT RAISE(ABORT,'immutable valuation audit'); END;
CREATE TRIGGER valoracion_audit_revision
      BEFORE INSERT ON valoracion_inversion_audit
      WHEN (SELECT revision FROM valoracion_inversion WHERE id=NEW.valoracion) IS NOT NEW.revision
      BEGIN SELECT RAISE(ABORT,'audit revision must match valuation'); END;
CREATE TRIGGER valoracion_creado_immutable
      BEFORE UPDATE OF creado_utc ON valoracion_inversion
      WHEN NEW.creado_utc!=OLD.creado_utc
      BEGIN SELECT RAISE(ABORT,'immutable valuation creation'); END;
CREATE TRIGGER valoracion_id_immutable
      BEFORE UPDATE OF id ON valoracion_inversion
      WHEN NEW.id!=OLD.id
      BEGIN SELECT RAISE(ABORT,'immutable valuation id'); END;
CREATE TRIGGER valoracion_insert_initial
      BEFORE INSERT ON valoracion_inversion
      WHEN NEW.revision!=1 OR NEW.motivo_correccion IS NOT NULL
      BEGIN SELECT RAISE(ABORT,'initial valuation requires revision 1 without motive'); END;
CREATE TRIGGER valoracion_no_delete
      BEFORE DELETE ON valoracion_inversion
      BEGIN SELECT RAISE(ABORT,'no delete'); END;
CREATE TRIGGER valoracion_posicion_immutable
      BEFORE UPDATE OF saldo_inversion,instrumento ON valoracion_inversion
      WHEN NEW.saldo_inversion!=OLD.saldo_inversion OR NEW.instrumento!=OLD.instrumento
      BEGIN SELECT RAISE(ABORT,'immutable valuation position'); END;
CREATE TRIGGER valoracion_saldo_type
      BEFORE INSERT ON valoracion_inversion
      WHEN (SELECT tipo FROM saldos WHERE id=NEW.saldo_inversion) IS NOT 'Inversión'
        OR (SELECT control FROM saldos WHERE id=NEW.saldo_inversion) IS NOT 'Inversiones'
      BEGIN SELECT RAISE(ABORT,'invalid valuation saldo'); END;
CREATE TRIGGER valoracion_update_correction
      BEFORE UPDATE ON valoracion_inversion
      WHEN NEW.revision!=OLD.revision+1
        OR NEW.motivo_correccion IS NULL
        OR length(trim(NEW.motivo_correccion))=0
      BEGIN SELECT RAISE(ABORT,'correction requires next revision and motive'); END;
PRAGMA foreign_keys=ON;
