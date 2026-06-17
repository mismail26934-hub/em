<?php
declare(strict_types=1);

function fleet_db_connect(array $config): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $host = (string) ($config['db_host'] ?? 'localhost');
    $name = (string) ($config['db_name'] ?? 'db_em');
    $user = (string) ($config['db_user'] ?? 'root');
    $pass = (string) ($config['db_pass'] ?? '');

    $dsn = sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', $host, $name);
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);

    return $pdo;
}
