# Consolidacion SQL - Gestion de Clubes

Se generaron dos archivos a partir del borrador aportado y de la estructura real inspeccionada en DBeaver.

## Archivos

- `SQL_maestro_referencia_limpio.sql`: copia limpia del borrador original para referencia/creacion en una base vacia. No ejecutarlo completo sobre `gestion_club`. Todavia requiere reconciliar el esquema maestro con todas las diferencias de la base actual.
- `01_migracion_anulacion_pagos_gestion_club.sql`: migracion incremental enfocada en el flujo de anulacion de pagos, escrita para los nombres de columnas reales que el usuario compartio. No crea de nuevo las tablas principales.

## Decisiones incluidas en la migracion

- El pago se anula completo y conserva su registro y detalles.
- El motivo, usuario y fecha de anulacion son obligatorios.
- Las cuotas se liberan y regresan a `PENDIENTE` o `VENCIDA`.
- El mismo detalle historico no se borra; la validacion impide dos pagos registrados para la misma cuota.
- El pago de reemplazo es opcional y queda vinculado al original.
- Solo Tesoreria, Presidencia y Secretaria reciben el permiso `pago.anular`.
- La migracion no hace devoluciones de dinero.

## Advertencia

La migracion SQL fue preparada a partir de las columnas y restricciones compartidas en la conversacion, pero no se ha ejecutado contra la base real ni se puede afirmar que haya pasado pruebas de integracion. Hacer backup y probar primero en una copia. En particular, validar que las tablas `permiso`, `rol_permiso`, `usuario_club_rol` y `auditoria` tengan las columnas descritas por las consultas previas.
