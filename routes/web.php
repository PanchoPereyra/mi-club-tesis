<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return 'HOME FUNCIONA';
});

Route::get('/prueba-laravel', function () {
    return 'LARAVEL FUNCIONA';
});
