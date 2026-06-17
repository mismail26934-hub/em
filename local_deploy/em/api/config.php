<?php
/**
 * Fleet EM Dashboard — server config.
 * Deploy folder `hosting/em/` to https://strakin.tech/em/
 */
return [
    'upload_secret' => 'fleet-em-change-me',
    'data_dir' => dirname(__DIR__) . '/data/list1',
    'public_base_path' => '/em/data/list1',
    'max_bytes' => 20 * 1024 * 1024,

    'db_host' => 'localhost',
    'db_name' => 'db_em',
    'db_user' => 'root',
    'db_pass' => '',
];
