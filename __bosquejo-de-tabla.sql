
-- tabla SOCIO

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

    CONSTRAINT fk_socio_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT uq_socio_id_club UNIQUE (id, club_id),
    CONSTRAINT uq_socio_club_dni UNIQUE (club_id, dni),

-- campo que permite saber a qué grupo pertenece cada integrante.
    ALTER TABLE socio
    ADD COLUMN grupo_familiar_id BIGINT;

    ALTER TABLE socio
    ADD CONSTRAINT fk_socio_grupo_familiar
        FOREIGN KEY (grupo_familiar_id, club_id)
        REFERENCES grupo_familiar(id, club_id);
);


-- tabla SEDE
CREATE TABLE sede (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(200),
    localidad VARCHAR(100),
    descripcion TEXT,

    CONSTRAINT fk_sede_club
        FOREIGN KEY (club_id)
        REFERENCES club(id)
);

-- tabla DEPORTE
CREATE TABLE deporte (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT
);

-- tabla DISCIPLINA
-- deporte: catálogo general de deportes.
-- disciplina: el deporte que un club ofrece concretamente.
CREATE TABLE disciplina (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    deporte_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,

    CONSTRAINT fk_disciplina_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT fk_disciplina_deporte
        FOREIGN KEY (deporte_id)
        REFERENCES deporte(id),

    CONSTRAINT uq_disciplina_club_deporte
        UNIQUE (club_id, deporte_id),

    CONSTRAINT uq_disciplina_id_club
        UNIQUE (id, club_id)
);



-- tabla CATEGORIA_SOCIAL
CREATE TABLE categoria_social (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,

    CONSTRAINT fk_categoria_social_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT uq_categoria_social_club_nombre
        UNIQUE (club_id, nombre)
);

-- tabla TEMPORADA
CREATE TABLE temporada (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    anio INTEGER NOT NULL,
    descripcion VARCHAR(150),

    CONSTRAINT fk_temporada_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT uq_temporada_club_anio UNIQUE (club_id, anio),
    CONSTRAINT uq_temporada_id_club UNIQUE (id, club_id)
);


-- tabla NIVEL_DEPORTIVO: En Tilcara, por ejemplo, Rugby tiene Infantil, Juvenil y Plantel Superior.
CREATE TABLE nivel_deportivo (
    id BIGSERIAL PRIMARY KEY,
    disciplina_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,

    CONSTRAINT fk_nivel_disciplina
        FOREIGN KEY (disciplina_id)
        REFERENCES disciplina(id),

    CONSTRAINT uq_nivel_disciplina_nombre UNIQUE (disciplina_id, nombre),
    CONSTRAINT uq_nivel_id_disciplina UNIQUE (id, disciplina_id)
);


-- tabla CATEGORIA_DEPORTIVA: En Tilcara, por ejemplo, Rugby tiene M7, M9, M11, M13, M15, M17 y Plantel Superior.
CREATE TABLE categoria_deportiva (
    id BIGSERIAL PRIMARY KEY,
    nivel_deportivo_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,

    CONSTRAINT fk_categoria_nivel
        FOREIGN KEY (nivel_deportivo_id)
        REFERENCES nivel_deportivo(id),

    CONSTRAINT uq_categoria_nivel_nombre
        UNIQUE (nivel_deportivo_id, nombre),

    CONSTRAINT uq_categoria_id_nivel
        UNIQUE (id, nivel_deportivo_id)
);



