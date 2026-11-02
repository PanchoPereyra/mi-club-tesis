-- MIGRACION INCREMENTAL CORREGIDA: anulacion segura de pagos
-- Destino: estructura REAL inspeccionada en gestion_club (PostgreSQL).
--
-- IMPORTANTE:
-- 1) Revisar/respaldar la base antes de ejecutar.
-- 2) Ejecutar este archivo completo en una ventana de mantenimiento.
-- 3) Esta migracion no crea tablas principales ni borra el historial.
-- 4) El flujo se prueba primero en una copia de la base.
-- 5) Esta versión respeta el esquema real: rol es global y no tiene club_id.
--
-- Decisiones: un pago anulado conserva el pago y sus detalles; el motivo es
-- obligatorio; las cuotas vuelven a PENDIENTE/VENCIDA; no se hacen devoluciones.

BEGIN;

-- 1. Campos de anulacion en la tabla pago existente.
ALTER TABLE public.pago
    ADD COLUMN IF NOT EXISTS estado VARCHAR(20) NOT NULL DEFAULT 'REGISTRADO',
    ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
    ADD COLUMN IF NOT EXISTS anulado_por_usuario_id BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS pago_reemplazo_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_pago_estado_anulacion'
          AND conrelid = 'public.pago'::regclass
    ) THEN
        ALTER TABLE public.pago
        ADD CONSTRAINT chk_pago_estado_anulacion CHECK (
            estado IN ('REGISTRADO', 'ANULADO')
            AND (
                (estado = 'REGISTRADO'
                 AND motivo_anulacion IS NULL
                 AND anulado_por_usuario_id IS NULL
                 AND fecha_anulacion IS NULL)
                OR
                (estado = 'ANULADO'
                 AND motivo_anulacion IS NOT NULL
                 AND length(btrim(motivo_anulacion)) > 0
                 AND anulado_por_usuario_id IS NOT NULL
                 AND fecha_anulacion IS NOT NULL)
            )
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_pago_anulado_por_usuario'
          AND conrelid = 'public.pago'::regclass
    ) THEN
        ALTER TABLE public.pago
        ADD CONSTRAINT fk_pago_anulado_por_usuario
        FOREIGN KEY (anulado_por_usuario_id) REFERENCES public.usuario(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_pago_reemplazo_club'
          AND conrelid = 'public.pago'::regclass
    ) THEN
        ALTER TABLE public.pago
        ADD CONSTRAINT fk_pago_reemplazo_club
        FOREIGN KEY (pago_reemplazo_id, club_id)
        REFERENCES public.pago(id, club_id);
    END IF;
END $$;

-- 2. Sustituir UNIQUE(cuota_generada_id): los detalles historicos de pagos
-- anulados se conservan, pero una cuota no puede tener dos pagos vigentes.
-- En la base real aparece como índice único, no como constraint.
DROP INDEX IF EXISTS public.uq_pago_detalle_cuota;
-- Compatibilidad por si otra versión lo hubiera creado como constraint.
ALTER TABLE public.pago_detalle
    DROP CONSTRAINT IF EXISTS uq_pago_detalle_cuota;

CREATE UNIQUE INDEX IF NOT EXISTS uq_pago_reemplazo_unico
    ON public.pago (pago_reemplazo_id)
    WHERE pago_reemplazo_id IS NOT NULL;

-- 3. Permiso para anular y roles autorizados acordados: Tesoreria, Presidencia,
-- Secretaria. No se concede al rol Administrador por defecto.
INSERT INTO public.permiso (codigo, nombre, descripcion)
VALUES ('pago.anular', 'Anular pagos', 'Anular un pago completo conservando el historial')
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion;

-- En el esquema real, rol es global: no tiene club_id. La asignación al club
-- se determina mediante usuario_club + usuario_club_rol.
INSERT INTO public.rol (nombre, descripcion)
VALUES
    ('Tesorería', 'Gestión de cobranzas y anulaciones'),
    ('Presidencia', 'Supervisión y autorización de anulaciones de pagos'),
    ('Secretaría', 'Gestión administrativa y correcciones autorizadas de pagos')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
FROM public.rol r
JOIN public.permiso p ON p.codigo = 'pago.anular'
WHERE r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 4. Validar detalles con bloqueo de la cuota. El bloqueo serializa intentos
-- concurrentes de pago sobre la misma cuota. El socio del pago es el responsable
-- de pago en la estructura real inspeccionada.
CREATE OR REPLACE FUNCTION public.validar_detalle_pago()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_cuota VARCHAR(20);
    v_importe_cuota NUMERIC(12,2);
    v_responsable_cuota BIGINT;
    v_responsable_pago BIGINT;
    v_estado_pago VARCHAR(20);
