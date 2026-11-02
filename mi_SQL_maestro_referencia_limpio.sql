-- SQL MAESTRO DE REFERENCIA - GESTION DE CLUBES
--
-- BASE: version limpia del borrador aportado por el usuario.
-- IMPORTANTE: este archivo es para crear una base VACIA y no debe ejecutarse
-- completo sobre gestion_club, que ya contiene tablas y restricciones.
--
-- Antes de considerarlo version definitiva para produccion, deben reconciliarse
-- los nombres y decisiones del esquema real (por ejemplo configuracion_cuota,
-- cuota_generada, pago y auditoria) con el archivo de migracion incremental.
-- El flujo de anulacion de pagos se entrega en un archivo separado.
--
-- BORRADOR CORREGIDO - SISTEMA DE GESTION DE CLUBES

-- Este archivo crea la estructura inicial completa, incluida la tabla club.

-- Ejecutar en una base vacia; no ejecutar completo si las tablas ya existen.



-- ============================================================

-- CLUBES

-- ============================================================

CREATE TABLE club (

    id BIGSERIAL PRIMARY KEY,

    nombre VARCHAR(150) NOT NULL UNIQUE

);



-- Registro inicial del club con el que comenzamos el proyecto.

INSERT INTO club (nombre) VALUES ('Tilcara')

ON CONFLICT (nombre) DO NOTHING;





-- ============================================================

-- SOCIOS Y SEDES

-- ============================================================

CREATE TABLE socio (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    dni VARCHAR(20),

    nombre VARCHAR(100) NOT NULL,

    apellido VARCHAR(100) NOT NULL,

    fecha_nacimiento DATE,

    telefono VARCHAR(30),

    email VARCHAR(150),

    domicilio VARCHAR(200),

    referencia_familiar VARCHAR(150),

    categoria_social_id BIGINT,

    CONSTRAINT fk_socio_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT uq_socio_id_club UNIQUE (id, club_id),

    CONSTRAINT uq_socio_club_dni UNIQUE (club_id, dni)

);



CREATE TABLE grupo_familiar (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    titular_socio_id BIGINT NOT NULL,

    CONSTRAINT fk_grupo_familiar_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT fk_grupo_familiar_titular FOREIGN KEY (titular_socio_id, club_id) REFERENCES socio(id, club_id),

    CONSTRAINT uq_grupo_familiar_id_club UNIQUE (id, club_id),

    CONSTRAINT uq_grupo_familiar_titular UNIQUE (titular_socio_id)

);



ALTER TABLE socio ADD COLUMN grupo_familiar_id BIGINT;

ALTER TABLE socio ADD CONSTRAINT fk_socio_grupo_familiar

    FOREIGN KEY (grupo_familiar_id, club_id) REFERENCES grupo_familiar(id, club_id);



CREATE TABLE sede (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    direccion VARCHAR(200),

    localidad VARCHAR(100),

    descripcion TEXT,

    CONSTRAINT fk_sede_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT uq_sede_id_club UNIQUE (id, club_id),

    CONSTRAINT uq_sede_club_nombre UNIQUE (club_id, nombre)

);



-- ============================================================

-- DISCIPLINAS Y TEMPORADAS

-- ============================================================

CREATE TABLE deporte (

    id BIGSERIAL PRIMARY KEY,

    nombre VARCHAR(100) NOT NULL UNIQUE,

    descripcion TEXT

);



CREATE TABLE disciplina (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    deporte_id BIGINT NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    descripcion TEXT,

    CONSTRAINT fk_disciplina_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT fk_disciplina_deporte FOREIGN KEY (deporte_id) REFERENCES deporte(id),

    CONSTRAINT uq_disciplina_club_deporte UNIQUE (club_id, deporte_id),

    CONSTRAINT uq_disciplina_id_club UNIQUE (id, club_id)

);



CREATE TABLE categoria_social (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    tipo VARCHAR(20) NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    descripcion TEXT,

    CONSTRAINT fk_categoria_social_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT chk_categoria_social_tipo CHECK (tipo IN ('INDIVIDUAL', 'FAMILIAR')),

    CONSTRAINT uq_categoria_social_club_nombre UNIQUE (club_id, nombre),

    CONSTRAINT uq_categoria_social_club_tipo UNIQUE (club_id, tipo),

    CONSTRAINT uq_categoria_social_id_club UNIQUE (id, club_id)

);



-- Crea las dos categorias sociales acordadas para cada club existente.

INSERT INTO categoria_social (club_id, tipo, nombre, descripcion)

SELECT c.id, cat.tipo, cat.nombre, cat.descripcion

FROM club c

CROSS JOIN (VALUES

    ('INDIVIDUAL', 'Individual', 'Categoria social individual'),

    ('FAMILIAR', 'Familiar', 'Categoria social familiar')

) AS cat(tipo, nombre, descripcion)

