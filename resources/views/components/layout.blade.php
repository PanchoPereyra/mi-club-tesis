@props([
    'titulo' => 'Club Tilcara',
    'descripcion' => 'Sitio web desarrollado con Laravel'
])

<!doctype html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="{{ $descripcion }}" />
    <title>{{ $titulo }}</title>

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="bg-white text-slate-900">

    {{-- <x-navbar />

    <x-hero /> --}}

    {{-- <x-actividades /> --}}

    <main>
        {{ $slot ?? '' }}
    </main>
    
</body>
</html>
