<footer class="bg-gray-900 text-white mt-16">
    <!-- 1. Sección de Newsletter -->
    {{-- <div class="border-b border-gray-800">
        <div class="container mx-auto px-4 py-8">
            <div class="max-w-2xl mx-auto text-center">
                <!-- Icono Mail -->
                <svg class="w-10 h-10 text-emerald-500 mx-auto mb-3" fill="none" viewBox="0 0 24 24"
                    stroke="currentColor" stroke-width="2">
                    <rect width="20" height="16" x="2" y="4" rx="2" />
                    <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                </svg>

                <h3 class="text-2xl font-semibold mb-2">Newsletter</h3>
                <p class="text-gray-400 mb-6">
                    Recibe las últimas noticias, eventos y novedades del club
                </p>

                <form id="form-newsletter" class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
                    @csrf
                    <input type="email" id="newsletter-email" placeholder="Tu dirección de email" required
                        class="w-full rounded-lg bg-gray-800 border border-gray-700 px-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500 text-sm" />
                    <button type="submit"
                        class="shrink-0 rounded-lg bg-emerald-600 hover:bg-emerald-700 px-8 py-2.5 text-sm font-semibold text-white transition-colors shadow-sm">
                        Suscribirse
                    </button>
                </form>

                <p id="newsletter-msg" class="hidden text-emerald-400 text-sm mt-3 font-medium">
                    ¡Te has suscrito al newsletter exitosamente!
                </p>
            </div>
        </div>
    </div> --}}

    {{-- ************************************************************************************************************** --}}
    <!-- 2. Footer Principal -->
    <div class="container mx-auto px-4 py-12">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 lg:gap-12">

            <!-- Columna 1: Contacto -->
            <div class="flex flex-col items-start">
                <h4 class="font-semibold text-lg mb-4 text-white">Contacto</h4>
                <div class="space-y-4">

                    <!-- Predio Ramón Brandolín -->
                    <div class="space-y-1">
                        <p class="flex items-center gap-2 text-sm font-semibold text-emerald-400">
                            <!-- MapPin Icon -->
                            <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"
                                stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round"
                                    d="M12 2a8 8 0 0 0-8 8c0 5.25 8 12 8 12s8-6.75 8-12a8 8 0 0 0-8-8z" />
                                <circle cx="12" cy="10" r="3" />
                            </svg>
                            Predio Deportivo "Ramón Brandolín"
                        </p>
                        <p class="text-sm text-gray-300 ml-6">Martín Zapata y Delfín Huergo</p>
                        <p class="text-sm text-gray-300 ml-6">Paraná, Entre Ríos</p>
                        <a href="https://www.google.com/maps?q=-31.747474,-60.503494" target="_blank"
                            rel="noopener noreferrer"
                            class="text-xs text-emerald-400 hover:text-emerald-300 ml-6 inline-block transition-colors">
                            Ver en Google Maps →
                        </a>
                    </div>

                    <!-- Sede Quincho -->
                    <div class="space-y-1">
                        <p class="flex items-center gap-2 text-sm font-semibold text-emerald-400">
                            <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"
                                stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round"
                                    d="M12 2a8 8 0 0 0-8 8c0 5.25 8 12 8 12s8-6.75 8-12a8 8 0 0 0-8-8z" />
                                <circle cx="12" cy="10" r="3" />
                            </svg>
                            Sede Quincho - Ruta 18 Km 18.4
                        </p>
                        <p class="text-sm text-gray-300 ml-6">Dr. René Favaloro - Barrio Tilcara</p>
                        <p class="text-sm text-gray-300 ml-6">Sauce Montrull, Dpto. Paraná, Entre Ríos</p>
                        <a href="https://www.google.com/maps?q=-31.771385335222124,-60.37031806565626" target="_blank"
                            rel="noopener noreferrer"
                            class="text-xs text-emerald-400 hover:text-emerald-300 ml-6 inline-block transition-colors">
                            Ver en Google Maps →
                        </a>
                    </div>

                    <!-- Teléfonos -->
                    <div class="space-y-1">
                        <p class="flex items-center gap-2 text-sm text-gray-300">
                            <!-- Phone Icon -->
                            <svg class="w-4 h-4 shrink-0 text-emerald-400" fill="none" viewBox="0 0 24 24"
                                stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round"
                                    d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
                            </svg>
                            <a href="tel:+543431234567" class="hover:text-emerald-400 transition-colors">+54 343 123
                                4567</a>
                        </p>
                        <p class="flex items-center gap-2 text-sm ml-6 text-gray-300">
                            <a href="tel:+543432345678" class="hover:text-emerald-400 transition-colors">+54 343 234
                                5678</a>
                        </p>
                    </div>

                    <!-- Email -->
                    <p class="flex items-center gap-2 text-sm text-gray-300">
                        <svg class="w-4 h-4 shrink-0 text-emerald-400" fill="none" viewBox="0 0 24 24"
                            stroke="currentColor" stroke-width="2">
                            <rect width="20" height="16" x="2" y="4" rx="2" />
                            <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                        </svg>
                        <a href="mailto:admin@clubtilcara.com.ar" class="hover:text-emerald-400 transition-colors">
                            admin@clubtilcara.com.ar
                        </a>
                    </p>
                </div>
            </div>

            {{-- ************************************************************************************************************** --}}
            <!-- Columna 2: Redes Sociales -->
            <div class="flex flex-col ">
                <h4 class="flex flex-col items-center text-center font-semibold text-lg mb-4 text-white">Síguenos</h4>
                <div class="flex justify-center gap-4">
                    <!-- Instagram -->
                    <a href="https://www.instagram.com/clubtilcara/" target="_blank" rel="noopener noreferrer"
                        class="text-gray-400 hover:text-emerald-400 transition-colors"
                        aria-label="Instagram Club Tilcara">
                        <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <rect width="20" height="20" x="2" y="2" rx="5" ry="5" />
                            <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z" />
                            <line x1="17.5" x2="17.51" y1="6.5" y2="6.5" />
                        </svg>
                    </a>

                    <!-- YouTube -->
                    <a href="https://www.youtube.com/@clubtilcararugby-hockey9629" target="_blank"
                        rel="noopener noreferrer" class="text-gray-400 hover:text-emerald-400 transition-colors"
                        aria-label="YouTube Club Tilcara">
                        <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                            <path
                                d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" />
                        </svg>
                    </a>

                    <!-- Facebook -->
                    <a href="https://www.facebook.com/clubtilcara/" target="_blank" rel="noopener noreferrer"
                        class="text-gray-400 hover:text-emerald-400 transition-colors"
                        aria-label="Facebook Club Tilcara">
                        <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                            <path
                                d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                        </svg>
                    </a>
                </div>
                <div class="mt-6 text-center">
                    <p class="text-sm font-semibold text-emerald-400">#verdeTILCARA</p>
                    <p class="text-sm mt-2 text-white">Club Tilcara</p>
                    <p class="text-sm text-gray-400">1954 - {{ date('Y') }}</p>
                </div>

            </div>

        </div>
    </div>

    <!-- 3. Acceso Admin + Copyright -->
    <div class="border-t border-emerald-950 py-6">
        <div class="container mx-auto px-4">
            <div class="text-center mb-3">
                <a href="/admin/login"
                    class="text-gray-600 hover:text-gray-400 text-xs transition-colors duration-300 inline-block">
                    Panel de Administración
                </a>
            </div>
            <p class="text-center text-xs sm:text-sm text-gray-500">
                © Diseño Gráfico / Diseño WEB / Luciano Cassano | Desarrollo / Sigma Ingeniería | Todos los derechos
                reservados.
            </p>
        </div>
    </div>
</footer>

<!-- Script interactivo simple para simular el toast/alerta del newsletter -->
<script>
    document.getElementById('form-newsletter')?.addEventListener('submit', function (e) {
        e.preventDefault();
        const input = document.getElementById('newsletter-email');
        const msg = document.getElementById('newsletter-msg');
        if (input && input.value) {
            input.value = '';
            msg?.classList.remove('hidden');
            setTimeout(() => {
                msg?.classList.add('hidden');
            }, 4000);
        }
    });
</script>
