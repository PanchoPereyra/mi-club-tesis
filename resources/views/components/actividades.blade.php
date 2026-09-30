@php
$actividadesData = [
    [
        'titulo' => 'Rugby',
        'imagen' => asset('img-varias/prueba1.jpeg'),
        'link' => '/actividades/rugby',
    ],
    [
        'titulo' => 'Hockey',
        'imagen' => asset('img-varias/hockey.jpg'),
        'link' => '/actividades/hockey',
    ],
    [
        'titulo' => 'Gym',
        'imagen' => asset('img-varias/gimnasio.png'),
        'link' => '/actividades/gym',
    ],
];
@endphp

<section class="max-w-6xl mx-auto px-4 py-12 sm:px-6 lg:py-16">
    <div class="text-center mb-10 sm:mb-12">
        <h2 class="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
            Actividades
        </h2>
    </div>

    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        @foreach ($actividadesData as $actividad)
            <a href="{{ $actividad['link'] }}" class="group relative block overflow-hidden rounded-xl shadow-md transition-shadow hover:shadow-xl">
                <div class="relative h-60 w-full overflow-hidden sm:h-72">
                    <img
                        src="{{ $actividad['imagen'] }}"
                        alt="Imagen de la actividad {{ $actividad['titulo'] }}"
                        class="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                    />
                    <div class="absolute inset-0 bg-emerald-950/70 transition-opacity group-hover:opacity-80"></div>
                </div>

                <div class="absolute inset-x-0 bottom-0 p-6 flex items-end">
                    <h3 class="text-2xl font-bold text-white tracking-tight drop-shadow-md">
                        {{ $actividad['titulo'] }}
                    </h3>
                </div>
            </a>
        @endforeach
    </div>
</section>