-- tabla INSCRIPCION_DEPORTIVA: Un socio puede inscribirse en varias disciplinas.
-- club_id permite verificar que el socio, la disciplina y la temporada sean del mismo club.
-- nivel_deportivo_id permite comprobar que la categoría elegida corresponda al nivel y a la disciplina de esa inscripción.
-- No duplicamos información sin propósito: esos campos permiten que PostgreSQL haga cumplir las reglas mediante claves foráneas compuestas.
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

    CONSTRAINT fk_inscripcion_socio_club
        FOREIGN KEY (socio_id, club_id)
        REFERENCES socio(id, club_id),

    CONSTRAINT fk_inscripcion_disciplina_club
        FOREIGN KEY (disciplina_id, club_id)
        REFERENCES disciplina(id, club_id),

    CONSTRAINT fk_inscripcion_temporada_club
        FOREIGN KEY (temporada_id, club_id)
        REFERENCES temporada(id, club_id),

    CONSTRAINT fk_inscripcion_nivel_disciplina
        FOREIGN KEY (nivel_deportivo_id, disciplina_id)
        REFERENCES nivel_deportivo(id, disciplina_id),

    CONSTRAINT fk_inscripcion_categoria_nivel
        FOREIGN KEY (categoria_deportiva_id, nivel_deportivo_id)
        REFERENCES categoria_deportiva(id, nivel_deportivo_id),

    CONSTRAINT chk_inscripcion_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        ),

    CONSTRAINT uq_inscripcion_socio_disciplina_temporada
        UNIQUE (socio_id, disciplina_id, temporada_id),

    CONSTRAINT uq_inscripcion_id_club
        UNIQUE (id, club_id)

    -- restricción única que nos permitirá relacionar la inscripción con su club y su socio
    ALTER TABLE inscripcion_deportiva
    ADD CONSTRAINT uq_inscripcion_id_club_socio
    UNIQUE (id, club_id, socio_id);


    ALTER TABLE inscripcion_deportiva
    ADD CONSTRAINT uq_inscripcion_id_club_socio
    UNIQUE (id, club_id, socio_id);

);




-- tabla ASISTENCIA: Un socio puede asistir a varias disciplinas y categorías deportivas.
CREATE TABLE asistencia (
    id BIGSERIAL PRIMARY KEY,
    inscripcion_deportiva_id BIGINT NOT NULL,
    fecha DATE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PRESENTE',
    condicion_deportiva VARCHAR(20) NOT NULL DEFAULT 'APTO',
    observacion TEXT,

    CONSTRAINT fk_asistencia_inscripcion
        FOREIGN KEY (inscripcion_deportiva_id)
        REFERENCES inscripcion_deportiva(id),

    CONSTRAINT chk_asistencia_estado
        CHECK (estado IN (
            'PRESENTE',
            'AUSENTE',
            'JUSTIFICADO'
        )),

    CONSTRAINT chk_asistencia_condicion
        CHECK (condicion_deportiva IN (
            'APTO',
            'LESIONADO'
        )),

    CONSTRAINT uq_asistencia_inscripcion_fecha
        UNIQUE (inscripcion_deportiva_id, fecha)
);

-- *************************************************************************
-- ******** ACA EMPIEZAN LAS TABLAS PARA ROLES, USUARIOS Y PERMISOS ********
-- *************************************************************************


-- Tabla USUARIO - La autenticación deberá realizarse con un mecanismo seguro de contraseñas en el backend; no se debe generar el hash manualmente ni guardar contraseñas en texto plano.
CREATE TABLE usuario (
    id BIGSERIAL PRIMARY KEY,
    nombre_usuario VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);



-- Tabla USUARIO_SOCIO -Esta relación permite que una misma cuenta consulte su información como socio en Tilcara y Rowing, sin duplicar la cuenta de acceso
-- ¿Qué garantizamos con esto?
--  Una cuenta puede vincularse con varios registros de socio.
--  Un registro de socio solo puede estar vinculado a una cuenta.
--  No se puede repetir el mismo vínculo.
-- Por ejemplo, tu cuenta podría estar vinculada al registro de socio de Tilcara y al de Rowing. Cada registro mantiene su propio club_id, así que los datos siguen separados.
CREATE TABLE usuario_socio (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    socio_id BIGINT NOT NULL,

    CONSTRAINT fk_usuario_socio_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(id),

    CONSTRAINT fk_usuario_socio_socio
        FOREIGN KEY (socio_id)
        REFERENCES socio(id),

    CONSTRAINT uq_usuario_socio
        UNIQUE (usuario_id, socio_id),

    CONSTRAINT uq_usuario_socio_registro
        UNIQUE (socio_id)
);