ON CONFLICT (club_id, tipo) DO NOTHING;



ALTER TABLE socio ADD CONSTRAINT fk_socio_categoria_social

    FOREIGN KEY (categoria_social_id, club_id) REFERENCES categoria_social(id, club_id);



-- La categoria INDIVIDUAL no se vincula a un grupo familiar; la FAMILIAR si.

-- La validacion se difiere hasta el COMMIT para permitir crear el socio, el grupo y sus vinculos

-- dentro de una misma transaccion.

CREATE OR REPLACE FUNCTION validar_categoria_y_grupo_socio()

RETURNS TRIGGER AS $$

DECLARE

    v_tipo_categoria VARCHAR(20);

BEGIN

    SELECT tipo INTO v_tipo_categoria

    FROM categoria_social

    WHERE id = NEW.categoria_social_id AND club_id = NEW.club_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION 'El socio debe tener una categoria social valida para su club';

    END IF;



    IF v_tipo_categoria = 'INDIVIDUAL' AND NEW.grupo_familiar_id IS NOT NULL THEN

        RAISE EXCEPTION 'Un socio de categoria individual no puede pertenecer a un grupo familiar';

    END IF;



    IF v_tipo_categoria = 'FAMILIAR' AND NEW.grupo_familiar_id IS NULL THEN

        RAISE EXCEPTION 'Un socio de categoria familiar debe pertenecer a un grupo familiar';

    END IF;



    RETURN NULL;

END;

$$ LANGUAGE plpgsql;



CREATE CONSTRAINT TRIGGER trg_validar_categoria_y_grupo_socio

AFTER INSERT OR UPDATE ON socio

DEFERRABLE INITIALLY DEFERRED

FOR EACH ROW EXECUTE FUNCTION validar_categoria_y_grupo_socio();



-- El titular tambien debe ser miembro del grupo y tener categoria social familiar.

CREATE OR REPLACE FUNCTION validar_titular_grupo_familiar()

RETURNS TRIGGER AS $$

DECLARE

    v_grupo_socio BIGINT;

    v_tipo_categoria VARCHAR(20);

BEGIN

    SELECT s.grupo_familiar_id, cs.tipo

      INTO v_grupo_socio, v_tipo_categoria

    FROM socio s

    JOIN categoria_social cs ON cs.id = s.categoria_social_id AND cs.club_id = s.club_id

    WHERE s.id = NEW.titular_socio_id AND s.club_id = NEW.club_id;



    IF NOT FOUND OR v_grupo_socio IS DISTINCT FROM NEW.id OR v_tipo_categoria IS DISTINCT FROM 'FAMILIAR' THEN

        RAISE EXCEPTION 'El titular debe pertenecer al grupo y tener categoria social familiar';

    END IF;

    RETURN NULL;

END;

$$ LANGUAGE plpgsql;



CREATE CONSTRAINT TRIGGER trg_validar_titular_grupo_familiar

AFTER INSERT OR UPDATE ON grupo_familiar

DEFERRABLE INITIALLY DEFERRED

FOR EACH ROW EXECUTE FUNCTION validar_titular_grupo_familiar();



CREATE TABLE temporada (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    anio INTEGER NOT NULL,

    descripcion VARCHAR(150),

    CONSTRAINT fk_temporada_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT uq_temporada_club_anio UNIQUE (club_id, anio),

    CONSTRAINT uq_temporada_id_club UNIQUE (id, club_id)

);



CREATE TABLE nivel_deportivo (

    id BIGSERIAL PRIMARY KEY,

    disciplina_id BIGINT NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    descripcion TEXT,

    CONSTRAINT fk_nivel_disciplina FOREIGN KEY (disciplina_id) REFERENCES disciplina(id),

    CONSTRAINT uq_nivel_disciplina_nombre UNIQUE (disciplina_id, nombre),

    CONSTRAINT uq_nivel_id_disciplina UNIQUE (id, disciplina_id)

);



CREATE TABLE categoria_deportiva (

    id BIGSERIAL PRIMARY KEY,

    nivel_deportivo_id BIGINT NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    descripcion TEXT,

    CONSTRAINT fk_categoria_nivel FOREIGN KEY (nivel_deportivo_id) REFERENCES nivel_deportivo(id),

    CONSTRAINT uq_categoria_nivel_nombre UNIQUE (nivel_deportivo_id, nombre),

    CONSTRAINT uq_categoria_id_nivel UNIQUE (id, nivel_deportivo_id)

);



