@php
$slides = [
    [
        'imagen' => asset('img-varias/pelota.jpeg'),
        'titulo' => 'Tu Éxito Comienza Aquí',
        'subtitulo' => 'Soluciones modernas para desafíos globales.',
    ],
    [
        'imagen' => asset('img-varias/pelota2.jpeg'),
        'titulo' => 'Diseño y Funcionalidad',
        'subtitulo' => 'Interfaces intuitivas que enamoran a tus usuarios.',
    ],
    [
        'imagen' => asset('img-varias/prueba1.jpeg'),
        'titulo' => 'Rendimiento Ultra Rápido',
        'subtitulo' => 'Tecnología de vanguardia para una web sin esperas.',
    ],
    [
        'imagen' => asset('img-varias/prueba2.jpeg'),
        'titulo' => 'Pasión y Compromiso',
        'subtitulo' => 'El club crece junto a cada uno de sus socios.',
    ],
];
@endphp

<!-- Estilos Swiper -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.css" />

<style>
    .full-pagination.swiper-pagination-bullets {
        bottom: 16px !important;
    }
    @media (min-width: 640px) {
        .full-pagination.swiper-pagination-bullets {
            bottom: 28px !important;
        }
    }
    .full-pagination .swiper-pagination-bullet {
        background: #cbd5e1 !important;
        opacity: 0.8 !important;
        width: 10px !important;
        height: 10px !important;
        margin: 0 5px !important;
        transition: all 0.3s ease;
    }
    .full-pagination .swiper-pagination-bullet-active {
        background: #ffffff !important;
        opacity: 1 !important;
        transform: scale(1.3);
    }
</style>

<!-- h-[calc(100svh-5rem)]: alto dinámico que resta el Navbar y respeta la barra móvil de los navegadores -->
<section class="relative w-full h-[calc(100svh-5rem)] min-h-[500px] overflow-hidden">
    <div class="swiper fullSwiper w-full h-full">
        <div class="swiper-wrapper">
            @foreach ($slides as $slide)
                <div class="swiper-slide w-full h-full relative overflow-hidden">
                    {{-- Imagen optimizada --}}
                    <img
                        src="{{ $slide['imagen'] }}"
                        alt="{{ $slide['titulo'] }}"
                        class="absolute inset-0 w-full h-full object-cover"
                        loading="lazy"
                    />

                    {{-- Degradé oscuro --}}
                    <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/10 to-black/20 flex flex-col items-center justify-center text-center p-4 sm:p-6">
                        <div class="max-w-3xl w-full px-2 sm:px-6">

                            {{-- Título responsivo --}}
                            <h2 class="text-white text-3xl sm:text-5xl md:text-6xl font-extrabold tracking-tight drop-shadow-md leading-tight">
                                {{ $slide['titulo'] }}
                            </h2>

                            {{-- Subtítulo responsivo --}}
                            <p class="text-zinc-200 text-base sm:text-xl md:text-2xl mt-4 sm:mt-6 font-light drop-shadow max-w-2xl mx-auto">
                                {{ $slide['subtitulo'] }}
                            </p>

                            {{-- Botones adaptables: columna en celular, fila en PC --}}
                            <div class="mt-8 sm:mt-10 flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-4 w-full max-w-sm sm:max-w-none mx-auto">
                                <a
                                    href="#contacto"
                                    class="w-full sm:w-auto text-center rounded-full bg-emerald-600 px-7 py-3 text-sm sm:text-base font-semibold text-white shadow-lg hover:bg-emerald-700 transition-colors"
                                >
                                    Empezar Ahora
                                </a>
                                <a
                                    href="#mas-info"
                                    class="w-full sm:w-auto text-center rounded-full border border-white/30 sm:border-transparent px-6 py-3 text-sm sm:text-base font-semibold text-white hover:bg-white/10 sm:hover:bg-transparent hover:text-zinc-200 transition-colors"
                                >
                                    Más información →
                                </a>
                            </div>

                        </div>
                    </div>
                </div>
            @endforeach
        </div>

        <!-- Flechas: Ocultas en móvil para evitar tapar texto, visibles desde tablet/PC -->
        <button
            id="full-prev"
            type="button"
            class="hidden sm:flex absolute left-4 md:left-6 top-1/2 -translate-y-1/2 z-20 w-11 h-11 md:w-14 md:h-14 rounded-full bg-black/25 text-white/80 items-center justify-center border border-white/20 backdrop-blur-sm hover:bg-black/50 hover:text-white transition-all"
            aria-label="Anterior"
        >
            <svg class="w-6 h-6 md:w-7 md:h-7 stroke-current" fill="none" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
            </svg>
        </button>

        <button
            id="full-next"
            type="button"
            class="hidden sm:flex absolute right-4 md:right-6 top-1/2 -translate-y-1/2 z-20 w-11 h-11 md:w-14 md:h-14 rounded-full bg-black/25 text-white/80 items-center justify-center border border-white/20 backdrop-blur-sm hover:bg-black/50 hover:text-white transition-all"
            aria-label="Siguiente"
        >
            <svg class="w-6 h-6 md:w-7 md:h-7 stroke-current" fill="none" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
        </button>

        <!-- Paginación -->
        <div class="swiper-pagination full-pagination"></div>
    </div>
</section>

<!-- Script de inicialización Swiper -->
<script type="module">
    import Swiper from "https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.mjs";

    new Swiper(".fullSwiper", {
        loop: true,
        slidesPerView: 1,
        spaceBetween: 0,
        effect: "fade",
        fadeEffect: {
            crossFade: true,
        },
        autoplay: {
            delay: 5000,
            disableOnInteraction: false,
        },
        navigation: {
            nextEl: "#full-next",
            prevEl: "#full-prev",
        },
        pagination: {
            el: ".full-pagination",
            clickable: true,
        },
    });
</script>
