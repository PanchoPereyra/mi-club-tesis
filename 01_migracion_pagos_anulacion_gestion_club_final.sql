-- MIGRACION INCREMENTAL: ANULACION Y CONTROLES DE PAGOS
-- Base objetivo: gestion_club (esquema public)
-- No elimina tablas ni registros. No ejecutar el SQL maestro sobre la base existente.
-- Preparada a partir del inventario compartido por el usuario; requiere prueba en copia.
-- Requisito de la aplicación: crear pago + detalles dentro de UNA transaccion.

BEGIN;

-- 1) Campos de anulacion. IF NOT EXISTS permite repetir la etapa de columnas.
ALTER TABLE public.pago
    ADD COLUMN IF NOT EXISTS estado VARCHAR(20) NOT NULL DEFAULT 'REGISTRADO',
    ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
    ADD COLUMN IF NOT EXISTS anulado_por_usuario_id BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS pago_reemplazo_id BIGINT;

-- 2) Restricciones y FK, sin asumir que ya existen.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pago_estado_anulacion' AND conrelid = 'public.pago'::regclass) THEN
        ALTER TABLE public.pago ADD CONSTRAINT chk_pago_estado_anulacion CHECK (
            (estado = 'REGISTRADO' AND motivo_anulacion IS NULL AND anulado_por_usuario_id IS NULL AND fecha_anulacion IS NULL)
            OR
            (estado = 'ANULADO' AND motivo_anulacion IS NOT NULL AND length(btrim(motivo_anulacion)) > 0
             AND anulado_por_usuario_id IS NOT NULL AND fecha_anulacion IS NOT NULL)
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pago_anulado_por_usuario' AND conrelid = 'public.pago'::regclass) THEN
        ALTER TABLE public.pago ADD CONSTRAINT fk_pago_anulado_por_usuario
            FOREIGN KEY (anulado_por_usuario_id) REFERENCES public.usuario(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pago_reemplazo_club' AND conrelid = 'public.pago'::regclass) THEN
        ALTER TABLE public.pago ADD CONSTRAINT fk_pago_reemplazo_club
            FOREIGN KEY (pago_reemplazo_id, club_id) REFERENCES public.pago(id, club_id);
    END IF;
END $$;

-- El indice previo impedia conservar detalles historicos y volver a pagar una cuota
-- luego de anular su pago. La validacion correcta se hace bloqueando la cuota.
DROP INDEX IF EXISTS public.uq_pago_detalle_cuota;
CREATE UNIQUE INDEX IF NOT EXISTS uq_pago_reemplazo_unico
    ON public.pago(pago_reemplazo_id) WHERE pago_reemplazo_id IS NOT NULL;

-- 3) Permiso y roles autorizados. Los roles son globales; la asignacion es por usuario_club.
INSERT INTO public.permiso(codigo, nombre, descripcion)
VALUES ('pago.anular', 'Anular pagos', 'Anular un pago completo con motivo e historial')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO public.rol(nombre, descripcion) VALUES
    ('Tesorería', 'Gestion de cuotas y pagos'),
    ('Presidencia', 'Supervision institucional'),
    ('Secretaría', 'Gestion administrativa de socios')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.rol_permiso(rol_id, permiso_id)
SELECT r.id, p.id
FROM public.rol r CROSS JOIN public.permiso p
WHERE r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
  AND p.codigo = 'pago.anular'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- 4) Validar detalles: cuota completa, club y responsable correctos, sin pagos activos duplicados.
