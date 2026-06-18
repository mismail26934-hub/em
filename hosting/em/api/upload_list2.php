<?php
declare(strict_types=1);

$config = require __DIR__ . '/config.php';
require_once __DIR__ . '/lib.php';

fleet_cors_headers('POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    fleet_respond(405, ['ok' => false, 'error' => 'Method not allowed']);
}

$token = $_SERVER['HTTP_X_UPLOAD_TOKEN'] ?? ($_POST['token'] ?? '');
if (!hash_equals((string) $config['upload_secret'], (string) $token)) {
    fleet_respond(403, ['ok' => false, 'error' => 'Token upload tidak valid']);
}

if (!isset($_FILES['file'])) {
    fleet_respond(400, ['ok' => false, 'error' => 'Field file wajib diisi']);
}

$file = $_FILES['file'];
if (!is_array($file) || ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
    $err = is_array($file) ? (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) : UPLOAD_ERR_NO_FILE;
    fleet_respond(400, ['ok' => false, 'error' => 'Upload gagal (kode ' . $err . ')']);
}

$maxBytes = (int) ($config['max_bytes'] ?? (20 * 1024 * 1024));
if ((int) $file['size'] > $maxBytes) {
    fleet_respond(400, ['ok' => false, 'error' => 'File terlalu besar (maks ' . $maxBytes . ' byte)']);
}

$original = (string) ($file['name'] ?? '');
$ext = strtolower(pathinfo($original, PATHINFO_EXTENSION));
if ($ext !== 'xlsx') {
    fleet_respond(400, ['ok' => false, 'error' => 'Hanya file .xlsx yang diizinkan']);
}

$cfg = $config;
$cfg['data_dir'] = (string) ($config['data_dir_list2'] ?? dirname(__DIR__) . '/data/list2');
$cfg['public_base_path'] = (string) ($config['public_base_path_list2'] ?? '/em/data/list2');

try {
    fleet_ensure_data_dir($cfg);
} catch (RuntimeException $e) {
    fleet_respond(500, ['ok' => false, 'error' => $e->getMessage()]);
}

fleet_delete_old_xlsx_files($cfg);

$filename = fleet_sanitize_xlsx_filename($original);
$target = fleet_file_path($cfg, $filename);

if (!move_uploaded_file((string) $file['tmp_name'], $target)) {
    fleet_respond(500, ['ok' => false, 'error' => 'Gagal menyimpan file ke server']);
}

@chmod($target, 0644);

try {
    $meta = fleet_save_list2_name($config, $filename);
} catch (Throwable $e) {
    @unlink($target);
    fleet_respond(500, [
        'ok' => false,
        'error' => 'File tersimpan tetapi gagal update database: ' . $e->getMessage(),
    ]);
}

fleet_respond(200, array_merge(['ok' => true], $meta));
