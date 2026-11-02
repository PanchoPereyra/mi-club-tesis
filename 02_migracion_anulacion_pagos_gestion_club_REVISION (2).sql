-- Migración: anulación segura de pagos
-- Base objetivo: gestion_club_pruebas
-- IMPORTANTE: ejecutar primero SOLO en la base de pruebas y dentro de una transacción.

BEGIN;

-- 1) Datos de anulación e historial en pago.
ALTER TABLE public.pago
    ADD COLUMN IF NOT EXISTS estado VARCHAR(20) NOT NULL DEFAULT 'REGISTRADO',
    ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
    ADD COLUMN IF NOT EXISTS anulado_por_usuario_id BIGINT,
    ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMP,
    ADD COLUMN IF NOT EXISTS pago_reemplazo_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pago_estado_anulacion' AND conrelid = 'public.pago'::regclass) THEN
        ALTER TABLE public.pago ADD CONSTRAINT chk_pago_estado_anulacion CHECK (
            (estado = 'REGISTRADO' AND motivo_anulacion IS NULL AND anulado_por_usuario_id IS NULL AND fecha_anulacion IS NULL)
            OR
            (estado = 'ANULADO' AND motivo_anulacion IS NOT NULL AND length(btrim(motivo_anulacion)) > 0 AND anulado_por_usuario_id IS NOT NULL AND fecha_anulacion IS NOT NULL)
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pago_anulado_por_usuario' AND conrelid = 'public.pago'::regclass) THEN
        ALTER TABLE public.pago ADD CONSTRAINT fk_pago_anulado_por_usuario FOREIGN KEY (anulado_por_usuario_id) REFERENCES public.usuario(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pago_reemplazo_mismo_club' AND conrelid = 'public.pago'::regclass) THEN
        ALTER TABLE public.pago ADD CONSTRAINT fk_pago_reemplazo_mismo_club FOREIGN KEY (pago_reemplazo_id, club_id) REFERENCES public.pago(id, club_id);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_pago_reemplazo_unico
    ON public.pago(pago_reemplazo_id) WHERE pago_reemplazo_id IS NOT NULL;

-- La unicidad histórica se controla con triggers: una cuota puede aparecer
-- en el detalle de un pago anulado y luego en un pago nuevo.
DROP INDEX IF EXISTS public.uq_pago_detalle_cuota;

-- 2) Permiso y roles autorizados para anular.
INSERT INTO public.permiso (codigo, nombre)
VALUES ('pago.anular', 'Anular pagos')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO public.rol (nombre)
VALUES ('Tesorería'), ('Presidencia'), ('Secretaría')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
FROM public.rol r CROSS JOIN public.permiso p
WHERE r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
  AND p.codigo = 'pago.anular'
ON CONFLICT DO NOTHING;

-- 3) Evitar cambios o borrados de detalles: se conserva el historial.
CREATE OR REPLACE FUNCTION public.proteger_detalle_pago_historico()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'El detalle de un pago es inmutable. Anule el pago y registre uno nuevo.';
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_detalle_pago_historico ON public.pago_detalle;
CREATE TRIGGER trg_proteger_detalle_pago_historico
BEFORE UPDATE OR DELETE ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.proteger_detalle_pago_historico();

-- 4) Validar cada detalle y bloquear la cuota para evitar pagos duplicados concurrentes.
CREATE OR REPLACE FUNCTION public.validar_detalle_pago()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_estado_cuota VARCHAR(20);
    v_importe_cuota NUMERIC;
    v_responsable BIGINT;
    v_estado_pago VARCHAR(20);
    v_socio_pago BIGINT;
BEGIN
    SELECT cg.estado, cg.importe_total, cg.responsable_pago_socio_id
      INTO v_estado_cuota, v_importe_cuota, v_responsable
      FROM public.cuota_generada cg
     WHERE cg.id = NEW.cuota_generada_id AND cg.club_id = NEW.club_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La cuota no existe en el club indicado.'; END IF;

    SELECT p.estado, p.socio_id INTO v_estado_pago, v_socio_pago
      FROM public.pago p
     WHERE p.id = NEW.pago_id AND p.club_id = NEW.club_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pago no existe en el club indicado.'; END IF;
    IF v_estado_pago <> 'REGISTRADO' THEN RAISE EXCEPTION 'No se pueden agregar detalles a un pago anulado.'; END IF;
    IF v_estado_cuota NOT IN ('PENDIENTE', 'VENCIDA') THEN RAISE EXCEPTION 'La cuota no está pendiente de pago.'; END IF;
    IF NEW.importe_aplicado <> v_importe_cuota THEN RAISE EXCEPTION 'La cuota debe pagarse por su importe total exacto.'; END IF;
    IF v_socio_pago <> v_responsable THEN RAISE EXCEPTION 'El socio responsable del pago no coincide con el responsable de la cuota.'; END IF;
    IF EXISTS (
        SELECT 1 FROM public.pago_detalle pd
        JOIN public.pago p ON p.id = pd.pago_id AND p.club_id = pd.club_id
        WHERE pd.cuota_generada_id = NEW.cuota_generada_id
          AND pd.club_id = NEW.club_id
          AND p.estado = 'REGISTRADO'
    ) THEN RAISE EXCEPTION 'La cuota ya está incluida en otro pago registrado.'; END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validar_detalle_pago ON public.pago_detalle;