CREATE TABLE inscripcion_deportiva (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    socio_id BIGINT NOT NULL,

    disciplina_id BIGINT NOT NULL,

    nivel_deportivo_id BIGINT NOT NULL,

    categoria_deportiva_id BIGINT NOT NULL,

    temporada_id BIGINT NOT NULL,

    fecha_inicio DATE NOT NULL,

    fecha_fin DATE,

    CONSTRAINT fk_inscripcion_socio_club FOREIGN KEY (socio_id, club_id) REFERENCES socio(id, club_id),

    CONSTRAINT fk_inscripcion_disciplina_club FOREIGN KEY (disciplina_id, club_id) REFERENCES disciplina(id, club_id),

    CONSTRAINT fk_inscripcion_temporada_club FOREIGN KEY (temporada_id, club_id) REFERENCES temporada(id, club_id),

    CONSTRAINT fk_inscripcion_nivel_disciplina FOREIGN KEY (nivel_deportivo_id, disciplina_id) REFERENCES nivel_deportivo(id, disciplina_id),

    CONSTRAINT fk_inscripcion_categoria_nivel FOREIGN KEY (categoria_deportiva_id, nivel_deportivo_id) REFERENCES categoria_deportiva(id, nivel_deportivo_id),

    CONSTRAINT chk_inscripcion_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),

    CONSTRAINT uq_inscripcion_socio_disciplina_temporada UNIQUE (socio_id, disciplina_id, temporada_id),

    CONSTRAINT uq_inscripcion_id_club UNIQUE (id, club_id),

    CONSTRAINT uq_inscripcion_id_club_socio UNIQUE (id, club_id, socio_id)

);



CREATE TABLE asistencia (

    id BIGSERIAL PRIMARY KEY,

    inscripcion_deportiva_id BIGINT NOT NULL,

    fecha DATE NOT NULL,

    estado VARCHAR(20) NOT NULL DEFAULT 'PRESENTE',

    condicion_deportiva VARCHAR(20) NOT NULL DEFAULT 'APTO',

    observacion TEXT,

    CONSTRAINT fk_asistencia_inscripcion FOREIGN KEY (inscripcion_deportiva_id) REFERENCES inscripcion_deportiva(id),

    CONSTRAINT chk_asistencia_estado CHECK (estado IN ('PRESENTE', 'AUSENTE', 'JUSTIFICADO')),

    CONSTRAINT chk_asistencia_condicion CHECK (condicion_deportiva IN ('APTO', 'LESIONADO')),

    CONSTRAINT uq_asistencia_inscripcion_fecha UNIQUE (inscripcion_deportiva_id, fecha)

);



-- ============================================================

-- USUARIOS, CLUBES, ROLES Y PERMISOS

-- ============================================================

CREATE TABLE usuario (

    id BIGSERIAL PRIMARY KEY,

    nombre_usuario VARCHAR(100) NOT NULL UNIQUE,

    email VARCHAR(150) NOT NULL UNIQUE,

    password_hash TEXT NOT NULL,

    nombre VARCHAR(100) NOT NULL,

    apellido VARCHAR(100) NOT NULL,

    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP

);



CREATE TABLE usuario_socio (

    id BIGSERIAL PRIMARY KEY,

    usuario_id BIGINT NOT NULL REFERENCES usuario(id),

    socio_id BIGINT NOT NULL REFERENCES socio(id),

    CONSTRAINT uq_usuario_socio UNIQUE (usuario_id, socio_id),

    CONSTRAINT uq_usuario_socio_registro UNIQUE (socio_id)

);



CREATE TABLE usuario_club (

    id BIGSERIAL PRIMARY KEY,

    usuario_id BIGINT NOT NULL REFERENCES usuario(id),

    club_id BIGINT NOT NULL REFERENCES club(id),

    CONSTRAINT uq_usuario_club UNIQUE (usuario_id, club_id),

    CONSTRAINT uq_usuario_club_id_club UNIQUE (id, club_id)

);



CREATE TABLE rol (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL REFERENCES club(id),

    nombre VARCHAR(100) NOT NULL,

    descripcion TEXT,

    CONSTRAINT uq_rol_club_nombre UNIQUE (club_id, nombre),

    CONSTRAINT uq_rol_id_club UNIQUE (id, club_id)

);



CREATE TABLE usuario_club_rol (

    id BIGSERIAL PRIMARY KEY,

    usuario_club_id BIGINT NOT NULL,

    rol_id BIGINT NOT NULL,

    club_id BIGINT NOT NULL,

    CONSTRAINT fk_ucr_usuario_club FOREIGN KEY (usuario_club_id, club_id) REFERENCES usuario_club(id, club_id),

    CONSTRAINT fk_ucr_rol FOREIGN KEY (rol_id, club_id) REFERENCES rol(id, club_id),

    CONSTRAINT uq_usuario_club_rol UNIQUE (usuario_club_id, rol_id),

    CONSTRAINT uq_usuario_club_rol_id UNIQUE (id, club_id)

);



CREATE TABLE permiso (

    id BIGSERIAL PRIMARY KEY,

    codigo VARCHAR(100) NOT NULL UNIQUE,

    nombre VARCHAR(100) NOT NULL,

    descripcion TEXT

);



