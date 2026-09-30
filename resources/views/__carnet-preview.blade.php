<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Carnet Digital - Club Tilcara</title>

    <!-- Esto es lo que faltaba para que carguen todos los estilos de Tailwind -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="bg-slate-100 min-h-screen flex items-center justify-center p-4">

    <div class="w-full max-w-sm">

        <!-- Tarjeta Carnet Digital -->
        <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-slate-900 via-slate-800 to-emerald-950 p-6 text-white shadow-2xl border border-emerald-500/30">
            <!-- Efecto de luz difuminada de fondo -->
            <div class="absolute -right-8 -top-8 h-36 w-36 rounded-full bg-emerald-500/10 blur-2xl pointer-events-none"></div>

            <!-- Cabecera del Carnet -->
            <div class="flex items-center justify-between border-b border-white/10 pb-4">
                <div class="flex items-center gap-3">
                    <img
                        src="{{ asset('img-inst/escudo-club.png') }}"
                        class="h-10 w-auto object-contain"
                        alt="Escudo Club Tilcara"
                    >
                    <div>
                        <h3 class="font-bold text-sm tracking-wide text-white">CLUB TILCARA</h3>
                        <p class="text-[10px] text-emerald-400 font-mono tracking-wider">CARNET DIGITAL</p>
                    </div>
                </div>
                <span class="rounded-full bg-emerald-500/20 px-2.5 py-0.5 text-[11px] font-semibold text-emerald-400 border border-emerald-500/40">
                    AL DÍA
                </span>
            </div>

            <!-- Datos del Socio -->
            <div class="mt-5 flex gap-4 items-center">
                <div class="h-20 w-20 rounded-xl bg-slate-700/60 border border-white/20 flex items-center justify-center text-2xl font-bold text-slate-300 shrink-0">
                    JP
                </div>
                <div class="overflow-hidden">
                    <h2 class="text-base font-bold text-white truncate">Juan Ignacio Pérez</h2>
                    <p class="text-xs text-slate-300">Socio N°: <span class="text-white font-mono font-medium">04821</span></p>
                    <p class="text-xs text-slate-300">DNI: <span class="text-white font-mono font-medium">38.452.120</span></p>
                    <p class="text-xs text-emerald-300 mt-1 font-medium">Rugby • Plantel Superior</p>
                </div>
            </div>

            <!-- Código QR y Validez -->
            <div class="mt-6 flex items-center justify-between border-t border-white/10 pt-4">
                <div>
                    <p class="text-[10px] text-slate-400 uppercase tracking-wider">Validez</p>
                    <p class="text-xs font-semibold text-white">Septiembre 2026</p>
                </div>
                <div class="h-12 w-12 bg-white rounded-lg p-1 flex items-center justify-center shadow">
                    <div class="w-full h-full bg-slate-900 rounded flex items-center justify-center text-[9px] text-white font-mono font-bold">
                        QR
                    </div>
                </div>
            </div>
        </div>

        <!-- Módulo de Pago debajo de la credencial -->
        <div class="mt-4 rounded-xl bg-white p-4 shadow-sm border border-slate-200">
            <div class="flex justify-between items-center text-sm">
                <span class="text-slate-600">Total Período Actual:</span>
                <span class="font-bold text-slate-900">$ 32.000</span>
            </div>
            <button type="button" class="mt-3 w-full rounded-lg bg-emerald-600 py-2.5 text-center text-sm font-semibold text-white shadow hover:bg-emerald-700 transition">
                Pagar con Mercado Pago
            </button>
        </div>

    </div>

</body>
</html>