CREATE TRIGGER trg_validar_detalle_pago
BEFORE INSERT ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.validar_detalle_pago();

CREATE OR REPLACE FUNCTION public.marcar_cuota_pagada()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.cuota_generada SET estado = 'PAGADA'
     WHERE id = NEW.cuota_generada_id AND club_id = NEW.club_id;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_marcar_cuota_pagada ON public.pago_detalle;
CREATE TRIGGER trg_marcar_cuota_pagada
AFTER INSERT ON public.pago_detalle
FOR EACH ROW EXECUTE FUNCTION public.marcar_cuota_pagada();

-- 5) El total del pago debe coincidir con la suma de sus detalles al confirmar
-- la transacción. Por eso pago y pago_detalle deben insertarse en una misma transacción.
CREATE OR REPLACE FUNCTION public.validar_total_pago()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_pago_id BIGINT;
    v_estado VARCHAR(20);
    v_total NUMERIC;
    v_detalle NUMERIC;
BEGIN
    IF TG_TABLE_NAME = 'pago' THEN v_pago_id := NEW.id; ELSE v_pago_id := NEW.pago_id; END IF;
    SELECT estado, importe_total INTO v_estado, v_total FROM public.pago WHERE id = v_pago_id;
    IF NOT FOUND OR v_estado = 'ANULADO' THEN RETURN NULL; END IF;
    SELECT COALESCE(SUM(importe_aplicado), 0) INTO v_detalle FROM public.pago_detalle WHERE pago_id = v_pago_id;
    IF v_detalle <= 0 OR v_detalle <> v_total THEN
        RAISE EXCEPTION 'El importe total del pago (%) debe coincidir con sus detalles (%).', v_total, v_detalle;
    END IF;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_validar_total_pago_pago ON public.pago;
CREATE CONSTRAINT TRIGGER trg_validar_total_pago_pago
AFTER INSERT OR UPDATE ON public.pago DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION public.validar_total_pago();
DROP TRIGGER IF EXISTS trg_validar_total_pago_detalle ON public.pago_detalle;
CREATE CONSTRAINT TRIGGER trg_validar_total_pago_detalle
AFTER INSERT ON public.pago_detalle DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION public.validar_total_pago();

-- 6) Proteger el registro del pago. Solo se permite pasar de REGISTRADO a ANULADO,
-- o vincular una única vez un pago de reemplazo a un pago ya anulado.
CREATE OR REPLACE FUNCTION public.proteger_pago_historico()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'No se pueden borrar pagos; deben conservarse en el historial.'; END IF;

    IF OLD.estado = 'ANULADO' THEN
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
           OR (OLD.pago_reemplazo_id IS NOT NULL AND NEW.pago_reemplazo_id IS DISTINCT FROM OLD.pago_reemplazo_id)
           OR (NEW.pago_reemplazo_id IS NOT NULL AND NEW.pago_reemplazo_id = OLD.id)
        THEN RAISE EXCEPTION 'El pago anulado es histórico e inmutable; solo se permite vincular su reemplazo una vez.'; END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'REGISTRADO' AND NEW.estado = 'ANULADO' THEN
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.club_id IS DISTINCT FROM OLD.club_id
           OR NEW.socio_id IS DISTINCT FROM OLD.socio_id
           OR NEW.fecha_pago IS DISTINCT FROM OLD.fecha_pago
           OR NEW.importe_total IS DISTINCT FROM OLD.importe_total
           OR NEW.medio_pago IS DISTINCT FROM OLD.medio_pago
           OR NEW.referencia IS DISTINCT FROM OLD.referencia
           OR NEW.registrado_por_usuario_id IS DISTINCT FROM OLD.registrado_por_usuario_id
           OR NEW.observacion IS DISTINCT FROM OLD.observacion
           OR NEW.pago_reemplazo_id IS DISTINCT FROM OLD.pago_reemplazo_id
        THEN RAISE EXCEPTION 'Solo se permite anular un pago sin modificar sus datos originales.'; END IF;
        IF NEW.motivo_anulacion IS NULL OR length(btrim(NEW.motivo_anulacion)) = 0 OR NEW.anulado_por_usuario_id IS NULL OR NEW.fecha_anulacion IS NULL THEN
            RAISE EXCEPTION 'La anulación requiere motivo, usuario y fecha.';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM public.usuario_club uc
            JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
            JOIN public.rol r ON r.id = ucr.rol_id
            WHERE uc.usuario_id = NEW.anulado_por_usuario_id
              AND uc.club_id = NEW.club_id
              AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
        ) THEN RAISE EXCEPTION 'El usuario no tiene un rol autorizado para anular pagos en este club.'; END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Los pagos registrados son inmutables; para corregirlos debe anularlos y registrar otro.';
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_pago_historico ON public.pago;
CREATE TRIGGER trg_proteger_pago_historico
BEFORE UPDATE OR DELETE ON public.pago
FOR EACH ROW EXECUTE FUNCTION public.proteger_pago_historico();