CREATE TABLE rol_permiso (

    id BIGSERIAL PRIMARY KEY,

    rol_id BIGINT NOT NULL REFERENCES rol(id),

    permiso_id BIGINT NOT NULL REFERENCES permiso(id),

    CONSTRAINT uq_rol_permiso UNIQUE (rol_id, permiso_id)

);



CREATE TABLE auditoria (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL REFERENCES club(id),

    usuario_id BIGINT NOT NULL REFERENCES usuario(id),

    entidad VARCHAR(100) NOT NULL,

    registro_id BIGINT NOT NULL,

    accion VARCHAR(20) NOT NULL,

    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    datos_anteriores JSONB,

    datos_nuevos JSONB,

    CONSTRAINT chk_auditoria_accion CHECK (accion IN ('ALTA', 'MODIFICACION', 'BAJA'))

);



CREATE TABLE asignacion_staff (

    id BIGSERIAL PRIMARY KEY,

    usuario_club_rol_id BIGINT NOT NULL REFERENCES usuario_club_rol(id),

    categoria_deportiva_id BIGINT NOT NULL REFERENCES categoria_deportiva(id),

    temporada_id BIGINT NOT NULL REFERENCES temporada(id),

    fecha_inicio DATE NOT NULL,

    fecha_fin DATE,

    CONSTRAINT chk_staff_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),

    CONSTRAINT uq_staff_asignacion UNIQUE (usuario_club_rol_id, categoria_deportiva_id, temporada_id)

);



-- Comprueba que el usuario, la categoria deportiva y la temporada pertenezcan al mismo club.

CREATE OR REPLACE FUNCTION validar_asignacion_staff_club()

RETURNS TRIGGER AS $$

DECLARE

    v_club_usuario BIGINT;

    v_club_temporada BIGINT;

    v_club_categoria BIGINT;

BEGIN

    SELECT uc.club_id INTO v_club_usuario

    FROM usuario_club_rol ucr

    JOIN usuario_club uc ON uc.id = ucr.usuario_club_id

    WHERE ucr.id = NEW.usuario_club_rol_id;



    SELECT club_id INTO v_club_temporada

    FROM temporada WHERE id = NEW.temporada_id;



    SELECT d.club_id INTO v_club_categoria

    FROM categoria_deportiva cd

    JOIN nivel_deportivo nd ON nd.id = cd.nivel_deportivo_id

    JOIN disciplina d ON d.id = nd.disciplina_id

    WHERE cd.id = NEW.categoria_deportiva_id;



    IF v_club_usuario IS NULL OR v_club_temporada IS NULL OR v_club_categoria IS NULL

       OR v_club_usuario <> v_club_temporada OR v_club_usuario <> v_club_categoria THEN

        RAISE EXCEPTION 'La asignacion del staff, la categoria y la temporada deben pertenecer al mismo club';

    END IF;

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_validar_asignacion_staff_club

BEFORE INSERT OR UPDATE ON asignacion_staff

FOR EACH ROW EXECUTE FUNCTION validar_asignacion_staff_club();



-- ============================================================

-- CONFIGURACION Y GENERACION DE CUOTAS

-- ============================================================

CREATE TABLE configuracion_cuota (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL REFERENCES club(id),

    tipo_cuota VARCHAR(20) NOT NULL,

    categoria_social_id BIGINT,

    disciplina_id BIGINT,

    nivel_deportivo_id BIGINT,

    importe NUMERIC(12,2) NOT NULL,

    vigente_desde DATE NOT NULL,

    vigente_hasta DATE,

    CONSTRAINT fk_config_cuota_categoria FOREIGN KEY (categoria_social_id, club_id) REFERENCES categoria_social(id, club_id),

    CONSTRAINT fk_config_cuota_disciplina FOREIGN KEY (disciplina_id, club_id) REFERENCES disciplina(id, club_id),

    CONSTRAINT fk_config_cuota_nivel FOREIGN KEY (nivel_deportivo_id, disciplina_id) REFERENCES nivel_deportivo(id, disciplina_id),

    CONSTRAINT chk_config_cuota_tipo CHECK (tipo_cuota IN ('SOCIAL', 'DEPORTIVA')),

    CONSTRAINT chk_config_cuota_importe CHECK (importe >= 0),

    CONSTRAINT chk_config_cuota_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),

    CONSTRAINT chk_config_cuota_referencia CHECK (

        (tipo_cuota = 'SOCIAL' AND categoria_social_id IS NOT NULL AND disciplina_id IS NULL AND nivel_deportivo_id IS NULL)

        OR

        (tipo_cuota = 'DEPORTIVA' AND categoria_social_id IS NULL AND disciplina_id IS NOT NULL AND nivel_deportivo_id IS NOT NULL)

    )

);