-- Tabla USUARIO_CLUB
CREATE TABLE usuario_club (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    club_id BIGINT NOT NULL,

    CONSTRAINT fk_usuario_club_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(id),

    CONSTRAINT fk_usuario_club_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

-- La restricción UNIQUE impide registrar dos veces el acceso del mismo usuario al mismo club.
    CONSTRAINT uq_usuario_club
        UNIQUE (usuario_id, club_id)
);


-- Tabla ROL
CREATE TABLE rol (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,

    CONSTRAINT fk_rol_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT uq_rol_club_nombre
        UNIQUE (club_id, nombre),

    CONSTRAINT uq_rol_id_club
        UNIQUE (id, club_id)
);


-- Tabla PERMISO
CREATE TABLE permiso (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
);



-- Tabla ROL_PERMISO
CREATE TABLE rol_permiso (
    id BIGSERIAL PRIMARY KEY,
    rol_id BIGINT NOT NULL,
    permiso_id BIGINT NOT NULL,

    CONSTRAINT fk_rol_permiso_rol
        FOREIGN KEY (rol_id)
        REFERENCES rol(id),

    CONSTRAINT fk_rol_permiso_permiso
        FOREIGN KEY (permiso_id)
        REFERENCES permiso(id),

    CONSTRAINT uq_rol_permiso
        UNIQUE (rol_id, permiso_id)
);



-- Tabla AUDITORIA: Esta tabla registra las acciones realizadas por los usuarios en el sistema, permitiendo un seguimiento de cambios y auditoría de eventos importantes.
CREATE TABLE auditoria (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    usuario_id BIGINT NOT NULL,
    entidad VARCHAR(100) NOT NULL,
    registro_id BIGINT NOT NULL,
    accion VARCHAR(20) NOT NULL,
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    datos_anteriores JSONB,
    datos_nuevos JSONB,

    CONSTRAINT fk_auditoria_club
        FOREIGN KEY (club_id) REFERENCES club(id),

    CONSTRAINT fk_auditoria_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario(id),

    CONSTRAINT chk_auditoria_accion
        CHECK (accion IN (
            'ALTA',
            'MODIFICACION',
            'BAJA'
        ))
);



-- Tabla ASIGNACION_STAFF: Esta tabla registra la asignación de usuarios con roles específicos a categorías deportivas durante una temporada determinada. Permite gestionar el personal del club y sus responsabilidades en relación con las actividades deportivas.
CREATE TABLE asignacion_staff (
    id BIGSERIAL PRIMARY KEY,
    usuario_club_rol_id BIGINT NOT NULL,
    categoria_deportiva_id BIGINT NOT NULL,
    temporada_id BIGINT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,

    CONSTRAINT fk_staff_usuario_club_rol
        FOREIGN KEY (usuario_club_rol_id)
        REFERENCES usuario_club_rol(id),

    CONSTRAINT fk_staff_categoria
        FOREIGN KEY (categoria_deportiva_id)
        REFERENCES categoria_deportiva(id),

    CONSTRAINT fk_staff_temporada
        FOREIGN KEY (temporada_id)
        REFERENCES temporada(id),

    CONSTRAINT chk_staff_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        ),

    CONSTRAINT uq_staff_asignacion
        UNIQUE (
            usuario_club_rol_id,
            categoria_deportiva_id,
            temporada_id
        )
);


-- Tabla GRUPO_FAMILIAR: Esta tabla permite registrar grupos familiares dentro de un club, asociando un titular socio con su grupo familiar. Cada grupo familiar está vinculado a un club específico y tiene un titular que es un socio del club.
-- ¿Por qué usamos estas restricciones?
-- - club_id: impide vincular el grupo con un socio de otro club.
-- - titular_socio_id: identifica quién concentra la cobranza.
-- - UNIQUE (titular_socio_id): evita que un mismo socio sea titular de varios grupos familiares.

CREATE TABLE grupo_familiar (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    titular_socio_id BIGINT NOT NULL,

    CONSTRAINT fk_grupo_familiar_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT fk_grupo_familiar_titular
        FOREIGN KEY (titular_socio_id, club_id)
        REFERENCES socio(id, club_id),

    CONSTRAINT uq_grupo_familiar_id_club
        UNIQUE (id, club_id),

    CONSTRAINT uq_grupo_familiar_titular
        UNIQUE (titular_socio_id)
);



