<?php

use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

require __DIR__.'/../vendor/autoload.php';

$storagePath = sys_get_temp_dir().'/laravel';

if (! is_dir($storagePath.'/framework/views')) {
    mkdir($storagePath.'/framework/views', 0775, true);
}

$app = require_once __DIR__.'/../bootstrap/app.php';
$app->useStoragePath($storagePath);
$app->handleRequest(Request::capture());