CREATE TABLE cuota_generada (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    tipo_cuota VARCHAR(20) NOT NULL,

    socio_id BIGINT,

    grupo_familiar_id BIGINT,

    inscripcion_deportiva_id BIGINT,

    responsable_pago_socio_id BIGINT NOT NULL,

    anio INTEGER NOT NULL,

    mes INTEGER NOT NULL,

    importe_base NUMERIC(12,2) NOT NULL,

    descuento NUMERIC(12,2) NOT NULL DEFAULT 0,

    recargo NUMERIC(12,2) NOT NULL DEFAULT 0,

    importe_total NUMERIC(12,2) NOT NULL,

    fecha_vencimiento DATE NOT NULL,

    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',

    fecha_generacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cuota_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT fk_cuota_socio FOREIGN KEY (socio_id, club_id) REFERENCES socio(id, club_id),

    CONSTRAINT fk_cuota_grupo FOREIGN KEY (grupo_familiar_id, club_id) REFERENCES grupo_familiar(id, club_id),

    CONSTRAINT fk_cuota_responsable FOREIGN KEY (responsable_pago_socio_id, club_id) REFERENCES socio(id, club_id),

    CONSTRAINT fk_cuota_inscripcion_jugador FOREIGN KEY (inscripcion_deportiva_id, club_id, socio_id) REFERENCES inscripcion_deportiva(id, club_id, socio_id),

    CONSTRAINT chk_cuota_tipo CHECK (tipo_cuota IN ('SOCIAL', 'DEPORTIVA')),

    CONSTRAINT chk_cuota_periodo CHECK (anio >= 2000 AND mes BETWEEN 1 AND 12),

    CONSTRAINT chk_cuota_importes CHECK (importe_base >= 0 AND descuento >= 0 AND descuento <= importe_base AND recargo >= 0 AND importe_total >= 0 AND importe_total = importe_base - descuento + recargo),

    CONSTRAINT chk_cuota_estado CHECK (estado IN ('PENDIENTE', 'VENCIDA', 'PAGADA', 'ANULADA')),

    CONSTRAINT chk_cuota_relaciones CHECK (

        (tipo_cuota = 'SOCIAL' AND ((socio_id IS NOT NULL AND grupo_familiar_id IS NULL AND inscripcion_deportiva_id IS NULL)

          OR (socio_id IS NULL AND grupo_familiar_id IS NOT NULL AND inscripcion_deportiva_id IS NULL)))

        OR

        (tipo_cuota = 'DEPORTIVA' AND socio_id IS NOT NULL AND grupo_familiar_id IS NULL AND inscripcion_deportiva_id IS NOT NULL)

    ),

    CONSTRAINT uq_cuota_id_club UNIQUE (id, club_id)

);



CREATE OR REPLACE FUNCTION validar_responsable_cuota()

RETURNS TRIGGER AS $$

DECLARE

    v_grupo_familiar_id BIGINT;

    v_titular_socio_id BIGINT;

    v_tipo_categoria VARCHAR(20);

BEGIN

    IF NEW.tipo_cuota = 'SOCIAL' THEN

        IF NEW.grupo_familiar_id IS NOT NULL THEN

            SELECT titular_socio_id INTO v_titular_socio_id

            FROM grupo_familiar

            WHERE id = NEW.grupo_familiar_id AND club_id = NEW.club_id;

            IF NOT FOUND OR v_titular_socio_id IS NULL THEN

                RAISE EXCEPTION 'El grupo familiar no existe en este club o no tiene titular';

            END IF;

            IF NEW.responsable_pago_socio_id <> v_titular_socio_id THEN

                RAISE EXCEPTION 'El responsable debe ser el titular del grupo familiar';

            END IF;

            SELECT cs.tipo INTO v_tipo_categoria

            FROM socio s JOIN categoria_social cs ON cs.id = s.categoria_social_id AND cs.club_id = s.club_id

            WHERE s.id = v_titular_socio_id AND s.club_id = NEW.club_id;

            IF v_tipo_categoria IS DISTINCT FROM 'FAMILIAR' THEN

                RAISE EXCEPTION 'La cuota social familiar requiere un titular con categoria familiar';

            END IF;

        ELSE

            IF NEW.socio_id IS NULL OR NEW.responsable_pago_socio_id <> NEW.socio_id THEN

                RAISE EXCEPTION 'En una cuota social individual, el responsable debe ser el socio';

            END IF;

            SELECT cs.tipo INTO v_tipo_categoria

            FROM socio s JOIN categoria_social cs ON cs.id = s.categoria_social_id AND cs.club_id = s.club_id

            WHERE s.id = NEW.socio_id AND s.club_id = NEW.club_id;

            IF v_tipo_categoria IS DISTINCT FROM 'INDIVIDUAL' THEN

                RAISE EXCEPTION 'La cuota social individual requiere categoria individual';

            END IF;

        END IF;

    ELSIF NEW.tipo_cuota = 'DEPORTIVA' THEN

        SELECT grupo_familiar_id INTO v_grupo_familiar_id

        FROM socio WHERE id = NEW.socio_id AND club_id = NEW.club_id;

        IF NOT FOUND THEN

            RAISE EXCEPTION 'El socio no existe en este club';

        END IF;

        IF v_grupo_familiar_id IS NULL THEN

            IF NEW.responsable_pago_socio_id <> NEW.socio_id THEN

                RAISE EXCEPTION 'El responsable debe ser el propio jugador';

            END IF;

        ELSE

            SELECT titular_socio_id INTO v_titular_socio_id

            FROM grupo_familiar WHERE id = v_grupo_familiar_id AND club_id = NEW.club_id;

            IF NOT FOUND OR v_titular_socio_id IS NULL THEN

                RAISE EXCEPTION 'El grupo familiar del socio no existe o no tiene titular';

            END IF;

            IF NEW.responsable_pago_socio_id <> v_titular_socio_id THEN

                RAISE EXCEPTION 'El responsable debe ser el titular del grupo familiar';

            END IF;

        END IF;

    END IF;

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_validar_responsable_cuota