-- Tabla CONFIGURACION_CUOTA: Esta tabla permite definir las cuotas que un club cobra a sus socios, diferenciando entre cuotas sociales y deportivas. Cada cuota está asociada a un club y puede estar vinculada a una categoría social o a una disciplina y nivel deportivo específicos.
CREATE TABLE configuracion_cuota (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    tipo_cuota VARCHAR(20) NOT NULL,

    categoria_social_id BIGINT,
    disciplina_id BIGINT,
    nivel_deportivo_id BIGINT,

    importe NUMERIC(12,2) NOT NULL,
    vigente_desde DATE NOT NULL,
    vigente_hasta DATE,

    CONSTRAINT fk_config_cuota_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT fk_config_cuota_categoria
        FOREIGN KEY (categoria_social_id)
        REFERENCES categoria_social(id),

    CONSTRAINT fk_config_cuota_disciplina
        FOREIGN KEY (disciplina_id)
        REFERENCES disciplina(id),

    CONSTRAINT fk_config_cuota_nivel
        FOREIGN KEY (nivel_deportivo_id)
        REFERENCES nivel_deportivo(id),

    CONSTRAINT chk_config_cuota_tipo
        CHECK (tipo_cuota IN ('SOCIAL', 'DEPORTIVA')),

    CONSTRAINT chk_config_cuota_importe
        CHECK (importe >= 0),

    CONSTRAINT chk_config_cuota_vigencia
        CHECK (
            vigente_hasta IS NULL
            OR vigente_hasta >= vigente_desde
        ),

    CONSTRAINT chk_config_cuota_referencia
        CHECK (
            (tipo_cuota = 'SOCIAL'
                AND categoria_social_id IS NOT NULL
                AND disciplina_id IS NULL
                AND nivel_deportivo_id IS NULL)
            OR
            (tipo_cuota = 'DEPORTIVA'
                AND categoria_social_id IS NULL
                AND disciplina_id IS NOT NULL
                AND nivel_deportivo_id IS NOT NULL)
        )
);



-- Tabla CUOTA_GENERADA: Esta tabla registra las cuotas generadas para los socios, ya sean sociales o deportivas. Cada cuota está asociada a un club y puede estar vinculada a un socio, un grupo familiar o una inscripción deportiva específica. Además, se registran los importes, descuentos, recargos y el estado de la cuota.

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

    CONSTRAINT fk_cuota_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT fk_cuota_socio
        FOREIGN KEY (socio_id, club_id)
        REFERENCES socio(id, club_id),

    CONSTRAINT fk_cuota_grupo
        FOREIGN KEY (grupo_familiar_id, club_id)
        REFERENCES grupo_familiar(id, club_id),

    CONSTRAINT fk_cuota_responsable
        FOREIGN KEY (responsable_pago_socio_id, club_id)
        REFERENCES socio(id, club_id),

    CONSTRAINT chk_cuota_tipo
        CHECK (tipo_cuota IN ('SOCIAL', 'DEPORTIVA')),

    CONSTRAINT chk_cuota_periodo
        CHECK (anio >= 2000 AND mes BETWEEN 1 AND 12),

    CONSTRAINT chk_cuota_importes
        CHECK (
            importe_base >= 0
            AND descuento >= 0
            AND recargo >= 0
            AND importe_total >= 0
        ),

    CONSTRAINT chk_cuota_estado
        CHECK (
            estado IN (
                'PENDIENTE',
                'VENCIDA',
                'PAGADA',
                'ANULADA'
            )
        ),

    CONSTRAINT chk_cuota_relaciones
        CHECK (
            (
                tipo_cuota = 'SOCIAL'
                AND (
                    (
                        socio_id IS NOT NULL
                        AND grupo_familiar_id IS NULL
                        AND inscripcion_deportiva_id IS NULL
                    )
                    OR
                    (
                        socio_id IS NULL
                        AND grupo_familiar_id IS NOT NULL
                        AND inscripcion_deportiva_id IS NULL
                    )
                )
            )
            OR
            (
                tipo_cuota = 'DEPORTIVA'
                AND socio_id IS NOT NULL
                AND grupo_familiar_id IS NULL
                AND inscripcion_deportiva_id IS NOT NULL
            )
        ),

    CONSTRAINT uq_cuota_id_club
        UNIQUE (id, club_id)


    -- Una cuota social individual por socio y mes
    CREATE UNIQUE INDEX uq_cuota_social_socio_periodo
    ON cuota_generada (socio_id, anio, mes)
    WHERE tipo_cuota = 'SOCIAL'
        AND socio_id IS NOT NULL;

  -- Una cuota social por grupo familiar y mes
    CREATE UNIQUE INDEX uq_cuota_social_grupo_periodo
    ON cuota_generada (grupo_familiar_id, anio, mes)
    WHERE tipo_cuota = 'SOCIAL'
    AND grupo_familiar_id IS NOT NULL;

  -- Una cuota por inscripción deportiva y mes
    CREATE UNIQUE INDEX uq_cuota_deportiva_periodo
    ON cuota_generada (
        inscripcion_deportiva_id,
        anio,
        mes
    )
    WHERE tipo_cuota = 'DEPORTIVA';

);



