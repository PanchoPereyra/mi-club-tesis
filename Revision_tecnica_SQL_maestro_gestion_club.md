# Revision tecnica inicial — SQL maestro de gestion_club

## Archivo revisado
`SQL_maestro_consolidado_gestion_club(1).sql`

## Resultado
- Contiene 24 sentencias `CREATE TABLE`.
- Incluye estructura para club, socios, grupos familiares, disciplinas, inscripciones, asistencia, cuotas, pagos, roles, permisos y auditoria.
- Incluye los campos de anulacion de pagos directamente en la tabla `pago`.
- No se ejecutó contra PostgreSQL; esta revisión es estática y no certifica que el script compile ni que funcione en una base real.

## Diferencia clave entre maestro y migracion
El SQL maestro crea `pago.estado`, `motivo_anulacion`, `anulado_por_usuario_id`, `fecha_anulacion` y `pago_reemplazo_id`.
El esquema actual informado de `gestion_club.pago` no tiene esos campos. Por eso, la migración debe agregarlos con `ADD COLUMN IF NOT EXISTS` y no debe asumir que ya existen.

## Controles que todavía faltan en este maestro
1. Impedir que un pago registrado se edite directamente; las correcciones deben hacerse anulando y registrando otro.
2. Validar de forma transaccional que el importe del pago sea igual a la suma de sus detalles.
3. Validar que cada cuota se pague completa y no pueda quedar cubierta por dos pagos activos, incluso con operaciones simultáneas.
4. Al anular un pago, devolver cada cuota a `PENDIENTE` o `VENCIDA` solo si no existe otro pago activo que la cubra.
5. Registrar la anulación en `auditoria` y exigir motivo, usuario autorizado y fecha.
6. Vincular de manera segura un pago de reemplazo con el pago anulado.
7. Aplicar el alcance de permisos por club y limitar la consulta de deuda del entrenador a sus jugadores; el esquema de permisos por sí solo no implementa esos filtros.

## Observaciones de consistencia
- La base actual reportada contiene 24 tablas, no 25; el maestro crea 24.
- El maestro es para una base nueva. No se debe ejecutar sobre `gestion_club`.
- El script inserta el club Tilcara y roles/permisos globales; no crea usuarios ni asigna automáticamente un usuario a un club.
- Las reglas de generación mensual, recargos, descuentos por hermanos y becas deportivas no quedan implementadas solo con este DDL.

## Próximo paso seguro
Preparar una migración incremental para el esquema existente y probarla en una copia de `gestion_club`. No ejecutar todavía este maestro ni la migración anterior sin corregir y probar los controles anteriores.