BEFORE INSERT OR UPDATE ON cuota_generada

FOR EACH ROW EXECUTE FUNCTION validar_responsable_cuota();



CREATE UNIQUE INDEX uq_cuota_social_socio_periodo

ON cuota_generada (socio_id, anio, mes)

WHERE tipo_cuota = 'SOCIAL' AND socio_id IS NOT NULL AND estado <> 'ANULADA';



CREATE UNIQUE INDEX uq_cuota_social_grupo_periodo

ON cuota_generada (grupo_familiar_id, anio, mes)

WHERE tipo_cuota = 'SOCIAL' AND grupo_familiar_id IS NOT NULL AND estado <> 'ANULADA';



CREATE UNIQUE INDEX uq_cuota_deportiva_periodo

ON cuota_generada (inscripcion_deportiva_id, anio, mes)

WHERE tipo_cuota = 'DEPORTIVA' AND estado <> 'ANULADA';



-- ============================================================

-- PAGOS

-- ============================================================

CREATE TABLE pago (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    responsable_pago_socio_id BIGINT NOT NULL,

    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    monto_total NUMERIC(12,2) NOT NULL,

    medio_pago VARCHAR(30) NOT NULL,

    referencia VARCHAR(150),

    CONSTRAINT fk_pago_club FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT fk_pago_responsable FOREIGN KEY (responsable_pago_socio_id, club_id) REFERENCES socio(id, club_id),

    CONSTRAINT chk_pago_monto CHECK (monto_total > 0),

    CONSTRAINT uq_pago_id_club UNIQUE (id, club_id)

);



CREATE TABLE pago_detalle (

    id BIGSERIAL PRIMARY KEY,

    club_id BIGINT NOT NULL,

    pago_id BIGINT NOT NULL,

    cuota_generada_id BIGINT NOT NULL,

    importe_aplicado NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_detalle_pago FOREIGN KEY (pago_id, club_id) REFERENCES pago(id, club_id),

    CONSTRAINT fk_detalle_cuota_club FOREIGN KEY (cuota_generada_id, club_id) REFERENCES cuota_generada(id, club_id),

    CONSTRAINT chk_detalle_importe CHECK (importe_aplicado > 0),

    CONSTRAINT uq_detalle_cuota UNIQUE (cuota_generada_id)

);



-- Cada detalle debe cancelar una cuota completa y estar a cargo del mismo responsable del pago.

-- El bloqueo de la cuota evita dos intentos simultaneos de cobrarla.

CREATE OR REPLACE FUNCTION validar_detalle_pago()

RETURNS TRIGGER AS $$

DECLARE

    v_estado_cuota VARCHAR(20);

    v_importe_cuota NUMERIC(12,2);

    v_responsable_cuota BIGINT;

    v_responsable_pago BIGINT;

BEGIN

    SELECT estado, importe_total, responsable_pago_socio_id

      INTO v_estado_cuota, v_importe_cuota, v_responsable_cuota

    FROM cuota_generada

    WHERE id = NEW.cuota_generada_id AND club_id = NEW.club_id

    FOR UPDATE;



    IF NOT FOUND THEN

        RAISE EXCEPTION 'La cuota no existe en el club indicado';

    END IF;



    SELECT responsable_pago_socio_id INTO v_responsable_pago

    FROM pago WHERE id = NEW.pago_id AND club_id = NEW.club_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION 'El pago no existe en el club indicado';

    END IF;



    IF v_estado_cuota NOT IN ('PENDIENTE', 'VENCIDA') THEN

        RAISE EXCEPTION 'Solo se pueden pagar cuotas pendientes o vencidas';

    END IF;



    IF NEW.importe_aplicado <> v_importe_cuota THEN

        RAISE EXCEPTION 'La cuota debe pagarse completa. Importe esperado: %', v_importe_cuota;

    END IF;



    IF v_responsable_pago <> v_responsable_cuota THEN

        RAISE EXCEPTION 'El responsable del pago no coincide con el responsable de la cuota';

    END IF;



    RETURN NEW;

