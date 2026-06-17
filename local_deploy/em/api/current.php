<?php
declare(strict_types=1);

$config = require __DIR__ . '/config.php';
require_once __DIR__ . '/lib.php';

fleet_cors_headers('GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fleet_respond(405, ['ok' => false, 'error' => 'Method not allowed']);
}

$current = fleet_read_current_from_db($config);
if ($current === null) {
    fleet_respond(404, [
        'ok' => false,
        'error' => 'Belum ada file Excel aktif di tb_list1',
    ]);
}

fleet_respond(200, array_merge(['ok' => true], $current));