CREATE OR REPLACE FUNCTION public.validar_detalle_pago()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_cuota public.cuota_generada%ROWTYPE;
    v_pago public.pago%ROWTYPE;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        RAISE EXCEPTION 'Los detalles de pago son inmutables; anule el pago completo y registre uno nuevo.';
    END IF;

    SELECT * INTO v_cuota
    FROM public.cuota_generada
    WHERE id = NEW.cuota_generada_id AND club_id = NEW.club_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuota % no existe en el club indicado.', NEW.cuota_generada_id;
    END IF;

    SELECT * INTO v_pago
    FROM public.pago
    WHERE id = NEW.pago_id AND club_id = NEW.club_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago no existe en el club indicado.';
    END IF;
    IF v_pago.estado <> 'REGISTRADO' THEN
        RAISE EXCEPTION 'No se pueden agregar detalles a un pago anulado.';
    END IF;
    IF v_cuota.estado NOT IN ('PENDIENTE', 'VENCIDA') THEN
        RAISE EXCEPTION 'La cuota % no esta disponible para pagar (estado: %).', v_cuota.id, v_cuota.estado;
    END IF;
    IF NEW.importe_aplicado <> v_cuota.importe_total THEN
        RAISE EXCEPTION 'La cuota % debe pagarse completa. Importe esperado: %, recibido: %.', v_cuota.id, v_cuota.importe_total, NEW.importe_aplicado;
    END IF;
    IF v_pago.socio_id <> v_cuota.responsable_pago_socio_id THEN
        RAISE EXCEPTION 'El socio responsable del pago no coincide con el responsable de la cuota %.', v_cuota.id;
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.pago_detalle pd
        JOIN public.pago p ON p.id = pd.pago_id AND p.club_id = pd.club_id
        WHERE pd.cuota_generada_id = NEW.cuota_generada_id
          AND pd.club_id = NEW.club_id
          AND p.estado = 'REGISTRADO'
    ) THEN
        RAISE EXCEPTION 'La cuota % ya esta cubierta por un pago registrado.', v_cuota.id;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_validar_detalle_pago ON public.pago_detalle;
CREATE TRIGGER trg_validar_detalle_pago
BEFORE INSERT OR UPDATE OR DELETE ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.validar_detalle_pago();

CREATE OR REPLACE FUNCTION public.marcar_cuota_pagada()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.cuota_generada
       SET estado = 'PAGADA'
     WHERE id = NEW.cuota_generada_id AND club_id = NEW.club_id;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_marcar_cuota_pagada ON public.pago_detalle;
CREATE TRIGGER trg_marcar_cuota_pagada
AFTER INSERT ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.marcar_cuota_pagada();

-- 5) Validacion diferida: el total del pago debe coincidir con sus detalles al COMMIT.
CREATE OR REPLACE FUNCTION public.validar_total_pago()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_pago_id BIGINT;
    v_pago public.pago%ROWTYPE;
    v_suma NUMERIC(12,2);
BEGIN
    IF TG_TABLE_NAME = 'pago' THEN
        v_pago_id := NEW.id;
    ELSE
        v_pago_id := NEW.pago_id;
    END IF;
    SELECT * INTO v_pago FROM public.pago WHERE id = v_pago_id;
    IF NOT FOUND OR v_pago.estado = 'ANULADO' THEN
        RETURN NULL;
    END IF;
    SELECT COALESCE(SUM(importe_aplicado), 0) INTO v_suma
    FROM public.pago_detalle WHERE pago_id = v_pago_id;
    IF v_suma <> v_pago.importe_total THEN
        RAISE EXCEPTION 'El pago % totaliza %, pero sus detalles suman %. Registre el pago y todos sus detalles en una sola transaccion.', v_pago.id, v_pago.importe_total, v_suma;
    END IF;
    RETURN NULL;
END $$;

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