BEGIN
    SELECT estado, importe_total, responsable_pago_socio_id
      INTO v_estado_cuota, v_importe_cuota, v_responsable_cuota
    FROM public.cuota_generada
    WHERE id = NEW.cuota_generada_id AND club_id = NEW.club_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuota no existe en el club indicado';
    END IF;

    SELECT socio_id, estado
      INTO v_responsable_pago, v_estado_pago
    FROM public.pago
    WHERE id = NEW.pago_id AND club_id = NEW.club_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago no existe en el club indicado';
    END IF;
    IF v_estado_pago <> 'REGISTRADO' THEN
        RAISE EXCEPTION 'No se pueden agregar detalles a un pago anulado';
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

    IF EXISTS (
        SELECT 1
        FROM public.pago_detalle pd
        JOIN public.pago p ON p.id = pd.pago_id AND p.club_id = pd.club_id
        WHERE pd.cuota_generada_id = NEW.cuota_generada_id
          AND pd.club_id = NEW.club_id
          AND p.estado = 'REGISTRADO'
          AND pd.id <> COALESCE(NEW.id, -1)
    ) THEN
        RAISE EXCEPTION 'La cuota ya tiene un pago registrado y no puede cobrarse nuevamente';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_detalle_pago ON public.pago_detalle;
CREATE TRIGGER trg_validar_detalle_pago
BEFORE INSERT ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.validar_detalle_pago();

-- 5. Al insertar el detalle, marcar la cuota como pagada. La operacion completa
-- se revierte si falla cualquier otra validacion de la transaccion.
CREATE OR REPLACE FUNCTION public.marcar_cuota_pagada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.cuota_generada
       SET estado = 'PAGADA'
     WHERE id = NEW.cuota_generada_id
       AND club_id = NEW.club_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_marcar_cuota_pagada ON public.pago_detalle;
CREATE TRIGGER trg_marcar_cuota_pagada
AFTER INSERT ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.marcar_cuota_pagada();

-- 6. Comprobar al COMMIT que un pago registrado coincide con la suma de detalles.
CREATE OR REPLACE FUNCTION public.validar_total_pago()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_pago_id BIGINT;
    v_importe_pago NUMERIC(12,2);
    v_estado_pago VARCHAR(20);
    v_suma_detalles NUMERIC(12,2);
BEGIN
    IF TG_TABLE_NAME = 'pago' THEN
        v_pago_id := NEW.id;
    ELSE
        v_pago_id := NEW.pago_id;
    END IF;

    SELECT importe_total, estado
      INTO v_importe_pago, v_estado_pago
    FROM public.pago WHERE id = v_pago_id;
    IF NOT FOUND OR v_estado_pago = 'ANULADO' THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(SUM(importe_aplicado), 0)
      INTO v_suma_detalles
    FROM public.pago_detalle WHERE pago_id = v_pago_id;

    IF v_suma_detalles <> v_importe_pago THEN
        RAISE EXCEPTION 'El total del pago (%) debe coincidir con la suma de sus detalles (%)',
            v_importe_pago, v_suma_detalles;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_total_pago ON public.pago;
CREATE CONSTRAINT TRIGGER trg_validar_total_pago
AFTER INSERT OR UPDATE ON public.pago
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION public.validar_total_pago();

DROP TRIGGER IF EXISTS trg_validar_total_pago_detalle ON public.pago_detalle;
CREATE CONSTRAINT TRIGGER trg_validar_total_pago_detalle
AFTER INSERT ON public.pago_detalle
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION public.validar_total_pago();

-- 7. Bloquear cambios en detalles historicos. Para corregir un cobro se anula
-- el pago completo y se registra uno nuevo; nunca se edita el detalle original.
CREATE OR REPLACE FUNCTION public.impedir_modificacion_detalle_pago()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Los detalles de pago no se pueden modificar ni borrar directamente';
END;
$$;

DROP TRIGGER IF EXISTS trg_impedir_modificacion_detalle_pago ON public.pago_detalle;
CREATE TRIGGER trg_impedir_modificacion_detalle_pago
BEFORE UPDATE OR DELETE ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.impedir_modificacion_detalle_pago();