-- Tabla PAGO: Esta tabla registra los pagos realizados por los socios, vinculándolos a un club y a un responsable de pago. Se registran la fecha del pago, el monto total, el medio de pago utilizado y una referencia opcional para identificar la transacción.
CREATE TABLE pago (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    responsable_pago_socio_id BIGINT NOT NULL,

    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_total NUMERIC(12,2) NOT NULL,
    medio_pago VARCHAR(30) NOT NULL,
    referencia VARCHAR(150),

    CONSTRAINT fk_pago_club
        FOREIGN KEY (club_id)
        REFERENCES club(id),

    CONSTRAINT fk_pago_responsable
        FOREIGN KEY (responsable_pago_socio_id, club_id)
        REFERENCES socio(id, club_id),

    CONSTRAINT chk_pago_monto
        CHECK (monto_total > 0),

    CONSTRAINT uq_pago_id_club
        UNIQUE (id, club_id)
);



-- Tabla PAGO_DETALLE: Esta tabla registra los detalles de los pagos realizados, asociando cada pago a una cuota generada específica. Se registran el importe aplicado a cada cuota y se establecen restricciones para garantizar la integridad de los datos.
CREATE TABLE pago_detalle (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    pago_id BIGINT NOT NULL,
    cuota_generada_id BIGINT NOT NULL,
    importe_aplicado NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_detalle_pago
        FOREIGN KEY (pago_id, club_id)
        REFERENCES pago(id, club_id),

    CONSTRAINT fk_detalle_cuota
        FOREIGN KEY (cuota_generada_id)
        REFERENCES cuota_generada(id),

    CONSTRAINT chk_detalle_importe
        CHECK (importe_aplicado > 0),

    CONSTRAINT uq_detalle_cuota
        UNIQUE (cuota_generada_id)
);



-- - La regla será:
-- - Cuota social individual: responsable = socio.
-- - Cuota social familiar: responsable = titular del grupo.
-- - Cuota deportiva: responsable = jugador si no pertenece a un grupo; de lo contrario, titular del grupo.

CREATE OR REPLACE FUNCTION validar_responsable_cuota()
RETURNS TRIGGER AS $$
DECLARE
    v_grupo_familiar_id BIGINT;
    v_titular_socio_id BIGINT;