END;

$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_validar_detalle_pago

BEFORE INSERT ON pago_detalle

FOR EACH ROW EXECUTE FUNCTION validar_detalle_pago();



-- Al registrar el detalle, la cuota queda pagada. Si la transaccion falla, se revierte tambien este cambio.

CREATE OR REPLACE FUNCTION marcar_cuota_pagada()

RETURNS TRIGGER AS $$

BEGIN

    UPDATE cuota_generada

       SET estado = 'PAGADA'

     WHERE id = NEW.cuota_generada_id

       AND club_id = NEW.club_id;

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_marcar_cuota_pagada

AFTER INSERT ON pago_detalle

FOR EACH ROW EXECUTE FUNCTION marcar_cuota_pagada();



-- La suma de los detalles debe coincidir con el total del comprobante al confirmar la transaccion.

CREATE OR REPLACE FUNCTION validar_total_pago()

RETURNS TRIGGER AS $$

DECLARE

    v_pago_id BIGINT;

    v_monto_pago NUMERIC(12,2);

    v_suma_detalles NUMERIC(12,2);

BEGIN

    IF TG_TABLE_NAME = 'pago' THEN

        v_pago_id := NEW.id;

    ELSE

        v_pago_id := NEW.pago_id;

    END IF;



    SELECT monto_total INTO v_monto_pago

    FROM pago WHERE id = v_pago_id;



    IF NOT FOUND THEN

        RETURN NULL;

    END IF;



    SELECT COALESCE(SUM(importe_aplicado), 0) INTO v_suma_detalles

    FROM pago_detalle WHERE pago_id = v_pago_id;



    IF v_suma_detalles <> v_monto_pago THEN

        RAISE EXCEPTION 'El total del pago (%) debe coincidir con la suma de sus detalles (%)', v_monto_pago, v_suma_detalles;

    END IF;



    RETURN NULL;

END;

$$ LANGUAGE plpgsql;



CREATE CONSTRAINT TRIGGER trg_validar_total_pago

AFTER INSERT OR UPDATE ON pago

DEFERRABLE INITIALLY DEFERRED

FOR EACH ROW EXECUTE FUNCTION validar_total_pago();



CREATE CONSTRAINT TRIGGER trg_validar_total_pago_detalle

AFTER INSERT ON pago_detalle

DEFERRABLE INITIALLY DEFERRED

FOR EACH ROW EXECUTE FUNCTION validar_total_pago();



-- Los detalles son parte del historial contable: no se editan ni borran directamente.

-- Una futura anulacion de pagos debera registrarse mediante un flujo explicito de anulacion/reversion.

CREATE OR REPLACE FUNCTION impedir_modificacion_detalle_pago()

RETURNS TRIGGER AS $$

BEGIN

    RAISE EXCEPTION 'Los detalles de pago no se pueden modificar ni borrar directamente';

END;

$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_impedir_modificacion_detalle_pago

BEFORE UPDATE OR DELETE ON pago_detalle

FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_detalle_pago();



-- Impide alterar datos que podrian romper la correspondencia entre pago y cuotas.

-- Se permite corregir el medio de pago o la referencia, pero no el responsable, club ni total.

CREATE OR REPLACE FUNCTION proteger_datos_esenciales_pago()

RETURNS TRIGGER AS $$

BEGIN

    IF NEW.club_id IS DISTINCT FROM OLD.club_id

       OR NEW.responsable_pago_socio_id IS DISTINCT FROM OLD.responsable_pago_socio_id

       OR NEW.monto_total IS DISTINCT FROM OLD.monto_total THEN

        RAISE EXCEPTION 'No se puede cambiar el club, responsable o importe de un pago ya registrado';

    END IF;

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_proteger_datos_esenciales_pago

BEFORE UPDATE ON pago

FOR EACH ROW EXECUTE FUNCTION proteger_datos_esenciales_pago();



-- ============================================================

-- CATALOGO DE PERMISOS Y ASIGNACION A ROLES

-- ============================================================

INSERT INTO permiso (codigo, nombre, descripcion) VALUES

('socio.consultar', 'Consultar socios', 'Consultar información de socios'),

('socio.crear', 'Crear socios', 'Dar de alta socios'),

('socio.editar', 'Editar socios', 'Modificar datos de socios'),

('socio.baja', 'Dar de baja socios', 'Registrar la baja de un socio'),

