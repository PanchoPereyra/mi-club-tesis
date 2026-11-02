-- SQL MAESTRO CONSOLIDADO - GESTION DE CLUBES
-- Basado en el esquema real inspeccionado en gestion_club y en las decisiones acordadas.
-- SOLO para una BASE NUEVA Y VACIA. NO ejecutar sobre gestion_club existente.
-- PostgreSQL. Revisado estructuralmente; debe probarse en una base de ensayo antes de producción.

BEGIN;

CREATE TABLE club (
 id BIGSERIAL PRIMARY KEY,
 nombre VARCHAR(150) NOT NULL UNIQUE
);
INSERT INTO club(nombre) VALUES ('Tilcara') ON CONFLICT (nombre) DO NOTHING;

CREATE TABLE usuario (
 id BIGSERIAL PRIMARY KEY,
 nombre_usuario VARCHAR(100) NOT NULL UNIQUE,
 email VARCHAR(150) NOT NULL UNIQUE,
 password_hash TEXT NOT NULL,
 nombre VARCHAR(100) NOT NULL,
 apellido VARCHAR(100) NOT NULL,
 fecha_creacion TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categoria_social (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 nombre VARCHAR(100) NOT NULL,
 importe NUMERIC(12,2) NOT NULL CHECK (importe >= 0),
 CONSTRAINT uq_categoria_social_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_categoria_social_nombre_club UNIQUE(club_id, nombre)
);

CREATE TABLE socio (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 categoria_social_id BIGINT,
 dni VARCHAR(20),
 nombre VARCHAR(100) NOT NULL,
 apellido VARCHAR(100) NOT NULL,
 fecha_nacimiento DATE,
 telefono VARCHAR(30),
 email VARCHAR(150),
 domicilio VARCHAR(200),
 grupo_familiar_id BIGINT,
 CONSTRAINT uq_socio_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_socio_club_dni UNIQUE(club_id, dni),
 CONSTRAINT fk_socio_categoria_social FOREIGN KEY(categoria_social_id, club_id) REFERENCES categoria_social(id, club_id)
);

CREATE TABLE grupo_familiar (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 titular_socio_id BIGINT NOT NULL,
 CONSTRAINT uq_grupo_familiar_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_grupo_familiar_id_club_titular UNIQUE(id, club_id, titular_socio_id),
 CONSTRAINT uq_grupo_familiar_titular UNIQUE(titular_socio_id),
 CONSTRAINT fk_grupo_familiar_titular FOREIGN KEY(titular_socio_id, club_id) REFERENCES socio(id, club_id)
);
ALTER TABLE socio ADD CONSTRAINT fk_socio_grupo_familiar FOREIGN KEY(grupo_familiar_id, club_id) REFERENCES grupo_familiar(id, club_id);

CREATE TABLE sede (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 nombre VARCHAR(100) NOT NULL,
 CONSTRAINT uq_sede_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_sede_nombre_club UNIQUE(club_id, nombre)
);
CREATE TABLE disciplina (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 nombre VARCHAR(100) NOT NULL,
 CONSTRAINT uq_disciplina_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_disciplina_nombre_club UNIQUE(club_id, nombre)
);
CREATE TABLE temporada (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 nombre VARCHAR(100) NOT NULL,
 fecha_inicio DATE NOT NULL,
 fecha_fin DATE NOT NULL,
 CONSTRAINT chk_temporada_fechas CHECK(fecha_fin >= fecha_inicio),
 CONSTRAINT uq_temporada_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_temporada_nombre_club UNIQUE(club_id, nombre)
);
CREATE TABLE nivel_deportivo (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 disciplina_id BIGINT NOT NULL,
 nombre VARCHAR(100) NOT NULL,
 CONSTRAINT uq_nivel_deportivo_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_nivel_deportivo_id_disciplina UNIQUE(id, disciplina_id),
 CONSTRAINT uq_nivel_deportivo_nombre_disciplina UNIQUE(disciplina_id, nombre),
 CONSTRAINT fk_nivel_deportivo_disciplina FOREIGN KEY(disciplina_id, club_id) REFERENCES disciplina(id, club_id)
);
CREATE TABLE categoria_deportiva (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL,
 disciplina_id BIGINT NOT NULL,
 nivel_deportivo_id BIGINT NOT NULL,
 nombre VARCHAR(100) NOT NULL,
 CONSTRAINT uq_categoria_deportiva_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_categoria_deportiva_id_disciplina UNIQUE(id, disciplina_id),
 CONSTRAINT uq_categoria_deportiva_id_nivel UNIQUE(id, nivel_deportivo_id),
 CONSTRAINT uq_categoria_deportiva_nombre_disciplina UNIQUE(disciplina_id, nombre),
 CONSTRAINT fk_categoria_deportiva_disciplina FOREIGN KEY(disciplina_id, club_id) REFERENCES disciplina(id, club_id),
 CONSTRAINT fk_categoria_deportiva_nivel FOREIGN KEY(nivel_deportivo_id, disciplina_id) REFERENCES nivel_deportivo(id, disciplina_id)
);
CREATE TABLE inscripcion_deportiva (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL,
 socio_id BIGINT NOT NULL,
 disciplina_id BIGINT NOT NULL,
 temporada_id BIGINT NOT NULL,
 nivel_deportivo_id BIGINT NOT NULL,
 categoria_deportiva_id BIGINT NOT NULL,
 fecha_inscripcion DATE NOT NULL DEFAULT CURRENT_DATE,
 CONSTRAINT uq_inscripcion_id_club UNIQUE(id, club_id),
 CONSTRAINT uq_inscripcion_id_club_socio UNIQUE(id, club_id, socio_id),
 CONSTRAINT uq_inscripcion_socio_disciplina_temporada UNIQUE(socio_id, disciplina_id, temporada_id),
 CONSTRAINT fk_inscripcion_socio FOREIGN KEY(socio_id, club_id) REFERENCES socio(id, club_id),
 CONSTRAINT fk_inscripcion_disciplina FOREIGN KEY(disciplina_id, club_id) REFERENCES disciplina(id, club_id),
 CONSTRAINT fk_inscripcion_temporada FOREIGN KEY(temporada_id, club_id) REFERENCES temporada(id, club_id),
 CONSTRAINT fk_inscripcion_nivel FOREIGN KEY(nivel_deportivo_id, disciplina_id) REFERENCES nivel_deportivo(id, disciplina_id),
 CONSTRAINT fk_inscripcion_categoria FOREIGN KEY(categoria_deportiva_id, disciplina_id) REFERENCES categoria_deportiva(id, disciplina_id),
 CONSTRAINT fk_inscripcion_categoria_club FOREIGN KEY(categoria_deportiva_id, club_id) REFERENCES categoria_deportiva(id, club_id),
 CONSTRAINT fk_inscripcion_categoria_nivel FOREIGN KEY(categoria_deportiva_id, nivel_deportivo_id) REFERENCES categoria_deportiva(id, nivel_deportivo_id)
);
CREATE TABLE asistencia (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL,
 inscripcion_deportiva_id BIGINT NOT NULL,
 fecha DATE NOT NULL,
 estado VARCHAR(20) NOT NULL CHECK(estado IN ('PRESENTE','AUSENTE','LESIONADO','JUSTIFICADO')),
 observacion VARCHAR(500),
 registrado_en TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_asistencia_inscripcion_fecha UNIQUE(inscripcion_deportiva_id, fecha),
 CONSTRAINT fk_asistencia_inscripcion FOREIGN KEY(inscripcion_deportiva_id, club_id) REFERENCES inscripcion_deportiva(id, club_id)
);
CREATE TABLE asignacion_staff (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL,
 socio_id BIGINT NOT NULL,
 disciplina_id BIGINT NOT NULL,
 funcion VARCHAR(100) NOT NULL,
 CONSTRAINT uq_asignacion_staff_id_club UNIQUE(id, club_id),
 CONSTRAINT fk_asignacion_staff_disciplina FOREIGN KEY(disciplina_id, club_id) REFERENCES disciplina(id, club_id),
 CONSTRAINT fk_asignacion_staff_socio FOREIGN KEY(socio_id, club_id) REFERENCES socio(id, club_id)
);

CREATE TABLE usuario_club (
 id BIGSERIAL PRIMARY KEY,
 usuario_id BIGINT NOT NULL REFERENCES usuario(id),
 club_id BIGINT NOT NULL REFERENCES club(id),
 CONSTRAINT uq_usuario_club UNIQUE(usuario_id, club_id),
 CONSTRAINT uq_usuario_club_id_club UNIQUE(id, club_id)
);
CREATE TABLE rol (
 id BIGSERIAL PRIMARY KEY,
 nombre VARCHAR(100) NOT NULL UNIQUE,
 descripcion VARCHAR(300)
);
CREATE TABLE permiso (
 id BIGSERIAL PRIMARY KEY,
 codigo VARCHAR(100) NOT NULL UNIQUE,
 nombre VARCHAR(150) NOT NULL,
 descripcion VARCHAR(300)
);
CREATE TABLE usuario_club_rol (
 id BIGSERIAL PRIMARY KEY,
 usuario_club_id BIGINT NOT NULL REFERENCES usuario_club(id),
 rol_id BIGINT NOT NULL REFERENCES rol(id),
 CONSTRAINT uq_usuario_club_rol UNIQUE(usuario_club_id, rol_id)
);
CREATE TABLE rol_permiso (
 id BIGSERIAL PRIMARY KEY,
 rol_id BIGINT NOT NULL REFERENCES rol(id),
 permiso_id BIGINT NOT NULL REFERENCES permiso(id),
 CONSTRAINT uq_rol_permiso UNIQUE(rol_id, permiso_id)
);
CREATE TABLE auditoria (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 usuario_id BIGINT REFERENCES usuario(id),
 tabla_afectada VARCHAR(100) NOT NULL,
 registro_id BIGINT,
 accion VARCHAR(20) NOT NULL CHECK(accion IN ('INSERTAR','MODIFICAR','ELIMINAR','ANULAR')),
 detalle TEXT,
 fecha_hora TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE configuracion_cuota (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 tipo_cuota VARCHAR(20) NOT NULL CHECK(tipo_cuota IN ('SOCIAL','DEPORTIVA')),
 disciplina_id BIGINT,
 importe NUMERIC(12,2) NOT NULL CHECK(importe >= 0),
 dia_vencimiento INTEGER NOT NULL CHECK(dia_vencimiento BETWEEN 1 AND 28),
 recargo_porcentaje NUMERIC(7,3) NOT NULL DEFAULT 0 CHECK(recargo_porcentaje >= 0),
 fecha_desde DATE NOT NULL,
 fecha_hasta DATE,
 CONSTRAINT chk_configuracion_cuota_fechas CHECK(fecha_hasta IS NULL OR fecha_hasta >= fecha_desde),
 CONSTRAINT chk_configuracion_cuota_disciplina CHECK((tipo_cuota='SOCIAL' AND disciplina_id IS NULL) OR (tipo_cuota='DEPORTIVA' AND disciplina_id IS NOT NULL)),
 CONSTRAINT uq_configuracion_cuota_id_club UNIQUE(id, club_id),
 CONSTRAINT fk_configuracion_cuota_disciplina FOREIGN KEY(disciplina_id, club_id) REFERENCES disciplina(id, club_id)
);
CREATE TABLE configuracion_cuota_nivel (
 id BIGSERIAL PRIMARY KEY,
 configuracion_cuota_id BIGINT NOT NULL,
 nivel_deportivo_id BIGINT NOT NULL,
 importe NUMERIC(12,2) NOT NULL CHECK(importe >= 0),
 club_id BIGINT NOT NULL REFERENCES club(id),
 CONSTRAINT uq_configuracion_cuota_nivel UNIQUE(configuracion_cuota_id, nivel_deportivo_id),
 CONSTRAINT fk_configuracion_cuota_nivel_configuracion FOREIGN KEY(configuracion_cuota_id) REFERENCES configuracion_cuota(id),
 CONSTRAINT fk_configuracion_cuota_nivel_configuracion_club FOREIGN KEY(configuracion_cuota_id, club_id) REFERENCES configuracion_cuota(id, club_id),
 CONSTRAINT fk_configuracion_cuota_nivel_nivel FOREIGN KEY(nivel_deportivo_id) REFERENCES nivel_deportivo(id),
 CONSTRAINT fk_configuracion_cuota_nivel_nivel_club FOREIGN KEY(nivel_deportivo_id, club_id) REFERENCES nivel_deportivo(id, club_id)
);
CREATE TABLE cuota_generada (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 tipo_cuota VARCHAR(20) NOT NULL CHECK(tipo_cuota IN ('SOCIAL','DEPORTIVA')),
 socio_id BIGINT,
 grupo_familiar_id BIGINT,
 inscripcion_deportiva_id BIGINT,
 responsable_pago_socio_id BIGINT NOT NULL,
 anio INTEGER NOT NULL CHECK(anio >= 2000),
 mes INTEGER NOT NULL CHECK(mes BETWEEN 1 AND 12),
 importe_base NUMERIC(12,2) NOT NULL CHECK(importe_base >= 0),
 recargo_importe NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(recargo_importe >= 0),
 importe_total NUMERIC(12,2) NOT NULL CHECK(importe_total = importe_base + recargo_importe),
 estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK(estado IN ('PENDIENTE','VENCIDA','PAGADA','ANULADA')),
 fecha_vencimiento DATE NOT NULL,
 fecha_generacion TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT chk_cuota_generada_sujeto CHECK(
  (tipo_cuota='SOCIAL' AND ((socio_id IS NOT NULL AND grupo_familiar_id IS NULL AND responsable_pago_socio_id=socio_id) OR (socio_id IS NULL AND grupo_familiar_id IS NOT NULL)))
  OR (tipo_cuota='DEPORTIVA' AND socio_id IS NOT NULL AND grupo_familiar_id IS NULL AND inscripcion_deportiva_id IS NOT NULL)
 ),
 CONSTRAINT uq_cuota_generada_id_club UNIQUE(id, club_id),
 CONSTRAINT fk_cuota_generada_grupo_familiar FOREIGN KEY(grupo_familiar_id, club_id) REFERENCES grupo_familiar(id, club_id),
 CONSTRAINT fk_cuota_generada_grupo_titular FOREIGN KEY(grupo_familiar_id, club_id, responsable_pago_socio_id) REFERENCES grupo_familiar(id, club_id, titular_socio_id),
 CONSTRAINT fk_cuota_generada_inscripcion FOREIGN KEY(inscripcion_deportiva_id, club_id) REFERENCES inscripcion_deportiva(id, club_id),
 CONSTRAINT fk_cuota_generada_responsable FOREIGN KEY(responsable_pago_socio_id, club_id) REFERENCES socio(id, club_id),
 CONSTRAINT fk_cuota_generada_socio FOREIGN KEY(socio_id, club_id) REFERENCES socio(id, club_id)
);
CREATE UNIQUE INDEX uq_cuota_social_familiar_periodo ON cuota_generada(club_id, grupo_familiar_id, anio, mes) WHERE tipo_cuota='SOCIAL' AND grupo_familiar_id IS NOT NULL;
CREATE UNIQUE INDEX uq_cuota_social_socio_periodo ON cuota_generada(club_id, socio_id, anio, mes) WHERE tipo_cuota='SOCIAL' AND socio_id IS NOT NULL;
CREATE UNIQUE INDEX uq_cuota_deportiva_inscripcion_periodo ON cuota_generada(club_id, inscripcion_deportiva_id, anio, mes) WHERE tipo_cuota='DEPORTIVA' AND inscripcion_deportiva_id IS NOT NULL;

CREATE TABLE pago (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL REFERENCES club(id),
 socio_id BIGINT NOT NULL,
 fecha_pago TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 importe_total NUMERIC(12,2) NOT NULL CHECK(importe_total > 0),
 medio_pago VARCHAR(20) NOT NULL CHECK(medio_pago IN ('EFECTIVO','TRANSFERENCIA','DEBITO','CREDITO','OTRO')),
 referencia VARCHAR(150),
 registrado_por_usuario_id BIGINT NOT NULL REFERENCES usuario(id),
 observacion VARCHAR(500),
 estado VARCHAR(20) NOT NULL DEFAULT 'REGISTRADO' CHECK(estado IN ('REGISTRADO','ANULADO')),
 motivo_anulacion TEXT,
 anulado_por_usuario_id BIGINT REFERENCES usuario(id),
 fecha_anulacion TIMESTAMP WITHOUT TIME ZONE,
 pago_reemplazo_id BIGINT,
 CONSTRAINT uq_pago_id_club UNIQUE(id, club_id),
 CONSTRAINT fk_pago_socio FOREIGN KEY(socio_id, club_id) REFERENCES socio(id, club_id),
 CONSTRAINT fk_pago_reemplazo_club FOREIGN KEY(pago_reemplazo_id, club_id) REFERENCES pago(id, club_id),
 CONSTRAINT chk_pago_estado_anulacion CHECK(
  (estado='REGISTRADO' AND motivo_anulacion IS NULL AND anulado_por_usuario_id IS NULL AND fecha_anulacion IS NULL)
  OR (estado='ANULADO' AND motivo_anulacion IS NOT NULL AND length(btrim(motivo_anulacion))>0 AND anulado_por_usuario_id IS NOT NULL AND fecha_anulacion IS NOT NULL)
 )
);
CREATE UNIQUE INDEX uq_pago_reemplazo_unico ON pago(pago_reemplazo_id) WHERE pago_reemplazo_id IS NOT NULL;
CREATE TABLE pago_detalle (
 id BIGSERIAL PRIMARY KEY,
 club_id BIGINT NOT NULL,
 pago_id BIGINT NOT NULL,
 cuota_generada_id BIGINT NOT NULL,
 importe_aplicado NUMERIC(12,2) NOT NULL CHECK(importe_aplicado > 0),
 CONSTRAINT fk_pago_detalle_cuota FOREIGN KEY(cuota_generada_id, club_id) REFERENCES cuota_generada(id, club_id),
 CONSTRAINT fk_pago_detalle_pago FOREIGN KEY(pago_id, club_id) REFERENCES pago(id, club_id)
);

-- Roles globales: las asignaciones concretas se realizan por usuario_club.
INSERT INTO rol(nombre, descripcion) VALUES
 ('Administrador','Configuracion tecnica del sistema'),
 ('Presidencia','Supervision institucional'),
 ('Tesorería','Gestion de cuotas y pagos'),
 ('Secretaría','Gestion administrativa de socios'),
 ('Entrenador','Consulta de deuda deportiva de sus jugadores'),
 ('Manager de división','Seguimiento de cuotas y asistencia'),
 ('Socio','Consulta de sus datos, cuotas y pagos')
ON CONFLICT(nombre) DO NOTHING;

INSERT INTO permiso(codigo,nombre,descripcion) VALUES
 ('socio.consultar','Consultar socios','Consultar datos de socios autorizados'),
 ('socio.gestionar','Gestionar socios','Alta, baja logica y modificacion administrativa de socios'),
 ('cuota.consultar','Consultar cuotas','Consultar estado y detalle de cuotas'),
 ('cuota.configurar','Configurar cuotas','Administrar importes y vigencias de cuotas'),
 ('pago.registrar','Registrar pagos','Registrar pagos completos de cuotas'),
 ('pago.anular','Anular pagos','Anular un pago completo con motivo e historial'),
 ('asistencia.consultar','Consultar asistencia','Consultar asistencia deportiva'),
 ('asistencia.gestionar','Gestionar asistencia','Registrar y corregir asistencia'),
 ('auditoria.consultar','Consultar auditoria','Consultar historial de acciones'),
 ('sistema.configurar','Configurar sistema','Administracion tecnica del sistema')
ON CONFLICT(codigo) DO NOTHING;

-- Asignaciones iniciales de permisos por rol; ajustar por club desde la aplicación.
INSERT INTO rol_permiso(rol_id, permiso_id)
SELECT r.id,p.id FROM rol r CROSS JOIN permiso p
WHERE (r.nombre='Administrador' AND p.codigo IN ('sistema.configurar','auditoria.consultar'))
 OR (r.nombre='Presidencia' AND p.codigo IN ('socio.consultar','cuota.consultar','pago.anular','auditoria.consultar'))
 OR (r.nombre='Tesorería' AND p.codigo IN ('socio.consultar','cuota.consultar','cuota.configurar','pago.registrar','pago.anular','auditoria.consultar'))
 OR (r.nombre='Secretaría' AND p.codigo IN ('socio.consultar','socio.gestionar','cuota.consultar','cuota.configurar','pago.anular'))
 OR (r.nombre='Entrenador' AND p.codigo IN ('cuota.consultar'))
 OR (r.nombre='Manager de división' AND p.codigo IN ('cuota.consultar','asistencia.consultar','asistencia.gestionar'))
 OR (r.nombre='Socio' AND p.codigo IN ('cuota.consultar'))
ON CONFLICT(rol_id, permiso_id) DO NOTHING;

COMMIT;

-- NOTAS DE ALCANCE:
-- 1. Este maestro reproduce la estructura consolidada actual; no es migracion.
-- 2. Las reglas de anulacion requieren instalar la migracion incremental correspondiente.
-- 3. La generación mensual de cuotas, descuentos por hermanos, becas deportivas,
--    auditoria automatica y las pantallas de la aplicación requieren lógica adicional.
-- 4. Probar en una base vacia de ensayo antes de usar en cualquier entorno real.