-- 7) Función oficial de anulación: conserva el pago y sus detalles, audita la acción
-- y devuelve las cuotas a pendiente/vencida solo si no quedan cubiertas por otro pago activo.
CREATE OR REPLACE FUNCTION public.anular_pago(p_pago_id BIGINT, p_usuario_id BIGINT, p_motivo TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_club_id BIGINT;
    v_estado VARCHAR(20);
BEGIN
    IF p_motivo IS NULL OR length(btrim(p_motivo)) = 0 THEN RAISE EXCEPTION 'Debe indicar el motivo de anulación.'; END IF;
    SELECT club_id, estado INTO v_club_id, v_estado FROM public.pago WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pago indicado no existe.'; END IF;
    IF v_estado <> 'REGISTRADO' THEN RAISE EXCEPTION 'Solo se pueden anular pagos registrados.'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuario_club uc
        JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
        JOIN public.rol r ON r.id = ucr.rol_id
        WHERE uc.usuario_id = p_usuario_id AND uc.club_id = v_club_id
          AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
    ) THEN RAISE EXCEPTION 'El usuario no tiene autorización para anular pagos en este club.'; END IF;

    PERFORM 1 FROM public.cuota_generada cg
    JOIN public.pago_detalle pd ON pd.cuota_generada_id = cg.id AND pd.club_id = cg.club_id
    WHERE pd.pago_id = p_pago_id ORDER BY cg.id FOR UPDATE OF cg;

    UPDATE public.pago
       SET estado = 'ANULADO', motivo_anulacion = btrim(p_motivo),
           anulado_por_usuario_id = p_usuario_id, fecha_anulacion = CURRENT_TIMESTAMP
     WHERE id = p_pago_id;

    UPDATE public.cuota_generada cg
       SET estado = CASE
           WHEN EXISTS (
               SELECT 1 FROM public.pago_detalle pd2
               JOIN public.pago p2 ON p2.id = pd2.pago_id AND p2.club_id = pd2.club_id
               WHERE pd2.cuota_generada_id = cg.id AND pd2.club_id = cg.club_id
                 AND p2.estado = 'REGISTRADO' AND p2.id <> p_pago_id
           ) THEN 'PAGADA'
           WHEN cg.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDA'
           ELSE 'PENDIENTE'
       END
      FROM public.pago_detalle pd
     WHERE pd.pago_id = p_pago_id AND pd.cuota_generada_id = cg.id AND pd.club_id = cg.club_id;

    INSERT INTO public.auditoria (club_id, usuario_id, tabla_afectada, registro_id, accion, detalle, fecha_hora)
    VALUES (v_club_id, p_usuario_id, 'pago', p_pago_id, 'ANULAR',
            'Motivo: ' || btrim(p_motivo), CURRENT_TIMESTAMP);
END;
$$;

-- 8) Vincular el reemplazo de un pago anulado. El reemplazo debe estar registrado y ser del mismo club.
CREATE OR REPLACE FUNCTION public.vincular_pago_reemplazo(p_pago_anulado_id BIGINT, p_pago_reemplazo_id BIGINT, p_usuario_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_club_id BIGINT;
BEGIN
    IF p_pago_anulado_id = p_pago_reemplazo_id THEN RAISE EXCEPTION 'Un pago no puede reemplazarse a sí mismo.'; END IF;
    SELECT club_id INTO v_club_id FROM public.pago WHERE id = p_pago_anulado_id AND estado = 'ANULADO' AND pago_reemplazo_id IS NULL FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El pago original debe estar anulado y no tener reemplazo vinculado.'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.pago WHERE id = p_pago_reemplazo_id AND club_id = v_club_id AND estado = 'REGISTRADO') THEN
        RAISE EXCEPTION 'El reemplazo debe ser un pago registrado del mismo club.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuario_club uc
        JOIN public.usuario_club_rol ucr ON ucr.usuario_club_id = uc.id
        JOIN public.rol r ON r.id = ucr.rol_id
        WHERE uc.usuario_id = p_usuario_id AND uc.club_id = v_club_id
          AND r.nombre IN ('Tesorería', 'Presidencia', 'Secretaría')
    ) THEN RAISE EXCEPTION 'El usuario no tiene autorización para vincular reemplazos en este club.'; END IF;
    UPDATE public.pago SET pago_reemplazo_id = p_pago_reemplazo_id WHERE id = p_pago_anulado_id;
END;
$$;

COMMIT;

-- IMPORTANTE para la aplicación: crear el pago y todos sus detalles en UNA SOLA transacción.
-- Para anular: SELECT public.anular_pago(id_pago, id_usuario, 'motivo');
-- Para vincular reemplazo: SELECT public.vincular_pago_reemplazo(id_anulado, id_reemplazo, id_usuario);
