<?php
declare(strict_types=1);

require_once __DIR__ . '/db.php';

function fleet_respond(int $code, array $payload): void
{
    http_response_code($code);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function fleet_cors_headers(string $methods = 'GET, POST, OPTIONS'): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: ' . $methods);
    header('Access-Control-Allow-Headers: Content-Type, X-Upload-Token');
}

function fleet_data_dir(array $config): string
{
    return (string) ($config['data_dir'] ?? dirname(__DIR__) . '/data/list1');
}

function fleet_ensure_data_dir(array $config): void
{
    $dir = fleet_data_dir($config);
    if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
        throw new RuntimeException('Folder data/list1 tidak dapat dibuat');
    }
}

function fleet_public_base_url(array $config): string
{
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $basePath = rtrim((string) ($config['public_base_path'] ?? '/em/data/list1'), '/');

    return $scheme . '://' . $host . $basePath;
}

function fleet_public_file_url(array $config, string $filename): string
{
    return fleet_public_base_url($config) . '/' . rawurlencode($filename);
}

function fleet_file_path(array $config, string $filename): string
{
    return rtrim(fleet_data_dir($config), DIRECTORY_SEPARATOR)
        . DIRECTORY_SEPARATOR
        . $filename;
}

function fleet_sanitize_xlsx_filename(string $original): string
{
    $base = basename($original);
    $base = preg_replace('/[^a-zA-Z0-9._ -]/', '_', $base) ?? 'upload.xlsx';
    $base = trim(preg_replace('/\s+/', ' ', $base) ?? 'upload.xlsx');
    if ($base === '' || $base === '.' || $base === '..') {
        $base = 'upload.xlsx';
    }

    $ext = strtolower(pathinfo($base, PATHINFO_EXTENSION));
    if ($ext !== 'xlsx') {
        $stem = pathinfo($base, PATHINFO_FILENAME);
        $base = ($stem !== '' ? $stem : 'upload') . '.xlsx';
    }

    return $base;
}

function fleet_delete_old_xlsx_files(array $config): void
{
    $dir = fleet_data_dir($config);
    if (!is_dir($dir)) {
        return;
    }

    foreach (glob(rtrim($dir, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . '*.xlsx') ?: [] as $old) {
        if (is_file($old)) {
            @unlink($old);
        }
    }
}

function fleet_format_datetime(?string $value): string
{
    if ($value === null || trim($value) === '') {
        return gmdate('c');
    }

    try {
        $dt = new DateTimeImmutable($value);
        return $dt->format(DateTimeInterface::ATOM);
    } catch (Exception) {
        return gmdate('c');
    }
}

function fleet_build_current_payload(array $config, string $filename, ?string $updatedAt = null): array
{
    $path = fleet_file_path($config, $filename);
    if (!is_file($path)) {
        throw new RuntimeException('File Excel tidak ditemukan di server');
    }

    return [
        'filename' => $filename,
        'url' => fleet_public_file_url($config, $filename),
        'size' => (int) filesize($path),
        'updated_at' => fleet_format_datetime($updatedAt),
    ];
}

function fleet_read_current_from_db(array $config): ?array
{
    try {
        $pdo = fleet_db_connect($config);
        $stmt = $pdo->query(
            'SELECT id_list1, name_list1, date_upload_list1
             FROM tb_list1
             ORDER BY id_list1 ASC
             LIMIT 1'
        );
        $row = $stmt->fetch();
        if (!is_array($row)) {
            return null;
        }

        $filename = trim((string) ($row['name_list1'] ?? ''));
        if ($filename === '') {
            return null;
        }

        $path = fleet_file_path($config, $filename);
        if (!is_file($path)) {
            return null;
        }

        return array_merge(
            fleet_build_current_payload(
                $config,
                $filename,
                (string) ($row['date_upload_list1'] ?? '')
            ),
            ['id_list1' => (int) ($row['id_list1'] ?? 0)]
        );
    } catch (Throwable) {
        return null;
    }
}

function fleet_save_list1_name(array $config, string $filename): array
{
    $pdo = fleet_db_connect($config);
    $stmt = $pdo->query('SELECT id_list1 FROM tb_list1 ORDER BY id_list1 ASC LIMIT 1');
    $row = $stmt->fetch();

    if (is_array($row) && isset($row['id_list1'])) {
        $update = $pdo->prepare(
            'UPDATE tb_list1
             SET name_list1 = ?, date_upload_list1 = NOW()
             WHERE id_list1 = ?'
        );
        $update->execute([$filename, (int) $row['id_list1']]);
        $id = (int) $row['id_list1'];
    } else {
        $insert = $pdo->prepare(
            'INSERT INTO tb_list1 (name_list1, id_upload_list1, date_upload_list1)
             VALUES (?, 1, NOW())'
        );
        $insert->execute([$filename]);
        $id = (int) $pdo->lastInsertId();
    }

    $dateStmt = $pdo->prepare('SELECT date_upload_list1 FROM tb_list1 WHERE id_list1 = ?');
    $dateStmt->execute([$id]);
    $dateRow = $dateStmt->fetch();
    $updatedAt = is_array($dateRow) ? (string) ($dateRow['date_upload_list1'] ?? '') : '';

    return array_merge(
        fleet_build_current_payload($config, $filename, $updatedAt),
        ['id_list1' => $id]
    );
}