-- 6) Bloquear ediciones directas del pago. Solo se permite anular mediante la funcion
-- anular_pago(), o vincular reemplazo mediante vincular_pago_reemplazo().
CREATE OR REPLACE FUNCTION public.proteger_pago()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_accion TEXT := current_setting('app.accion_pago', true);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'No se pueden borrar pagos; use la anulacion para conservar el historial.';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.estado <> 'REGISTRADO' OR NEW.motivo_anulacion IS NOT NULL OR NEW.anulado_por_usuario_id IS NOT NULL OR NEW.fecha_anulacion IS NOT NULL OR NEW.pago_reemplazo_id IS NOT NULL THEN
            RAISE EXCEPTION 'Un pago nuevo debe crearse como REGISTRADO y sin datos de anulacion o reemplazo.';
        END IF;
        RETURN NEW;
    END IF;

    IF v_accion = 'ANULAR' AND OLD.estado = 'REGISTRADO' AND NEW.estado = 'ANULADO'
       AND (to_jsonb(NEW) - ARRAY['estado','motivo_anulacion','anulado_por_usuario_id','fecha_anulacion'])
           = (to_jsonb(OLD) - ARRAY['estado','motivo_anulacion','anulado_por_usuario_id','fecha_anulacion']) THEN
        RETURN NEW;
    END IF;
    IF v_accion = 'VINCULAR_REEMPLAZO' AND OLD.estado = 'ANULADO' AND NEW.estado = OLD.estado
       AND OLD.pago_reemplazo_id IS NULL AND NEW.pago_reemplazo_id IS NOT NULL
       AND (to_jsonb(NEW) - 'pago_reemplazo_id') = (to_jsonb(OLD) - 'pago_reemplazo_id') THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Los pagos son inmutables. Para corregir un error, anule el pago y registre otro.';
END $$;

DROP TRIGGER IF EXISTS trg_proteger_pago ON public.pago;
CREATE TRIGGER trg_proteger_pago
BEFORE INSERT OR UPDATE OR DELETE ON public.pago
FOR EACH ROW EXECUTE FUNCTION public.proteger_pago();

-- 7) Anular pago completo. El motivo es obligatorio; no hay devolucion de dinero en esta version.
CREATE OR REPLACE FUNCTION public.anular_pago(
    p_pago_id BIGINT,
    p_usuario_id BIGINT,
    p_motivo TEXT
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_pago public.pago%ROWTYPE;
    v_cuota RECORD;
BEGIN
    IF p_motivo IS NULL OR length(btrim(p_motivo)) = 0 THEN
        RAISE EXCEPTION 'Debe indicar un motivo de anulacion.';
    END IF;

    SELECT * INTO v_pago FROM public.pago WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No existe el pago %.', p_pago_id; END IF;
    IF v_pago.estado <> 'REGISTRADO' THEN RAISE EXCEPTION 'El pago % ya esta anulado.', p_pago_id; END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.usuario_club uc
        JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
        JOIN public.rol r ON r.id = ucr.rol_id
        JOIN public.rol_permiso rp ON rp.rol_id = r.id
        JOIN public.permiso pe ON pe.id = rp.permiso_id
        WHERE uc.usuario_id = p_usuario_id AND uc.club_id = v_pago.club_id
          AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
          AND pe.codigo = 'pago.anular'
    ) THEN
        RAISE EXCEPTION 'El usuario % no tiene permiso para anular pagos en el club %.', p_usuario_id, v_pago.club_id;
    END IF;

    -- Bloquea las cuotas para serializar anulaciones frente a nuevos pagos.
    PERFORM q.id
      FROM public.cuota_generada q
      JOIN public.pago_detalle pd ON pd.cuota_generada_id = q.id AND pd.club_id = q.club_id
     WHERE pd.pago_id = v_pago.id AND pd.club_id = v_pago.club_id
     ORDER BY q.id FOR UPDATE OF q;

    PERFORM set_config('app.accion_pago', 'ANULAR', true);
    UPDATE public.pago
       SET estado = 'ANULADO', motivo_anulacion = btrim(p_motivo),
           anulado_por_usuario_id = p_usuario_id, fecha_anulacion = CURRENT_TIMESTAMP
     WHERE id = v_pago.id;
    PERFORM set_config('app.accion_pago', '', true);

    FOR v_cuota IN
        SELECT DISTINCT q.id, q.club_id, q.fecha_vencimiento
        FROM public.cuota_generada q
        JOIN public.pago_detalle pd ON pd.cuota_generada_id = q.id AND pd.club_id = q.club_id
        WHERE pd.pago_id = v_pago.id AND pd.club_id = v_pago.club_id
        ORDER BY q.id
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM public.pago_detalle pd2
            JOIN public.pago p2 ON p2.id = pd2.pago_id AND p2.club_id = pd2.club_id
            WHERE pd2.cuota_generada_id = v_cuota.id AND pd2.club_id = v_cuota.club_id
              AND p2.estado = 'REGISTRADO'
        ) THEN
            UPDATE public.cuota_generada
               SET estado = CASE WHEN CURRENT_DATE > v_cuota.fecha_vencimiento THEN 'VENCIDA' ELSE 'PENDIENTE' END
             WHERE id = v_cuota.id AND club_id = v_cuota.club_id;
        END IF;
    END LOOP;

    INSERT INTO public.auditoria(club_id, usuario_id, tabla_afectada, registro_id, accion, detalle, fecha_hora)
    VALUES (v_pago.club_id, p_usuario_id, 'pago', v_pago.id, 'ANULAR',
            'Motivo: ' || btrim(p_motivo), CURRENT_TIMESTAMP);