BEGIN
    IF NEW.tipo_cuota = 'SOCIAL' THEN

        IF NEW.grupo_familiar_id IS NOT NULL THEN

            SELECT titular_socio_id
            INTO v_titular_socio_id
            FROM grupo_familiar
            WHERE id = NEW.grupo_familiar_id
              AND club_id = NEW.club_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'El grupo familiar no existe en este club';
            END IF;

            IF NEW.responsable_pago_socio_id
               <> v_titular_socio_id THEN
                RAISE EXCEPTION
                    'El responsable debe ser el titular del grupo familiar';
            END IF;

        ELSE

            IF NEW.responsable_pago_socio_id
               <> NEW.socio_id THEN
                RAISE EXCEPTION
                    'En una cuota social individual, el responsable debe ser el socio';
            END IF;

        END IF;

    ELSIF NEW.tipo_cuota = 'DEPORTIVA' THEN

        SELECT grupo_familiar_id
        INTO v_grupo_familiar_id
        FROM socio
        WHERE id = NEW.socio_id
          AND club_id = NEW.club_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'El socio no existe en este club';
        END IF;

        IF v_grupo_familiar_id IS NULL THEN

            IF NEW.responsable_pago_socio_id
               <> NEW.socio_id THEN
                RAISE EXCEPTION
                    'El responsable debe ser el propio jugador';
            END IF;

        ELSE

            SELECT titular_socio_id
            INTO v_titular_socio_id
            FROM grupo_familiar
            WHERE id = v_grupo_familiar_id
              AND club_id = NEW.club_id;

            IF NEW.responsable_pago_socio_id
               <> v_titular_socio_id THEN
                RAISE EXCEPTION
                    'El responsable debe ser el titular del grupo familiar';
            END IF;

        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Activamos la validación
CREATE TRIGGER trg_validar_responsable_cuota
BEFORE INSERT OR UPDATE ON cuota_generada
FOR EACH ROW
EXECUTE FUNCTION validar_responsable_cuota();


-- Evitar cuotas duplicadas
CREATE UNIQUE INDEX uq_cuota_social_socio_periodo
ON cuota_generada (socio_id, anio, mes)
WHERE tipo_cuota = 'SOCIAL'
  AND socio_id IS NOT NULL
  AND estado <> 'ANULADA';


CREATE UNIQUE INDEX uq_cuota_social_grupo_periodo
ON cuota_generada (grupo_familiar_id, anio, mes)
WHERE tipo_cuota = 'SOCIAL'
  AND grupo_familiar_id IS NOT NULL
  AND estado <> 'ANULADA';


CREATE UNIQUE INDEX uq_cuota_deportiva_periodo
ON cuota_generada (inscripcion_deportiva_id, anio, mes)
WHERE tipo_cuota = 'DEPORTIVA'
  AND estado <> 'ANULADA';



-- *************************************************************************
-- ********                        PERMISOS                         ********
-- *************************************************************************


-- =========================================================
-- 1. CATALOGO DE PERMISOS
-- =========================================================

INSERT INTO permiso (codigo, nombre, descripcion) VALUES

-- Socios
('socio.consultar', 'Consultar socios',
 'Consultar información de socios'),
('socio.crear', 'Crear socios',
 'Dar de alta socios'),
('socio.editar', 'Editar socios',
 'Modificar datos de socios'),
('socio.baja', 'Dar de baja socios',
 'Registrar la baja de un socio'),

-- Inscripciones deportivas
('inscripcion.consultar', 'Consultar inscripciones',
 'Consultar inscripciones deportivas'),
('inscripcion.gestionar', 'Gestionar inscripciones',
 'Crear y modificar inscripciones'),

-- Asistencias
('asistencia.consultar', 'Consultar asistencias',
 'Consultar registros de asistencia'),
('asistencia.registrar', 'Registrar asistencias',
 'Cargar y corregir asistencias'),

-- Cuotas
('cuota.consultar', 'Consultar cuotas',
 'Consultar cuotas y vencimientos'),
('cuota.gestionar', 'Gestionar cuotas',
 'Administrar cuotas e importes'),
('cuota.social.estado.consultar', 'Consultar estado de cuota social',
 'Consultar el estado de las cuotas sociales'),
('cuota.deportiva.estado.consultar', 'Consultar estado de cuota deportiva',
 'Consultar el estado de las cuotas deportivas'),
('deuda.estado.consultar', 'Consultar estado de deuda',
 'Consultar si un jugador tiene deuda'),

-- Pagos
('pago.consultar', 'Consultar pagos',
 'Consultar pagos registrados'),
('pago.registrar', 'Registrar pagos',
 'Registrar cobranzas'),

-- Cobertura médica
('cobertura.consultar', 'Consultar cobertura médica',
 'Consultar la información habilitada sobre cobertura médica'),

-- Usuarios, roles y configuración
('usuario.gestionar', 'Gestionar usuarios',
 'Administrar accesos al club'),