('inscripcion.consultar', 'Consultar inscripciones', 'Consultar inscripciones deportivas'),

('inscripcion.gestionar', 'Gestionar inscripciones', 'Crear y modificar inscripciones'),

('asistencia.consultar', 'Consultar asistencias', 'Consultar registros de asistencia'),

('asistencia.registrar', 'Registrar asistencias', 'Cargar y corregir asistencias'),

('cuota.consultar', 'Consultar cuotas', 'Consultar cuotas y vencimientos'),

('cuota.gestionar', 'Gestionar cuotas', 'Administrar cuotas e importes'),

('cuota.social.estado.consultar', 'Consultar estado de cuota social', 'Consultar el estado de las cuotas sociales'),

('cuota.deportiva.estado.consultar', 'Consultar estado de cuota deportiva', 'Consultar el estado de las cuotas deportivas'),

('deuda.estado.consultar', 'Consultar estado de deuda', 'Consultar si un jugador tiene deuda'),

('pago.consultar', 'Consultar pagos', 'Consultar pagos registrados'),

('pago.registrar', 'Registrar pagos', 'Registrar cobranzas'),

('cobertura.consultar', 'Consultar cobertura médica', 'Consultar la información habilitada sobre cobertura médica'),

('usuario.gestionar', 'Gestionar usuarios', 'Administrar accesos al club'),

('rol.gestionar', 'Gestionar roles', 'Administrar roles y sus permisos'),

('club.configurar', 'Configurar club', 'Modificar la configuración del club')

ON CONFLICT (codigo) DO UPDATE SET nombre = EXCLUDED.nombre, descripcion = EXCLUDED.descripcion;



INSERT INTO rol (club_id, nombre, descripcion)

SELECT c.id, r.nombre, r.descripcion

FROM club c

CROSS JOIN (VALUES

    ('Administrador', 'Administración general del club'),

    ('Secretaría', 'Gestión administrativa de socios e inscripciones'),

    ('Entrenador', 'Gestión deportiva de sus divisiones asignadas'),

    ('Manager de división', 'Gestión deportiva y administrativa de su división'),

    ('Socio', 'Acceso de autogestión a sus propios datos')

) AS r(nombre, descripcion)

ON CONFLICT (club_id, nombre) DO NOTHING;



DELETE FROM rol_permiso

WHERE rol_id IN (SELECT id FROM rol WHERE nombre IN ('Administrador', 'Secretaría', 'Entrenador', 'Manager de división', 'Socio'));



INSERT INTO rol_permiso (rol_id, permiso_id)

SELECT r.id, p.id

FROM rol r

JOIN (VALUES

    ('Administrador', 'socio.consultar'), ('Administrador', 'socio.crear'), ('Administrador', 'socio.editar'), ('Administrador', 'socio.baja'),

    ('Administrador', 'inscripcion.consultar'), ('Administrador', 'inscripcion.gestionar'), ('Administrador', 'cuota.consultar'), ('Administrador', 'cuota.gestionar'),

    ('Administrador', 'pago.consultar'), ('Administrador', 'usuario.gestionar'), ('Administrador', 'rol.gestionar'), ('Administrador', 'club.configurar'),

    ('Secretaría', 'socio.consultar'), ('Secretaría', 'socio.crear'), ('Secretaría', 'socio.editar'), ('Secretaría', 'socio.baja'),

    ('Secretaría', 'inscripcion.consultar'), ('Secretaría', 'inscripcion.gestionar'), ('Secretaría', 'cuota.consultar'), ('Secretaría', 'cuota.gestionar'),

    ('Secretaría', 'pago.consultar'), ('Secretaría', 'pago.registrar'),

    ('Entrenador', 'socio.consultar'), ('Entrenador', 'inscripcion.consultar'), ('Entrenador', 'asistencia.consultar'), ('Entrenador', 'asistencia.registrar'), ('Entrenador', 'deuda.estado.consultar'),

    ('Manager de división', 'socio.consultar'), ('Manager de división', 'inscripcion.consultar'), ('Manager de división', 'asistencia.consultar'), ('Manager de división', 'asistencia.registrar'),

    ('Manager de división', 'deuda.estado.consultar'), ('Manager de división', 'cuota.social.estado.consultar'), ('Manager de división', 'cuota.deportiva.estado.consultar'), ('Manager de división', 'cobertura.consultar'),

    ('Socio', 'socio.consultar'), ('Socio', 'socio.editar'), ('Socio', 'inscripcion.consultar'), ('Socio', 'cuota.consultar'), ('Socio', 'pago.consultar')

) AS asignacion(nombre_rol, codigo_permiso) ON TRUE

JOIN permiso p ON p.codigo = asignacion.codigo_permiso

WHERE r.nombre = asignacion.nombre_rol

ON CONFLICT (rol_id, permiso_id) DO NOTHING;