END $$;

-- 8) Vincular un pago nuevo como reemplazo de un pago ya anulado.
CREATE OR REPLACE FUNCTION public.vincular_pago_reemplazo(
    p_pago_original_id BIGINT,
    p_pago_reemplazo_id BIGINT,
    p_usuario_id BIGINT
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_original public.pago%ROWTYPE;
    v_reemplazo public.pago%ROWTYPE;
BEGIN
    SELECT * INTO v_original FROM public.pago WHERE id = p_pago_original_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No existe el pago original %.', p_pago_original_id; END IF;
    SELECT * INTO v_reemplazo FROM public.pago WHERE id = p_pago_reemplazo_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No existe el pago de reemplazo %.', p_pago_reemplazo_id; END IF;
    IF v_original.estado <> 'ANULADO' THEN RAISE EXCEPTION 'Solo se puede reemplazar un pago anulado.'; END IF;
    IF v_original.pago_reemplazo_id IS NOT NULL THEN RAISE EXCEPTION 'El pago original ya tiene un reemplazo vinculado.'; END IF;
    IF v_original.id = v_reemplazo.id OR v_original.club_id <> v_reemplazo.club_id THEN
        RAISE EXCEPTION 'El reemplazo debe ser otro pago del mismo club.';
    END IF;
    IF v_reemplazo.estado <> 'REGISTRADO' THEN RAISE EXCEPTION 'El pago de reemplazo debe estar REGISTRADO.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuario_club uc
        JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
        JOIN public.rol r ON r.id = ucr.rol_id
        JOIN public.rol_permiso rp ON rp.rol_id = r.id
        JOIN public.permiso pe ON pe.id = rp.permiso_id
        WHERE uc.usuario_id = p_usuario_id AND uc.club_id = v_original.club_id
          AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría') AND pe.codigo = 'pago.anular'
    ) THEN RAISE EXCEPTION 'El usuario no tiene permiso para vincular el reemplazo.'; END IF;

    PERFORM set_config('app.accion_pago', 'VINCULAR_REEMPLAZO', true);
    UPDATE public.pago SET pago_reemplazo_id = v_reemplazo.id WHERE id = v_original.id;
    PERFORM set_config('app.accion_pago', '', true);
END $$;

COMMIT;

-- IMPORTANTE PARA LA APLICACION:
-- * Ejecutar anular_pago(id_pago, id_usuario, motivo) para anular; no editar pago directamente.
-- * Pago y todos sus detalles deben insertarse dentro de la misma transaccion.
-- * Una cuota debe pagarse completa; un pago puede incluir varias cuotas.
-- * Esta migracion fue revisada estaticamente, pero no ejecutada contra PostgreSQL.
--   Probar primero en una copia de gestion_club y revisar permisos del usuario de conexion.