('rol.gestionar', 'Gestionar roles',
 'Administrar roles y sus permisos'),
('club.configurar', 'Configurar club',
 'Modificar la configuración del club')

ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion;


-- =========================================================
-- 2. CREAR LOS ROLES PARA CADA CLUB
-- =========================================================

INSERT INTO rol (club_id, nombre, descripcion)
SELECT c.id, r.nombre, r.descripcion
FROM club c
CROSS JOIN (
    VALUES
        ('Administrador',
         'Administración general del club'),
        ('Secretaría',
         'Gestión administrativa de socios e inscripciones'),
        ('Entrenador',
         'Gestión deportiva de sus divisiones asignadas'),
        ('Manager de división',
         'Gestión deportiva y administrativa de su división'),
        ('Socio',
         'Acceso de autogestión a sus propios datos')
) AS r(nombre, descripcion)

ON CONFLICT (club_id, nombre) DO NOTHING;


-- =========================================================
-- 3. LIMPIAR ASIGNACIONES ANTERIORES DE ESTOS ROLES
-- =========================================================

DELETE FROM rol_permiso
WHERE rol_id IN (
    SELECT id
    FROM rol
    WHERE nombre IN (
        'Administrador',
        'Secretaría',
        'Entrenador',
        'Manager de división',
        'Socio'
    )
);


-- =========================================================
-- 4. ASIGNAR PERMISOS A CADA ROL
-- =========================================================

INSERT INTO rol_permiso (rol_id, permiso_id)

SELECT r.id, p.id
FROM rol r
JOIN (
    VALUES

    -- ADMINISTRADOR
    ('Administrador', 'socio.consultar'),
    ('Administrador', 'socio.crear'),
    ('Administrador', 'socio.editar'),
    ('Administrador', 'socio.baja'),
    ('Administrador', 'inscripcion.consultar'),
    ('Administrador', 'inscripcion.gestionar'),
    ('Administrador', 'cuota.consultar'),
    ('Administrador', 'cuota.gestionar'),
    ('Administrador', 'pago.consultar'),
    ('Administrador', 'usuario.gestionar'),
    ('Administrador', 'rol.gestionar'),
    ('Administrador', 'club.configurar'),

    -- SECRETARIA
    ('Secretaría', 'socio.consultar'),
    ('Secretaría', 'socio.crear'),
    ('Secretaría', 'socio.editar'),
    ('Secretaría', 'socio.baja'),
    ('Secretaría', 'inscripcion.consultar'),
    ('Secretaría', 'inscripcion.gestionar'),
    ('Secretaría', 'cuota.consultar'),
    ('Secretaría', 'cuota.gestionar'),
    ('Secretaría', 'pago.consultar'),
    ('Secretaría', 'pago.registrar'),

    -- ENTRENADOR
    ('Entrenador', 'socio.consultar'),
    ('Entrenador', 'inscripcion.consultar'),
    ('Entrenador', 'asistencia.consultar'),
    ('Entrenador', 'asistencia.registrar'),
    ('Entrenador', 'deuda.estado.consultar'),

    -- MANAGER DE DIVISION
    ('Manager de división', 'socio.consultar'),
    ('Manager de división', 'inscripcion.consultar'),
    ('Manager de división', 'asistencia.consultar'),
    ('Manager de división', 'asistencia.registrar'),
    ('Manager de división', 'deuda.estado.consultar'),
    ('Manager de división', 'cuota.social.estado.consultar'),
    ('Manager de división', 'cuota.deportiva.estado.consultar'),
    ('Manager de división', 'cobertura.consultar'),

    -- SOCIO
    ('Socio', 'socio.consultar'),
    ('Socio', 'socio.editar'),
    ('Socio', 'inscripcion.consultar'),
    ('Socio', 'cuota.consultar'),
    ('Socio', 'pago.consultar')

) AS asignacion(nombre_rol, codigo_permiso)
    ON TRUE

JOIN permiso p
    ON p.codigo = asignacion.codigo_permiso

WHERE r.nombre = asignacion.nombre_rol

ON CONFLICT (rol_id, permiso_id) DO NOTHING;

