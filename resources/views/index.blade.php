<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Club Tilcara</title>

    {{-- Carga de Tailwind y estilos compilados por Vite --}}
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="bg-white text-slate-900">

    {{-- 1. Navbar --}}
    <x-navbar />

    {{-- 2. Hero con carrusel --}}
    <x-hero />
    {{-- <h2 class="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl text-center mt-10">
        Actividades
    </h2> --}} --}}

    {{-- 3. Actividades --}}
    <x-actividades />

        {{-- 4. Footer --}}
    <x-footer />

</body>
</html>
