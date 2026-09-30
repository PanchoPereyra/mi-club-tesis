<header class="sticky top-0 z-50 w-full bg-white border-b border-zinc-100 shadow-sm">
    <div class="relative w-full flex h-20 items-center justify-between px-6 sm:px-10 lg:px-12">

        <!-- 1. Extremo Izquierdo: Escudo -->
        <a href="/" class="flex items-center shrink-0">
            <img
                src="{{ asset('img-inst/escudo-club.png') }}"
                alt="Escudo del Club"
                class="h-14 w-auto object-contain hover:opacity-90 transition-opacity"
            />
        </a>

        <!-- 2. Botón Hamburguesa (solo visible en celulares) -->
        <button
            id="btn-menu"
            type="button"
            class="md:hidden p-2 rounded-lg text-slate-700 hover:bg-slate-100 focus:outline-none transition-colors"
            aria-label="Abrir menú"
        >
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
        </button>

        <!-- 3. UN SOLO MENÚ (se transforma según el tamaño de pantalla) -->
        <div
            id="menu-principal"
            class="hidden md:flex absolute md:static top-20 left-0 w-full md:w-auto flex-col md:flex-row md:items-center md:justify-between md:flex-1 md:ml-12 bg-white md:bg-transparent border-b md:border-none border-slate-100 p-6 md:p-0 shadow-xl md:shadow-none gap-6 md:gap-0"
        >
            <!-- Enlaces (en PC se centran con md:mx-auto) -->
            <nav class="flex flex-col md:flex-row items-start md:items-center gap-4 lg:gap-8 text-base md:text-sm font-medium text-slate-700 md:mx-auto">
                <a href="/autoridades" class="hover:text-emerald-600 transition-colors">Autoridades</a>
                <a href="/historia" class="hover:text-emerald-600 transition-colors">Historia</a>
                <a href="/galeria" class="hover:text-emerald-600 transition-colors">Galería</a>
                <a href="/contacto" class="hover:text-emerald-600 transition-colors">Contacto</a>
                <a href="/beneficios" class="hover:text-emerald-600 transition-colors">Beneficios</a>
                <a href="/entrenadores" class="hover:text-emerald-600 transition-colors">Entrenadores</a>
            </nav>

            <!-- Botones (en PC quedan empujados al extremo derecho) -->
            <div class="flex flex-col md:flex-row items-stretch md:items-center gap-3 pt-4 md:pt-0 border-t md:border-none border-slate-100">
                <a
                    href="/login"
                    class="text-center rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-emerald-600 hover:text-white hover:border-emerald-600 transition-colors"
                >
                    Ingresar
                </a>
                <a
                    href="/registro"
                    class="text-center rounded-lg bg-[#0d1424] px-4 py-2 text-sm font-medium text-white hover:bg-emerald-600 transition-colors shadow-sm"
                >
                    Registro
                </a>
            </div>
        </div>

    </div>
</header>

<script>
    document.addEventListener('DOMContentLoaded', () => {
        const btn = document.getElementById('btn-menu');
        const menu = document.getElementById('menu-principal');

        if (btn && menu) {
            btn.addEventListener('click', () => {
                menu.classList.toggle('hidden');
                menu.classList.toggle('flex');
            });
        }
    });
</script>