-- 8. Proteger pagos: no se modifica el contenido contable; solo se permite pasar
-- de REGISTRADO a ANULADO con motivo, usuario y fecha. Un pago anulado queda cerrado.
CREATE OR REPLACE FUNCTION public.proteger_pago_y_anulacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.estado = 'ANULADO' THEN
        -- Se permite únicamente vincular una vez el pago de reemplazo.
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.club_id IS DISTINCT FROM OLD.club_id
           OR NEW.socio_id IS DISTINCT FROM OLD.socio_id
           OR NEW.fecha_pago IS DISTINCT FROM OLD.fecha_pago
           OR NEW.importe_total IS DISTINCT FROM OLD.importe_total
           OR NEW.medio_pago IS DISTINCT FROM OLD.medio_pago
           OR NEW.referencia IS DISTINCT FROM OLD.referencia
           OR NEW.registrado_por_usuario_id IS DISTINCT FROM OLD.registrado_por_usuario_id
           OR NEW.observacion IS DISTINCT FROM OLD.observacion
           OR NEW.estado IS DISTINCT FROM OLD.estado
           OR NEW.motivo_anulacion IS DISTINCT FROM OLD.motivo_anulacion
           OR NEW.anulado_por_usuario_id IS DISTINCT FROM OLD.anulado_por_usuario_id
           OR NEW.fecha_anulacion IS DISTINCT FROM OLD.fecha_anulacion
           OR (OLD.pago_reemplazo_id IS NOT NULL AND NEW.pago_reemplazo_id IS DISTINCT FROM OLD.pago_reemplazo_id) THEN
            RAISE EXCEPTION 'Un pago anulado es inmutable; solo se permite vincular una vez su reemplazo';
        END IF;
        IF NEW.pago_reemplazo_id IS NOT NULL THEN
            IF NEW.pago_reemplazo_id = OLD.id OR NOT EXISTS (
                SELECT 1 FROM public.pago p
                WHERE p.id = NEW.pago_reemplazo_id
                  AND p.club_id = OLD.club_id
                  AND p.estado = 'REGISTRADO'
            ) THEN
                RAISE EXCEPTION 'El pago de reemplazo debe ser otro pago registrado del mismo club';
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.club_id IS DISTINCT FROM OLD.club_id
       OR NEW.socio_id IS DISTINCT FROM OLD.socio_id
       OR NEW.fecha_pago IS DISTINCT FROM OLD.fecha_pago
       OR NEW.importe_total IS DISTINCT FROM OLD.importe_total
       OR NEW.medio_pago IS DISTINCT FROM OLD.medio_pago
       OR NEW.referencia IS DISTINCT FROM OLD.referencia
       OR NEW.registrado_por_usuario_id IS DISTINCT FROM OLD.registrado_por_usuario_id
       OR NEW.observacion IS DISTINCT FROM OLD.observacion
       OR NEW.pago_reemplazo_id IS DISTINCT FROM OLD.pago_reemplazo_id THEN
        RAISE EXCEPTION 'No se editan los datos de un pago registrado; debe anularse y registrarse nuevamente';
    END IF;

    IF NEW.estado IS DISTINCT FROM OLD.estado THEN
        IF NEW.estado <> 'ANULADO'
           OR NEW.motivo_anulacion IS NULL
           OR length(btrim(NEW.motivo_anulacion)) = 0
           OR NEW.anulado_por_usuario_id IS NULL
           OR NEW.fecha_anulacion IS NULL THEN
            RAISE EXCEPTION 'La anulacion requiere estado ANULADO, motivo, usuario y fecha';
        END IF;
        IF NOT EXISTS (
            SELECT 1
            FROM public.usuario_club uc
            JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
            JOIN public.rol r ON r.id = ucr.rol_id
            JOIN public.rol_permiso rp ON rp.rol_id = r.id
            JOIN public.permiso pe ON pe.id = rp.permiso_id
            WHERE uc.usuario_id = NEW.anulado_por_usuario_id
              AND uc.club_id = NEW.club_id
              AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
              AND pe.codigo = 'pago.anular'
        ) THEN
            RAISE EXCEPTION 'El usuario no tiene permiso para anular pagos en este club';
        END IF;
    ELSIF NEW.motivo_anulacion IS DISTINCT FROM OLD.motivo_anulacion
       OR NEW.anulado_por_usuario_id IS DISTINCT FROM OLD.anulado_por_usuario_id
       OR NEW.fecha_anulacion IS DISTINCT FROM OLD.fecha_anulacion THEN
        RAISE EXCEPTION 'Los datos de anulacion solo se pueden establecer al anular el pago';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_pago_y_anulacion ON public.pago;
CREATE TRIGGER trg_proteger_pago_y_anulacion
BEFORE UPDATE ON public.pago
FOR EACH ROW EXECUTE FUNCTION public.proteger_pago_y_anulacion();

