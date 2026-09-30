<?php

use Illuminate\Support\Facades\Route;

Route::view('/', 'index')->name('home');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::view('dashboard', 'dashboard')->name('dashboard');
});

// Route::get('/preview-carnet', function () {
//     return view('carnet-preview');
// });

require __DIR__.'/settings.php';