-- 9. Funcion de anulacion completa. Solo la pueden usar usuarios que tengan
-- uno de los roles acordados dentro del mismo club. No realiza devoluciones.
CREATE OR REPLACE FUNCTION public.anular_pago(
    p_pago_id BIGINT,
    p_usuario_id BIGINT,
    p_motivo TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_club_id BIGINT;
    v_estado_pago VARCHAR(20);
    v_fecha_pago TIMESTAMP WITHOUT TIME ZONE;
    v_socio_id BIGINT;
    v_detalle RECORD;
BEGIN
    IF p_motivo IS NULL OR length(btrim(p_motivo)) = 0 THEN
        RAISE EXCEPTION 'El motivo de anulacion es obligatorio';
    END IF;

    SELECT club_id, estado, fecha_pago, socio_id
      INTO v_club_id, v_estado_pago, v_fecha_pago, v_socio_id
    FROM public.pago
    WHERE id = p_pago_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el pago indicado';
    END IF;
    IF v_estado_pago <> 'REGISTRADO' THEN
        RAISE EXCEPTION 'El pago ya fue anulado o no se encuentra registrado';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.usuario_club uc
        JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
        JOIN public.rol r ON r.id = ucr.rol_id
        JOIN public.rol_permiso rp ON rp.rol_id = r.id
        JOIN public.permiso pe ON pe.id = rp.permiso_id
        WHERE uc.usuario_id = p_usuario_id
          AND uc.club_id = v_club_id
          AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
          AND pe.codigo = 'pago.anular'
    ) THEN
        RAISE EXCEPTION 'El usuario no tiene permiso para anular pagos en este club';
    END IF;

    -- Bloquear las cuotas en orden estable para evitar carreras con otras cobranzas.
    FOR v_detalle IN
        SELECT cg.id, cg.club_id
        FROM public.pago_detalle pd
        JOIN public.cuota_generada cg ON cg.id = pd.cuota_generada_id AND cg.club_id = pd.club_id
        WHERE pd.pago_id = p_pago_id
        ORDER BY cg.id
        FOR UPDATE OF cg
    LOOP
        NULL;
    END LOOP;

    UPDATE public.pago
       SET estado = 'ANULADO',
           motivo_anulacion = btrim(p_motivo),
           anulado_por_usuario_id = p_usuario_id,
           fecha_anulacion = CURRENT_TIMESTAMP
     WHERE id = p_pago_id;

    UPDATE public.cuota_generada cg
       SET estado = CASE
           WHEN cg.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDA'
           ELSE 'PENDIENTE'
       END
    FROM public.pago_detalle pd
    WHERE pd.pago_id = p_pago_id
      AND cg.id = pd.cuota_generada_id
      AND cg.club_id = pd.club_id;

    -- Auditoria usando las columnas reales inspeccionadas en gestion_club.
    INSERT INTO public.auditoria
        (club_id, usuario_id, tabla_afectada, registro_id, accion, detalle, fecha_hora)
    VALUES
        (v_club_id, p_usuario_id, 'pago', p_pago_id, 'ANULAR',
         'Motivo: ' || btrim(p_motivo), CURRENT_TIMESTAMP);
END;
$$;

-- 10. Vincular opcionalmente el nuevo pago con el original anulado.
CREATE OR REPLACE FUNCTION public.vincular_pago_reemplazo(
    p_pago_original_id BIGINT,
    p_pago_reemplazo_id BIGINT,
    p_usuario_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_club_id BIGINT;
BEGIN
    SELECT club_id INTO v_club_id
    FROM public.pago
    WHERE id = p_pago_original_id AND estado = 'ANULADO'
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago original debe existir y estar anulado';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.pago p
        WHERE p.id = p_pago_reemplazo_id
          AND p.club_id = v_club_id
          AND p.estado = 'REGISTRADO'
    ) THEN
        RAISE EXCEPTION 'El reemplazo debe ser un pago registrado del mismo club';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.usuario_club uc
        JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
        JOIN public.rol r ON r.id = ucr.rol_id
        JOIN public.rol_permiso rp ON rp.rol_id = r.id
        JOIN public.permiso pe ON pe.id = rp.permiso_id
        WHERE uc.usuario_id = p_usuario_id AND uc.club_id = v_club_id
          AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
          AND pe.codigo = 'pago.anular'
    ) THEN
        RAISE EXCEPTION 'El usuario no tiene permiso para vincular el reemplazo';
    END IF;

    UPDATE public.pago
       SET pago_reemplazo_id = p_pago_reemplazo_id
     WHERE id = p_pago_original_id;
END;
$$;

COMMIT;

-- Uso desde la aplicacion (ejemplo; no ejecutar como parte de la migracion):
-- SELECT public.anular_pago(<id_pago>, <id_usuario>, 'Motivo obligatorio');
-- SELECT public.vincular_pago_reemplazo(<id_original>, <id_nuevo>, <id_usuario>);
--
-- Nota: antes de habilitar en produccion, probar en una copia de la base:
-- 1) pago de una cuota; 2) pago con varias cuotas; 3) pago duplicado;
-- 4) anulacion y nuevo pago de la misma cuota; 5) usuario sin permiso;
-- 6) motivo vacio; 7) reemplazo de otro club; 8) dos intentos simultaneos.
